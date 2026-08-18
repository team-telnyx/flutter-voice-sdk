import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/utils/stats/call_report_collector.dart';
import 'package:telnyx_webrtc/utils/stats/call_report_log_collector.dart';

void main() {
  group('Call report intermediate flushing', () {
    test('serializes a structured flush reason', () {
      final payload = CallReportPayload(
        summary: CallSummary(
          callId: 'call-1',
          direction: 'outbound',
          sdkVersion: 'test',
        ),
        stats: const [],
        segment: 0,
        flushReason: const CallReportFlushReason(
          type: CallReportFlushReasonType.socketClose,
          socketClose: CallReportSocketCloseDetails(
            code: 1006,
            codeName: 'abnormal-closure',
            reason: 'network lost',
            wasClean: false,
            error: 'socket closed',
          ),
        ),
      );

      expect(payload.toJson()['flushReason'], {
        'type': 'socket-close',
        'socketClose': {
          'code': 1006,
          'codeName': 'abnormal-closure',
          'reason': 'network lost',
          'wasClean': false,
          'error': 'socket closed',
        },
      });
    });

    test('requests a buffer-limit flush at the stats threshold', () async {
      final collector = CallReportCollector();
      CallReportFlushReason? requestedReason;
      collector.onFlushNeeded = (reason) => requestedReason = reason;

      for (var index = 0; index < 300; index++) {
        collector.createStatsEntryForTesting(
          endTime: DateTime.utc(2026, 8, 17).add(Duration(seconds: index)),
        );
      }
      await collector.requestIntermediateFlushForTesting(
        DateTime.utc(2026, 8, 17, 0, 10),
      );

      expect(requestedReason?.type, CallReportFlushReasonType.bufferLimit);
    });

    test('requests a buffer-limit flush at the logs threshold', () async {
      final logs = CallReportLogCollector(maxEntries: 1000);
      final collector = CallReportCollector(logCollector: logs);
      CallReportFlushReason? requestedReason;
      collector.onFlushNeeded = (reason) => requestedReason = reason;

      for (var index = 0; index < 800; index++) {
        logs.addLog(level: 'debug', message: 'log-$index');
      }
      await collector.requestIntermediateFlushForTesting(
        DateTime.utc(2026, 8, 17),
      );

      expect(requestedReason?.type, CallReportFlushReasonType.bufferLimit);
    });

    test('uses the configured safety interval', () async {
      final collector = CallReportCollector(
        options: const CallReportOptions(flushIntervalMs: 25),
      );
      CallReportFlushReason? requestedReason;
      collector.onFlushNeeded = (reason) => requestedReason = reason;
      collector.createStatsEntryForTesting();

      await collector.requestIntermediateFlushForTesting(
        DateTime.now().add(const Duration(seconds: 1)),
      );

      expect(requestedReason?.type, CallReportFlushReasonType.safetyInterval);
    });

    test('does not request a flush when both buffers are empty', () async {
      final collector = CallReportCollector(
        options: const CallReportOptions(flushIntervalMs: 1),
      );
      var requests = 0;
      collector.onFlushNeeded = (_) => requests++;

      await collector.requestIntermediateFlushForTesting(
        DateTime.now().add(const Duration(seconds: 1)),
      );

      expect(requests, 0);
    });
  });
}
