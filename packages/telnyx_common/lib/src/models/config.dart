import 'package:telnyx_webrtc/config.dart' as webrtc;

/// Configuration for connecting to Telnyx using credentials.
class CredentialConfig {
  /// The SIP username for authentication.
  final String sipUser;
  
  /// The SIP password for authentication.
  final String sipPassword;
  
  /// The FCM token for push notifications (optional).
  final String? fcmToken;
  
  /// Whether to enable debug logging.
  final bool debug;
  
  /// Timeout for reconnection attempts in milliseconds.
  final int reconnectionTimeout;
  
  /// Whether to enable auto-reconnection.
  final bool autoReconnect;
  
  const CredentialConfig({
    required this.sipUser,
    required this.sipPassword,
    this.fcmToken,
    this.debug = false,
    this.reconnectionTimeout = 30000,
    this.autoReconnect = true,
  });
  
  /// Converts this config to the underlying webrtc CredentialConfig.
  webrtc.CredentialConfig toWebRtcConfig() {
    return webrtc.CredentialConfig(
      sipUser: sipUser,
      sipPassword: sipPassword,
      fcmToken: fcmToken,
      debug: debug,
      reconnectionTimeout: reconnectionTimeout,
      autoReconnect: autoReconnect,
    );
  }
}

/// Configuration for connecting to Telnyx using a token.
class TokenConfig {
  /// The authentication token.
  final String token;
  
  /// The FCM token for push notifications (optional).
  final String? fcmToken;
  
  /// Whether to enable debug logging.
  final bool debug;
  
  /// Timeout for reconnection attempts in milliseconds.
  final int reconnectionTimeout;
  
  /// Whether to enable auto-reconnection.
  final bool autoReconnect;
  
  const TokenConfig({
    required this.token,
    this.fcmToken,
    this.debug = false,
    this.reconnectionTimeout = 30000,
    this.autoReconnect = true,
  });
  
  /// Converts this config to the underlying webrtc TokenConfig.
  webrtc.TokenConfig toWebRtcConfig() {
    return webrtc.TokenConfig(
      token: token,
      fcmToken: fcmToken,
      debug: debug,
      reconnectionTimeout: reconnectionTimeout,
      autoReconnect: autoReconnect,
    );
  }
}