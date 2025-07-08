import 'dart:async';
import 'package:telnyx_webrtc/model/push_notification.dart';

import 'push_notification_gateway.dart';
import '../callkit/callkit_event_handler.dart';
import 'notification_display_service.dart';
import 'push_token_provider.dart';
import 'default_push_token_provider.dart';
import '../callkit/callkit_adapter_bridge.dart';

/// Configuration for the push notification manager.
class PushNotificationManagerConfig {
  final bool enableNativeUI;
  final bool enableBackgroundHandling;
  final NotificationConfig? notificationConfig;
  final PushTokenProvider? customTokenProvider;
  final int staleNotificationTimeoutSeconds;

  const PushNotificationManagerConfig({
    this.enableNativeUI = true,
    this.enableBackgroundHandling = true,
    this.notificationConfig,
    this.customTokenProvider,
    this.staleNotificationTimeoutSeconds = 30,
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
  Function(String token)? _onTokenRefresh;

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
    Function(String token)? onTokenRefresh,
  }) async {
    if (_initialized || _disposed) return;

    try {
      print('PushNotificationManager: Starting initialization...');

      _onPushNotificationProcessed = onPushNotificationProcessed;
      _onTokenRefresh = onTokenRefresh;

      // Initialize core components
      await _initializeComponents();

      // Set up event handlers
      _setupEventHandlers();

      // Get initial token
      await _initializeToken();

      _initialized = true;
      print('PushNotificationManager: Initialization completed');
    } catch (e) {
      print('PushNotificationManager: Error during initialization: $e');
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

    // Initialize gateway with the bridge
    _gateway = PushNotificationGateway(
      _callKitBridge,
      onPushNotificationProcessed: (pushMetaData) {
        _onPushNotificationProcessed?.call(pushMetaData);
      },
    );

    print('PushNotificationManager: Components initialized');
  }

  /// Sets up event handlers for CallKit events.
  void _setupEventHandlers() {
    if (!_config.enableNativeUI) return;

    _eventHandler.setEventCallbacks(
      onCallAccept: (callId, extra) {
        print('PushNotificationManager: Call accepted - $callId');
        _handleCallAcceptEvent(callId, extra);
      },
      onCallDecline: (callId, extra) {
        print('PushNotificationManager: Call declined - $callId');
        _handleCallDeclineEvent(callId, extra);
      },
      onCallEnd: (callId, extra) {
        print('PushNotificationManager: Call ended - $callId');
        _handleCallEndEvent(callId, extra);
      },
      onCallTimeout: (callId, extra) {
        print('PushNotificationManager: Call timeout - $callId');
        _handleCallTimeoutEvent(callId, extra);
      },
      onCallIncoming: (callId, extra) {
        print('PushNotificationManager: Call incoming - $callId');
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
        print('PushNotificationManager: Initial token retrieved');
        _onTokenRefresh?.call(_currentToken!);
      }

      // Set up token refresh listener
      await _tokenProvider.setupTokenRefreshListener((newToken) {
        _currentToken = newToken;
        print('PushNotificationManager: Token refreshed');
        _onTokenRefresh?.call(newToken);
      });
    } catch (e) {
      print('PushNotificationManager: Error initializing token: $e');
    }
  }

  /// Handles incoming push notifications.
  ///
  /// [payload] - The raw push notification payload
  Future<void> handlePushNotification(Map<String, dynamic> payload) async {
    if (!_initialized || _disposed) {
      print(
          'PushNotificationManager: Manager not initialized, ignoring push notification');
      return;
    }

    try {
      print(
          'PushNotificationManager: Handling push notification: ${payload.keys}');
      await _gateway.handlePushNotification(payload);
    } catch (e) {
      print('PushNotificationManager: Error handling push notification: $e');
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
      print('PushNotificationManager: Error showing incoming call: $e');
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
      print('PushNotificationManager: Error showing outgoing call: $e');
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
      print('PushNotificationManager: Error ending call: $e');
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
      print('PushNotificationManager: Error refreshing token: $e');
      return null;
    }
  }

  // CallKit bridge event handlers
  void _handleCallAccepted(String callId) {
    print(
        'PushNotificationManager: Call accepted via CallKit bridge - $callId');
    // Additional processing can be added here if needed
  }

  void _handleCallDeclined(String callId) {
    print(
        'PushNotificationManager: Call declined via CallKit bridge - $callId');
    // Additional processing can be added here if needed
  }

  void _handleCallEnded(String callId) {
    print('PushNotificationManager: Call ended via CallKit bridge - $callId');
    // Additional processing can be added here if needed
  }

  // Event handlers for CallKitEventHandler callbacks
  void _handleCallAcceptEvent(String callId, Map<String, dynamic> extra) {
    final metadata = _eventHandler.extractMetadata(extra);
    if (metadata != null) {
      // Process accept action with metadata
      print('PushNotificationManager: Processing call accept with metadata');
    }
  }

  void _handleCallDeclineEvent(String callId, Map<String, dynamic> extra) {
    final metadata = _eventHandler.extractMetadata(extra);
    if (metadata != null) {
      // Process decline action with metadata
      print('PushNotificationManager: Processing call decline with metadata');
    }
  }

  void _handleCallEndEvent(String callId, Map<String, dynamic> extra) {
    print('PushNotificationManager: Processing call end event');
  }

  void _handleCallTimeoutEvent(String callId, Map<String, dynamic> extra) {
    print('PushNotificationManager: Processing call timeout event');
  }

  void _handleCallIncomingEvent(String callId, Map<String, dynamic> extra) {
    print('PushNotificationManager: Processing call incoming event');
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
    _onTokenRefresh = null;

    print('PushNotificationManager: Disposed');
  }
}

/// No-op implementation of NotificationDisplayService for when native UI is disabled.
class _NoOpNotificationDisplayService implements NotificationDisplayService {
  @override
  Future<void> initialize() async {
    print(
        'NoOpNotificationDisplayService: Native UI disabled, skipping initialization');
  }

  @override
  Future<void> showIncomingCall({
    required String callId,
    required String callerName,
    required String callerNumber,
    Map<String, dynamic> extra = const {},
  }) async {
    print(
        'NoOpNotificationDisplayService: Would show incoming call for $callId');
  }

  @override
  Future<void> showMissedCall({
    required String callId,
    required String callerName,
    required String callerNumber,
    Map<String, dynamic> extra = const {},
  }) async {
    print('NoOpNotificationDisplayService: Would show missed call for $callId');
  }

  @override
  Future<void> showOutgoingCall({
    required String callId,
    required String callerName,
    required String destination,
    Map<String, dynamic> extra = const {},
  }) async {
    print(
        'NoOpNotificationDisplayService: Would show outgoing call for $callId');
  }

  @override
  Future<void> endCall(String callId) async {
    print('NoOpNotificationDisplayService: Would end call for $callId');
  }

  @override
  CallInfo? parseCallInfo(Map<String, dynamic> payload) {
    print('NoOpNotificationDisplayService: Parsing call info (placeholder)');
    return null;
  }

  @override
  void dispose() {
    // No-op
  }
}
