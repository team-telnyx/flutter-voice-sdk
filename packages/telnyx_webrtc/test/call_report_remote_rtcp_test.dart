import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:telnyx_webrtc/utils/stats/call_report_collector.dart';

void main() {
  test('serializes audio remote RTCP reports and computes average RTT', () {
    final collector = CallReportCollector();
    final now = DateTime.utc(2026, 8, 17);

    collector.processStatsReportsForTesting(
      [
        StatsReport('remote-in', 'remote-inbound-rtp', 0, {
          'kind': 'audio',
          'packetsReceived': 95,
          'packetsLost': 5,
          'fractionLost': 0.05,
          'jitter': 0.02,
          'roundTripTime': 0.15,
          'totalRoundTripTime': 1.2,
          'roundTripTimeMeasurements': 4,
          'nackCount': 2,
          'reportsReceived': 6,
          'packetsDiscarded': 1,
        }),
        StatsReport('remote-out', 'remote-outbound-rtp', 0, {
          'kind': 'audio',
          'packetsSent': 110,
          'bytesSent': 2200,
          'reportsCount': 7,
          'roundTripTime': 0.16,
          'totalPacketSendDelay': 0.3,
        }),
        StatsReport('video-ignored', 'remote-inbound-rtp', 0, {
          'kind': 'video',
          'packetsReceived': 999,
        }),
      ],
      now: now,
    );

    final json = collector
        .createStatsEntryForTesting(
          endTime: now.add(const Duration(seconds: 1)),
        )
        .toJson();

    expect(json['remoteRtcp']['inbound'], {
      'packetsReceived': 95,
      'packetsLost': 5,
      'fractionLost': 0.05,
      'jitter': 0.02,
      'roundTripTime': 0.15,
      'totalRoundTripTime': 1.2,
      'roundTripTimeMeasurements': 4,
      'roundTripTimeAvg': 0.3,
      'nackCount': 2,
      'reportsReceived': 6,
      'packetsDiscarded': 1,
    });
    expect(json['remoteRtcp']['outbound'], {
      'packetsSent': 110,
      'bytesSent': 2200,
      'reportsCount': 7,
      'roundTripTime': 0.16,
      'totalPacketSendDelay': 0.3,
    });
  });
}
