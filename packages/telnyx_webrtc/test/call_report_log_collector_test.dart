import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/utils/stats/call_report_log_collector.dart';

void main() {
  test('New Call log exposes dashboard media labels without constraints', () {
    final collector = CallReportLogCollector()
      ..logNewCall(
        callId: 'call-id',
        direction: 'outbound',
        audio: true,
        video: false,
        debug: false,
        forceRelayCandidate: false,
        mutedMicOnStart: false,
        trickleIce: false,
        telnyxSessionId: 'session-id',
        telnyxLegId: 'leg-id',
      );

    final log = collector.getLogsJson().single;
    expect(log['message'], 'New Call');
    expect(log['context']['audio'], isTrue);
    expect(log['context']['video'], isFalse);
    expect(log['context']['telnyxSessionId'], 'session-id');
    expect(log['context'].containsKey('audioConstraints'), isFalse);
  });

  test('uploaded snapshot removal preserves logs added after cap eviction', () {
    final collector = CallReportLogCollector(maxEntries: 3)
      ..addLog(level: 'debug', message: 'uploaded-1')
      ..addLog(level: 'debug', message: 'uploaded-2');
    final snapshot = collector.getLogBuffer();

    collector
      ..addLog(level: 'debug', message: 'new-1')
      ..addLog(level: 'debug', message: 'new-2')
      ..addLog(level: 'debug', message: 'new-3')
      ..removeThrough(snapshot.last);

    expect(
      collector.getLogsJson().map((entry) => entry['message']),
      ['new-1', 'new-2', 'new-3'],
    );
  });

  test('uploaded snapshot removal removes only its retained prefix', () {
    final collector = CallReportLogCollector(maxEntries: 4)
      ..addLog(level: 'debug', message: 'uploaded-1')
      ..addLog(level: 'debug', message: 'uploaded-2');
    final snapshot = collector.getLogBuffer();

    collector
      ..addLog(level: 'debug', message: 'new-1')
      ..removeThrough(snapshot.last);

    expect(
      collector.getLogsJson().map((entry) => entry['message']),
      ['new-1'],
    );
  });
}
