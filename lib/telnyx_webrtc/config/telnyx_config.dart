class CredentialConfig {
  CredentialConfig(this.sipUser, this.sipPassword, this.sipCallerIDName,
      this.sipCallerIDNumber, this.fcmToken);

  final String sipUser;
  final String sipPassword;
  final String sipCallerIDName;
  final String sipCallerIDNumber;
  final String? fcmToken;
}
