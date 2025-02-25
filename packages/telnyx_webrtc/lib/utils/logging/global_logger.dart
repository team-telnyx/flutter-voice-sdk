import 'package:telnyx_webrtc/utils/logging/custom_logger.dart';
import 'package:telnyx_webrtc/utils/logging/default_logger.dart';
import 'package:telnyx_webrtc/utils/logging/log_level.dart';

/// Global logger class that will be used to log messages throughout the SDK
class GlobalLogger {
  static CustomLogger _logger = DefaultLogger();

  /// Get the current logger instance
  static CustomLogger get logger => _logger;

  /// Log a message with the info log level.
  void i(String message) {
    _logger.log(LogLevel.info, message);
  }

  /// Log a message with the debug log level.
  void d(String message) {
    _logger.log(LogLevel.debug, message);
  }

  /// Log a message with the error log level.
  void e(String message) {
    _logger.log(LogLevel.error, message);
  }

  /// Log a message with the warning log level.
  void w(String message) {
    _logger.log(LogLevel.warning, message);
  }

  /// Log a message with the verto log level. Verto logs are logs related to the Verto protocol.
  void v(String message) {
    _logger.log(LogLevel.verto, message);
  }

  /// Set the logger instance
  static set logger(CustomLogger logger) {
    _logger = logger;
  }
}