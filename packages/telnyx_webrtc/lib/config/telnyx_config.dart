/// Creates an instance of CredentialConfig which can be used to log in
///
/// Uses the [sipUser] and [sipPassword] fields to log in
/// [sipCallerIDName] and [sipCallerIDNumber] will be the Name and Number associated
/// [notificationToken] is the token used to register the device for notifications if required (FCM or APNS)
/// The [autoReconnect] flag decided whether or not to attempt a reconnect (3 attempts) in the case of a login failure with
/// legitimate credentials
class CredentialConfig {
  CredentialConfig(this.sipUser, this.sipPassword, this.sipCallerIDName,
      this.sipCallerIDNumber, this.notificationToken, this.autoReconnect,
      [this.ringTonePath, this.ringbackPath]);

  final String sipUser;
  final String sipPassword;
  final String sipCallerIDName;
  final String sipCallerIDNumber;
  final String? notificationToken;
  final bool? autoReconnect;
  final String? ringTonePath;
  final String? ringbackPath;
}

/// Creates an instance of TokenConfig which can be used to log in
///
/// Uses the [sipToken] field to log in
/// [sipCallerIDName] and [sipCallerIDNumber] will be the Name and Number associated
/// [notificationToken] is the token used to register the device for notifications if required (FCM or APNS)
/// The [autoReconnect] flag decided whether or not to attempt a reconnect (3 attempts) in the case of a login failure with
/// a legitimate token
class TokenConfig {
  TokenConfig(this.sipToken, this.sipCallerIDName, this.sipCallerIDNumber,
      this.notificationToken, this.autoReconnect,
      [this.ringTonePath, this.ringbackPath]);

  final String sipToken;
  final String sipCallerIDName;
  final String sipCallerIDNumber;
  final String? notificationToken;
  final bool? autoReconnect;
  final String? ringTonePath;
  final String? ringbackPath;
}
