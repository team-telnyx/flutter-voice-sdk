import 'dart:async';
import 'package:telnyx_webrtc/telnyx_client.dart';
import 'package:telnyx_webrtc/model/telnyx_socket_error.dart';
import 'package:telnyx_webrtc/model/gateway_state.dart';
import 'package:telnyx_webrtc/model/push_notification.dart';
import '../models/connection_state.dart';
import '../models/config.dart';

/// Internal component responsible for managing the lifecycle of the TelnyxClient.
///
/// This class wraps the core TelnyxClient and manages its connection lifecycle,
/// translating low-level connection events into high-level ConnectionState enums.
class SessionManager {
  /// The underlying TelnyxClient instance.
  late final TelnyxClient _telnyxClient;
  
  /// Stream controller for connection state changes.
  final StreamController<ConnectionState> _connectionStateController = 
      StreamController<ConnectionState>.broadcast();
  
  /// Current connection state.
  ConnectionState _currentState = const Disconnected();
  
  /// Whether the session manager has been disposed.
  bool _disposed = false;
  
  /// Timer for connection timeout.
  Timer? _connectionTimer;
  
  /// Subscription to gateway state changes.
  StreamSubscription? _gatewayStateSubscription;
  
  SessionManager() {
    _telnyxClient = TelnyxClient();
    _setupCallbacks();
  }
  
  /// Stream of connection state changes.
  Stream<ConnectionState> get connectionState => _connectionStateController.stream;
  
  /// Current connection state (synchronous access).
  ConnectionState get currentState => _currentState;
  
  /// The underlying TelnyxClient instance.
  TelnyxClient get telnyxClient => _telnyxClient;
  
  /// Sets up callbacks for the TelnyxClient.
  void _setupCallbacks() {
    _telnyxClient.onSocketErrorReceived = _handleSocketError;
  }
  
  /// Connects using credential configuration.
  Future<void> connectWithCredential(CredentialConfig config) async {
    if (_disposed) throw StateError('SessionManager has been disposed');
    
    _updateState(const Connecting());
    
    try {
      // Start connection timeout
      _startConnectionTimeout();
      
      // Monitor gateway state for connection status
      _monitorGatewayState();
      
      // Connect with the underlying client
      _telnyxClient.connectWithCredential(config.toWebRtcConfig());
      
    } catch (error) {
      _cancelConnectionTimeout();
      _updateState(ConnectionError(TelnyxSocketError(
        errorCode: 500,
        errorMessage: 'Connection failed: $error',
      )));
    }
  }
  
  /// Connects using token configuration.
  Future<void> connectWithToken(TokenConfig config) async {
    if (_disposed) throw StateError('SessionManager has been disposed');
    
    _updateState(const Connecting());
    
    try {
      // Start connection timeout
      _startConnectionTimeout();
      
      // Monitor gateway state for connection status
      _monitorGatewayState();
      
      // Connect with the underlying client
      _telnyxClient.connectWithToken(config.toWebRtcConfig());
      
    } catch (error) {
      _cancelConnectionTimeout();
      _updateState(ConnectionError(TelnyxSocketError(
        errorCode: 500,
        errorMessage: 'Connection failed: $error',
      )));
    }
  }
  
  /// Connects with push metadata for handling incoming calls.
  Future<void> connectWithPushMetadata(
    PushMetaData pushMetaData, {
    CredentialConfig? credentialConfig,
    TokenConfig? tokenConfig,
    bool declinePush = false,
  }) async {
    if (_disposed) throw StateError('SessionManager has been disposed');
    
    _updateState(const Connecting());
    
    try {
      // Set push metadata
      TelnyxClient.setPushMetaData(pushMetaData);
      
      // Handle push notification
      _telnyxClient.handlePushNotification(
        pushMetaData.toJson(),
        credentialConfig: credentialConfig?.toWebRtcConfig(),
        tokenConfig: tokenConfig?.toWebRtcConfig(),
        decline: declinePush,
      );
      
      if (!declinePush) {
        _startConnectionTimeout();
        _monitorGatewayState();
      } else {
        // For decline, we don't need to maintain connection
        _updateState(const Disconnected());
      }
      
    } catch (error) {
      _cancelConnectionTimeout();
      _updateState(ConnectionError(TelnyxSocketError(
        errorCode: 500,
        errorMessage: 'Push connection failed: $error',
      )));
    }
  }
  
  /// Disconnects from the Telnyx backend.
  Future<void> disconnect() async {
    if (_disposed) return;
    
    _cancelConnectionTimeout();
    _stopMonitoringGatewayState();
    
    try {
      _telnyxClient.disconnect();
      _updateState(const Disconnected());
    } catch (error) {
      // Even if disconnect fails, we consider ourselves disconnected
      _updateState(const Disconnected());
    }
  }
  
  /// Starts monitoring the gateway state for connection status.
  void _monitorGatewayState() {
    _stopMonitoringGatewayState();
    
    // Note: The TelnyxClient doesn't expose gateway state as a stream,
    // so we'll poll it periodically or rely on socket callbacks
    _gatewayStateSubscription = Stream.periodic(
      const Duration(seconds: 1),
      (_) => _telnyxClient.getGatewayState(),
    ).listen(_handleGatewayState);
  }
  
  /// Stops monitoring the gateway state.
  void _stopMonitoringGatewayState() {
    _gatewayStateSubscription?.cancel();
    _gatewayStateSubscription = null;
  }
  
  /// Handles gateway state changes.
  void _handleGatewayState(GatewayState gatewayState) {
    switch (gatewayState) {
      case GatewayState.noreg:
      case GatewayState.unreg:
        if (_currentState is Connecting) {
          // Still connecting, don't change state yet
        } else if (_currentState is Connected) {
          _updateState(const Disconnected());
        }
        break;
      case GatewayState.trying:
      case GatewayState.register:
        if (_currentState is! Connecting) {
          _updateState(const Connecting());
        }
        break;
      case GatewayState.reged:
        _cancelConnectionTimeout();
        _updateState(const Connected());
        break;
      case GatewayState.failed:
        _cancelConnectionTimeout();
        _updateState(ConnectionError(TelnyxSocketError(
          errorCode: 503,
          errorMessage: 'Gateway registration failed',
        )));
        break;
    }
  }
  
  /// Handles socket errors from the TelnyxClient.
  void _handleSocketError(TelnyxSocketError error) {
    _cancelConnectionTimeout();
    _updateState(ConnectionError(error));
  }
  
  /// Starts a connection timeout timer.
  void _startConnectionTimeout() {
    _cancelConnectionTimeout();
    _connectionTimer = Timer(const Duration(seconds: 30), () {
      if (_currentState is Connecting) {
        _updateState(ConnectionError(TelnyxSocketError(
          errorCode: 408,
          errorMessage: 'Connection timeout',
        )));
      }
    });
  }
  
  /// Cancels the connection timeout timer.
  void _cancelConnectionTimeout() {
    _connectionTimer?.cancel();
    _connectionTimer = null;
  }
  
  /// Updates the connection state and notifies listeners.
  void _updateState(ConnectionState newState) {
    if (_currentState != newState) {
      _currentState = newState;
      if (!_disposed) {
        _connectionStateController.add(newState);
      }
    }
  }
  
  /// Disposes of the session manager and cleans up resources.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    
    _cancelConnectionTimeout();
    _stopMonitoringGatewayState();
    _connectionStateController.close();
    
    try {
      _telnyxClient.disconnect();
    } catch (_) {
      // Ignore errors during disposal
    }
  }
}