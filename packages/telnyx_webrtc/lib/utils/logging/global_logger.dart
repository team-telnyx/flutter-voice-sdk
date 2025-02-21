import 'package:telnyx_webrtc/utils/logging/custom_logger.dart';
import 'package:telnyx_webrtc/utils/logging/default_logger.dart';

/// Global logger class that will be used to log messages throughout the SDK
class GlobalLogger {
  static CustomLogger _logger = DefaultLogger();

  /// Get the current logger instance
  static CustomLogger get logger => _logger;

  /// Set the logger instance
  static set logger(CustomLogger logger) {
    _logger = logger;
  }
}