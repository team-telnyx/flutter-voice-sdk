import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:telnyx_webrtc/utils/stats/call_report_collector.dart';

void main() {
  test('serializes extended RTP audio and media playout stats', () {
    final collector = CallReportCollector();
    final now = DateTime.utc(2026, 8, 17);

    collector.processStatsReportsForTesting(
      [
        StatsReport('outbound-audio', 'outbound-rtp', 0, {
          'kind': 'audio',
          'packetsSent': 100,
          'bytesSent': 2000,
          'retransmittedPacketsSent': 3,
          'retransmittedBytesSent': 60,
          'headerBytesSent': 400,
          'nackCount': 2,
          'targetBitrate': 32000,
          'totalPacketSendDelay': 0.25,
          'active': true,
        }),
        StatsReport('inbound-audio', 'inbound-rtp', 0, {
          'kind': 'audio',
          'packetsReceived': 90,
          'bytesReceived': 1800,
          'nackCount': 4,
          'headerBytesReceived': 360,
          'fecPacketsReceived': 5,
          'fecPacketsDiscarded': 1,
          'jitterBufferTargetDelay': 0.12,
          'jitterBufferMinimumDelay': 0.08,
          'totalSamplesDecoded': 48000,
          'samplesDecodedWithSilence': 120,
          'samplesDecodedWithConcealment': 240,
          'totalAudioEnergy': 12.5,
          'totalSamplesDuration': 10.0,
        }),
        StatsReport('playout-audio', 'media-playout', 0, {
          'kind': 'audio',
          'synthesizedSamples': 240,
          'synthesizedDuration': 0.005,
          'totalPlayoutDelay': 2.5,
          'totalSampleCount': 48000,
        }),
      ],
      now: now,
    );

    final json = collector
        .createStatsEntryForTesting(
          endTime: now.add(const Duration(seconds: 1)),
        )
        .toJson();

    expect(json['audio']['outbound'], containsPair('active', true));
    expect(json['audio']['outbound'], containsPair('nackCount', 2));
    expect(
      json['audio']['outbound'],
      containsPair('retransmittedPacketsSent', 3),
    );
    expect(json['audio']['outbound'], containsPair('targetBitrate', 32000.0));

    expect(json['audio']['inbound'], containsPair('nackCount', 4));
    expect(
      json['audio']['inbound'],
      containsPair('jitterBufferMinimumDelay', 0.08),
    );
    expect(
      json['audio']['inbound'],
      containsPair('samplesDecodedWithConcealment', 240),
    );
    expect(json['audio']['inbound'], containsPair('totalAudioEnergy', 12.5));

    expect(json['mediaPlayout'], {
      'synthesizedSamples': 240,
      'synthesizedDuration': 0.005,
      'totalPlayoutDelay': 2.5,
      'totalSampleCount': 48000,
    });
  });
}
