/// TDD failing tests for VSD-420: LogCollector for Flutter SDK.
///
/// These tests reference a new `LogCollector` class and `LogEntry` model that
/// do NOT yet exist in `lib/utils/logging/log_collector.dart`.  They also
/// reference new methods on `GlobalLogger` (context parameter) and a global
/// singleton accessor.  All will fail at compile time until implementation.
///
/// Test plan (10 tests):
/// 1. LogCollector start/stop — entries only captured between start() and stop().
/// 2. Level filtering — when level is warn, debug/info entries not captured.
/// 3. Max entries eviction — fill beyond maxEntries, oldest evicted (FIFO).
/// 4. Drain — returns all entries and clears buffer.
/// 5. GlobalLogger integration — GlobalLogger().d(...) forwarded to LogCollector.
/// 6. GlobalLogger inactive — no entries captured when not started.
/// 7. CallReport integration — LogCollector entries in CallReportPayload.logs.
/// 8. Context serialization — nested objects serialize correctly.
/// 9. Intermediate flush — after drain(), new entries captured for next segment.
/// 10. Concurrent calls — LogCollector doesn't leak between calls.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/utils/logging/global_logger.dart';
import 'package:telnyx_webrtc/utils/logging/log_collector.dart';
import 'package:telnyx_webrtc/utils/logging/log_level.dart';
import 'package:telnyx_webrtc/utils/logging/custom_logger.dart';
import 'package:telnyx_webrtc/utils/stats/call_report_collector.dart';

/// Mock custom logger that records all log calls.
class _RecordingLogger implements CustomLogger {
  final List<({LogLevel level, String message})> calls = [];

  @override
  void log(LogLevel level, String message) {
    calls.add((level: level, message: message));
  }

  @override
  void setLogLevel(LogLevel level) {
    // no-op
  }

  void reset() => calls.clear();
}

void main() {
  group('VSD-420: LogCollector start/stop', () {
    test(
      'entries are only captured between start() and stop()',
      () {
        // Before start — no capture.
        final collector = LogCollector(
          enabled: true,
          level: CollectorLogLevel.debug,
          maxEntries: 100,
        )..addEntry(level: 'debug', message: 'before start');
        expect(collector.logCount, equals(0));

        // Start capturing.
        collector.start();
        expect(collector.isActive, isTrue);

        collector.addEntry(level: 'debug', message: 'during capture');
        expect(collector.logCount, equals(1));

        // Stop capturing.
        collector.stop();
        expect(collector.isActive, isFalse);

        collector.addEntry(level: 'debug', message: 'after stop');
        expect(
          collector.logCount,
          equals(1),
          reason: 'No new entries after stop()',
        );
      },
    );
  });

  group('VSD-420: LogCollector level filtering', () {
    test(
      'when level is warn, debug and info entries are not captured',
      () {
        final collector = LogCollector(
          enabled: true,
          level: CollectorLogLevel.warn,
          maxEntries: 100,
        )
          ..start()
          ..addEntry(level: 'debug', message: 'debug msg')
          ..addEntry(level: 'info', message: 'info msg')
          ..addEntry(level: 'warn', message: 'warn msg')
          ..addEntry(level: 'error', message: 'error msg');

        expect(
          collector.logCount,
          equals(2),
          reason: 'Only warn and error entries should be captured',
        );

        final logs = collector.getLogs();
        expect(logs[0].level, equals('warn'));
        expect(logs[0].message, equals('warn msg'));
        expect(logs[1].level, equals('error'));
        expect(logs[1].message, equals('error msg'));
      },
    );
  });

  group('VSD-420: LogCollector max entries eviction (FIFO)', () {
    test(
      'fill beyond maxEntries evicts oldest entries (FIFO)',
      () {
        final collector = LogCollector(
          enabled: true,
          level: CollectorLogLevel.debug,
          maxEntries: 3,
        )
          ..start()
          ..addEntry(level: 'debug', message: 'entry 1')
          ..addEntry(level: 'debug', message: 'entry 2')
          ..addEntry(level: 'debug', message: 'entry 3');
        expect(collector.logCount, equals(3));

        // Adding a 4th should evict the oldest (entry 1).
        collector.addEntry(level: 'debug', message: 'entry 4');
        expect(
          collector.logCount,
          equals(3),
          reason: 'Buffer should not exceed maxEntries',
        );

        final logs = collector.getLogs();
        expect(
          logs[0].message,
          equals('entry 2'),
          reason: 'Oldest entry (entry 1) should have been evicted',
        );
        expect(logs[1].message, equals('entry 3'));
        expect(logs[2].message, equals('entry 4'));
      },
    );
  });

  group('VSD-420: LogCollector drain', () {
    test(
      'drain returns all entries as JSON and clears the buffer',
      () {
        final collector = LogCollector(
          enabled: true,
          level: CollectorLogLevel.debug,
          maxEntries: 100,
        )
          ..start()
          ..addEntry(
            level: 'info',
            message: 'test message',
            context: {'key': 'value'},
          )
          ..addEntry(level: 'error', message: 'another error');

        expect(collector.logCount, equals(2));

        final drained = collector.drain();
        expect(drained.length, equals(2));
        expect(drained[0]['level'], equals('info'));
        expect(drained[0]['message'], equals('test message'));
        expect(drained[0]['context'], equals({'key': 'value'}));
        expect(drained[1]['level'], equals('error'));
        expect(drained[1]['message'], equals('another error'));

        // Buffer should be empty after drain.
        expect(collector.logCount, equals(0));

        // New entries can still be captured after drain.
        collector.addEntry(level: 'warn', message: 'post-drain warning');
        expect(collector.logCount, equals(1));
      },
    );
  });

  group('VSD-420: GlobalLogger integration', () {
    test(
      'GlobalLogger().d(...) is forwarded to the global LogCollector when active',
      () {
        final recordingLogger = _RecordingLogger();
        GlobalLogger.logger = recordingLogger;

        final collector = LogCollector(
          enabled: true,
          level: CollectorLogLevel.debug,
          maxEntries: 100,
        );
        setGlobalLogCollector(collector);
        collector.start();

        // The new GlobalLogger.d() should accept an optional context param.
        // This method signature does not exist yet — will fail at compile.
        GlobalLogger().d('debug from logger', context: {'module': 'test'});
        GlobalLogger().w('warn from logger');
        GlobalLogger().e('error from logger');

        expect(
          collector.logCount,
          equals(3),
          reason: 'All log levels should be forwarded when collector is active',
        );

        final logs = collector.getLogs();
        expect(logs[0].level, equals('debug'));
        expect(logs[0].message, equals('debug from logger'));
        expect(logs[0].context, equals({'module': 'test'}));
        expect(logs[1].level, equals('warn'));
        expect(logs[2].level, equals('error'));

        // The underlying logger should also have received the messages.
        expect(recordingLogger.calls.length, equals(3));

        // Cleanup.
        collector.stop();
        setGlobalLogCollector(null);
      },
    );
  });

  group('VSD-420: GlobalLogger inactive — no capture', () {
    test(
      'no entries captured when LogCollector is not started',
      () {
        final recordingLogger = _RecordingLogger();
        GlobalLogger.logger = recordingLogger;

        final collector = LogCollector(
          enabled: true,
          level: CollectorLogLevel.debug,
          maxEntries: 100,
        );
        setGlobalLogCollector(collector);

        // Do NOT call start().
        expect(collector.isActive, isFalse);

        GlobalLogger().d('should not be captured');
        GlobalLogger().e('should not be captured either');

        expect(
          collector.logCount,
          equals(0),
          reason: 'No entries should be captured when not started',
        );

        // Cleanup.
        setGlobalLogCollector(null);
      },
    );

    test(
      'no entries captured when no global LogCollector is set',
      () {
        final recordingLogger = _RecordingLogger();
        GlobalLogger.logger = recordingLogger;

        // Ensure no global collector is set.
        setGlobalLogCollector(null);
        expect(getGlobalLogCollector(), isNull);

        GlobalLogger().d('no collector registered');
        GlobalLogger().e('still no collector');

        // Underlying logger should still work.
        expect(recordingLogger.calls.length, equals(2));
      },
    );
  });

  group('VSD-420: CallReport integration', () {
    test(
      'LogCollector entries are included in CallReportPayload.logs',
      () {
        final collector = LogCollector(
          enabled: true,
          level: CollectorLogLevel.debug,
          maxEntries: 100,
        );
        setGlobalLogCollector(collector);
        collector
          ..start()
          ..addEntry(level: 'info', message: 'call started')
          ..addEntry(level: 'warn', message: 'high jitter detected')
          ..addEntry(level: 'error', message: 'ICE restart failed');

        // CallReportCollector should include LogCollector entries in its
        // payload's `logs` field.  This integration does not exist yet.
        final reportCollector = CallReportCollector()
          ..configureLogCollector(
            enabled: true,
            level: CollectorLogLevel.debug,
            maxEntries: 100,
          );

        // The payload should include the LogCollector entries.
        // This method or integration does not exist yet.
        final logsJson = reportCollector.getLogCollectorEntries();
        expect(logsJson, isNotNull);
        expect(logsJson!.length, equals(3));
        expect(logsJson[0]['level'], equals('info'));
        expect(logsJson[1]['level'], equals('warn'));
        expect(logsJson[2]['level'], equals('error'));

        // Cleanup.
        collector.stop();
        setGlobalLogCollector(null);
      },
    );
  });

  group('VSD-420: Context serialization', () {
    test(
      'nested objects in context serialize correctly to JSON',
      () {
        final collector = LogCollector(
          enabled: true,
          level: CollectorLogLevel.debug,
          maxEntries: 100,
        )
          ..start()
          ..addEntry(
            level: 'debug',
            message: 'complex context',
            context: {
              'callId': 'abc-123',
              'stats': {
                'jitter': 5.2,
                'rtt': 0.15,
                'mos': 4.1,
              },
              'iceCandidates': [
                {'type': 'host', 'address': '192.168.1.1'},
                {'type': 'srflx', 'address': '203.0.113.1'},
              ],
              'nested': {
                'level1': {
                  'level2': {
                    'level3': 'deep value',
                  },
                },
              },
            },
          );

        final logs = collector.getLogs();
        expect(logs.length, equals(1));

        final json = logs[0].toJson();
        expect(json['context'], isNotNull);

        final context = json['context'] as Map<String, dynamic>;
        expect(context['callId'], equals('abc-123'));
        expect(
          (context['stats'] as Map<String, dynamic>)['jitter'],
          equals(5.2),
        );
        expect((context['stats'] as Map<String, dynamic>)['mos'], equals(4.1));

        final candidates = context['iceCandidates'] as List<dynamic>;
        expect(candidates.length, equals(2));
        expect((candidates[0] as Map<String, dynamic>)['type'], equals('host'));

        final nested = context['nested'] as Map<String, dynamic>;
        final level1 = nested['level1'] as Map<String, dynamic>;
        final level2 = level1['level2'] as Map<String, dynamic>;
        expect(level2['level3'], equals('deep value'));
      },
    );
  });

  group('VSD-420: Intermediate flush', () {
    test(
      'after drain(), new entries are captured for the next segment',
      () {
        // First segment.
        final collector = LogCollector(
          enabled: true,
          level: CollectorLogLevel.debug,
          maxEntries: 100,
        )
          ..start()
          ..addEntry(level: 'info', message: 'segment 1 - entry 1')
          ..addEntry(level: 'info', message: 'segment 1 - entry 2');
        expect(collector.logCount, equals(2));

        final firstDrain = collector.drain();
        expect(firstDrain.length, equals(2));
        expect(collector.logCount, equals(0));

        // Second segment — collector should still be active and capturing.
        expect(collector.isActive, isTrue);

        collector
          ..addEntry(level: 'warn', message: 'segment 2 - entry 1')
          ..addEntry(level: 'error', message: 'segment 2 - entry 2')
          ..addEntry(level: 'debug', message: 'segment 2 - entry 3');
        expect(collector.logCount, equals(3));

        final secondDrain = collector.drain();
        expect(secondDrain.length, equals(3));
        expect(secondDrain[0]['message'], equals('segment 2 - entry 1'));
        expect(secondDrain[2]['message'], equals('segment 2 - entry 3'));

        // Collector is still active and can continue capturing.
        collector.addEntry(level: 'info', message: 'segment 3 - entry 1');
        expect(collector.logCount, equals(1));
      },
    );
  });

  group('VSD-420: Concurrent calls lifecycle', () {
    test(
      'LogCollector does not leak between calls (start/stop lifecycle)',
      () {
        // Simulate two sequential calls.  Each call starts a fresh LogCollector.
        // The global singleton is set per-call and cleared after.

        // Call 1.
        final collector1 = LogCollector(
          enabled: true,
          level: CollectorLogLevel.debug,
          maxEntries: 100,
        );
        setGlobalLogCollector(collector1);
        collector1
          ..start()
          ..addEntry(level: 'info', message: 'call 1 log');
        expect(collector1.logCount, equals(1));

        collector1.stop();
        final call1Logs = collector1.drain();
        expect(call1Logs.length, equals(1));
        expect(call1Logs[0]['message'], equals('call 1 log'));

        // Clear the global singleton between calls.
        setGlobalLogCollector(null);

        // Call 2 — new collector, should not see call 1's entries.
        final collector2 = LogCollector(
          enabled: true,
          level: CollectorLogLevel.debug,
          maxEntries: 100,
        );
        setGlobalLogCollector(collector2);
        collector2
          ..start()
          ..addEntry(level: 'info', message: 'call 2 log');
        expect(
          collector2.logCount,
          equals(1),
          reason: 'Call 2 collector should only have its own entries',
        );

        final call2Logs = collector2.getLogs();
        expect(call2Logs[0].message, equals('call 2 log'));
        expect(call2Logs[0].level, equals('info'));

        // Cleanup.
        collector2.stop();
        setGlobalLogCollector(null);
      },
    );
  });
}
