/// Log level filter for debug/diagnostics output.
///
/// Used by [Config.debugLogLevel] to control which messages reach the
/// [GlobalLogger]. Messages below the configured level are suppressed.
///
/// - [DebugLogLevel.debug] — all messages (debug, info, warning, error).
/// - [DebugLogLevel.info] — info, warning, and error messages (default).
/// - [DebugLogLevel.warning] — warning and error messages only.
/// - [DebugLogLevel.error] — error messages only.
enum DebugLogLevel {
  /// All messages (debug, info, warning, error).
  debug,

  /// Info, warning, and error messages.
  info,

  /// Warning and error messages only.
  warning,

  /// Error messages only.
  error,
}
