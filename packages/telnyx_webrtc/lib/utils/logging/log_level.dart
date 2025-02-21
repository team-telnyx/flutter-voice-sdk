/// Enum to describe the log level that the SDK should use.
///
/// The log level itself is implemented as an integer.
/// Each level has a provided [priority].
///
/// - [LogLevel.none]: Disable logs. SDK logs will not be printed. (default)
/// - [LogLevel.error]: Print error logs only.
/// - [LogLevel.warning]: Print warning logs only.
/// - [LogLevel.debug]: Print debug logs only.
/// - [LogLevel.info]: Print info logs only.
/// - [LogLevel.verto]: Print verto messages. Incoming and outgoing verto messages are printed.
/// - [LogLevel.all]: All the SDK logs are printed.
enum LogLevel {
  /// Disable logs. SDK logs will not be printed.
  none(8),
  /// Print error logs only.
  error(6),

  /// Print warning logs only.
  warning(5),

  /// Print debug logs only.
  debug(3),

  /// Print info logs only.
  info(4),

  /// Print verto messages. Incoming and outgoing verto messages are printed.
  verto(9),

  /// All the SDK logs are printed.
  all(null);

  /// The priority of the log level.
  final int? priority;

  const LogLevel(this.priority);
}