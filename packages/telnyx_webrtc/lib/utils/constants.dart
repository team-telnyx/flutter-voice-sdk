class Constants {
  static const String notificationKey = 'com.telnyx.webrtc.notification';

  // TelnyxClient Gateway registration variables
  static const int retryRegisterTime = 3;
  static const int retryConnectTime = 3;
  static const int gatewayResponseDelay = 3000;
  static const int reconnectTimer = 1000;

  // Stats Manager constants
  static const int statsInitial = 1000;
  static const int statsInterval = 2000;
  static const int candidateLimit = 10;
}
