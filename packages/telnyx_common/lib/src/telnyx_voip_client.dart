import 'dart:async';
import 'dart:convert'; // Added for jsonDecode
import 'package:telnyx_webrtc/model/push_notification.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';
import 'package:telnyx_webrtc/telnyx_client.dart';
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

  /// This is the unified entry point for all push notifications. It intelligently
  /// determines whether to show a new incoming call UI or to process an already
  /// actioned (accepted/declined) call upon app launch.
  Future<void> handlePushNotification(Map<String, dynamic> payload) async {
    if (_disposed) throw StateError('TelnyxVoipClient has been disposed');

    // Ensure the push manager is ready, as we might need it for the UI.
    await _ensurePushNotificationManagerInitialized();

    // The gateway expects the metadata to be under a 'metadata' key.
    final metadataJson = payload['metadata'];
    if (metadataJson == null) {
      print('TelnyxVoipClient: No metadata in push payload, cannot process.');
      return;
    }

    final Map<String, dynamic> metadataMap;
    if (metadataJson is String) {
      metadataMap = jsonDecode(metadataJson);
    } else if (metadataJson is Map<String, dynamic>) {
      metadataMap = metadataJson;
    } else {
      print('TelnyxVoipClient: Invalid metadata format in push payload.');
      return;
    }

    final pushMetaData = PushMetaData.fromJson(metadataMap);

    // Check if this push has already been actioned (accepted or declined).
    final bool isActioned =
        (pushMetaData.isAnswer ?? false) || (pushMetaData.isDecline ?? false);

    if (isActioned) {
      // This is an app launch from an accepted/declined push.
      // Bypass the UI display and go straight to connection handling.
      print('TelnyxVoipClient: Handling actioned push. Bypassing UI display.');

      // We need to get the stored config to connect.
      final config = await ConfigHelper.getConfig();
      if (config == null) {
        print(
            'TelnyxVoipClient: No stored config found for push handling. Aborting.');
        return;
      }
      // Update the in-memory config to ensure the session manager uses it.
      _storedConfig = config;

      // This will call the low-level telnyx_webrtc client to connect with the correct state.
      _sessionManager.handlePushNotificationWithConfig(pushMetaData, config);
    } else {
      // This is an initial push notification from a background isolate.
      // Display the native incoming call UI via the gateway.
      print('TelnyxVoipClient: Handling initial push. Displaying UI.');
      await _pushNotificationManager!.handlePushNotification(payload);
    }
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
  void _handlePushNotificationAccepted(
      String callId, Map<String, dynamic> extra) async {
    print('TelnyxVoipClient: Push notification accepted for call $callId');

    // Update stored push data to indicate acceptance
    // The app launch flow will handle the actual connection and processing
    final metadata = _extractMetadata(extra);
    if (metadata != null) {
      try {
        // Update the stored push data with isAnswer = true
        // This matches the old implementation approach
        TelnyxClient.setPushMetaData(
          extra,
          isAnswer: true, // ← Key change: mark as accepted
          isDecline: false,
        );

        print(
            'TelnyxVoipClient: Updated stored push data with acceptance flag');
      } catch (e) {
        print('TelnyxVoipClient: Error updating stored push data: $e');
      }
    }

    // DON'T attempt manual login here - let the app launch flow handle everything
    // This was the core issue causing duplicate login attempts
    print(
        'TelnyxVoipClient: Push notification acceptance processed - app launch will handle connection');
  }

  /// Handles when a push notification is declined via CallKit.
  void _handlePushNotificationDeclined(
      String callId, Map<String, dynamic> extra) async {
    print('TelnyxVoipClient: Push notification declined for call $callId');

    final metadata = _extractMetadata(extra);
    if (metadata != null) {
      try {
        final PushMetaData pushMetaData = PushMetaData.fromJson(metadata)
          ..isDecline = true;
        final config = await ConfigHelper.getConfig();

        print(
            'TelnyxVoipClient: Handling push notification decline via background client.');

        if (config != null) {
          // The SessionManager holds the TelnyxClient instance.
          // We use it to send the decline message.
          _sessionManager.handlePushNotificationWithConfig(
              pushMetaData, config);
        } else {
          print(
              'TelnyxVoipClient: Could not get config for temp client to decline push');
        }
      } catch (e) {
        print(
            'TelnyxVoipClient: Error processing push notification decline: $e');
      } finally {
        // Regardless of success or failure, this background client's job is done.
        // Dispose of it to close any open sockets.
        print(
            'TelnyxVoipClient: Disposing background client after decline action.');
        dispose();
      }
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
