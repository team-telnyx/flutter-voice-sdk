class DefaultConfig {
  static const String telnyxProdHostAddress = 'rtc.telnyx.com';
  static const String telnyxDevHostAddress = 'rtcdev.telnyx.com';
  static const int telnyxPort = 443;
  static const String socketHostAddress =
      'wss://${DefaultConfig.telnyxProdHostAddress}:${DefaultConfig.telnyxPort}';
  static const String defaultTurn = 'turn:turn.telnyx.com:3478?transport=tcp';
  static const String defaultStun = 'stun:stun.telnyx.com:3478';
  static const String devTurn = 'turn:turndev.telnyx.com:3478?transport=tcp';
  static const String devStun = 'stun:stundev.telnyx.com:3478';
  static const username = 'testuser';
  static const password = 'testpassword';
}
