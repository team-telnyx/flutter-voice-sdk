### Config
Config is used to log in and connect to the Telnyx WebRTC client. It contains the necessary fields to log in with either a token or credentials.

The base Config class is represented like so:

```dart
class Config {
  final String sipCallerIDName;
  final String sipCallerIDNumber;
  final String? notificationToken;
  final bool? autoReconnect;
  final LogLevel logLevel;
  final bool debug;
  final CustomLogger? customLogger;
  final String? ringTonePath;
  final String? ringbackPath;
  int? reconnectionTimeout;
  final Region region;
  final bool fallbackOnRegionFailure;

  Config({
    required this.sipCallerIDName,
    required this.sipCallerIDNumber,
    this.notificationToken,
    this.autoReconnect,
    this.logLevel = LogLevel.all,
    required this.debug,
    this.customLogger,
    this.ringTonePath,
    this.ringbackPath,
    this.reconnectionTimeout,
    this.region = Region.auto,
    this.fallbackOnRegionFailure = true,
  });
}
```

#### Config Parameters

- **`sipCallerIDName`** (String, required): Name associated with the SIP account
- **`sipCallerIDNumber`** (String, required): Number associated with the SIP account
- **`notificationToken`** (String?, optional): Token used to register the device for notifications if required (FCM or APNS)
- **`autoReconnect`** (bool?, optional): Flag to decide whether or not to attempt a reconnect (3 attempts) in the case of a login failure with legitimate credentials
- **`logLevel`** (LogLevel, optional): Log level to set for SDK Logging (defaults to `LogLevel.all`)
- **`debug`** (bool, required): Flag to enable debug logs
- **`customLogger`** (CustomLogger?, optional): Custom logger to use for logging - if left null the default logger will be used which uses the Logger package
- **`ringTonePath`** (String?, optional): Path to the ringtone file (audio to play when receiving a call)
- **`ringbackPath`** (String?, optional): Path to the ringback file (audio to play when calling)
- **`reconnectionTimeout`** (int?, optional): Reconnection timeout in milliseconds (Default 60 seconds). This is the maximum time allowed for a call to be in the RECONNECTING or DROPPED state
- **`region`** (Region, optional): The region to use for the connection (defaults to `Region.auto`)
- **`fallbackOnRegionFailure`** (bool, optional): Whether the SDK should default to AUTO after attempting and failing to connect to a specified region (defaults to `true`)

#### Available Regions

The `Region` enum provides the following options:

- **`Region.auto`**: Automatically select the best region (default)
- **`Region.eu`**: European region
- **`Region.usCentral`**: US Central region
- **`Region.usEast`**: US East region
- **`Region.usWest`**: US West region
- **`Region.caCentral`**: Canada Central region
- **`Region.apac`**: Asia Pacific region

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
/// [logLevel] is the log level to set for SDK Logging
/// [debug] flag to enable debug logs which will collect stats for each call and provide WebRTC stats to view in the portal
/// [ringTonePath] is the path to the ringtone file (audio to play when receiving a call)
/// [ringbackPath] is the path to the ringback file (audio to play when calling)
/// [customLogger] is a custom logger to use for logging - if left null the default logger will be used which uses the Logger package
/// [reconnectionTimeout] is the reconnection timeout in milliseconds (Default 60 seconds)
/// [region] is the region to use for the connection (Auto by default)
/// [fallbackOnRegionFailure] determines whether the SDK should default to AUTO after attempting and failing to connect to a specified region
class TokenConfig extends Config {
  TokenConfig({
    required this.sipToken,
    required super.sipCallerIDName,
    required super.sipCallerIDNumber,
    super.notificationToken,
    super.autoReconnect,
    required super.logLevel,
    required super.debug,
    super.ringTonePath,
    super.ringbackPath,
    super.customLogger,
    super.reconnectionTimeout,
    super.region = Region.auto,
    super.fallbackOnRegionFailure = true,
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
/// [logLevel] is the log level to set for SDK Logging
/// [debug] flag to enable debug logs which will collect stats for each call and provide WebRTC stats to view in the portal
/// [ringTonePath] is the path to the ringtone file (audio to play when receiving a call)
/// [ringbackPath] is the path to the ringback file (audio to play when calling)
/// [customLogger] is a custom logger to use for logging - if left null the default logger will be used which uses the Logger package
/// [reconnectionTimeout] is the reconnection timeout in milliseconds (Default 60 seconds)
/// [region] is the region to use for the connection (Auto by default)
/// [fallbackOnRegionFailure] determines whether the SDK should default to AUTO after attempting and failing to connect to a specified region
class CredentialConfig extends Config {
  CredentialConfig({
    required this.sipUser,
    required this.sipPassword,
    required super.sipCallerIDName,
    required super.sipCallerIDNumber,
    super.notificationToken,
    super.autoReconnect,
    required super.logLevel,
    required super.debug,
    super.ringTonePath,
    super.ringbackPath,
    super.customLogger,
    super.reconnectionTimeout,
    super.region = Region.auto,
    super.fallbackOnRegionFailure = true,
  });

  final String sipUser;
  final String sipPassword;
}
```