### Config
Config is used to log in and connect to the Telnyx WebRTC client. It contains the necessary fields to log in with either a token or credentials.

The base Config class is represented like so:

```dart
class Config {
  final String sipCallerIDName;
  final String sipCallerIDNumber;
  final String? notificationToken;
  final bool autoReconnect;
  final bool debug;
  final String? ringTonePath;
  final String? ringbackPath;

  Config({
    required this.sipCallerIDName,
    required this.sipCallerIDNumber,
    this.notificationToken,
    this.autoReconnect = true,
    this.debug = false,
    this.ringTonePath,
    this.ringbackPath,
  });
}
```

The base Config class contains shared fields that are used by both the `TokenConfig` and `CredentialConfig` classes. These are the actual classes that you will use to log into the client.

#### TokenConfig

`TokenConfig` is used to log in with a token. It extends the base `Config` class and looks like this:

```dart
/// Creates an instance of TokenConfig which can be used to log in
///
/// Uses the [sipToken] field to log in
/// [sipCallerIDName] and [sipCallerIDNumber] will be the Name and Number associated
/// [notificationToken] is the token used to register the device for notifications if required (FCM or APNS)
/// The [autoReconnect] flag decided whether or not to attempt a reconnect (3 attempts) in the case of a login failure with
/// a legitimate token
class TokenConfig extends Config {
  TokenConfig({
    required this.sipToken,
    required super.sipCallerIDName,
    required super.sipCallerIDNumber,
    super.notificationToken,
    super.autoReconnect,
    required super.debug,
    super.ringTonePath,
    super.ringbackPath,
  });

  final String sipToken;
}
```

#### CredentialConfig

`CredentialConfig` is used to log in with credentials. It extends the base `Config` class and looks like this:

```dart
/// Creates an instance of CredentialConfig which can be used to log in
///
/// Uses the [sipUser] and [sipPassword] fields to log in
/// [sipCallerIDName] and [sipCallerIDNumber] will be the Name and Number associated
/// [notificationToken] is the token used to register the device for notifications if required (FCM or APNS)
/// The [autoReconnect] flag decided whether or not to attempt a reconnect (3 attempts) in the case of a login failure with
/// legitimate credentials
class CredentialConfig extends Config {
  CredentialConfig({
    required this.sipUser,
    required this.sipPassword,
    required super.sipCallerIDName,
    required super.sipCallerIDNumber,
    super.notificationToken,
    super.autoReconnect,
    required super.debug,
    super.ringTonePath,
    super.ringbackPath,
  });

  final String sipUser;
  final String sipPassword;
}
```