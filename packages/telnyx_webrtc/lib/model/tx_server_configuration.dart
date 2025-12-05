import 'package:telnyx_webrtc/config.dart';

/// Configuration for Telnyx server connections including host, port, and ICE servers.
///
/// This class provides factory methods to create production or development
/// server configurations with appropriate TURN/STUN server settings.
class TxServerConfiguration {
  /// Creates a server configuration with the specified parameters.
  const TxServerConfiguration({
    this.host = DefaultConfig.telnyxProdHostAddress,
    this.port = DefaultConfig.telnyxPort,
    this.turn = DefaultConfig.defaultTurn,
    this.stun = DefaultConfig.defaultStun,
  });

  /// The host address for the WebSocket connection.
  final String host;

  /// The port for the WebSocket connection.
  final int port;

  /// The TURN server URL for ICE candidates.
  final String turn;

  /// The STUN server URL for ICE candidates.
  final String stun;

  /// Creates a production server configuration with default production values.
  ///
  /// Uses:
  /// - Host: rtc.telnyx.com
  /// - TURN: turn.telnyx.com
  /// - STUN: stun.telnyx.com
  static TxServerConfiguration production() => const TxServerConfiguration(
        host: DefaultConfig.telnyxProdHostAddress,
        port: DefaultConfig.telnyxPort,
        turn: DefaultConfig.defaultTurn,
        stun: DefaultConfig.defaultStun,
      );

  /// Creates a development server configuration with default development values.
  ///
  /// Uses:
  /// - Host: rtcdev.telnyx.com
  /// - TURN: turndev.telnyx.com
  /// - STUN: stundev.telnyx.com
  static TxServerConfiguration development() => const TxServerConfiguration(
        host: DefaultConfig.telnyxDevHostAddress,
        port: DefaultConfig.telnyxPort,
        turn: DefaultConfig.devTurn,
        stun: DefaultConfig.devStun,
      );

  /// Returns the full WebSocket URL for this configuration.
  String get socketUrl => 'wss://$host:$port';

  @override
  String toString() {
    return 'TxServerConfiguration(host: $host, port: $port, turn: $turn, stun: $stun)';
  }
}
