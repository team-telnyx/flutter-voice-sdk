import 'package:telnyx_webrtc/utils/logging/log_level.dart';

/// Custom logger interface to allow the user to provide their own logging implementation.
abstract class CustomLogger {
  /// Log level set by the user - will filter specific logs based on the level.
  var _logLevel = LogLevel.none;

  /// Set the log level for the SDK.
  void setLogLevel(LogLevel level) {
    _logLevel = level;
  }

  /// Log a message with the specified log level.
  void log(LogLevel level, String message);
}
