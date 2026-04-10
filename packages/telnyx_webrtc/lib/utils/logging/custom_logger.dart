import 'package:telnyx_webrtc/utils/logging/log_level.dart';

/// Custom logger interface to allow the user to provide their own logging implementation.
abstract class CustomLogger {
  /// Set the log level for the SDK.
  void setLogLevel(LogLevel level);

  /// Log a message with the specified log level.
  void log(LogLevel level, String message);
}
