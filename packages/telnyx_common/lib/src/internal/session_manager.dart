import 'dart:async';
import 'package:telnyx_webrtc/telnyx_client.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart' as telnyx_config;
import 'package:telnyx_webrtc/model/telnyx_socket_error.dart';
import 'package:telnyx_webrtc/model/push_notification.dart';
import '../models/connection_state.dart';
import '../models/config.dart';

/// Internal component responsible for managing the TelnyxClient connection lifecycle.
///
/// This class wraps the core TelnyxClient and translates low-level connection
/// events into high-level ConnectionState changes. It handles authentication,
/// connection management, and error handling.
class SessionManager {
  final TelnyxClient _telnyxClient = TelnyxClient();
  final StreamController<ConnectionState> _connectionStateController = 
      StreamController<ConnectionState>.broadcast();

  ConnectionState _currentState = const Disconnected();
  bool _disposed = false;

  /// Creates a new SessionManager instance.
  SessionManager() {
    _setupSocketObservers();
  }

  /// Stream of connection state changes.
  Stream<ConnectionState> get connectionState => _connectionStateController.stream;

  /// Current connection state (synchronous access).
  ConnectionState get currentState => _currentState;

  /// Access to the underlying TelnyxClient for call operations.
  TelnyxClient get telnyxClient => _telnyxClient;

  /// Connects to the Telnyx platform using credential authentication.
  Future<void> connectWithCredential(CredentialConfig config) async {
    if (_disposed) throw StateError('SessionManager has been disposed');

    _updateState(const Connecting());

    try {
      final telnyxConfig = telnyx_config.CredentialConfig(
        sipUser: config.sipUser,
        sipPassword: config.sipPassword,
        sipCallerIDName: config.sipUser, // Use sipUser as default caller ID name
        sipCallerIDNumber: config.sipUser, // Use sipUser as default caller ID number
        notificationToken: config.fcmToken,
        debug: config.debug,
      );

      _telnyxClient.connectWithCredential(telnyxConfig);
    } catch (error, stackTrace) {
      _updateState(ConnectionError(error, stackTrace));
    }
  }

  /// Connects to the Telnyx platform using token authentication.
  Future<void> connectWithToken(TokenConfig config) async {
    if (_disposed) throw StateError('SessionManager has been disposed');

    _updateState(const Connecting());

    try {
      final telnyxConfig = telnyx_config.TokenConfig(
        sipToken: config.token,
        sipCallerIDName: 'User', // Default caller ID name for token auth
        sipCallerIDNumber: 'Unknown', // Default caller ID number for token auth
        notificationToken: config.fcmToken,
        debug: config.debug,
      );

      _telnyxClient.connectWithToken(telnyxConfig);
    } catch (error, stackTrace) {
      _updateState(ConnectionError(error, stackTrace));
    }
  }

  /// Connects with push notification metadata for incoming calls.
  Future<void> connectWithPushMetadata(PushMetaData pushMetaData) async {
    if (_disposed) throw StateError('SessionManager has been disposed');

    _updateState(const Connecting());

    try {
      // The TelnyxClient should handle push metadata connection
      // This is typically used for incoming calls from push notifications
      _telnyxClient.handlePushNotification(pushMetaData, null, null);
    } catch (error, stackTrace) {
      _updateState(ConnectionError(error, stackTrace));
    }
  }

  /// Disconnects from the Telnyx platform.
  Future<void> disconnect() async {
    if (_disposed) return;

    try {
      _telnyxClient.disconnect();
      _updateState(const Disconnected());
    } catch (error, stackTrace) {
      _updateState(ConnectionError(error, stackTrace));
    }
  }

  /// Sets up observers for socket events from the TelnyxClient.
  void _setupSocketObservers() {
    _telnyxClient.onSocketErrorReceived = (TelnyxSocketError error) {
      _updateState(ConnectionError(error));
    };

    // Note: The TelnyxClient doesn't expose a direct connection state stream,
    // so we rely on socket messages and errors to infer the connection state.
    // The Connected state will be set when we receive a clientReady message
    // in the CallStateController.
  }

  /// Updates the connection state and notifies listeners.
  void _updateState(ConnectionState newState) {
    if (_currentState.runtimeType != newState.runtimeType) {
      _currentState = newState;
      if (!_disposed) {
        _connectionStateController.add(newState);
      }
    }
  }

  /// Sets the connection state to Connected.
  ///
  /// This is called by the CallStateController when it receives a clientReady message.
  void setConnected() {
    _updateState(const Connected());
  }

  /// Disposes of the session manager and cleans up resources.
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    _telnyxClient.disconnect();
    _connectionStateController.close();
  }
}