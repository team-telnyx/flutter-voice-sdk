import 'package:telnyx_webrtc/utils/logging/global_logger.dart';

/// Helper class to track timing benchmarks during call connection.
/// Used to identify performance bottlenecks in the call setup process.
/// All benchmarks are collected and logged together when the call connects.
class CallTimingBenchmark {
  static final Stopwatch _totalTimer = Stopwatch();
  static final Map<String, int> _milestones = {};
  static bool _isFirstCandidate = true;

  /// Starts the benchmark timer. Call this when accept() is invoked.
  static void start() {
    _totalTimer.reset();
    _milestones.clear();
    _isFirstCandidate = true;
    _totalTimer.start();
  }

  /// Records a milestone with the current elapsed time.
  static void mark(String milestone) {
    if (!_totalTimer.isRunning) return;
    _milestones[milestone] = _totalTimer.elapsedMilliseconds;
  }

  /// Records the first ICE candidate (only once per call).
  static void markFirstCandidate() {
    if (!_totalTimer.isRunning) return;
    if (_isFirstCandidate) {
      _isFirstCandidate = false;
      mark('first_ice_candidate');
    }
  }

  /// Ends the benchmark and logs a formatted summary of all milestones.
  static void end() {
    if (!_totalTimer.isRunning) return;
    _totalTimer.stop();

    final total = _totalTimer.elapsedMilliseconds;
    final buffer = StringBuffer()
      ..writeln('')
      ..writeln(
        '╔══════════════════════════════════════════════════════════╗',
      )
      ..writeln(
        '║           CALL CONNECTION BENCHMARK RESULTS              ║',
      )
      ..writeln(
        '╠══════════════════════════════════════════════════════════╣',
      );

    // Sort milestones by time for chronological display
    final sortedEntries = _milestones.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    int? previousTime;
    for (final entry in sortedEntries) {
      final delta =
          previousTime != null ? entry.value - previousTime : entry.value;
      final deltaStr = previousTime != null ? '(+${delta}ms)' : '';
      buffer.writeln(
        '║  ${entry.key.padRight(35)} ${entry.value.toString().padLeft(6)}ms ${deltaStr.padLeft(10)} ║',
      );
      previousTime = entry.value;
    }

    buffer
      ..writeln(
        '╠══════════════════════════════════════════════════════════╣',
      )
      ..writeln(
        '║  TOTAL CONNECTION TIME:              ${total.toString().padLeft(6)}ms            ║',
      )
      ..writeln(
        '╚══════════════════════════════════════════════════════════╝',
      );

    GlobalLogger().i(buffer.toString());
  }
}
