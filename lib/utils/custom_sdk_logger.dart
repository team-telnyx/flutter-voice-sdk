import 'package:logger/logger.dart';
import 'package:telnyx_webrtc/utils/logging/custom_logger.dart';
import 'package:telnyx_webrtc/utils/logging/log_level.dart';

/// Custom logger implementation that uses the Logger package to log messages based on the log level set by the user.
class CustomSDKLogger implements CustomLogger {
  /// Logger instance used to log messages
  late Logger logger;

  LogLevel _logLevel = LogLevel.info;

  /// Default constructor that initializes the logger with the default log level
  CustomSDKLogger() {
    logger = Logger(
      filter: CustomLogFilter(_logLevel),
    );
  }

  @override
  void setLogLevel(LogLevel level) {
    _logLevel = level;
    logger = Logger(
      filter: CustomLogFilter(_logLevel),
    );
  }

  @override
  void d(String message) {
    logger.d(message);
  }

  @override
  void e(String message) {
    logger.e(message);
  }

  @override
  void i(String message) {
    logger.i(message);
  }

  @override
  void v(String message) {
    logger.t(message);
  }

  @override
  void w(String message) {
    logger.w(message);
  }
}

/// Custom log filter that will filter logs based on the log level set by the user
class CustomLogFilter extends LogFilter {
  /// Log level set by the user
  final LogLevel logLevel;

  /// Constructor that initializes the log level
  CustomLogFilter(this.logLevel);

  @override
  bool shouldLog(LogEvent event) {
    switch (logLevel) {
      case LogLevel.none:
        return false;
      case LogLevel.error:
        return event.level == Level.error;
      case LogLevel.warning:
        return event.level == Level.warning || event.level == Level.error;
      case LogLevel.debug:
        return event.level == Level.debug || event.level == Level.warning || event.level == Level.error;
      case LogLevel.info:
        return event.level == Level.info || event.level == Level.debug || event.level == Level.warning || event.level == Level.error;
      case LogLevel.verto:
        return event.level == Level.trace || event.level == Level.info || event.level == Level.debug || event.level == Level.warning || event.level == Level.error;
      case LogLevel.all:
        return true;
      default:
        return false;
    }
  }
}