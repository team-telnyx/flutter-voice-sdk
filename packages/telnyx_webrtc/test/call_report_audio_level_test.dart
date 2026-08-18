import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:telnyx_webrtc/utils/stats/call_report_collector.dart';

void main() {
  test('computes audio levels from cumulative energy deltas', () {
    final collector = CallReportCollector();
    final start = DateTime.utc(2026, 8, 18);

    collector.processStatsReportsForTesting([
      StatsReport('inbound', 'inbound-rtp', 0, {
        'kind': 'audio',
        'totalAudioEnergy': 1.0,
        'totalSamplesDuration': 4.0,
      }),
    ], now: start);
    collector.processStatsReportsForTesting([
      StatsReport('inbound', 'inbound-rtp', 1000, {
        'kind': 'audio',
        'totalAudioEnergy': 1.25,
        'totalSamplesDuration': 5.0,
      }),
    ], now: start.add(const Duration(seconds: 1)));

    final inbound = collector
        .createStatsEntryForTesting(
            endTime: start.add(const Duration(seconds: 1)))
        .toJson()['audio']['inbound'];
    expect(inbound['audioLevelAvg'], 0.5);
  });

  test('serializes local media-source data on outbound audio', () {
    final collector = CallReportCollector();
    final now = DateTime.utc(2026, 8, 18);

    collector.processStatsReportsForTesting([
      StatsReport('source-1', 'media-source', 0, {
        'kind': 'audio',
        'trackIdentifier': 'microphone-track',
        'audioLevel': 0.25,
        'totalAudioEnergy': 2.0,
        'totalSamplesDuration': 8.0,
        'echoReturnLoss': 12.0,
      }),
      StatsReport('outbound', 'outbound-rtp', 0, {
        'kind': 'audio',
        'mediaSourceId': 'source-1',
        'packetsSent': 10,
      }),
    ], now: now);

    final outbound = collector
        .createStatsEntryForTesting(
            endTime: now.add(const Duration(seconds: 1)))
        .toJson()['audio']['outbound'];
    expect(outbound['audioLevelAvg'], 0.25);
    expect(outbound['mediaSource'], containsPair('id', 'source-1'));
    expect(
      outbound['mediaSource'],
      containsPair('trackIdentifier', 'microphone-track'),
    );
  });
}
