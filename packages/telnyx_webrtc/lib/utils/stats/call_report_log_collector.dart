import 'package:telnyx_webrtc/utils/logging/global_logger.dart';

/// Event types for structured call lifecycle logging
enum CallReportEventType {
  callStarted,
  callStateChanged,
  callEnded,
  iceConnectionStateChanged,
  signalingStateChanged,
  iceGatheringStateChanged,
}

/// Log levels for call report log entries
enum CallReportLogLevel {
  debug,
  info,
  warning,
  error,
}

/// A structured log entry for call lifecycle events
class CallReportLogEntry {
  final String timestamp;
  final String level;
  final String message;
  final Map<String, dynamic>? context;

  CallReportLogEntry({
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

/// Collects structured call lifecycle event logs for inclusion in call reports.
///
/// Captures events like call state changes, ICE connection state transitions,
/// signaling state changes, etc. with timestamps and optional context data.
/// Inspired by the iOS SDK's structured logging approach.
class CallReportLogCollector {
  /// Maximum number of log entries to buffer
  final int maxEntries;

  /// Minimum log level to capture
  final String logLevel;

  final List<CallReportLogEntry> _logBuffer = [];

  CallReportLogCollector({
    this.maxEntries = 1000,
    this.logLevel = 'debug',
  });

  /// The priority of each log level (lower = less verbose)
  static const Map<String, int> _logLevelPriority = {
    'debug': 0,
    'info': 1,
    'warning': 2,
    'error': 3,
  };

  /// Whether the given level meets the minimum log level threshold
  bool _shouldLog(String level) {
    final minPriority = _logLevelPriority[logLevel] ?? 0;
    final entryPriority = _logLevelPriority[level] ?? 0;
    return entryPriority >= minPriority;
  }

  /// Add a structured log entry
  void addLog({
    required String level,
    required String message,
    Map<String, dynamic>? context,
  }) {
    if (!_shouldLog(level)) return;

    final entry = CallReportLogEntry(
      timestamp: DateTime.now().toUtc().toIso8601String(),
      level: level,
      message: message,
      context: context,
    );

    _logBuffer.add(entry);

    // Enforce buffer limit
    if (_logBuffer.length > maxEntries) {
      _logBuffer.removeAt(0);
      GlobalLogger().w(
        'CallReportLogCollector: Buffer limit reached ($maxEntries), removed oldest entry',
      );
    }
  }

  /// Log a call lifecycle event
  void logEvent(
    CallReportEventType eventType, {
    String level = 'info',
    String? message,
    Map<String, dynamic>? context,
  }) {
    addLog(
      level: level,
      message: message ?? eventType.name,
      context: {
        'eventType': eventType.name,
        if (context != null) ...context,
      },
    );
  }

  /// Convenience: log call started
  void logCallStarted({
    required String callId,
    required String direction,
    String? destinationNumber,
    String? callerNumber,
  }) {
    logEvent(
      CallReportEventType.callStarted,
      level: 'info',
      message: 'Call started',
      context: {
        'callId': callId,
        'direction': direction,
        if (destinationNumber != null) 'destinationNumber': destinationNumber,
        if (callerNumber != null) 'callerNumber': callerNumber,
      },
    );
  }

  /// Convenience: log call state changed
  void logCallStateChanged({
    required String callId,
    required String fromState,
    required String toState,
  }) {
    logEvent(
      CallReportEventType.callStateChanged,
      level: 'info',
      message: 'Call state changed: $fromState -> $toState',
      context: {
        'callId': callId,
        'fromState': fromState,
        'toState': toState,
      },
    );
  }

  /// Convenience: log call ended
  void logCallEnded({
    required String callId,
    String? reason,
    double? durationSeconds,
  }) {
    logEvent(
      CallReportEventType.callEnded,
      level: 'info',
      message: 'Call ended',
      context: {
        'callId': callId,
        if (reason != null) 'reason': reason,
        if (durationSeconds != null) 'durationSeconds': durationSeconds,
      },
    );
  }

  /// Convenience: log ICE connection state changed
  void logIceConnectionStateChanged({
    required String callId,
    required String state,
  }) {
    logEvent(
      CallReportEventType.iceConnectionStateChanged,
      level: 'debug',
      message: 'ICE connection state: $state',
      context: {
        'callId': callId,
        'iceConnectionState': state,
      },
    );
  }

  /// Convenience: log signaling state changed
  void logSignalingStateChanged({
    required String callId,
    required String state,
  }) {
    logEvent(
      CallReportEventType.signalingStateChanged,
      level: 'debug',
      message: 'Signaling state: $state',
      context: {
        'callId': callId,
        'signalingState': state,
      },
    );
  }

  /// Convenience: log ICE gathering state changed
  void logIceGatheringStateChanged({
    required String callId,
    required String state,
  }) {
    logEvent(
      CallReportEventType.iceGatheringStateChanged,
      level: 'debug',
      message: 'ICE gathering state: $state',
      context: {
        'callId': callId,
        'iceGatheringState': state,
      },
    );
  }

  /// Get all collected log entries as JSON-serializable list
  List<Map<String, dynamic>> getLogsJson() {
    return _logBuffer.map((e) => e.toJson()).toList();
  }

  /// Get the current log buffer (for debugging)
  List<CallReportLogEntry> getLogBuffer() => List.unmodifiable(_logBuffer);

  /// Get the number of log entries
  int get length => _logBuffer.length;

  /// Clear all log entries
  void clear() {
    _logBuffer.clear();
  }

  /// Clear and return all log entries (for intermediate segment flushing)
  List<Map<String, dynamic>> flushLogs() {
    final logs = getLogsJson();
    _logBuffer.clear();
    return logs;
  }
}
