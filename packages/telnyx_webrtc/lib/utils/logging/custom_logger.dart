import 'package:telnyx_webrtc/utils/logging/log_level.dart';

/// Custom logger interface to allow the user to provide their own logging implementation.
abstract class CustomLogger {

  /// Log level set by the user - will filter specific logs based on the level.
  var _logLevel = LogLevel.none;

  /// Set the log level for the SDK.
  void setLogLevel(LogLevel level) {
    _logLevel = level;
  }

  /// Log a message with the error log level.
  void e(String message);

  /// Log a message with the warning log level.
  void w(String message);

  /// Log a message with the debug log level.
  void d(String message);

  /// Log a message with the info log level.
  void i(String message);

  /// Log a message with the verto log level. Verto logs are logs related to the Verto protocol.
  void v(String message);
}

