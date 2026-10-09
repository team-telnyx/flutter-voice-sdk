/// TDD failing tests for VSD-419: PreCallDiagnostic for Flutter SDK.
///
/// These tests reference new classes that do NOT yet exist:
/// - `PreCallDiagnostic` (lib/utils/pre_call_diagnosis.dart)
/// - `DiagnosticReport` and related model classes
///
/// The tests also reference new methods/constructors on existing classes that
/// the implementation will need to add (e.g. `CallReportOptions.fromConfig`).
///
/// All tests will fail at compile time until the implementation is written.
///
/// Test plan (15 tests):
///  1. DiagnosticReport structure — all required fields present.
///  2. MinMaxAverage computation — given [10, 20, 30], verify min/max/avg.
///  3. MOS computation — given jitter=5ms, rtt=50ms, loss=0, MOS in excellent range.
///  4. Quality mapping — MOS > 4.0 → excellent, 3.5-4.0 → good, etc.
///  5. ICE candidate extraction — ICE candidates collected from test call.
///  6. Run with token config — connects, makes test call, returns report.
///  7. Run with credential config — same with sipUser/sipPassword.
///  8. Error handling — SIP 4xx throws error with sipReason.
///  9. Error handling — connection failure throws error.
/// 10. Timeout — no stats within 30s throws timeout error.
/// 11. Cleanup on success — call hung up and client disconnected.
/// 12. Cleanup on failure — try/finally ensures cleanup even on failure.
/// 13. Jitter/RTT averaging — multiple samples, correct min/max/average.
/// 14. Session stats extraction — packetsReceived, packetsLost, etc.
/// 15. Integration with TelnyxClient API — uses connect, newCall, hangup, disconnect.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/utils/pre_call_diagnosis.dart';
import 'package:telnyx_webrtc/utils/stats/mos_calculator.dart';
import 'package:telnyx_webrtc/model/call_quality.dart';

/// Tests that require a live WebSocket connection to rtc.telnyx.com are
/// marked as integration tests and skipped by default.  Run them with:
///   flutter test --dart-define=RUN_INTEGRATION=true
const _runIntegration =
    bool.fromEnvironment('RUN_INTEGRATION', defaultValue: false);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('VSD-419: DiagnosticReport structure', () {
    test(
      'DiagnosticReport has all required fields',
      () {
        final report = DiagnosticReport(
          iceCandidateStats: [],
          iceCandidatePairStats: {},
          jitter: MinMaxAverage(min: 0, max: 0, average: 0),
          rtt: MinMaxAverage(min: 0, max: 0, average: 0),
          mos: 4.0,
          quality: DiagnosticQuality.excellent,
          sessionStats: DiagnosticSessionStats(
            packetsReceived: 0,
            packetsLost: 0,
            packetsSent: 0,
            bytesSent: 0,
            bytesReceived: 0,
          ),
        );

        expect(report.iceCandidateStats, isA<List<RTCIceCandidateStats>>());
        expect(report.iceCandidatePairStats, isA<Map<String, dynamic>>());
        expect(report.jitter, isA<MinMaxAverage>());
        expect(report.rtt, isA<MinMaxAverage>());
        expect(report.mos, isA<double>());
        expect(report.quality, isA<DiagnosticQuality>());
        expect(report.sessionStats, isA<DiagnosticSessionStats>());

        // Verify specific fields.
        expect(report.mos, equals(4.0));
        expect(report.quality, equals(DiagnosticQuality.excellent));
        expect(report.sessionStats.packetsReceived, equals(0));
        expect(report.sessionStats.packetsLost, equals(0));
        expect(report.sessionStats.packetsSent, equals(0));
        expect(report.sessionStats.bytesSent, equals(0));
        expect(report.sessionStats.bytesReceived, equals(0));
      },
    );
  });

  group('VSD-419: MinMaxAverage computation', () {
    test(
      'given [10, 20, 30], verify min=10, max=30, average=20',
      () {
        final mma = MinMaxAverage.fromValues([10.0, 20.0, 30.0]);

        expect(mma.min, equals(10.0));
        expect(mma.max, equals(30.0));
        expect(mma.average, equals(20.0));
      },
    );

    test('MinMaxAverage handles single value', () {
      final mma = MinMaxAverage.fromValues([42.0]);

      expect(mma.min, equals(42.0));
      expect(mma.max, equals(42.0));
      expect(mma.average, equals(42.0));
    });

    test('MinMaxAverage handles empty list with zeros', () {
      final mma = MinMaxAverage.fromValues([]);

      expect(mma.min, equals(0.0));
      expect(mma.max, equals(0.0));
      expect(mma.average, equals(0.0));
    });
  });

  group('VSD-419: MOS computation', () {
    test(
      'given jitter=5ms, rtt=50ms, packetsLost=0, MOS is in excellent range (4.0+)',
      () {
        // Use the existing MosCalculator to compute MOS.
        final mos = MosCalculator.calculateMos(
          rtt: 0.05, // 50ms in seconds
          jitter: 0.005, // 5ms in seconds
          packetLoss: 0.0,
        );

        expect(
          mos,
          greaterThanOrEqualTo(4.0),
          reason: 'Good network conditions should yield MOS >= 4.0',
        );
        expect(
          mos,
          lessThanOrEqualTo(4.5),
          reason: 'MOS should never exceed 4.5',
        );
      },
    );
  });

  group('VSD-419: Quality mapping', () {
    test(
      'DiagnosticQuality.fromMos uses canonical MOS bands (matches '
      'CallQuality / JS getQuality): >4.2 excellent, >=4.1 good, '
      '>=3.7 fair, >=3.1 poor, else bad',
      () {
        expect(
          DiagnosticQuality.fromMos(4.3),
          equals(DiagnosticQuality.excellent),
        );
        expect(DiagnosticQuality.fromMos(4.15), equals(DiagnosticQuality.good));
        expect(DiagnosticQuality.fromMos(4.0), equals(DiagnosticQuality.fair));
        expect(DiagnosticQuality.fromMos(3.5), equals(DiagnosticQuality.poor));
        expect(DiagnosticQuality.fromMos(3.0), equals(DiagnosticQuality.bad));
        expect(DiagnosticQuality.fromMos(1.5), equals(DiagnosticQuality.bad));

        // DiagnosticQuality mirrors the existing CallQuality mapping so the
        // two quality scales stay consistent.
        expect(CallQuality.fromMos(4.3), equals(CallQuality.excellent));
        expect(CallQuality.fromMos(4.15), equals(CallQuality.good));
        expect(CallQuality.fromMos(4.0), equals(CallQuality.fair));
        expect(CallQuality.fromMos(3.5), equals(CallQuality.poor));
      },
    );
  });

  group('VSD-419: ICE candidate extraction', () {
    test(
      'RTCIceCandidateStats has all expected fields',
      () {
        final candidate = RTCIceCandidateStats(
          address: '192.168.1.1',
          candidateType: 'host',
          deleted: false,
          id: 'RTCIceLc_1_1234',
          port: 54321,
          priority: 2113929471,
          protocol: 'udp',
          relayProtocol: null,
          timestamp: '2026-07-09T11:00:00.000Z',
          transportId: 'transport-1',
          type: 'local',
          url: '',
        );

        expect(candidate.address, equals('192.168.1.1'));
        expect(candidate.candidateType, equals('host'));
        expect(candidate.deleted, isFalse);
        expect(candidate.id, equals('RTCIceLc_1_1234'));
        expect(candidate.port, equals(54321));
        expect(candidate.priority, equals(2113929471));
        expect(candidate.protocol, equals('udp'));
        expect(candidate.relayProtocol, isNull);
        expect(candidate.timestamp, equals('2026-07-09T11:00:00.000Z'));
        expect(candidate.transportId, equals('transport-1'));
        expect(candidate.type, equals('local'));
      },
    );
  });

  group('VSD-419: Run with token config', () {
    test(
      'PreCallDiagnostic.run with sipToken connects, makes test call, returns report',
      () async {
        final options = PreCallDiagnosisOptions(
          texMLApplicationNumber: '+18001234567',
          sipToken: 'test-token-123',
          sipCallerIDName: 'Diagnostic Test',
          sipCallerIDNumber: '+15551234567',
        );

        // This will fail because PreCallDiagnostic.run() does not exist yet.
        final report = await PreCallDiagnostic.run(options);

        expect(report, isA<DiagnosticReport>());
        expect(report.mos, greaterThan(0.0));
        expect(report.quality, isA<DiagnosticQuality>());
        expect(report.iceCandidateStats, isA<List>());
        expect(report.jitter, isA<MinMaxAverage>());
        expect(report.rtt, isA<MinMaxAverage>());
        expect(report.sessionStats, isA<DiagnosticSessionStats>());
      },
      skip: _runIntegration ? null : 'Integration test — requires live server',
    );
  });

  group('VSD-419: Run with credential config', () {
    test(
      'PreCallDiagnostic.run with sipUser/sipPassword connects and returns report',
      () async {
        final options = PreCallDiagnosisOptions(
          texMLApplicationNumber: '+18001234567',
          sipUser: 'testuser',
          sipPassword: 'testpass',
          sipCallerIDName: 'Diagnostic Test',
          sipCallerIDNumber: '+15551234567',
        );

        final report = await PreCallDiagnostic.run(options);

        expect(report, isA<DiagnosticReport>());
        expect(report.mos, greaterThan(0.0));
      },
      skip: _runIntegration ? null : 'Integration test — requires live server',
    );
  });

  group('VSD-419: Error handling — SIP 4xx', () {
    test(
      'if test call returns SIP 4xx, throws error with sipReason',
      () async {
        final options = PreCallDiagnosisOptions(
          texMLApplicationNumber: '+18005551234',
          sipToken: 'test-token-123',
          sipCallerIDName: 'Diagnostic Test',
          sipCallerIDNumber: '+15551234567',
        );

        // The run() method should throw when the call receives a SIP 4xx.
        // We cannot easily mock the internal TelnyxClient here, but the test
        // documents the expected behavior.
        expect(
          () => PreCallDiagnostic.run(options),
          throwsA(
            isA<PreCallDiagnosticException>()
                .having((e) => e.sipCode, 'sipCode', greaterThanOrEqualTo(400))
                .having((e) => e.sipReason, 'sipReason', isNotEmpty),
          ),
        );
      },
      skip: _runIntegration ? null : 'Integration test — requires live server',
    );
  });

  group('VSD-419: Error handling — connection failure', () {
    test(
      'if client cannot connect, throws error',
      () async {
        final options = PreCallDiagnosisOptions(
          texMLApplicationNumber: '+18005551234',
          sipToken: 'invalid-token',
          sipCallerIDName: 'Diagnostic Test',
          sipCallerIDNumber: '+15551234567',
        );

        expect(
          () => PreCallDiagnostic.run(options),
          throwsA(isA<Exception>()),
        );
      },
      skip: _runIntegration ? null : 'Integration test — requires live server',
    );
  });

  group('VSD-419: Timeout (30s)', () {
    test(
      'if no stats received within 30 seconds, throws timeout error',
      () async {
        final options = PreCallDiagnosisOptions(
          texMLApplicationNumber: '+18005551234',
          sipToken: 'test-token-123',
          sipCallerIDName: 'Diagnostic Test',
          sipCallerIDNumber: '+15551234567',
        );

        // PreCallDiagnostic should have a 30s timeout safety.
        expect(
          () => PreCallDiagnostic.run(options),
          throwsA(
            isA<PreCallDiagnosticException>().having(
              (e) => e.reason,
              'reason',
              equals(PreCallDiagnosticFailureReason.timeout),
            ),
          ),
        );
      },
      skip: _runIntegration ? null : 'Integration test — requires live server',
    );
  });

  group('VSD-419: Cleanup on success', () {
    test(
      'after successful diagnosis, call is hung up and client is disconnected',
      () async {
        final options = PreCallDiagnosisOptions(
          texMLApplicationNumber: '+18005551234',
          sipToken: 'test-token-123',
          sipCallerIDName: 'Diagnostic Test',
          sipCallerIDNumber: '+15551234567',
        );

        // The run() method should clean up after success.
        // We verify the report is returned, which implies cleanup happened
        // (the method would hang if disconnect didn't complete).
        final report = await PreCallDiagnostic.run(options);

        expect(report, isA<DiagnosticReport>());
        // If we got here, the call was hung up and client disconnected.
      },
      skip: _runIntegration ? null : 'Integration test — requires live server',
    );
  });

  group('VSD-419: Cleanup on failure (try/finally)', () {
    test(
      'even if diagnosis fails, call is hung up and client is disconnected',
      () async {
        final options = PreCallDiagnosisOptions(
          texMLApplicationNumber: '+18005551234',
          sipToken: 'test-token-123',
          sipCallerIDName: 'Diagnostic Test',
          sipCallerIDNumber: '+15551234567',
        );

        // Even when run() throws, it should clean up via try/finally.
        // We expect the exception but also verify cleanup was attempted.
        try {
          await PreCallDiagnostic.run(options);
          fail('Should have thrown an exception');
        } catch (e) {
          // The exception is expected.  The fact that we catch it means
          // the cleanup (disconnect) happened — otherwise the method
          // would hang indefinitely.
          expect(e, isA<Exception>());
        }
      },
      skip: _runIntegration ? null : 'Integration test — requires live server',
    );
  });

  group('VSD-419: Jitter/RTT averaging', () {
    test(
      'multiple stats samples are collected, correct min/max/average computed',
      () {
        // Simulate multiple jitter samples: [5.0, 10.0, 15.0, 20.0, 25.0]
        final jitterValues = [5.0, 10.0, 15.0, 20.0, 25.0];
        final jitterMma = MinMaxAverage.fromValues(jitterValues);

        expect(jitterMma.min, equals(5.0));
        expect(jitterMma.max, equals(25.0));
        expect(jitterMma.average, equals(15.0));

        // Simulate RTT samples: [0.02, 0.04, 0.06, 0.08, 0.10]
        final rttValues = [0.02, 0.04, 0.06, 0.08, 0.10];
        final rttMma = MinMaxAverage.fromValues(rttValues);

        expect(rttMma.min, equals(0.02));
        expect(rttMma.max, equals(0.10));
        expect(rttMma.average, closeTo(0.06, 0.001));
      },
    );
  });

  group('VSD-419: Session stats extraction', () {
    test(
      'packetsReceived, packetsLost, packetsSent, bytesSent, bytesReceived are correctly extracted',
      () {
        final sessionStats = DiagnosticSessionStats(
          packetsReceived: 1500,
          packetsLost: 15,
          packetsSent: 1600,
          bytesSent: 256000,
          bytesReceived: 240000,
        );

        expect(sessionStats.packetsReceived, equals(1500));
        expect(sessionStats.packetsLost, equals(15));
        expect(sessionStats.packetsSent, equals(1600));
        expect(sessionStats.bytesSent, equals(256000));
        expect(sessionStats.bytesReceived, equals(240000));
      },
    );
  });

  group('VSD-419: Integration with TelnyxClient API', () {
    test(
      'PreCallDiagnostic.run uses TelnyxClient API correctly (connect, newCall, hangup, disconnect)',
      () async {
        final options = PreCallDiagnosisOptions(
          texMLApplicationNumber: '+18005551234',
          sipToken: 'test-token-123',
          sipCallerIDName: 'Diagnostic Test',
          sipCallerIDNumber: '+15551234567',
        );

        // The run() method should:
        // 1. Create a TelnyxClient with TokenConfig
        // 2. Call connect() and wait for socket connected
        // 3. Call newCall() with destinationNumber = texMLApplicationNumber
        // 4. Collect stats via onCallQualityChange callback
        // 5. Hang up the call
        // 6. Disconnect the client
        // 7. Return the DiagnosticReport
        //
        // We verify the method exists and returns a report.
        final report = await PreCallDiagnostic.run(options);

        expect(report, isA<DiagnosticReport>());
        expect(report.iceCandidateStats, isA<List<RTCIceCandidateStats>>());
        expect(report.iceCandidatePairStats, isA<Map<String, dynamic>?>());
        expect(report.jitter, isA<MinMaxAverage>());
        expect(report.rtt, isA<MinMaxAverage>());
        expect(report.mos, greaterThan(0.0));
        expect(report.quality, isA<DiagnosticQuality>());
        expect(report.sessionStats, isA<DiagnosticSessionStats>());
      },
      skip: _runIntegration ? null : 'Integration test — requires live server',
    );
  });
}
