import 'package:telnyx_webrtc/utils/logging/log_level.dart';
import 'package:telnyx_webrtc/utils/logging/custom_logger.dart';
import 'package:telnyx_webrtc/utils/logging/global_logger.dart';
import 'package:telnyx_webrtc/model/region.dart';
import 'package:telnyx_webrtc/model/tx_ice_server.dart';
import 'package:telnyx_webrtc/model/tx_server_configuration.dart';
import 'package:telnyx_webrtc/config/debug_output.dart';
import 'package:telnyx_webrtc/config/debug_log_level.dart';

// Re-export GlobalLogger so tests/consumers can import it from telnyx_config.dart
export 'package:telnyx_webrtc/utils/logging/global_logger.dart';

// Re-export debug enums so consumers don't need a separate import.
export 'package:telnyx_webrtc/config/debug_output.dart';
export 'package:telnyx_webrtc/config/debug_log_level.dart';

// Re-export CallReportOptions so tests/consumers can import it from telnyx_config.dart
export 'package:telnyx_webrtc/utils/stats/call_report_collector.dart'
    show CallReportOptions;

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
    this.pushAnswerTimeout,
    this.region = Region.auto,
    this.fallbackOnRegionFailure = true,
    this.forceRelayCandidate = false,
    this.iceServers,
    this.serverConfiguration,
    this.callReportInterval = 5000,
    this.callReportLogLevel = 'debug',
    this.callReportMaxLogEntries = 1000,
    this.enableCallReports = true,
    this.debugOutput = DebugOutput.socket,
    this.debugLogLevel = DebugLogLevel.info,
    this.debugLogMaxEntries = 1000,
    this.callReportFlushInterval = 180000,
    this.prefetchIceCandidates = true,
    this.autoRecoverCalls = true,
    this.hangupOnBeforeUnload = true,
    this.maxReconnectAttempts = 10,
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

  /// pushAnswerTimeout in milliseconds (Default 10 seconds)
  /// This is the maximum time to wait for an INVITE after accepting from push notification
  /// Can be overridden per call via handlePushNotification's pushAnswerTimeoutMs parameter
  int? pushAnswerTimeout = 10000;

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

  /// Custom ICE servers for WebRTC peer connections.
  ///
  /// When provided, these ICE servers will be used instead of the default
  /// Telnyx TURN/STUN servers. This allows for custom TURN/STUN server
  /// configuration to support specific network requirements.
  ///
  /// Example:
  /// ```dart
  /// iceServers: [
  ///   TxIceServer(urls: ['stun:stun.example.com:3478']),
  ///   TxIceServer(
  ///     urls: ['turn:turn.example.com:3478?transport=tcp'],
  ///     username: 'user',
  ///     credential: 'password',
  ///   ),
  /// ]
  /// ```
  final List<TxIceServer>? iceServers;

  /// Server configuration for signaling and ICE servers.
  ///
  /// When provided, this configuration will be used for the WebSocket
  /// connection and ICE server settings. If [iceServers] is also provided,
  /// it takes precedence over the ICE servers in this configuration.
  final TxServerConfiguration? serverConfiguration;

  /// Call report stats collection interval in milliseconds (default: 5000)
  /// Call reports are always enabled — this controls the collection frequency.
  final int callReportInterval;

  /// Minimum log level for call report structured logging (default: "debug")
  /// Valid values: "debug", "info", "warning", "error"
  final String callReportLogLevel;

  /// Maximum number of structured log entries to buffer per call (default: 1000)
  final int callReportMaxLogEntries;

  /// Enable call report stats collection (default: true)
  final bool enableCallReports;

  /// Debug output destination for call reports and diagnostics (default: [DebugOutput.socket])
  final DebugOutput debugOutput;

  /// Debug log level filter for the GlobalLogger (default: [DebugLogLevel.info])
  final DebugLogLevel debugLogLevel;

  /// Maximum number of debug log entries to buffer (default: 1000)
  final int debugLogMaxEntries;

  /// Call report flush interval in milliseconds for intermediate segments (default: 180000 = 3 min)
  final int callReportFlushInterval;

  /// Whether to prefetch ICE candidates before setLocalDescription (default: true)
  final bool prefetchIceCandidates;

  /// Whether to automatically recover calls on reconnect (default: true)
  final bool autoRecoverCalls;

  /// Whether to hangup on page beforeunload event (default: true)
  final bool hangupOnBeforeUnload;

  /// Maximum reconnection attempts before giving up; 0 means unlimited (default: 10)
  final int maxReconnectAttempts;

  /// Apply the [debugLogLevel] to the GlobalLogger by setting a level filter.
  /// Messages below the configured level are suppressed.
  void applyDebugLogLevel() {
    final levelMap = <DebugLogLevel, LogLevel>{
      DebugLogLevel.debug: LogLevel.debug,
      DebugLogLevel.info: LogLevel.info,
      DebugLogLevel.warning: LogLevel.warning,
      DebugLogLevel.error: LogLevel.error,
    };
    final minLevel = levelMap[debugLogLevel] ?? LogLevel.info;
    GlobalLogger.logger = _LevelFilterLogger(GlobalLogger.logger, minLevel);
  }
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
/// [pushAnswerTimeout] is the timeout in milliseconds to wait for INVITE after accepting from push notification (default: 10000ms)
/// [forceRelayCandidate] controls whether the SDK should force TURN relay for peer connections (default: false)
/// [iceServers] custom ICE servers for WebRTC peer connections
/// [serverConfiguration] server configuration for signaling and ICE servers
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
  /// [pushAnswerTimeout] is the timeout in milliseconds to wait for INVITE after accepting from push notification (default: 10000ms)
  /// [iceServers] custom ICE servers for WebRTC peer connections
  /// [serverConfiguration] server configuration for signaling and ICE servers
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
    super.pushAnswerTimeout,
    super.region = Region.auto,
    super.fallbackOnRegionFailure = true,
    super.forceRelayCandidate = false,
    super.iceServers,
    super.serverConfiguration,
    super.callReportInterval = 5000,
    super.callReportLogLevel = 'debug',
    super.callReportMaxLogEntries = 1000,
    super.enableCallReports = true,
    super.debugOutput = DebugOutput.socket,
    super.debugLogLevel = DebugLogLevel.info,
    super.debugLogMaxEntries = 1000,
    super.callReportFlushInterval = 180000,
    super.prefetchIceCandidates = true,
    super.autoRecoverCalls = true,
    super.hangupOnBeforeUnload = true,
    super.maxReconnectAttempts = 10,
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
/// [pushAnswerTimeout] is the timeout in milliseconds to wait for INVITE after accepting from push notification (default: 10000ms)
/// [forceRelayCandidate] controls whether the SDK should force TURN relay for peer connections (default: false)
/// [iceServers] custom ICE servers for WebRTC peer connections
/// [serverConfiguration] server configuration for signaling and ICE servers
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
  /// [pushAnswerTimeout] is the timeout in milliseconds to wait for INVITE after accepting from push notification (default: 10000ms)
  /// [iceServers] custom ICE servers for WebRTC peer connections
  /// [serverConfiguration] server configuration for signaling and ICE servers
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
    super.pushAnswerTimeout,
    super.region = Region.auto,
    super.fallbackOnRegionFailure = true,
    super.forceRelayCandidate = false,
    super.iceServers,
    super.serverConfiguration,
    super.callReportInterval = 5000,
    super.callReportLogLevel = 'debug',
    super.callReportMaxLogEntries = 1000,
    super.enableCallReports = true,
    super.debugOutput = DebugOutput.socket,
    super.debugLogLevel = DebugLogLevel.info,
    super.debugLogMaxEntries = 1000,
    super.callReportFlushInterval = 180000,
    super.prefetchIceCandidates = true,
    super.autoRecoverCalls = true,
    super.hangupOnBeforeUnload = true,
    super.maxReconnectAttempts = 10,
  });

  /// Token to log in with. The token would be generated from a Generated Credential via the API
  final String sipToken;
}

/// Wraps a [CustomLogger] and suppresses messages below [_minLevel].
class _LevelFilterLogger implements CustomLogger {
  _LevelFilterLogger(this._inner, this._minLevel);

  final CustomLogger _inner;
  final LogLevel _minLevel;

  @override
  void setLogLevel(LogLevel level) => _inner.setLogLevel(level);

  @override
  void log(LogLevel level, String message) {
    final msgPriority = level.priority;
    final minPriority = _minLevel.priority;
    if (msgPriority != null && minPriority != null) {
      if (msgPriority < minPriority) return;
    }
    _inner.log(level, message);
  }
}
