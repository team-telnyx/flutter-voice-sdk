/// Log level for the [LogCollector].
///
/// Lower levels include higher levels (i.e. [CollectorLogLevel.debug] captures
/// everything, [CollectorLogLevel.error] only captures errors).
enum CollectorLogLevel {
  /// Captures all entries, including verbose debug logs.
  debug,

  /// Captures informational entries and above.
  info,

  /// Captures warnings and errors only.
  warn,

  /// Captures errors only.
  error,
}

/// A single captured log entry.
class LogEntry {
  /// ISO-8601 UTC timestamp of when the entry was captured.
  final String timestamp;

  /// The log level of the entry (for example 'info' or 'error').
  final String level;

  /// The (redacted) log message text.
  final String message;

  /// Optional structured context attached to the entry.
  final Map<String, dynamic>? context;

  /// Creates a captured log entry.
  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.context,
  });

  /// Serializes this entry to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'timestamp': timestamp,
        'level': level,
        'message': message,
        if (context != null) 'context': context,
      };
}

/// Priority mapping for [CollectorLogLevel] (lower = more verbose).
const Map<CollectorLogLevel, int> _collectorLevelPriority = {
  CollectorLogLevel.debug: 0,
  CollectorLogLevel.info: 1,
  CollectorLogLevel.warn: 2,
  CollectorLogLevel.error: 3,
};

/// A ring-buffer log collector that captures SDK log entries between
/// [start] and [stop] calls.
///
/// Entries are filtered by [level] and capped at [maxEntries] (FIFO eviction).
class LogCollector {
  /// Whether this collector captures entries at all.
  final bool enabled;

  /// Minimum level an entry must meet to be captured.
  final CollectorLogLevel level;

  /// Maximum number of entries retained before FIFO eviction.
  final int maxEntries;

  final List<LogEntry> _buffer = [];
  bool _active = false;

  /// Creates a log collector with the given capture [level] and [maxEntries].
  LogCollector({
    this.enabled = true,
    this.level = CollectorLogLevel.debug,
    this.maxEntries = 1000,
  });

  /// Whether the collector is currently capturing entries.
  bool get isActive => _active;

  /// Number of entries currently in the buffer.
  int get logCount => _buffer.length;

  /// Start capturing log entries.
  void start() {
    _active = true;
  }

  /// Stop capturing log entries.
  void stop() {
    _active = false;
  }

  /// Add an entry to the buffer if the collector is active and the level
  /// meets the minimum threshold.
  void addEntry({
    required String level,
    required String message,
    Map<String, dynamic>? context,
  }) {
    if (!enabled || !_active) return;

    // Level filtering
    final entryLevel = _parseLevel(level);
    if (entryLevel == null) return;
    if (_collectorLevelPriority[entryLevel]! <
        _collectorLevelPriority[this.level]!) {
      return;
    }

    final entry = LogEntry(
      timestamp: DateTime.now().toUtc().toIso8601String(),
      level: level,
      // Redact credentials/secrets before buffering so they are never retained
      // in memory or uploaded in call reports — even when a verbose log level
      // captures raw signaling payloads (login messages, tokens, etc.).
      message: _redactSecrets(message),
      context: _redactContext(context),
    );

    _buffer.add(entry);

    // FIFO eviction
    if (_buffer.length > maxEntries) {
      _buffer.removeAt(0);
    }
  }

  /// Get a copy of all log entries.
  List<LogEntry> getLogs() => List.unmodifiable(_buffer);

  /// Clear all entries from the buffer.
  void clear() {
    _buffer.clear();
  }

  /// Drain all entries as JSON-serializable maps and clear the buffer.
  List<Map<String, dynamic>> drain() {
    final result = _buffer.map((e) => e.toJson()).toList();
    _buffer.clear();
    return result;
  }

  /// Matches JSON `"key":"value"` pairs whose key names a credential/secret.
  static final RegExp _secretKeyValue = RegExp(
    r'("(?:login_token|loginToken|passwd|password|sipPassword|sip_password|token|secret)"\s*:\s*")[^"]*(")',
    caseSensitive: false,
  );

  /// Redacts values of known sensitive JSON keys from a log [message] so that
  /// credentials/tokens are never captured verbatim.
  static String _redactSecrets(String message) {
    return message.replaceAllMapped(
      _secretKeyValue,
      (match) => '${match[1]}***REDACTED***${match[2]}',
    );
  }

  static bool _isSensitiveKey(String key) {
    final lower = key.toLowerCase();
    return lower.contains('password') ||
        lower.contains('passwd') ||
        lower.contains('token') ||
        lower.contains('secret');
  }

  /// Redacts sensitive values from a structured log [context] map.
  static Map<String, dynamic>? _redactContext(Map<String, dynamic>? context) {
    if (context == null || context.isEmpty) return context;
    final result = <String, dynamic>{};
    context.forEach((key, value) {
      if (_isSensitiveKey(key)) {
        result[key] = '***REDACTED***';
      } else if (value is String) {
        result[key] = _redactSecrets(value);
      } else {
        result[key] = value;
      }
    });
    return result;
  }

  /// Parse a string level into a [CollectorLogLevel].
  static CollectorLogLevel? _parseLevel(String level) {
    switch (level.toLowerCase()) {
      case 'debug':
        return CollectorLogLevel.debug;
      case 'info':
        return CollectorLogLevel.info;
      case 'warn':
      case 'warning':
        return CollectorLogLevel.warn;
      case 'error':
        return CollectorLogLevel.error;
      default:
        return null;
    }
  }
}

// ---------------------------------------------------------------------------
// Global singleton
// ---------------------------------------------------------------------------

/// The global [LogCollector] singleton, or `null` if none is set.
LogCollector? _globalLogCollector;

/// Set the global [LogCollector] singleton.  Pass `null` to clear.
void setGlobalLogCollector(LogCollector? collector) {
  _globalLogCollector = collector;
}

/// Get the global [LogCollector] singleton, or `null` if none is set.
LogCollector? getGlobalLogCollector() => _globalLogCollector;
