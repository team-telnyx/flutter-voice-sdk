import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:telnyx_webrtc/utils/stats/call_report_collector.dart';

void main() {
  group('CallReportCollector transport and codec stats', () {
    test('serializes transport state and resolves RTP codecs', () {
      final collector = CallReportCollector();
      final now = DateTime.utc(2026, 8, 14);

      collector.processStatsReportsForTesting([
        StatsReport('codec-out', 'codec', 0, {
          'mimeType': 'audio/opus',
          'clockRate': 48000,
          'channels': 2,
          'sdpFmtpLine': 'minptime=10;useinbandfec=1',
          'payloadType': 111,
        }),
        StatsReport('codec-in', 'codec', 0, {
          'mimeType': 'audio/PCMU',
          'clockRate': 8000,
          'channels': 1,
          'payloadType': 0,
        }),
        StatsReport('outbound-audio', 'outbound-rtp', 0, {
          'kind': 'audio',
          'codecId': 'codec-out',
          'packetsSent': 10,
        }),
        StatsReport('inbound-audio', 'inbound-rtp', 0, {
          'kind': 'audio',
          'codecId': 'codec-in',
          'packetsReceived': 12,
        }),
        StatsReport('pair-selected', 'candidate-pair', 0, {
          'state': 'succeeded',
          'localCandidateId': 'local-selected',
          'remoteCandidateId': 'remote-selected',
        }),
        StatsReport('transport-1', 'transport', 0, {
          'iceState': 'connected',
          'dtlsState': 'connected',
          'srtpCipher': 'AES_CM_128_HMAC_SHA1_80',
          'tlsVersion': 'FEFD',
          'selectedCandidatePairChanges': 2,
          'selectedCandidatePairId': 'pair-selected',
        }),
      ], now: now);

      final json = collector
          .createStatsEntryForTesting(
              endTime: now.add(const Duration(seconds: 1)))
          .toJson();

      expect(json['transport'], {
        'iceState': 'connected',
        'dtlsState': 'connected',
        'srtpCipher': 'AES_CM_128_HMAC_SHA1_80',
        'tlsVersion': 'FEFD',
        'selectedCandidatePairChanges': 2,
        'selectedCandidatePairId': 'pair-selected',
      });
      expect(json['ice']['id'], 'pair-selected');
      expect(json['audio']['outbound']['codec'], {
        'mimeType': 'audio/opus',
        'clockRate': 48000,
        'channels': 2,
        'sdpFmtpLine': 'minptime=10;useinbandfec=1',
        'payloadType': 111,
        'codecId': 'codec-out',
      });
      expect(json['audio']['inbound']['codec'], {
        'mimeType': 'audio/PCMU',
        'clockRate': 8000,
        'channels': 1,
        'payloadType': 0,
        'codecId': 'codec-in',
      });
    });

    test('waiting transport pair does not replace nominated fallback', () {
      final collector = CallReportCollector();
      final now = DateTime.utc(2026, 8, 14);

      collector.processStatsReportsForTesting([
        StatsReport('pair-selected', 'candidate-pair', 0, {
          'state': 'waiting',
        }),
        StatsReport('pair-fallback', 'candidate-pair', 0, {
          'state': 'succeeded',
          'nominated': true,
        }),
        StatsReport('transport-1', 'transport', 0, {
          'selectedCandidatePairId': 'pair-selected',
        }),
      ], now: now);

      final interval = collector.createStatsEntryForTesting(
        endTime: now.add(const Duration(seconds: 1)),
      );

      expect(interval.ice?.id, 'pair-fallback');
    });
  });
}
