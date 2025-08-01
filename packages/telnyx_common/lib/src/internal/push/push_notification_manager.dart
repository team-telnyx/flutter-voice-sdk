import 'dart:async';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:telnyx_webrtc/model/push_notification.dart';

import 'push_notification_gateway.dart';
import '../callkit/callkit_event_handler.dart';
import 'notification_display_service.dart';
import 'push_token_provider.dart';
import 'default_push_token_provider.dart';
import '../callkit/callkit_adapter_bridge.dart';
import '../../utils/background_detector.dart';

/// Configuration for the push notification manager.
class PushNotificationManagerConfig {
  /// Whether to enable native call UI integration (CallKit on iOS, ConnectionService on Android).
  ///
  /// When enabled (default: true):
  /// - Shows system-native incoming call screens
  /// - Integrates with device's call history
  /// - Provides native call control buttons (accept/decline/mute/speaker)
  /// - Handles call audio routing through the system
  ///
  /// When disabled:
  /// - No native UI is shown
  /// - App must handle all call UI through custom implementation
  /// - Useful for apps that want complete control over call presentation
  final bool enableNativeUI;

  /// Whether to enable background push notification handling.
  ///
  /// When enabled (default: true):
  /// - Push notifications are processed even when app is in background/terminated
  /// - Enables VoIP push notifications to wake the app
  /// - Allows receiving calls when app is not actively running
  ///
  /// When disabled:
  /// - Push notifications only work when app is in foreground
  /// - Incoming calls may be missed if app is backgrounded
  /// - Reduces battery usage but limits call availability
  final bool enableBackgroundHandling;

  /// Optional configuration for notification display customization.
  ///
  /// Allows customizing:
  /// - Notification icons and colors
  /// - Call screen appearance
  /// - Audio settings and ringtones
  /// - Text and localization
  ///
  /// If null, uses default system notification settings.
  final NotificationConfig? notificationConfig;

  /// Optional custom push token provider for platform-specific token management.
  ///
  /// Use this to:
  /// - Implement custom Firebase/APNS token handling
  /// - Add token validation or transformation logic
  /// - Integrate with custom push notification services
  ///
  /// If null, uses DefaultPushTokenProvider which handles standard FCM/APNS tokens.
  final PushTokenProvider? customTokenProvider;

  /// Timeout in seconds for determining if a push notification is stale.
  ///
  /// Default: 30 seconds
  ///
  /// When a push notification is older than this timeout:
  /// - It's considered "stale" and won't show as an incoming call
  /// - Instead shows as a missed call notification
  /// - Prevents showing outdated call invitations
  ///
  /// This prevents users from accidentally answering calls that have already ended.
  final int staleNotificationTimeoutSeconds;

  /// Whether to enable immediate decline from push notifications.
  ///
  /// Default: true (enabled)
  ///
  /// When enabled and push contains isDecline=true:
  /// - Call is declined immediately without showing UI
  /// - Connects with decline_push parameter to server
  /// - Allows declining calls without waiting for full invite
  ///
  /// When disabled:
  /// - All declines require full connection and invite processing
  /// - Slightly slower decline response time
  ///
  /// This feature improves user experience by enabling instant call rejection.
  final bool enableDeclinePush;

  const PushNotificationManagerConfig({
    this.enableNativeUI = true,
    this.enableBackgroundHandling = true,
    this.notificationConfig,
    this.customTokenProvider,
    this.staleNotificationTimeoutSeconds = 30,
    this.enableDeclinePush = true,
  });
}

/// Comprehensive push notification manager that coordinates all push notification
/// functionality including token management, event handling, and UI display.
///
/// This manager provides a unified entry point for all push notification operations
/// and handles platform-specific differences internally.
class PushNotificationManager {
  final PushNotificationManagerConfig _config;

  // Core components
  late final PushNotificationGateway _gateway;
  late final CallKitEventHandler _eventHandler;
  late final NotificationDisplayService _displayService;
  late final PushTokenProvider _tokenProvider;
  late final CallKitAdapterBridge _callKitBridge;

  // State management
  bool _initialized = false;
  bool _disposed = false;
  String? _currentToken;

  // Event callbacks
  PushNotificationCallback? _onPushNotificationProcessed;
  Function(String callId, Map<String, dynamic> extra)?
      _onPushNotificationAccepted;
  Function(String callId, Map<String, dynamic> extra)?
      _onPushNotificationDeclined;
  Function(String token)? _onTokenRefresh;

  // Action callbacks for foreground calls
  Function(String callId)? _onForegroundCallAccepted;
  Function(String callId)? _onForegroundCallDeclined;
  Function(String callId)? _onForegroundCallEnded;

  /// Creates a new push notification manager with the given configuration.
  PushNotificationManager({
    PushNotificationManagerConfig? config,
  }) : _config = config ?? const PushNotificationManagerConfig();

  /// Initializes the push notification manager.
  ///
  /// This method sets up all necessary components for handling push notifications
  /// including token providers, event handlers, and display services.
  Future<void> initialize({
    PushNotificationCallback? onPushNotificationProcessed,
    Function(String callId, Map<String, dynamic> extra)?
        onPushNotificationAccepted,
    Function(String callId, Map<String, dynamic> extra)?
        onPushNotificationDeclined,
    Function(String token)? onTokenRefresh,
    Function(String callId)? onForegroundCallAccepted,
    Function(String callId)? onForegroundCallDeclined,
    Function(String callId)? onForegroundCallEnded,
  }) async {
    if (_initialized || _disposed) return;

    try {
      debugPrint('PushNotificationManager: Starting initialization...');

      _onPushNotificationProcessed = onPushNotificationProcessed;
      _onPushNotificationAccepted = onPushNotificationAccepted;
      _onPushNotificationDeclined = onPushNotificationDeclined;
      _onTokenRefresh = onTokenRefresh;
      _onForegroundCallAccepted = onForegroundCallAccepted;
      _onForegroundCallDeclined = onForegroundCallDeclined;
      _onForegroundCallEnded = onForegroundCallEnded;

      // Initialize core components
      await _initializeComponents();

      // Set up event handlers
      _setupEventHandlers();

      // Get initial token
      await _initializeToken();

      _initialized = true;
      debugPrint('PushNotificationManager: Initialization completed');
    } catch (e) {
      debugPrint('PushNotificationManager: Error during initialization: $e');
      rethrow;
    }
  }

  /// Initializes all core components.
  Future<void> _initializeComponents() async {
    // Initialize token provider - use custom provider if provided, otherwise use default
    _tokenProvider = _config.customTokenProvider ?? DefaultPushTokenProvider();

    // Initialize display service if native UI is enabled
    if (_config.enableNativeUI) {
      _displayService = NotificationDisplayService(
        config: _config.notificationConfig,
      );
      await _displayService.initialize();
    } else {
      _displayService = _NoOpNotificationDisplayService();
    }

    // Initialize event handler
    _eventHandler = CallKitEventHandler();
    await _eventHandler.initialize();

    // Initialize CallKit bridge that connects new architecture with existing CallKitAdapter
    _callKitBridge = CallKitAdapterBridge(
      displayService: _displayService,
      eventHandler: _eventHandler,
      onCallAccepted: _handleCallAccepted,
      onCallDeclined: _handleCallDeclined,
      onCallEnded: _handleCallEnded,
    );
    await _callKitBridge.initialize();

    // Initialize gateway with the bridge and event handler
    _gateway = PushNotificationGateway(
      _callKitBridge,
      onPushNotificationProcessed: (pushMetaData) {
        _onPushNotificationProcessed?.call(pushMetaData);
      },
    );

    debugPrint('PushNotificationManager: Components initialized');
  }

  /// Sets up event handlers for CallKit events.
  void _setupEventHandlers() {
    if (!_config.enableNativeUI) return;

    _eventHandler.setEventCallbacks(
      onCallAccept: (callId, extra) {
        debugPrint('PushNotificationManager: Call accepted - $callId');
        _handleCallAcceptEvent(callId, extra);
      },
      onCallDecline: (callId, extra) {
        debugPrint('PushNotificationManager: Call declined - $callId');
        _handleCallDeclineEvent(callId, extra);
      },
      onCallEnd: (callId, extra) {
        debugPrint('PushNotificationManager: Call ended - $callId');
        _handleCallEndEvent(callId, extra);
      },
      onCallTimeout: (callId, extra) {
        debugPrint('PushNotificationManager: Call timeout - $callId');
        _handleCallTimeoutEvent(callId, extra);
      },
      onCallIncoming: (callId, extra) {
        debugPrint('PushNotificationManager: Call incoming - $callId');
        _handleCallIncomingEvent(callId, extra);
      },
    );
  }

  /// Initializes push token and sets up refresh listener.
  Future<void> _initializeToken() async {
    try {
      // Get initial token
      _currentToken = await _tokenProvider.getToken();
      if (_currentToken != null) {
        debugPrint('PushNotificationManager: Initial token retrieved');
        _onTokenRefresh?.call(_currentToken!);
      }

      // Set up token refresh listener
      await _tokenProvider.setupTokenRefreshListener((newToken) {
        _currentToken = newToken;
        debugPrint('PushNotificationManager: Token refreshed');
        _onTokenRefresh?.call(newToken);
      });
    } catch (e) {
      debugPrint('PushNotificationManager: Error initializing token: $e');
    }
  }

  /// Handles incoming push notifications.
  ///
  /// [payload] - The raw push notification payload
  Future<void> handlePushNotification(Map<String, dynamic> payload) async {
    if (!_initialized || _disposed) {
      debugPrint(
          'PushNotificationManager: Manager not initialized, ignoring push notification');
      return;
    }

    try {
      debugPrint(
          'PushNotificationManager: Handling push notification: ${payload.keys}');
      await _gateway.handlePushNotification(payload);
    } catch (e) {
      debugPrint(
          'PushNotificationManager: Error handling push notification: $e');
    }
  }

  /// Displays an incoming call UI manually.
  ///
  /// [callId] - Unique identifier for the call
  /// [callerName] - Name of the caller
  /// [callerNumber] - Phone number of the caller
  /// [extra] - Additional metadata for the call
  Future<void> showIncomingCall({
    required String callId,
    required String callerName,
    required String callerNumber,
    Map<String, dynamic> extra = const {},
  }) async {
    if (!_config.enableNativeUI || !_initialized || _disposed) return;

    try {
      await _displayService.showIncomingCall(
        callId: callId,
        callerName: callerName,
        callerNumber: callerNumber,
        extra: extra,
      );
    } catch (e) {
      debugPrint('PushNotificationManager: Error showing incoming call: $e');
    }
  }

  /// Displays an outgoing call UI manually.
  ///
  /// [callId] - Unique identifier for the call
  /// [callerName] - Name of the caller (local user)
  /// [destination] - Destination number being called
  /// [extra] - Additional metadata for the call
  Future<void> showOutgoingCall({
    required String callId,
    required String callerName,
    required String destination,
    Map<String, dynamic> extra = const {},
  }) async {
    if (!_config.enableNativeUI || !_initialized || _disposed) return;

    try {
      await _displayService.showOutgoingCall(
        callId: callId,
        callerName: callerName,
        destination: destination,
        extra: extra,
      );
    } catch (e) {
      debugPrint('PushNotificationManager: Error showing outgoing call: $e');
    }
  }

  /// Ends a call notification.
  ///
  /// [callId] - Unique identifier for the call to end
  Future<void> endCall(String callId) async {
    if (!_config.enableNativeUI || !_initialized || _disposed) return;

    try {
      await _displayService.endCall(callId);
    } catch (e) {
      debugPrint('PushNotificationManager: Error ending call: $e');
    }
  }

  /// Gets the current push token.
  String? get currentToken => _currentToken;

  /// Refreshes the push token.
  Future<String?> refreshToken() async {
    if (!_initialized || _disposed) return null;

    try {
      _currentToken = await _tokenProvider.getToken();
      if (_currentToken != null) {
        _onTokenRefresh?.call(_currentToken!);
      }
      return _currentToken;
    } catch (e) {
      debugPrint('PushNotificationManager: Error refreshing token: $e');
      return null;
    }
  }

  // CallKit bridge event handlers
  void _handleCallAccepted(String callId) {
    debugPrint(
        'PushNotificationManager: Call accepted via CallKit bridge - $callId');
    // Call the foreground action callback if available
    if (_onForegroundCallAccepted != null) {
      debugPrint(
          'PushNotificationManager: Calling foreground call accepted callback');
      _onForegroundCallAccepted!(callId);
    } else {
      debugPrint(
          'PushNotificationManager: No foreground call accepted callback available');
    }
  }

  void _handleCallDeclined(String callId) {
    debugPrint(
        'PushNotificationManager: Call declined via CallKit bridge - $callId');
    // Call the foreground action callback if available
    if (_onForegroundCallDeclined != null) {
      debugPrint(
          'PushNotificationManager: Calling foreground call declined callback');
      _onForegroundCallDeclined!(callId);
    } else {
      debugPrint(
          'PushNotificationManager: No foreground call declined callback available');
    }
  }

  void _handleCallEnded(String callId) {
    debugPrint(
        'PushNotificationManager: Call ended via CallKit bridge - $callId');
    // Call the foreground action callback if available
    if (_onForegroundCallEnded != null) {
      debugPrint(
          'PushNotificationManager: Calling foreground call ended callback');
      _onForegroundCallEnded!(callId);
    } else {
      debugPrint(
          'PushNotificationManager: No foreground call ended callback available');
    }
  }

  // Event handlers for CallKitEventHandler callbacks
  void _handleCallAcceptEvent(String callId, Map<String, dynamic> extra) {
    BackgroundDetector.ignore = true;

    // [PUSH-DIAG] Log accept event processing
    debugPrint('[PUSH-DIAG] PushManager: _handleCallAcceptEvent called');
    debugPrint('[PUSH-DIAG] PushManager: callId=$callId');
    debugPrint('[PUSH-DIAG] PushManager: extra.keys=${extra.keys.toList()}');
    debugPrint('[PUSH-DIAG] PushManager: full extra=$extra');

    debugPrint('[PUSH-DIAG] PushManager: About to extract metadata...');
    final metadata = _eventHandler.extractMetadata(extra);
    debugPrint('[PUSH-DIAG] PushManager: extracted metadata=$metadata');
    debugPrint('[PUSH-DIAG] PushManager: Metadata found=${metadata != null}');
    debugPrint(
        '[PUSH-DIAG] PushManager: Has push callback=${_onPushNotificationAccepted != null}');
    debugPrint(
        '[PUSH-DIAG] PushManager: Has foreground callback=${_onForegroundCallAccepted != null}');

    if (metadata != null) {
      // This is a push notification call - process with metadata
      debugPrint(
          '[PUSH-DIAG] PushManager: Decision=PUSH - Processing push call accept with metadata');
      debugPrint(
          '[PUSH-DIAG] PushManager: _onPushNotificationAccepted callback exists: ${_onPushNotificationAccepted != null}');

      // Call the acceptance callback if provided
      if (_onPushNotificationAccepted != null) {
        debugPrint(
            '[PUSH-DIAG] PushManager: Calling _onPushNotificationAccepted callback');
        _onPushNotificationAccepted?.call(callId, extra);
        debugPrint(
            '[PUSH-DIAG] PushManager: _onPushNotificationAccepted callback completed');
      } else {
        debugPrint(
            '[PUSH-DIAG] PushManager: ERROR - No _onPushNotificationAccepted callback available!');
      }
    } else {
      // This is a foreground call - directly handle the acceptance
      debugPrint(
          '[PUSH-DIAG] PushManager: Decision=FOREGROUND - Processing foreground call accept (no metadata)');
      // The CallKit bridge callbacks will handle this
      _handleCallAccepted(callId);
    }
  }

  void _handleCallDeclineEvent(String callId, Map<String, dynamic> extra) {
    debugPrint(
        'PushNotificationManager: _handleCallDeclineEvent called for call $callId');
    final metadata = _eventHandler.extractMetadata(extra);
    if (metadata != null) {
      // This is a push notification call - process with metadata
      if (_onPushNotificationDeclined != null) {
        debugPrint(
            'PushNotificationManager: Calling _onPushNotificationDeclined callback');
        _onPushNotificationDeclined?.call(callId, extra);
        debugPrint(
            'PushNotificationManager: _onPushNotificationDeclined callback completed');
      } else {
        debugPrint(
            'PushNotificationManager: No _onPushNotificationDeclined callback available');
      }
    } else {
      // This is a foreground call - directly handle the decline
      debugPrint(
          'PushNotificationManager: Processing foreground call decline (no metadata)');
      // The CallKit bridge callbacks will handle this
      _handleCallDeclined(callId);
    }
  }

  void _handleCallEndEvent(String callId, Map<String, dynamic> extra) {
    debugPrint(
        'PushNotificationManager: Processing call end event for $callId');
    // For end events, we don't need metadata - just forward to the bridge
    _handleCallEnded(callId);
  }

  void _handleCallTimeoutEvent(String callId, Map<String, dynamic> extra) {
    debugPrint('PushNotificationManager: Processing call timeout event');
  }

  void _handleCallIncomingEvent(String callId, Map<String, dynamic> extra) {
    debugPrint('PushNotificationManager: Processing call incoming event');
  }

  /// Disposes of the push notification manager and cleans up all resources.
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    _gateway.dispose();
    _callKitBridge.dispose();
    _eventHandler.dispose();
    _displayService.dispose();
    _tokenProvider.dispose();

    _onPushNotificationProcessed = null;
    _onPushNotificationAccepted = null;
    _onPushNotificationDeclined = null;
    _onTokenRefresh = null;
    _onForegroundCallAccepted = null;
    _onForegroundCallDeclined = null;
    _onForegroundCallEnded = null;

    debugPrint('PushNotificationManager: Disposed');
  }
}

/// No-op implementation of NotificationDisplayService for when native UI is disabled.
class _NoOpNotificationDisplayService implements NotificationDisplayService {
  @override
  Future<void> initialize() async {
    debugPrint(
        'NoOpNotificationDisplayService: Native UI disabled, skipping initialization');
  }

  @override
  Future<void> showIncomingCall({
    required String callId,
    required String callerName,
    required String callerNumber,
    Map<String, dynamic> extra = const {},
  }) async {
    debugPrint(
        'NoOpNotificationDisplayService: Would show incoming call for $callId');
  }

  @override
  Future<void> showMissedCall({
    required String callId,
    required String callerName,
    required String callerNumber,
    Map<String, dynamic> extra = const {},
  }) async {
    debugPrint(
        'NoOpNotificationDisplayService: Would show missed call for $callId');
  }

  @override
  Future<void> showOutgoingCall({
    required String callId,
    required String callerName,
    required String destination,
    Map<String, dynamic> extra = const {},
  }) async {
    debugPrint(
        'NoOpNotificationDisplayService: Would show outgoing call for $callId');
  }

  @override
  Future<void> endCall(String callId) async {
    debugPrint('NoOpNotificationDisplayService: Would end call for $callId');
  }

  @override
  CallInfo? parseCallInfo(Map<String, dynamic> payload) {
    debugPrint(
        'NoOpNotificationDisplayService: Parsing call info (placeholder)');
    return null;
  }

  @override
  void dispose() {
    // No-op
  }
}
