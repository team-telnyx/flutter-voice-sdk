class CredentialConfig {
  CredentialConfig(this.sipUser, this.sipPassword, this.sipCallerIDName,
      this.sipCallerIDNumber, this.fcmToken, this.autoReconnect);

  final String sipUser;
  final String sipPassword;
  final String sipCallerIDName;
  final String sipCallerIDNumber;
  final String? fcmToken;
  final bool? autoReconnect;
}

class TokenConfig {
  TokenConfig(this.sipToken, this.sipCallerIDName,
      this.sipCallerIDNumber, this.fcmToken, this.autoReconnect);

  final String sipToken;
  final String sipCallerIDName;
  final String sipCallerIDNumber;
  final String? fcmToken;
  final bool? autoReconnect;
}
