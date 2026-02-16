import 'package:telnyx_webrtc/config.dart';

/// Configuration for Telnyx server connections including host, port, and ICE servers.
///
/// This class provides factory methods to create production or development
/// server configurations with appropriate TURN/STUN server settings.
///
/// ICE server order (aligned with JS/iOS SDKs):
/// 1. Telnyx STUN server
/// 2. Google STUN server (for redundancy)
/// 3. TURN UDP server (primary - lower latency)
/// 4. TURN TCP server (fallback - for restrictive firewalls)
class TxServerConfiguration {
  /// Creates a server configuration with the specified parameters.
  ///
  /// [host] The host address for the WebSocket connection.
  /// [port] The port for the WebSocket connection.
  /// [turnUdp] The primary TURN server URL (UDP transport - lower latency).
  /// [turnTcp] The fallback TURN server URL (TCP transport - for restrictive firewalls).
  /// [stun] The Telnyx STUN server URL.
  /// [googleStun] The Google STUN server URL for redundancy.
  const TxServerConfiguration({
    this.host = DefaultConfig.telnyxProdHostAddress,
    this.port = DefaultConfig.telnyxPort,
    this.turnUdp = DefaultConfig.defaultTurnUdp,
    this.turnTcp = DefaultConfig.defaultTurnTcp,
    this.stun = DefaultConfig.defaultStun,
    this.googleStun = DefaultConfig.googleStun,
  });

  /// The host address for the WebSocket connection.
  final String host;

  /// The port for the WebSocket connection.
  final int port;

  /// The primary TURN server URL (UDP transport - lower latency).
  final String turnUdp;

  /// The fallback TURN server URL (TCP transport - for restrictive firewalls).
  final String turnTcp;

  /// The Telnyx STUN server URL for ICE candidates.
  final String stun;

  /// The Google STUN server URL for additional STUN redundancy.
  /// Aligned with JS WebRTC SDK for consistent behavior across platforms.
  final String googleStun;

  /// Legacy getter for backward compatibility.
  /// Returns the primary TURN server (UDP).
  @Deprecated('Use turnUdp instead. TCP is available via turnTcp.')
  String get turn => turnUdp;

  /// Creates a production server configuration with default production values.
  ///
  /// Uses:
  /// - Host: rtc.telnyx.com
  /// - TURN UDP: turn.telnyx.com (primary - lower latency)
  /// - TURN TCP: turn.telnyx.com (fallback - for restrictive firewalls)
  /// - STUN: stun.telnyx.com
  /// - Google STUN: stun.l.google.com (for redundancy)
  static TxServerConfiguration production() => const TxServerConfiguration(
    host: DefaultConfig.telnyxProdHostAddress,
    port: DefaultConfig.telnyxPort,
    turnUdp: DefaultConfig.defaultTurnUdp,
    turnTcp: DefaultConfig.defaultTurnTcp,
    stun: DefaultConfig.defaultStun,
    googleStun: DefaultConfig.googleStun,
  );

  /// Creates a development server configuration with default development values.
  ///
  /// Uses:
  /// - Host: rtcdev.telnyx.com
  /// - TURN UDP: turndev.telnyx.com (primary - lower latency)
  /// - TURN TCP: turndev.telnyx.com (fallback - for restrictive firewalls)
  /// - STUN: stundev.telnyx.com
  /// - Google STUN: stun.l.google.com (for redundancy)
  static TxServerConfiguration development() => const TxServerConfiguration(
    host: DefaultConfig.telnyxDevHostAddress,
    port: DefaultConfig.telnyxPort,
    turnUdp: DefaultConfig.devTurnUdp,
    turnTcp: DefaultConfig.devTurnTcp,
    stun: DefaultConfig.devStun,
    googleStun: DefaultConfig.googleStun,
  );

  /// Returns the full WebSocket URL for this configuration.
  String get socketUrl => 'wss://$host:$port';

  @override
  String toString() {
    return 'TxServerConfiguration(host: $host, port: $port, '
        'turnUdp: $turnUdp, turnTcp: $turnTcp, stun: $stun, googleStun: $googleStun)';
  }
}
