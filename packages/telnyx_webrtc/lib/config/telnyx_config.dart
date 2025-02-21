import 'package:telnyx_webrtc/utils/logging/log_level.dart';
import 'package:telnyx_webrtc/utils/logging/custom_logger.dart';

/// Base configuration class for common parameters
class Config {
  /// Base configuration class for common parameters
  Config({
    required this.sipCallerIDName,
    required this.sipCallerIDNumber,
    this.notificationToken,
    this.autoReconnect,
    this.logLevel = LogLevel.info,
    required this.debug,
    this.customLogger,
    this.ringTonePath,
    this.ringbackPath,
  });

  /// Name associated with the SIP account
  final String sipCallerIDName;

  /// Number associated with the SIP account
  final String sipCallerIDNumber;

  /// Token used to register the device for notifications if required (FCM or APNS)
  final String? notificationToken;

  /// Flag to decide whether or not to attempt a reconnect (3 attempts) in the case of a login failure with legitimate credentials
  final bool? autoReconnect;

  /// Log level to set for SDK Logging
  final LogLevel logLevel;

  /// Flag to enable debug logs
  final bool debug;

  /// Custom logger to use for logging - if left null the default logger will be used which uses the Logger package
  final CustomLogger? customLogger;

  /// Path to the ringtone file (audio to play when receiving a call)
  final String? ringTonePath;

  /// Path to the ringback file (audio to play when calling)
  final String? ringbackPath;
}

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
class CredentialConfig extends Config {
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
  });

  /// SIP username to log in with. Either a SIP Credential from the Portal or a Generated Credential from the API
  final String sipUser;

  /// SIP password to log in with. Either a SIP Credential from the Portal or a Generated Credential from the API
  final String sipPassword;
}

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
class TokenConfig extends Config {
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
  });

  /// Token to log in with. The token would be generated from a Generated Credential via the API
  final String sipToken;
}
