class Constants {
  static const String notificationKey = 'com.telnyx.webrtc.notification';

  // TelnyxClient Gateway registration variables
  static const int retryRegisterTime = 3;
  static const int retryConnectTime = 3;
  static const int gatewayResponseDelay = 3000;
  static const int reconnectTimer = 1000;

  // Reconnection timeout in milliseconds (60 seconds)
  // This is the maximum time allowed for a call to be in the RECONNECTING or DROPPED  state
  static const int reconnectionTimeout = 60000;

  // Stats Manager constants
  static const int statsInitial = 1000;
  static const int statsInterval = 2000;
  static const int candidateLimit = 10;
}
