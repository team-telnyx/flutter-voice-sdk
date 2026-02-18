import 'package:telnyx_webrtc/model/tx_ice_server.dart';

/// Default configuration values for Telnyx WebRTC connections.
///
/// This class provides constants for production and development server
/// addresses, as well as default ICE server configurations for TURN/STUN.
class DefaultConfig {
  // MARK: - Host Configuration
  static const String telnyxProdHostAddress = 'rtc.telnyx.com';
  static const String telnyxDevHostAddress = 'rtcdev.telnyx.com';
  static const int telnyxPort = 443;
  static const String socketHostAddress =
      'wss://${DefaultConfig.telnyxProdHostAddress}:${DefaultConfig.telnyxPort}';

  // MARK: - Production TURN/STUN Servers
  /// Production TURN server with TCP transport
  static const String defaultTurn = 'turn:turn.telnyx.com:3478?transport=tcp';

  /// Production TURN server with UDP transport (preferred for lower latency)
  static const String defaultTurnUdp = 'turn:turn.telnyx.com:3478?transport=udp';

  /// Production STUN server
  static const String defaultStun = 'stun:stun.telnyx.com:3478';

  // MARK: - Development TURN/STUN Servers
  /// Development TURN server with TCP transport
  static const String devTurn = 'turn:turndev.telnyx.com:3478?transport=tcp';

  /// Development TURN server with UDP transport
  static const String devTurnUdp = 'turn:turndev.telnyx.com:3478?transport=udp';

  /// Development STUN server
  static const String devStun = 'stun:stundev.telnyx.com:3478';

  // MARK: - Google STUN Server (Fallback)
  /// Google's public STUN server for additional reliability
  static const String googleStun = 'stun:stun.l.google.com:19302';

  // MARK: - TURN Authentication
  static const username = 'testuser';
  static const password = 'testpassword';

  // MARK: - Default ICE Servers

  /// Default production ICE servers configuration.
  ///
  /// Includes:
  /// - Telnyx STUN server
  /// - Google STUN server (fallback)
  /// - Telnyx TURN server with UDP transport (preferred)
  /// - Telnyx TURN server with TCP transport (fallback)
  static List<TxIceServer> get defaultProdIceServers => [
        const TxIceServer(urls: [defaultStun]),
        const TxIceServer(urls: [googleStun]),
        TxIceServer(
          urls: [defaultTurnUdp],
          username: username,
          credential: password,
        ),
        TxIceServer(
          urls: [defaultTurn],
          username: username,
          credential: password,
        ),
      ];

  /// Default development ICE servers configuration.
  ///
  /// Includes:
  /// - Telnyx dev STUN server
  /// - Google STUN server (fallback)
  /// - Telnyx dev TURN server with UDP transport (preferred)
  /// - Telnyx dev TURN server with TCP transport (fallback)
  static List<TxIceServer> get defaultDevIceServers => [
        const TxIceServer(urls: [devStun]),
        const TxIceServer(urls: [googleStun]),
        TxIceServer(
          urls: [devTurnUdp],
          username: username,
          credential: password,
        ),
        TxIceServer(
          urls: [devTurn],
          username: username,
          credential: password,
        ),
      ];
}
