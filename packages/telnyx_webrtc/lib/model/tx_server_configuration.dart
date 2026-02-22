import 'package:telnyx_webrtc/config.dart';
import 'package:telnyx_webrtc/model/tx_ice_server.dart';

/// Represents the WebRTC environment (production or development).
///
/// This enum is used to select the appropriate server configuration
/// for TURN/STUN servers and signaling server.
enum WebRTCEnvironment {
  /// Development environment using dev servers
  development,

  /// Production environment using production servers
  production,
}

/// Configuration for Telnyx server connections including host, port, and ICE servers.
///
/// This class provides factory methods to create production or development
/// server configurations with appropriate TURN/STUN server settings.
///
/// The configuration supports:
/// - Custom signaling server host and port
/// - Custom ICE servers array (TURN/STUN)
/// - Environment-based default configurations
///
/// Example usage:
/// ```dart
/// // Use default production configuration
/// final config = TxServerConfiguration.production();
///
/// // Use custom ICE servers
/// final customConfig = TxServerConfiguration(
///   webRTCIceServers: [
///     TxIceServer(urls: ['stun:stun.example.com:3478']),
///     TxIceServer(
///       urls: ['turn:turn.example.com:3478?transport=tcp'],
///       username: 'user',
///       credential: 'pass',
///     ),
///   ],
/// );
/// ```
class TxServerConfiguration {
  /// Creates a server configuration with the specified parameters.
  ///
  /// [host] The signaling server host address.
  /// [port] The signaling server port.
  /// [turn] Legacy single TURN server URL (deprecated, use webRTCIceServers).
  /// [stun] Legacy single STUN server URL (deprecated, use webRTCIceServers).
  /// [webRTCIceServers] Custom ICE servers array for WebRTC peer connections.
  /// [environment] The WebRTC environment (production or development).
  TxServerConfiguration({
    this.host = DefaultConfig.telnyxProdHostAddress,
    this.port = DefaultConfig.telnyxPort,
    String? turn,
    String? stun,
    List<TxIceServer>? webRTCIceServers,
    this.environment = WebRTCEnvironment.production,
  })  : turn = turn ?? DefaultConfig.defaultTurn,
        stun = stun ?? DefaultConfig.defaultStun,
        // Note: Using the `environment` parameter (not `this.environment`) to
        // determine default ICE servers. This is valid Dart - parameters are
        // accessible in the initializer list before instance fields are set.
        webRTCIceServers = webRTCIceServers ??
            (environment == WebRTCEnvironment.development
                ? DefaultConfig.defaultDevIceServers
                : DefaultConfig.defaultProdIceServers);

  /// The host address for the WebSocket connection.
  final String host;

  /// The port for the WebSocket connection.
  final int port;

  /// The TURN server URL for ICE candidates.
  ///
  /// @deprecated Use [webRTCIceServers] instead for more flexibility.
  /// This property is kept for backward compatibility.
  final String turn;

  /// The STUN server URL for ICE candidates.
  ///
  /// @deprecated Use [webRTCIceServers] instead for more flexibility.
  /// This property is kept for backward compatibility.
  final String stun;

  /// The list of ICE servers for WebRTC peer connections.
  ///
  /// This property allows configuring multiple TURN and STUN servers
  /// with authentication credentials. It mirrors the iOS SDK's
  /// `webRTCIceServers` property for cross-platform consistency.
  final List<TxIceServer> webRTCIceServers;

  /// The WebRTC environment (production or development).
  final WebRTCEnvironment environment;

  /// Creates a production server configuration with default production values.
  ///
  /// Uses:
  /// - Host: rtc.telnyx.com
  /// - ICE Servers: Telnyx production STUN/TURN servers + Google STUN
  static TxServerConfiguration production({
    List<TxIceServer>? webRTCIceServers,
  }) =>
      TxServerConfiguration(
        host: DefaultConfig.telnyxProdHostAddress,
        port: DefaultConfig.telnyxPort,
        turn: DefaultConfig.defaultTurn,
        stun: DefaultConfig.defaultStun,
        webRTCIceServers: webRTCIceServers,
        environment: WebRTCEnvironment.production,
      );

  /// Creates a development server configuration with default development values.
  ///
  /// Uses:
  /// - Host: rtcdev.telnyx.com
  /// - ICE Servers: Telnyx development STUN/TURN servers + Google STUN
  static TxServerConfiguration development({
    List<TxIceServer>? webRTCIceServers,
  }) =>
      TxServerConfiguration(
        host: DefaultConfig.telnyxDevHostAddress,
        port: DefaultConfig.telnyxPort,
        turn: DefaultConfig.devTurn,
        stun: DefaultConfig.devStun,
        webRTCIceServers: webRTCIceServers,
        environment: WebRTCEnvironment.development,
      );

  /// Returns the full WebSocket URL for this configuration.
  String get socketUrl => 'wss://$host:$port';

  /// Creates a copy of this configuration with the specified changes.
  ///
  /// Note: changing [environment] alone does NOT update [webRTCIceServers].
  /// If you want environment-appropriate ICE servers, also pass [webRTCIceServers]
  /// explicitly, or construct a fresh instance via [TxServerConfiguration.production]
  /// or [TxServerConfiguration.development] instead.
  TxServerConfiguration copyWith({
    String? host,
    int? port,
    String? turn,
    String? stun,
    List<TxIceServer>? webRTCIceServers,
    WebRTCEnvironment? environment,
  }) {
    return TxServerConfiguration(
      host: host ?? this.host,
      port: port ?? this.port,
      turn: turn ?? this.turn,
      stun: stun ?? this.stun,
      webRTCIceServers: webRTCIceServers ?? this.webRTCIceServers,
      environment: environment ?? this.environment,
    );
  }

  @override
  String toString() {
    return 'TxServerConfiguration(host: $host, port: $port, environment: $environment, iceServers: ${webRTCIceServers.length} servers)';
  }
}
