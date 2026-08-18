import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/utils/stats/call_report_collector.dart';

void main() {
  StatsInterval interval({
    required String networkType,
    required String candidateType,
    required int requestsSent,
    required int responsesReceived,
    required int bytesSent,
    required int bytesReceived,
    bool writable = true,
    String iceState = 'connected',
  }) {
    return StatsInterval(
      intervalStartUtc: DateTime.utc(2026, 8, 18).toIso8601String(),
      intervalEndUtc: DateTime.utc(2026, 8, 18, 0, 0, 5).toIso8601String(),
      audio: AudioStats(
        outbound: OutboundAudioStats(bytesSent: bytesSent),
        inbound: InboundAudioStats(bytesReceived: bytesReceived),
      ),
      ice: IceStats(
        local: IceCandidateStats(
          networkType: networkType,
          candidateType: candidateType,
        ),
        requestsSent: requestsSent,
        responsesReceived: responsesReceived,
        writable: writable,
      ),
      transport: TransportStats(iceState: iceState),
    );
  }

  test('forces relay for a stalled non-relay VPN path', () {
    final collector = CallReportCollector()
      ..injectIntervalForTest(
        interval(
          networkType: 'vpn',
          candidateType: 'host',
          requestsSent: 2,
          responsesReceived: 2,
          bytesSent: 100,
          bytesReceived: 100,
        ),
      )
      ..injectIntervalForTest(
        interval(
          networkType: 'vpn',
          candidateType: 'host',
          requestsSent: 4,
          responsesReceived: 2,
          bytesSent: 200,
          bytesReceived: 100,
        ),
      );

    expect(collector.shouldForceRelayCandidateForRecovery(), isTrue);
  });

  test('does not force relay for healthy, non-VPN, or relay paths', () {
    for (final latest in [
      interval(
        networkType: 'vpn',
        candidateType: 'host',
        requestsSent: 4,
        responsesReceived: 4,
        bytesSent: 200,
        bytesReceived: 200,
      ),
      interval(
        networkType: 'wifi',
        candidateType: 'host',
        requestsSent: 4,
        responsesReceived: 2,
        bytesSent: 200,
        bytesReceived: 100,
      ),
      interval(
        networkType: 'vpn',
        candidateType: 'relay',
        requestsSent: 4,
        responsesReceived: 2,
        bytesSent: 200,
        bytesReceived: 100,
      ),
    ]) {
      final collector = CallReportCollector()
        ..injectIntervalForTest(
          interval(
            networkType: 'vpn',
            candidateType: 'host',
            requestsSent: 2,
            responsesReceived: 2,
            bytesSent: 100,
            bytesReceived: 100,
          ),
        )
        ..injectIntervalForTest(latest);
      expect(collector.shouldForceRelayCandidateForRecovery(), isFalse);
    }
  });
}
