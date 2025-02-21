import 'package:flutter/foundation.dart';
import 'package:telnyx_webrtc/utils/logging/custom_logger.dart';
import 'package:telnyx_webrtc/utils/logging/log_level.dart';

/// Default logger implementation that will be used when no custom logger is provided
/// This logger utilizes simple prints based on the log level set by the user.
class DefaultLogger implements CustomLogger {
  LogLevel _logLevel = LogLevel.info;

  @override
  void d(String message) {
    if (_logLevel.index <= LogLevel.debug.index) {
      if (kDebugMode) {
        print('DEBUG: $message');
      }
    }
  }

  @override
  void e(String message) {
    if (_logLevel.index <= LogLevel.error.index) {
      if (kDebugMode) {
        print('ERROR: $message');
      }
    }
  }

  @override
  void i(String message) {
    if (_logLevel.index <= LogLevel.info.index) {
      if (kDebugMode) {
        print('INFO: $message');
      }
    }
  }

  @override
  void v(String message) {
    if (_logLevel.index <= LogLevel.verto.index) {
      if (kDebugMode) {
        print('VERTO: $message');
      }
    }
  }

  @override
  void w(String message) {
    if (_logLevel.index <= LogLevel.warning.index) {
      if (kDebugMode) {
        print('WARNING: $message');
      }
    }
  }

  @override
  void setLogLevel(LogLevel level) {
    _logLevel = level;
  }
}

