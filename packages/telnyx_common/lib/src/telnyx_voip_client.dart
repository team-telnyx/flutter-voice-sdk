import 'dart:async';
import 'package:telnyx_webrtc/model/push_notification.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';
import 'package:telnyx_common/src/models/call.dart';
import 'package:telnyx_common/src/models/connection_state.dart';
import 'package:telnyx_common/src/internal/session_manager.dart';
import 'package:telnyx_common/src/internal/call_state_controller.dart';
import 'package:telnyx_common/src/internal/callkit_adapter.dart';
import 'package:telnyx_common/src/internal/push_notification_gateway.dart';
import 'package:telnyx_common/utils/iterable_extensions.dart';

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
  CallKitAdapter? _callKitAdapter;
  PushNotificationGateway? _pushGateway;

  // Configuration
  bool _nativeUIEnabled = false;
  bool _disposed = false;

  /// Creates a new TelnyxVoipClient instance.
  ///
  /// [enableNativeUI] - Whether to enable native call UI integration (Phase 2).
  /// When enabled, the client will automatically show native incoming call
  /// screens and manage call UI through the system's call interface.
  TelnyxVoipClient({bool enableNativeUI = false}) {
    _nativeUIEnabled = enableNativeUI;
    _initializeComponents();
  }

  /// Stream of connection state changes.
  ///
  /// Emits the current status of the connection to the Telnyx backend.
  /// Values include connecting, connected, disconnected, and error states.
  /// Listen to this to show connection indicators in your UI.
  Stream<ConnectionState> get connectionState => _sessionManager.connectionState;

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

  /// Connects to the Telnyx platform using credential authentication.
  ///
  /// [config] - The credential configuration containing SIP username and password.
  ///
  /// Returns a Future that completes when the connection attempt is initiated.
  /// Listen to [connectionState] to monitor the actual connection status.
  Future<void> login(CredentialConfig config) async {
    if (_disposed) throw StateError('TelnyxVoipClient has been disposed');

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

    await _sessionManager.connectWithToken(config);
  }

  /// Disconnects from the Telnyx platform.
  ///
  /// This method terminates the connection, ends any active calls, and
  /// cleans up all related resources.
  Future<void> logout() async {
    if (_disposed) return;

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
    if (_nativeUIEnabled && _callKitAdapter != null) {
      await _callKitAdapter!.startOutgoingCall(
        callId: call.callId,
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

    if (_pushGateway == null) {
      throw StateError('Push notification handling requires native UI to be enabled');
    }

    await _pushGateway!.handlePushNotification(payload);
  }

  /// Initializes the internal components.
  void _initializeComponents() {
    // Initialize session manager
    _sessionManager = SessionManager();

    // Initialize call state controller
    _callStateController = CallStateController(_sessionManager.telnyxClient, _sessionManager);

    // Monitor connection state for call cleanup
    _callStateController.monitorConnectionState(_sessionManager.connectionState);

    // Initialize native UI components if enabled
    if (_nativeUIEnabled) {
      _initializeNativeUI();
    }
  }

  /// Initializes native UI components (Phase 2).
  void _initializeNativeUI() {
    // Initialize CallKit adapter
    _callKitAdapter = CallKitAdapter(
      onCallAccepted: _handleCallAccepted,
      onCallDeclined: _handleCallDeclined,
      onCallEnded: _handleCallEnded,
    );

    // Initialize push notification gateway
    _pushGateway = PushNotificationGateway(
      _callKitAdapter!,
      onPushNotificationProcessed: _handlePushNotificationProcessed,
    );

    // Initialize the CallKit adapter
    _callKitAdapter!.initialize();
  }

  /// Handles call accepted from native UI.
  void _handleCallAccepted(String callId) {
    final call = _callStateController.currentCalls
        .where((c) => c.callId == callId)
        .firstOrNull;

    if (call != null && call.isIncoming) {
      call.answer();
    }
  }

  /// Handles call declined from native UI.
  void _handleCallDeclined(String callId) {
    final call = _callStateController.currentCalls
        .where((c) => c.callId == callId)
        .firstOrNull;

    if (call != null) {
      call.hangup();
    }
  }

  /// Handles call ended from native UI.
  void _handleCallEnded(String callId) {
    final call = _callStateController.currentCalls
        .where((c) => c.callId == callId)
        .firstOrNull;

    if (call != null) {
      call.hangup();
    }
  }

  /// Handles processed push notifications.
  void _handlePushNotificationProcessed(PushMetaData pushMetaData) {
    // Connect with push metadata to handle the incoming call
    _sessionManager.connectWithPushMetadata(pushMetaData);
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
    _callKitAdapter?.dispose();
    _pushGateway?.dispose();
  }
}