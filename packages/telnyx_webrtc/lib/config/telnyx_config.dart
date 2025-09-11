import 'package:telnyx_webrtc/utils/logging/log_level.dart';
import 'package:telnyx_webrtc/utils/logging/custom_logger.dart';
import 'package:telnyx_webrtc/model/region.dart';

/// Base configuration class for common parameters
class Config {
  /// Base configuration class for common parameters
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
    this.forceRelayCandidate = false,
    this.useTrickleIce = false,
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

  /// reconnectionTimeout in milliseconds (Default 60 seconds)
  // This is the maximum time allowed for a call to be in the RECONNECTING or DROPPED state
  int? reconnectionTimeout = 60000;

  /// The region to use for the connection (Auto by default)
  final Region region;

  /// Whether the SDK should default to AUTO after attempting and failing to connect to a specified region
  final bool fallbackOnRegionFailure;

  /// Controls whether the SDK should force TURN relay for peer connections.
  /// When enabled, the SDK will only use TURN relay candidates for ICE gathering,
  /// which prevents the "local network access" permission popup from appearing.
  /// - Note: Enabling this may affect the quality of calls when devices are on the same local network,
  ///   as all media will be relayed through TURN servers.
  /// - Important: This setting is disabled by default to maintain optimal call quality.
  final bool forceRelayCandidate;

  /// Controls whether the SDK should use Trickle ICE for peer connections.
  /// When enabled, ICE candidates are sent individually as they are discovered,
  /// allowing for faster call establishment. When disabled, the SDK waits for
  /// all ICE candidates to be gathered before sending the offer/answer.
  /// - Note: This setting is disabled by default to maintain compatibility.
  final bool useTrickleIce;
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
/// [forceRelayCandidate] controls whether the SDK should force TURN relay for peer connections (default: false)
/// [useTrickleIce] controls whether the SDK should use Trickle ICE for peer connections (default: false)
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
    super.reconnectionTimeout,
    super.region = Region.auto,
    super.fallbackOnRegionFailure = true,
    super.forceRelayCandidate = false,
    super.useTrickleIce = false,
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
/// [forceRelayCandidate] controls whether the SDK should force TURN relay for peer connections (default: false)
/// [useTrickleIce] controls whether the SDK should use Trickle ICE for peer connections (default: false)
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
    super.reconnectionTimeout,
    super.region = Region.auto,
    super.fallbackOnRegionFailure = true,
    super.forceRelayCandidate = false,
    super.useTrickleIce = false,
  });

  /// Token to log in with. The token would be generated from a Generated Credential via the API
  final String sipToken;
}
