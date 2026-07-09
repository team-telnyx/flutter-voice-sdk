import 'dart:async';
import 'dart:convert';

import 'package:telnyx_webrtc/utils/logging/log_level.dart';

/// Log level for the [LogCollector].
///
/// Lower levels include higher levels (i.e. [CollectorLogLevel.debug] captures
/// everything, [CollectorLogLevel.error] only captures errors).
enum CollectorLogLevel {
  debug,
  info,
  warn,
  error,
}

/// A single captured log entry.
class LogEntry {
  final String timestamp;
  final String level;
  final String message;
  final Map<String, dynamic>? context;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.context,
  });

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
  final bool enabled;
  final CollectorLogLevel level;
  final int maxEntries;

  final List<LogEntry> _buffer = [];
  bool _active = false;

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
      message: message,
      context: context,
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
