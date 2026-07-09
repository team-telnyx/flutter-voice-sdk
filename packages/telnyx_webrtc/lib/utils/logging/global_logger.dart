import 'package:telnyx_webrtc/utils/logging/custom_logger.dart';
import 'package:telnyx_webrtc/utils/logging/default_logger.dart';
import 'package:telnyx_webrtc/utils/logging/log_collector.dart';
import 'package:telnyx_webrtc/utils/logging/log_level.dart';

/// Global logger class that will be used to log messages throughout the SDK
class GlobalLogger {
  static CustomLogger _logger = DefaultLogger();

  /// Get the current logger instance
  static CustomLogger get logger => _logger;

  /// Log a message with the info log level.
  void i(String message, {Map<String, dynamic>? context}) {
    _logger.log(LogLevel.info, message);
    _forwardToCollector('info', message, context);
  }

  /// Log a message with the debug log level.
  void d(String message, {Map<String, dynamic>? context}) {
    _logger.log(LogLevel.debug, message);
    _forwardToCollector('debug', message, context);
  }

  /// Log a message with the error log level.
  void e(String message, {Map<String, dynamic>? context}) {
    _logger.log(LogLevel.error, message);
    _forwardToCollector('error', message, context);
  }

  /// Log a message with the warning log level.
  void w(String message, {Map<String, dynamic>? context}) {
    _logger.log(LogLevel.warning, message);
    _forwardToCollector('warn', message, context);
  }

  /// Log a message with the verto log level. Verto logs are logs related to the Verto protocol.
  void v(String message, {Map<String, dynamic>? context}) {
    _logger.log(LogLevel.verto, message);
    _forwardToCollector('debug', message, context);
  }

  /// Set the logger instance
  static set logger(CustomLogger logger) {
    _logger = logger;
  }

  /// Forward a log entry to the global [LogCollector] if one is active.
  static void _forwardToCollector(
    String level,
    String message,
    Map<String, dynamic>? context,
  ) {
    final collector = getGlobalLogCollector();
    if (collector != null && collector.isActive) {
      collector.addEntry(level: level, message: message, context: context);
    }
  }
}
