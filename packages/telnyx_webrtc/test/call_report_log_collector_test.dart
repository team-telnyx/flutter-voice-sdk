import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/utils/stats/call_report_log_collector.dart';

void main() {
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
