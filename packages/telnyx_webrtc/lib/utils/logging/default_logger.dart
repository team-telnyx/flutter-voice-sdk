import 'package:flutter/foundation.dart';
import 'package:telnyx_webrtc/utils/logging/custom_logger.dart';
import 'package:telnyx_webrtc/utils/logging/log_level.dart';

/// Default logger implementation that will be used when no custom logger is provided
/// This logger utilizes simple prints based on the log level set by the user.
class DefaultLogger implements CustomLogger {
  LogLevel _logLevel = LogLevel.info;

  @override
  void setLogLevel(LogLevel level) {
    _logLevel = level;
  }

  @override
  void log(LogLevel level, String message) {
    if (_shouldLog(level)) {
      if (kDebugMode) {
        print('${level.name.toUpperCase()}: $message');
      }
    }
  }

  /// Determines if a log message should be printed based on the current log level
  bool _shouldLog(LogLevel level) {
    // If log level is set to none, don't log anything
    if (_logLevel == LogLevel.none) {
      return false;
    }

    // If log level is set to all, log everything
    if (_logLevel == LogLevel.all) {
      return true;
    }

    // For other levels, compare priorities
    // Log if the message level priority is greater than or equal to the set log level priority
    // Higher priority numbers mean more restrictive (less verbose)
    if (level.priority != null && _logLevel.priority != null) {
      return level.priority! >= _logLevel.priority!;
    }

    // Handle edge cases where priority might be null
    return false;
  }
}
