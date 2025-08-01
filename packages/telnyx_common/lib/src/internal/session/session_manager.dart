import 'dart:async';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:telnyx_webrtc/telnyx_client.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';
import 'package:telnyx_webrtc/model/telnyx_socket_error.dart';
import 'package:telnyx_webrtc/model/push_notification.dart';
import 'package:telnyx_common/src/models/connection_state.dart';

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

  // Store caller ID information from login config
  String? _sipCallerIDName;
  String? _sipCallerIDNumber;

  // Store the configuration for push notification handling
  Config? _storedConfig;

  bool _handlingPushNotification = false;

  /// Creates a new SessionManager instance.
  SessionManager() {
    _setupSocketObservers();
  }

  /// Stream of connection state changes.
  Stream<ConnectionState> get connectionState =>
      _connectionStateController.stream;

  /// Current connection state (synchronous access).
  ConnectionState get currentState => _currentState;

  /// Access to the underlying TelnyxClient for call operations.
  TelnyxClient get telnyxClient => _telnyxClient;

  /// SIP caller ID name from the login configuration.
  String? get sipCallerIDName => _sipCallerIDName;

  /// SIP caller ID number from the login configuration.
  String? get sipCallerIDNumber => _sipCallerIDNumber;

  /// Current session ID (UUID) for this connection.
  String get sessionId => _telnyxClient.sessid;

  bool get isHandlingPushNotification => _handlingPushNotification;

  set isHandlingPushNotification(bool value) {
    _handlingPushNotification = value;
  }

  /// Disables push notifications for the current session.
  void disablePushNotifications() {
    _telnyxClient.disablePushNotifications();
  }

  /// Handles push notifications with the stored configuration.
  void handlePushNotificationWithConfig(
      PushMetaData pushMetaData, Config config) {
    debugPrint('SessionManager: handlePushNotificationWithConfig called');
    debugPrint('SessionManager: Push metadata: ${pushMetaData.toJson()}');
    debugPrint('SessionManager: Config type: ${config.runtimeType}');
    _handlingPushNotification = true;

    try {
      if (config is CredentialConfig) {
        debugPrint(
            'SessionManager: Calling TelnyxClient.handlePushNotification with CredentialConfig');
        telnyxClient.handlePushNotification(
          pushMetaData,
          config,
          null,
        );
      } else if (config is TokenConfig) {
        debugPrint(
            'SessionManager: Calling TelnyxClient.handlePushNotification with TokenConfig');
        telnyxClient.handlePushNotification(
          pushMetaData,
          null,
          config,
        );
      } else {
        debugPrint('SessionManager: Unsupported config type: ${config.runtimeType}');
      }
    } catch (e) {
      debugPrint('SessionManager: Error handling push notification: $e');
    }
  }

  /// Connects to the Telnyx platform using credential authentication.
  Future<void> connectWithCredential(CredentialConfig config) async {
    if (_disposed) throw StateError('SessionManager has been disposed');

    _updateState(const Connecting());

    try {
      // Store caller ID information for later use
      _sipCallerIDName = config.sipCallerIDName;
      _sipCallerIDNumber = config.sipCallerIDNumber;

      // Store the configuration for push notification handling
      _storedConfig = config;

      final telnyxConfig = CredentialConfig(
        sipUser: config.sipUser,
        sipPassword: config.sipPassword,
        sipCallerIDName: config.sipCallerIDName,
        sipCallerIDNumber: config.sipCallerIDNumber,
        notificationToken: config.notificationToken,
        autoReconnect: config.autoReconnect,
        logLevel: config.logLevel,
        debug: config.debug,
        customLogger: config.customLogger,
        ringTonePath: config.ringTonePath,
        ringbackPath: config.ringbackPath,
        reconnectionTimeout: config.reconnectionTimeout,
        region: config.region,
        fallbackOnRegionFailure: config.fallbackOnRegionFailure,
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
      // Store caller ID information for later use
      _sipCallerIDName = config.sipCallerIDName;
      _sipCallerIDNumber = config.sipCallerIDNumber;

      // Store the configuration for push notification handling
      _storedConfig = config;

      final telnyxConfig = TokenConfig(
        sipToken: config.sipToken,
        sipCallerIDName: config.sipCallerIDName,
        sipCallerIDNumber: config.sipCallerIDNumber,
        notificationToken: config.notificationToken,
        autoReconnect: config.autoReconnect,
        logLevel: config.logLevel,
        debug: config.debug,
        customLogger: config.customLogger,
        ringTonePath: config.ringTonePath,
        ringbackPath: config.ringbackPath,
        reconnectionTimeout: config.reconnectionTimeout,
        region: config.region,
        fallbackOnRegionFailure: config.fallbackOnRegionFailure,
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
      // Use stored configuration for push notification handling
      if (_storedConfig != null) {
        if (_storedConfig is CredentialConfig) {
          _telnyxClient.handlePushNotification(
            pushMetaData,
            _storedConfig as CredentialConfig,
            null,
          );
        } else if (_storedConfig is TokenConfig) {
          _telnyxClient.handlePushNotification(
            pushMetaData,
            null,
            _storedConfig as TokenConfig,
          );
        }
      } else {
        // Fallback to the old behavior if no stored config
        _telnyxClient.handlePushNotification(pushMetaData, null, null);
      }
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

      // Clear stored caller ID information
      _sipCallerIDName = null;
      _sipCallerIDNumber = null;

      // Clear stored configuration
      _storedConfig = null;
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

    // Clear stored caller ID information
    _sipCallerIDName = null;
    _sipCallerIDNumber = null;

    // Clear stored configuration
    _storedConfig = null;
  }
}
