import 'dart:async';
import 'dart:convert'; // Added for jsonDecode
import 'package:telnyx_webrtc/model/push_notification.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';
import 'package:telnyx_common/src/models/call.dart';
import 'package:telnyx_common/src/models/connection_state.dart';
import 'package:telnyx_common/src/internal/session/session_manager.dart';
import 'package:telnyx_common/src/internal/calls/call_state_controller.dart';
import 'package:telnyx_common/src/internal/push/push_notification_manager.dart';
import 'package:telnyx_common/src/internal/push/push_token_provider.dart';
import 'package:telnyx_common/src/internal/push/notification_display_service.dart';
import 'package:telnyx_common/utils/iterable_extensions.dart';
import 'package:telnyx_common/src/util/config_helper.dart';

/// The main public interface for the telnyx_common module.
///
/// This class serves as the Façade for the entire module, providing a simplified
/// API that completely hides the underlying complexity. It is the sole entry point
/// for developers using the telnyx_common package.
///
/// The TelnyxVoipClient is designed to be state-management agnostic, exposing
/// all observable state via Dart's native Stream<T>. This allows developers to
/// integrate it into their chosen state management solution naturally.
class TelnyxVoipClient {
  // Internal components
  late final SessionManager _sessionManager;
  late final CallStateController _callStateController;
  PushNotificationManager? _pushNotificationManager;

  // Configuration
  final PushNotificationManagerConfig _pushConfig;
  bool _disposed = false;

  // Store configuration for push notification handling
  Config? _storedConfig;
  PushMetaData? _storedPushMetaData;
  Map<String, dynamic>? _storedPushPayload;

  /// Creates a new TelnyxVoipClient instance.
  ///
  /// [enableNativeUI] - Whether to enable native call UI integration.
  /// When enabled, the client will automatically show native incoming call
  /// screens and manage call UI through the system's call interface.
  ///
  /// [enableBackgroundHandling] - Whether to enable background push notification handling.
  ///
  /// [notificationConfig] - Optional configuration for notification display.
  ///
  /// [customTokenProvider] - Optional custom push token provider. If not provided,
  /// push token functionality will be disabled. Applications should implement
  /// PushTokenProvider to provide platform-specific token management.
  TelnyxVoipClient({
    bool enableNativeUI = false,
    bool enableBackgroundHandling = true,
    NotificationConfig? notificationConfig,
    PushTokenProvider? customTokenProvider,
  }) : _pushConfig = PushNotificationManagerConfig(
          enableNativeUI: enableNativeUI,
          enableBackgroundHandling: enableBackgroundHandling,
          notificationConfig: notificationConfig,
          customTokenProvider: customTokenProvider,
        ) {
    _initializeComponents();
  }

  /// Stream of connection state changes.
  ///
  /// Emits the current status of the connection to the Telnyx backend.
  /// Values include connecting, connected, disconnected, and error states.
  /// Listen to this to show connection indicators in your UI.
  Stream<ConnectionState> get connectionState =>
      _sessionManager.connectionState;

  /// Stream of all current calls.
  ///
  /// Emits a list of all current Call objects. Use this for applications
  /// that need to support multiple simultaneous calls (e.g., call waiting,
  /// conference calls).
  Stream<List<Call>> get calls => _callStateController.calls;

  /// Stream of the currently active call.
  ///
  /// A convenience stream that emits the currently active Call object.
  /// It emits null when no call is in progress. Ideal for applications
  /// that only handle a single call at a time.
  Stream<Call?> get activeCall => _callStateController.activeCall;

  /// Current connection state (synchronous access).
  ConnectionState get currentConnectionState => _sessionManager.currentState;

  /// Current list of calls (synchronous access).
  List<Call> get currentCalls => _callStateController.currentCalls;

  /// Current active call (synchronous access).
  Call? get currentActiveCall => _callStateController.currentActiveCall;

  /// Current push token (synchronous access).
  String? get currentPushToken => _pushNotificationManager?.currentToken;

  /// Current session ID (UUID) for this connection.
  String get sessionId => _sessionManager.sessionId;

  /// Disables push notifications for the current session.
  ///
  /// This method sends a request to the Telnyx backend to disable push
  /// notifications for the current registered device/session.
  void disablePushNotifications() {
    _sessionManager.disablePushNotifications();
  }

  /// Connects to the Telnyx platform using credential authentication.
  ///
  /// [config] - The credential configuration containing SIP username and password.
  ///
  /// Returns a Future that completes when the connection attempt is initiated.
  /// Listen to [connectionState] to monitor the actual connection status.
  Future<void> login(CredentialConfig config) async {
    if (_disposed) throw StateError('TelnyxVoipClient has been disposed');

    // Store the configuration for push notification handling
    _storedConfig = config;
    await ConfigHelper.saveConfig(config);


    // Initialize push notification manager if not already done
    await _ensurePushNotificationManagerInitialized();

    await _sessionManager.connectWithCredential(config);
  }

  /// Connects to the Telnyx platform using token authentication.
  ///
  /// [config] - The token configuration containing the authentication token.
  ///
  /// Returns a Future that completes when the connection attempt is initiated.
  /// Listen to [connectionState] to monitor the actual connection status.
  Future<void> loginWithToken(TokenConfig config) async {
    if (_disposed) throw StateError('TelnyxVoipClient has been disposed');

    // Store the configuration for push notification handling
    _storedConfig = config;
    await ConfigHelper.saveConfig(config);

    // Initialize push notification manager if not already done
    await _ensurePushNotificationManagerInitialized();

    await _sessionManager.connectWithToken(config);
  }

  /// Attempts to log in using a configuration stored on the device.
  ///
  /// This is useful for automatically reconnecting when the app starts.
  /// Returns `true` if a stored configuration was found and a login attempt
  /// was initiated, `false` otherwise.
  Future<bool> loginFromStoredConfig() async {
    if (_disposed) throw StateError('TelnyxVoipClient has been disposed');

    final config = await ConfigHelper.getConfig();
    if (config != null) {
      print('TelnyxVoipClient: Found stored config, attempting to log in...');
      if (config is CredentialConfig) {
        await login(config);
      } else if (config is TokenConfig) {
        await loginWithToken(config);
      }
      return true;
    } else {
      print('TelnyxVoipClient: No stored config found.');
      return false;
    }
  }

  /// Disconnects from the Telnyx platform.
  ///
  /// This method terminates the connection, ends any active calls, and
  /// cleans up all related resources.
  Future<void> logout() async {
    if (_disposed) return;

    // Clear stored configuration
    _storedConfig = null;
    _storedPushMetaData = null;
    _storedPushPayload = null;

    await _sessionManager.disconnect();
  }

  /// Initiates a new outgoing call.
  ///
  /// [destination] - The destination number or SIP URI to call.
  ///
  /// Returns a Future that completes with the Call object once the
  /// invitation has been sent. The call's state can be monitored through
  /// the returned Call object's streams.
  Future<Call> newCall({required String destination}) async {
    if (_disposed) throw StateError('TelnyxVoipClient has been disposed');

    final call = await _callStateController.newCall(destination);

    // Show outgoing call UI if native UI is enabled
    if (_pushConfig.enableNativeUI && _pushNotificationManager != null) {
      await _pushNotificationManager!.showOutgoingCall(
        callId: call.callId,
        callerName: 'Local User', // This could be made configurable
        destination: destination,
      );
    }

    return call;
  }

  /// Processes a remote push notification payload.
  ///
  /// This method must be called from the application's background push handler
  /// to initiate the incoming call flow. It parses the push payload, extracts
  /// call metadata, and triggers the appropriate UI and connection logic.
  ///
  /// [payload] - The raw push notification payload from FCM/APNS.
  ///
  /// Example usage in FirebaseMessaging.onBackgroundMessage:
  /// ```dart
  /// FirebaseMessaging.onBackgroundMessage((RemoteMessage message) async {
  ///   await telnyxVoipClient.handlePushNotification(message.data);
  /// });
  /// ```
  Future<void> handlePushNotification(Map<String, dynamic> payload) async {
    if (_disposed) throw StateError('TelnyxVoipClient has been disposed');

    // Store the push payload for potential use later
    _storedPushPayload = payload;

    // Ensure push notification manager is initialized
    await _ensurePushNotificationManagerInitialized();

    await _pushNotificationManager!.handlePushNotification(payload);
  }

  /// Refreshes the current push token.
  ///
  /// Returns the new token if successful, null otherwise.
  Future<String?> refreshPushToken() async {
    if (_disposed) throw StateError('TelnyxVoipClient has been disposed');

    await _ensurePushNotificationManagerInitialized();
    return await _pushNotificationManager!.refreshToken();
  }

  /// Initializes the internal components.
  void _initializeComponents() {
    // Initialize session manager
    _sessionManager = SessionManager();

    // Initialize call state controller
    _callStateController =
        CallStateController(_sessionManager.telnyxClient, _sessionManager);

    // Monitor connection state for call cleanup
    _callStateController
        .monitorConnectionState(_sessionManager.connectionState);
  }

  /// Ensures the push notification manager is initialized.
  Future<void> _ensurePushNotificationManagerInitialized() async {
    if (_pushNotificationManager != null) return;

    _pushNotificationManager = PushNotificationManager(config: _pushConfig);

    await _pushNotificationManager!.initialize(
      onPushNotificationProcessed: _handlePushNotificationProcessed,
      onPushNotificationAccepted: _handlePushNotificationAccepted,
      onPushNotificationDeclined: _handlePushNotificationDeclined,
      onTokenRefresh: _handleTokenRefresh,
    );
  }

  /// Handles processed push notifications.
  void _handlePushNotificationProcessed(PushMetaData pushMetaData) {
    // Store the push metadata for potential use later
    _storedPushMetaData = pushMetaData;
    
    // Connect with push metadata to handle the incoming call
    _sessionManager.connectWithPushMetadata(pushMetaData);
  }

  /// Handles when a push notification is accepted via CallKit.
  void _handlePushNotificationAccepted(String callId, Map<String, dynamic> extra) async {
    print('TelnyxVoipClient: Push notification accepted for call $callId');

    // If we don't have a config, it means the app was likely terminated.
    // We need to load it from storage and log in first.
    if (_storedConfig == null) {
      print('TelnyxVoipClient: No stored config in memory, attempting to log in from storage...');
      final loggedIn = await loginFromStoredConfig();
      if (!loggedIn) {
        print('TelnyxVoipClient: Could not log in from stored config. Aborting push acceptance.');
        return;
      }
      // Give a moment for the login process to start before proceeding.
      await Future.delayed(const Duration(milliseconds: 500));
    }


    // Try to use stored push metadata first, otherwise extract from extra data
    PushMetaData? pushMetaData = _storedPushMetaData;

    if (pushMetaData == null) {
      // Extract metadata from the extra data
      final metadata = _extractMetadata(extra);
      if (metadata != null) {
        try {
          pushMetaData = PushMetaData.fromJson(metadata);
        } catch (e) {
          print('TelnyxVoipClient: Error parsing push metadata from extra data: $e');
          return;
        }
      }
    }

    if (pushMetaData != null && _storedConfig != null) {
      // Create PushMetaData with isAnswer = true to signal auto-accept
      final acceptPushMetaData = PushMetaData(
        callerName: pushMetaData.callerName,
        callerNumber: pushMetaData.callerNumber,
        callId: pushMetaData.callId,
        voiceSdkId: pushMetaData.voiceSdkId,
      );

      // Set the isAnswer flag to true for auto-accept
      acceptPushMetaData.isAnswer = true;

      // Handle the push notification with the stored configuration
      _sessionManager.handlePushNotificationWithConfig(acceptPushMetaData, _storedConfig!);

      print('TelnyxVoipClient: Push notification acceptance handled successfully');
    } else {
      print('TelnyxVoipClient: Missing push metadata or stored config for push acceptance');
    }
  }

  /// Handles when a push notification is declined via CallKit.
  void _handlePushNotificationDeclined(String callId, Map<String, dynamic> extra) {
    print('TelnyxVoipClient: Push notification declined for call $callId');

    // Try to use stored push metadata first, otherwise extract from extra data
    PushMetaData? pushMetaData = _storedPushMetaData;

    if (pushMetaData == null) {
      // Extract metadata from the extra data
      final metadata = _extractMetadata(extra);
      if (metadata != null) {
        try {
          pushMetaData = PushMetaData.fromJson(metadata);
        } catch (e) {
          print('TelnyxVoipClient: Error parsing push metadata from extra data: $e');
          return;
        }
      }
    }

    if (pushMetaData != null && _storedConfig != null) {
      // Create PushMetaData with isDecline = true to signal auto-decline
      final declinePushMetaData = PushMetaData(
        callerName: pushMetaData.callerName,
        callerNumber: pushMetaData.callerNumber,
        callId: pushMetaData.callId,
        voiceSdkId: pushMetaData.voiceSdkId,
      );

      // Set the isDecline flag to true for auto-decline
      declinePushMetaData.isDecline = true;

      // Handle the push notification with the stored configuration
      _sessionManager.handlePushNotificationWithConfig(declinePushMetaData, _storedConfig!);

      print('TelnyxVoipClient: Push notification decline handled successfully');
    } else {
      print('TelnyxVoipClient: Missing push metadata or stored config for push decline');
    }
  }

  /// Extracts metadata from CallKit extra data.
  Map<String, dynamic>? _extractMetadata(Map<String, dynamic> extra) {
    try {
      final metadata = extra['metadata'];
      if (metadata == null) return null;

      if (metadata is String) {
        return jsonDecode(metadata) as Map<String, dynamic>;
      } else if (metadata is Map<String, dynamic>) {
        return metadata;
      }
      return null;
    } catch (e) {
      print('TelnyxVoipClient: Error extracting metadata: $e');
      return null;
    }
  }

  /// Handles push token refresh.
  void _handleTokenRefresh(String newToken) {
    print(
        'TelnyxVoipClient: Push token refreshed: ${newToken.substring(0, 10)}...');
    // Here you could implement token registration with your backend
  }

  /// Disposes of the client and cleans up all resources.
  ///
  /// This method should be called when the client is no longer needed
  /// to prevent memory leaks and ensure proper cleanup.
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    _callStateController.dispose();
    _sessionManager.dispose();
    _pushNotificationManager?.dispose();

    // Clear stored data
    _storedConfig = null;
    _storedPushMetaData = null;
    _storedPushPayload = null;
  }
}
