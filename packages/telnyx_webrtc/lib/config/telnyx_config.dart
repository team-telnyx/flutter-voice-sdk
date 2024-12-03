/// Base configuration class for common parameters
class Config {
  Config(
    this.sipCallerIDName,
    this.sipCallerIDNumber,
    this.notificationToken,
    this.autoReconnect,
    this.debug, [
    this.ringTonePath,
    this.ringbackPath,
  ]);

  final String sipCallerIDName;
  final String sipCallerIDNumber;
  final String? notificationToken;
  final bool? autoReconnect;
  final bool debug;
  final String? ringTonePath;
  final String? ringbackPath;
}

/// Creates an instance of CredentialConfig which can be used to log in
///
/// Uses the [sipUser] and [sipPassword] fields to log in
/// [sipCallerIDName] and [sipCallerIDNumber] will be the Name and Number associated
/// [notificationToken] is the token used to register the device for notifications if required (FCM or APNS)
/// The [autoReconnect] flag decided whether or not to attempt a reconnect (3 attempts) in the case of a login failure with
/// legitimate credentials
class CredentialConfig extends Config {
  CredentialConfig(
    this.sipUser,
    this.sipPassword,
    String sipCallerIDName,
    String sipCallerIDNumber,
    String? notificationToken,
    bool? autoReconnect,
    bool debug, [
    String? ringTonePath,
    String? ringbackPath,
  ]) : super(
          sipCallerIDName,
          sipCallerIDNumber,
          notificationToken,
          autoReconnect,
          debug,
          ringTonePath,
          ringbackPath,
        );

  final String sipUser;
  final String sipPassword;
}

/// Creates an instance of TokenConfig which can be used to log in
///
/// Uses the [sipToken] field to log in
/// [sipCallerIDName] and [sipCallerIDNumber] will be the Name and Number associated
/// [notificationToken] is the token used to register the device for notifications if required (FCM or APNS)
/// The [autoReconnect] flag decided whether or not to attempt a reconnect (3 attempts) in the case of a login failure with
/// a legitimate token
class TokenConfig extends Config {
  TokenConfig(
    this.sipToken,
    String sipCallerIDName,
    String sipCallerIDNumber,
    String? notificationToken,
    bool? autoReconnect,
    bool debug, [
    String? ringTonePath,
    String? ringbackPath,
  ]) : super(
          sipCallerIDName,
          sipCallerIDNumber,
          notificationToken,
          autoReconnect,
          debug,
          ringTonePath,
          ringbackPath,
        );

  final String sipToken;
}
