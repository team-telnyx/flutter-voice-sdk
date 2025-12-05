import 'package:telnyx_webrtc/config.dart';

/// Configuration class for Telnyx server settings.
///
/// This class holds the configuration for connecting to Telnyx servers,
/// including the host address, port, and TURN/STUN server URLs.
///
/// Use the factory constructors [TxServerConfiguration.production] and
/// [TxServerConfiguration.development] to create configurations for
/// the respective environments.
class TxServerConfiguration {
  /// Creates a new [TxServerConfiguration] with the specified settings.
  ///
  /// [host] - The WebSocket host address (e.g., 'rtc.telnyx.com')
  /// [port] - The WebSocket port (default: 443)
  /// [turn] - The TURN server URL
  /// [stun] - The STUN server URL
  const TxServerConfiguration({
    this.host = DefaultConfig.telnyxProdHostAddress,
    this.port = DefaultConfig.telnyxPort,
    this.turn = DefaultConfig.defaultTurn,
    this.stun = DefaultConfig.defaultStun,
  });

  /// The WebSocket host address
  final String host;

  /// The WebSocket port
  final int port;

  /// The TURN server URL
  final String turn;

  /// The STUN server URL
  final String stun;

  /// Creates a production server configuration with default production values.
  ///
  /// Uses:
  /// - Host: rtc.telnyx.com
  /// - TURN: turn.telnyx.com:3478
  /// - STUN: stun.telnyx.com:3478
  factory TxServerConfiguration.production() => const TxServerConfiguration(
    host: DefaultConfig.telnyxProdHostAddress,
    port: DefaultConfig.telnyxPort,
    turn: DefaultConfig.defaultTurn,
    stun: DefaultConfig.defaultStun,
  );

  /// Creates a development server configuration with default development values.
  ///
  /// Uses:
  /// - Host: rtcdev.telnyx.com
  /// - TURN: turndev.telnyx.com:3478
  /// - STUN: stundev.telnyx.com:3478
  factory TxServerConfiguration.development() => const TxServerConfiguration(
    host: DefaultConfig.telnyxDevHostAddress,
    port: DefaultConfig.telnyxPort,
    turn: DefaultConfig.devTurn,
    stun: DefaultConfig.devStun,
  );

  /// Returns the full WebSocket URL for this configuration.
  String get socketUrl => 'wss://$host:$port';

  /// Creates a copy of this configuration with the specified fields replaced.
  TxServerConfiguration copyWith({
    String? host,
    int? port,
    String? turn,
    String? stun,
  }) {
    return TxServerConfiguration(
      host: host ?? this.host,
      port: port ?? this.port,
      turn: turn ?? this.turn,
      stun: stun ?? this.stun,
    );
  }

  @override
  String toString() {
    return 'TxServerConfiguration(host: $host, port: $port, turn: $turn, stun: $stun)';
  }
}
