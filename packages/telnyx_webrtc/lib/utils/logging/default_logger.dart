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
    if (_logLevel.index <= level.index) {
      if (kDebugMode) {
        print('${level.name.toUpperCase()}: $message');
      }
    }
  }
}

