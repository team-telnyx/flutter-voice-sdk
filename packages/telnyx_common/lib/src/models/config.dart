/// Configuration classes for authenticating with the Telnyx platform.

/// Base configuration class for Telnyx authentication.
abstract class Config {
  /// FCM token for push notifications (optional).
  final String? fcmToken;

  /// Whether to enable debug logging.
  final bool debug;

  const Config({
    this.fcmToken,
    this.debug = false,
  });
}

/// Configuration for credential-based authentication.
///
/// This configuration uses SIP username and password for authentication.
class CredentialConfig extends Config {
  /// SIP username for authentication.
  final String sipUser;

  /// SIP password for authentication.
  final String sipPassword;

  const CredentialConfig({
    required this.sipUser,
    required this.sipPassword,
    super.fcmToken,
    super.debug = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CredentialConfig &&
          other.sipUser == sipUser &&
          other.sipPassword == sipPassword &&
          other.fcmToken == fcmToken &&
          other.debug == debug);

  @override
  int get hashCode => Object.hash(sipUser, sipPassword, fcmToken, debug);

  @override
  String toString() => 'CredentialConfig(sipUser: $sipUser, debug: $debug)';
}

/// Configuration for token-based authentication.
///
/// This configuration uses a pre-generated authentication token.
class TokenConfig extends Config {
  /// Authentication token for the Telnyx platform.
  final String token;

  const TokenConfig({
    required this.token,
    super.fcmToken,
    super.debug = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TokenConfig &&
          other.token == token &&
          other.fcmToken == fcmToken &&
          other.debug == debug);

  @override
  int get hashCode => Object.hash(token, fcmToken, debug);

  @override
  String toString() => 'TokenConfig(debug: $debug)';
}