class DefaultConfig {
  static const String telnyxProdHostAddress = 'rtc.telnyx.com';
  static const String telnyxDevHostAddress = 'rtcdev.telnyx.com';
  static const int telnyxPort = 443;
  static const String socketHostAddress =
      'wss://${DefaultConfig.telnyxProdHostAddress}:${DefaultConfig.telnyxPort}';

  // Production TURN servers
  // UDP preferred for lower latency, TCP as fallback for restrictive firewalls
  static const String defaultTurnUdp =
      'turn:turn.telnyx.com:3478?transport=udp';
  static const String defaultTurnTcp =
      'turn:turn.telnyx.com:3478?transport=tcp';

  // Production STUN server
  static const String defaultStun = 'stun:stun.telnyx.com:3478';

  // Development TURN servers
  // UDP preferred for lower latency, TCP as fallback for restrictive firewalls
  static const String devTurnUdp = 'turn:turndev.telnyx.com:3478?transport=udp';
  static const String devTurnTcp = 'turn:turndev.telnyx.com:3478?transport=tcp';

  // Development STUN server
  static const String devStun = 'stun:stundev.telnyx.com:3478';

  // Google STUN server for additional STUN redundancy (aligned with JS WebRTC SDK)
  static const String googleStun = 'stun:stun.l.google.com:19302';

  // Legacy aliases for backward compatibility
  @Deprecated('Use defaultTurnUdp instead. TCP is now a fallback.')
  static const String defaultTurn = defaultTurnUdp;
  @Deprecated('Use devTurnUdp instead. TCP is now a fallback.')
  static const String devTurn = devTurnUdp;

  static const username = 'testuser';
  static const password = 'testpassword';
}
