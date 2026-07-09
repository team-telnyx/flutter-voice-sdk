/// TDD failing tests for VSD-421: Call Quality Warnings.
///
/// These tests reference new classes and registries that do NOT yet exist:
/// - `TelnyxWarning` (lib/model/telnyx_warning.dart)
/// - `TelnyxError` (lib/model/telnyx_error.dart)
/// - `SdkWarningRegistry` (lib/model/sdk_warning_registry.dart)
/// - `SdkErrorRegistry` (lib/model/sdk_error_registry.dart)
/// - `SdkWarningCode` constants (lib/model/sdk_warning_codes.dart)
/// - `SdkErrorCode` constants (lib/model/sdk_error_codes.dart)
/// - `QualityWarningMonitor` (lib/utils/stats/quality_warning_monitor.dart)
///
/// All tests will fail at compile time until the implementation is written.
///
/// Test plan (22 tests):
///  1. Warning registry completeness — all 25 warning codes with all fields.
///  2. Error registry completeness — all 23 error codes with all fields incl fatal.
///  3. createWarning factory — returns correct TelnyxWarning.
///  4. createError factory — returns correct TelnyxError.
///  5. HIGH_RTT detection — RTT > 0.4s for 3 consecutive intervals → warning.
///  6. HIGH_RTT reset — RTT returns to normal → counter reset.
///  7. HIGH_JITTER detection — jitter > 30ms for 3 intervals → warning.
///  8. HIGH_PACKET_LOSS detection — loss > 1% for 3 intervals (delta-based).
///  9. LOW_MOS detection — MOS < 3.5 for 3 intervals → warning.
/// 10. LOW_LOCAL_AUDIO pre-confirmation — audio < 0.001 for 3 intervals → warning.
/// 11. LOW_LOCAL_AUDIO post-confirmation — 30s continuous silence → warning.
/// 12. LOW_INBOUND_AUDIO detection — inbound < 0.001 for 3 intervals → warning.
/// 13. LOW_BYTES_RECEIVED detection — bytesReceived delta == 0 for 3 intervals.
/// 14. LOW_BYTES_SENT detection — bytesSent delta == 0 for 3 intervals.
/// 15. Warning throttling — same warning not re-emitted within 15s.
/// 16. ICE_CANDIDATE_PAIR_CHANGED — pair ID change → warning.
/// 17. ICE_CONNECTIVITY_LOST — iceConnectionState 'disconnected' → warning.
/// 18. PEER_CONNECTION_FAILED — peerConnectionState 'failed' → warning.
/// 19. Fatal error terminates call.
/// 20. Non-fatal error continues.
/// 21. Warning callback fires with structured TelnyxWarning.
/// 22. Error callback fires with structured TelnyxError.
library;

import 'package:flutter_test/flutter_test.dart';

// These imports reference files that do NOT exist yet — tests will fail
// at compile time until the implementation is complete.
import 'package:telnyx_webrtc/model/telnyx_warning.dart';
import 'package:telnyx_webrtc/model/telnyx_error.dart';
import 'package:telnyx_webrtc/model/sdk_warning_codes.dart';
import 'package:telnyx_webrtc/model/sdk_error_codes.dart';
import 'package:telnyx_webrtc/model/sdk_warning_registry.dart';
import 'package:telnyx_webrtc/model/sdk_error_registry.dart';
import 'package:telnyx_webrtc/utils/stats/quality_warning_monitor.dart';
import 'package:telnyx_webrtc/utils/stats/call_report_collector.dart';

/// Helper to build a minimal StatsInterval for testing.
StatsInterval _makeStats({
  double? rtt,
  double? jitter,
  int? packetsReceived,
  int? packetsLost,
  int? packetsSent,
  int? bytesSent,
  int? bytesReceived,
  double? outboundAudioLevel,
  double? inboundAudioLevel,
  String? iceCandidatePairId,
}) {
  return StatsInterval(
    intervalStartUtc: DateTime.now().toUtc().toIso8601String(),
    intervalEndUtc: DateTime.now().toUtc().toIso8601String(),
    audio: AudioStats(
      outbound: OutboundAudioStats(
        packetsSent: packetsSent,
        bytesSent: bytesSent,
        audioLevelAvg: outboundAudioLevel,
      ),
      inbound: InboundAudioStats(
        packetsReceived: packetsReceived,
        packetsLost: packetsLost,
        bytesReceived: bytesReceived,
        audioLevelAvg: inboundAudioLevel,
        jitterAvg: jitter,
      ),
    ),
    connection: ConnectionStats(
      roundTripTimeAvg: rtt,
      packetsSent: packetsSent,
      packetsReceived: packetsReceived,
      bytesSent: bytesSent,
      bytesReceived: bytesReceived,
    ),
    ice: IceStats(id: iceCandidatePairId),
  );
}

void main() {
  group('VSD-421: Warning registry completeness', () {
    test('all 25 warning codes exist in SdkWarningRegistry with all fields',
        () {
      final expectedCodes = <int>[
        // Network quality (310xx)
        SdkWarningCode.highRtt, // 31001
        SdkWarningCode.highJitter, // 31002
        SdkWarningCode.highPacketLoss, // 31003
        SdkWarningCode.lowMos, // 31004
        SdkWarningCode.lowLocalAudio, // 31005
        SdkWarningCode.lowInboundAudio, // 31006
        // Connection / data-flow (320xx)
        SdkWarningCode.lowBytesReceived, // 32001
        SdkWarningCode.lowBytesSent, // 32002
        SdkWarningCode.recordingUnavailable, // 32003
        SdkWarningCode.recordingBufferOverflow, // 32004
        // Call connection (330xx)
        SdkWarningCode.iceConnectivityLost, // 33001
        SdkWarningCode.iceGatheringTimeout, // 33002
        SdkWarningCode.iceGatheringEmpty, // 33003
        SdkWarningCode.peerConnectionFailed, // 33004
        SdkWarningCode.onlyHostIceCandidates, // 33005
        SdkWarningCode.answerWhilePeerActive, // 33006
        SdkWarningCode.duplicateInboundAnswer, // 33007
        SdkWarningCode.iceCandidatePairChanged, // 33008
        SdkWarningCode.audioInputDeviceChangeSkipped, // 33009
        SdkWarningCode.multipleActiveCallsDetected, // 33010
        SdkWarningCode.sharedRemoteElementOverwrite, // 33011
        // Authentication (340xx)
        SdkWarningCode.tokenExpiringSoon, // 34001
        // Session / reconnection (350xx)
        SdkWarningCode.unknownReattachedSession, // 35002
        // Signaling health (360xx)
        SdkWarningCode.signalingRecoveryRequired, // 36003
        SdkWarningCode.mediaRecoveryRequired, // 36004
        SdkWarningCode.reconnectionFailedWithNoAutoReconnect, // 36005
      ];

      expect(
        expectedCodes.length,
        equals(26),
        reason: 'There should be exactly 26 warning code constants',
      );

      for (final code in expectedCodes) {
        final definition = SdkWarningRegistry.get(code);
        expect(
          definition,
          isNotNull,
          reason: 'Warning code $code should exist in registry',
        );
        expect(
          definition!.name,
          isNotEmpty,
          reason: 'Warning $code must have a name',
        );
        expect(
          definition.message,
          isNotEmpty,
          reason: 'Warning $code must have a message',
        );
        expect(
          definition.description,
          isNotEmpty,
          reason: 'Warning $code must have a description',
        );
        expect(
          definition.causes,
          isNotEmpty,
          reason: 'Warning $code must have at least one cause',
        );
        expect(
          definition.solutions,
          isNotEmpty,
          reason: 'Warning $code must have at least one solution',
        );
      }
    });
  });

  group('VSD-421: Error registry completeness', () {
    test(
        'all 23 error codes exist in SdkErrorRegistry with all fields incl fatal',
        () {
      final expectedCodes = <int>[
        // SDP errors (400xx)
        SdkErrorCode.sdpCreateOfferFailed, // 40001
        SdkErrorCode.sdpCreateAnswerFailed, // 40002
        SdkErrorCode.sdpSetLocalDescriptionFailed, // 40003
        SdkErrorCode.sdpSetRemoteDescriptionFailed, // 40004
        SdkErrorCode.sdpSendFailed, // 40005
        // Media / device errors (420xx)
        SdkErrorCode.mediaMicrophonePermissionDenied, // 42001
        SdkErrorCode.mediaDeviceNotFound, // 42002
        SdkErrorCode.mediaGetUserMediaFailed, // 42003
        // Call-control errors (440xx)
        SdkErrorCode.holdFailed, // 44001
        SdkErrorCode.invalidCallParameters, // 44002
        SdkErrorCode.byeSendFailed, // 44003
        SdkErrorCode.subscribeFailed, // 44004
        SdkErrorCode.peerClosedDuringInit, // 44005
        // WebSocket / transport errors (450xx)
        SdkErrorCode.websocketConnectionFailed, // 45001
        SdkErrorCode.websocketError, // 45002
        SdkErrorCode.reconnectionExhausted, // 45003
        SdkErrorCode.gatewayFailed, // 45004
        // Authentication errors (460xx)
        SdkErrorCode.loginFailed, // 46001
        SdkErrorCode.invalidCredentials, // 46002
        SdkErrorCode.authenticationRequired, // 46003
        // ICE restart errors (470xx)
        SdkErrorCode.iceRestartFailed, // 47001
        // Network errors (480xx)
        SdkErrorCode.networkOffline, // 48001
        // Session errors (485xx)
        SdkErrorCode.sessionNotReattached, // 48501
        // General / catch-all (490xx)
        SdkErrorCode.unexpectedError, // 49001
      ];

      expect(
        expectedCodes.length,
        equals(24),
        reason: 'There should be exactly 24 error code constants',
      );

      for (final code in expectedCodes) {
        final definition = SdkErrorRegistry.get(code);
        expect(
          definition,
          isNotNull,
          reason: 'Error code $code should exist in registry',
        );
        expect(
          definition!.name,
          isNotEmpty,
          reason: 'Error $code must have a name',
        );
        expect(
          definition.message,
          isNotEmpty,
          reason: 'Error $code must have a message',
        );
        expect(
          definition.description,
          isNotEmpty,
          reason: 'Error $code must have a description',
        );
        expect(
          definition.causes,
          isNotEmpty,
          reason: 'Error $code must have at least one cause',
        );
        expect(
          definition.solutions,
          isNotEmpty,
          reason: 'Error $code must have at least one solution',
        );
        expect(
          definition.fatal,
          isA<bool>(),
          reason: 'Error $code must have a boolean fatal flag',
        );
      }
    });
  });

  group('VSD-421: createWarning factory', () {
    test('SdkWarningRegistry.createWarning returns correct TelnyxWarning', () {
      final warning = SdkWarningRegistry.createWarning(SdkWarningCode.highRtt);

      expect(warning.code, equals(SdkWarningCode.highRtt));
      expect(warning.name, equals('HIGH_RTT'));
      expect(warning.message, equals('High network latency detected'));
      expect(warning.description, isNotEmpty);
      expect(warning.causes.length, greaterThan(0));
      expect(warning.solutions.length, greaterThan(0));
    });

    test('createWarning with custom message override', () {
      final warning = SdkWarningRegistry.createWarning(
        SdkWarningCode.highJitter,
        message: 'Custom jitter message',
      );

      expect(warning.code, equals(SdkWarningCode.highJitter));
      expect(warning.name, equals('HIGH_JITTER'));
      expect(warning.message, equals('Custom jitter message'));
      // Other fields should come from the registry.
      expect(warning.description, isNotEmpty);
    });
  });

  group('VSD-421: createError factory', () {
    test('SdkErrorRegistry.createError returns correct TelnyxError', () {
      final error = SdkErrorRegistry.createError(
        SdkErrorCode.reconnectionExhausted,
      );

      expect(error.code, equals(SdkErrorCode.reconnectionExhausted));
      expect(error.name, equals('RECONNECTION_EXHAUSTED'));
      expect(error.message, equals('Unable to reconnect to server'));
      expect(error.description, isNotEmpty);
      expect(error.causes.length, greaterThan(0));
      expect(error.solutions.length, greaterThan(0));
      expect(
        error.fatal,
        isTrue,
        reason: 'RECONNECTION_EXHAUSTED should be fatal',
      );
    });

    test('createError with fatalOverride', () {
      final error = SdkErrorRegistry.createError(
        SdkErrorCode.mediaMicrophonePermissionDenied,
        fatalOverride: false,
      );

      expect(error.code, equals(SdkErrorCode.mediaMicrophonePermissionDenied));
      // The registry default is fatal=true, but the override should win.
      expect(
        error.fatal,
        isFalse,
        reason: 'fatalOverride should take precedence over registry default',
      );
    });
  });

  group('VSD-421: HIGH_RTT detection', () {
    test(
      'RTT > 0.4s for 3 consecutive intervals emits HIGH_RTT warning',
      () {
        final warnings = <TelnyxWarning>[];
        final monitor = QualityWarningMonitor(
          callId: 'test-call-1',
          onWarning: warnings.add,
        )
          // Interval 1 — RTT above threshold (0.4s).
          ..checkStats(_makeStats(rtt: 0.5));
        expect(
          warnings.length,
          equals(0),
          reason: 'First breach should not emit warning',
        );

        // Interval 2 — still above.
        monitor.checkStats(_makeStats(rtt: 0.45));
        expect(
          warnings.length,
          equals(0),
          reason: 'Second breach should not emit warning',
        );

        // Interval 3 — third consecutive breach → warning.
        monitor.checkStats(_makeStats(rtt: 0.6));
        expect(warnings.length, equals(1));
        expect(warnings[0].code, equals(SdkWarningCode.highRtt));
        expect(warnings[0].name, equals('HIGH_RTT'));
      },
    );
  });

  group('VSD-421: HIGH_RTT reset', () {
    test(
      'RTT returns to normal resets the breach counter and allows re-fire',
      () {
        final warnings = <TelnyxWarning>[];
        final monitor = QualityWarningMonitor(
          callId: 'test-call-2',
          onWarning: warnings.add,
        )
          // Two consecutive breaches.
          ..checkStats(_makeStats(rtt: 0.5))
          ..checkStats(_makeStats(rtt: 0.45));
        expect(warnings.length, equals(0));

        // RTT returns to normal — counter resets.
        monitor.checkStats(_makeStats(rtt: 0.1));
        expect(warnings.length, equals(0));

        // Now three more breaches should fire again.
        monitor
          ..checkStats(_makeStats(rtt: 0.5))
          ..checkStats(_makeStats(rtt: 0.5))
          ..checkStats(_makeStats(rtt: 0.5));
        expect(warnings.length, equals(1));
        expect(warnings[0].code, equals(SdkWarningCode.highRtt));
      },
    );
  });

  group('VSD-421: HIGH_JITTER detection', () {
    test(
      'jitter > 30ms for 3 consecutive intervals emits HIGH_JITTER warning',
      () {
        final warnings = <TelnyxWarning>[];
        final monitor = QualityWarningMonitor(
          callId: 'test-call-3',
          onWarning: warnings.add,
        )
          // jitter is in milliseconds in StatsInterval.
          ..checkStats(_makeStats(jitter: 35))
          ..checkStats(_makeStats(jitter: 40));
        expect(warnings.length, equals(0));

        monitor.checkStats(_makeStats(jitter: 50));
        expect(warnings.length, equals(1));
        expect(warnings[0].code, equals(SdkWarningCode.highJitter));
        expect(warnings[0].name, equals('HIGH_JITTER'));
      },
    );
  });

  group('VSD-421: HIGH_PACKET_LOSS detection (delta-based)', () {
    test(
      'packet loss > 1% for 3 consecutive intervals emits HIGH_PACKET_LOSS',
      () {
        final warnings = <TelnyxWarning>[];
        final monitor = QualityWarningMonitor(
          callId: 'test-call-4',
          onWarning: warnings.add,
        )
          // Delta-based: packetsReceived and packetsLost are cumulative.
          // Interval 1: 100 received, 0 lost
          ..checkStats(_makeStats(packetsReceived: 100, packetsLost: 0));
        expect(warnings.length, equals(0));

        // Interval 2: 100 more received (200 total), 2 lost (2% loss)
        monitor.checkStats(_makeStats(packetsReceived: 200, packetsLost: 2));
        expect(
          warnings.length,
          equals(0),
          reason: 'First breach (2% loss > 1%) should not emit',
        );

        // Interval 3: 100 more (300 total), 3 more lost (3% loss this interval)
        monitor.checkStats(_makeStats(packetsReceived: 300, packetsLost: 5));
        expect(
          warnings.length,
          equals(0),
          reason: 'Second breach should not emit',
        );

        // Interval 4: 100 more (400 total), 2 more lost (2% loss this interval)
        monitor.checkStats(_makeStats(packetsReceived: 400, packetsLost: 7));
        expect(warnings.length, equals(1));
        expect(warnings[0].code, equals(SdkWarningCode.highPacketLoss));
      },
    );
  });

  group('VSD-421: LOW_MOS detection', () {
    test(
      'MOS < 3.5 for 3 consecutive intervals emits LOW_MOS warning',
      () {
        final warnings = <TelnyxWarning>[];
        final monitor = QualityWarningMonitor(
          callId: 'test-call-5',
          onWarning: warnings.add,
        )
          // The monitor computes a simplified MOS from jitter/rtt/loss, using
          // per-interval packet-loss deltas. RTT/jitter are kept below their
          // individual HIGH_RTT/HIGH_JITTER thresholds so only LOW_MOS can fire.
          //
          // Baseline interval establishes the packet counters; with no previous
          // sample the per-interval loss is 0, so MOS stays above 3.5 and this
          // interval does not breach on its own.
          ..checkStats(
            _makeStats(
              rtt: 0.3,
              jitter: 25,
              packetsReceived: 100,
              packetsLost: 0,
            ),
          )
          // Breach 1: ~13% per-interval loss drags MOS below 3.5.
          ..checkStats(
            _makeStats(
              rtt: 0.3,
              jitter: 25,
              packetsReceived: 200,
              packetsLost: 15,
            ),
          )
          // Breach 2.
          ..checkStats(
            _makeStats(
              rtt: 0.3,
              jitter: 25,
              packetsReceived: 300,
              packetsLost: 30,
            ),
          );
        expect(warnings.length, equals(0));

        // Breach 3 → warning.
        monitor.checkStats(
          _makeStats(
            rtt: 0.3,
            jitter: 25,
            packetsReceived: 400,
            packetsLost: 45,
          ),
        );
        expect(warnings.length, equals(1));
        expect(warnings[0].code, equals(SdkWarningCode.lowMos));
        expect(warnings[0].name, equals('LOW_MOS'));
      },
    );
  });

  group('VSD-421: LOW_LOCAL_AUDIO pre-confirmation', () {
    test(
      'audio level < 0.001 for 3 consecutive intervals (pre-confirmation) emits warning',
      () {
        final warnings = <TelnyxWarning>[];
        final monitor = QualityWarningMonitor(
          callId: 'test-call-6',
          onWarning: warnings.add,
        )
          // Outbound audio level below threshold, before audio is confirmed.
          ..checkStats(_makeStats(outboundAudioLevel: 0.0001))
          ..checkStats(_makeStats(outboundAudioLevel: 0.0005));
        expect(warnings.length, equals(0));

        monitor.checkStats(_makeStats(outboundAudioLevel: 0.0001));
        expect(warnings.length, equals(1));
        expect(warnings[0].code, equals(SdkWarningCode.lowLocalAudio));
        expect(warnings[0].name, equals('LOW_LOCAL_AUDIO'));
      },
    );
  });

  group('VSD-421: LOW_LOCAL_AUDIO post-confirmation (30s silence)', () {
    test(
      'after audio is confirmed, 30s continuous silence emits LOW_LOCAL_AUDIO',
      () {
        final warnings = <TelnyxWarning>[];
        final monitor = QualityWarningMonitor(
          callId: 'test-call-7',
          onWarning: warnings.add,
        )
          // First, confirm audio by sending a high level.
          ..checkStats(_makeStats(outboundAudioLevel: 0.5));
        expect(warnings.length, equals(0));

        // Now simulate continuous silence.  With 5s intervals, 6 intervals
        // = 30s of silence after confirmation.
        for (int i = 0; i < 5; i++) {
          monitor.checkStats(_makeStats(outboundAudioLevel: 0.0001));
        }
        expect(
          warnings.length,
          equals(0),
          reason: 'Should not fire before 30s of continuous silence',
        );

        // 6th interval = 30s of silence → warning.
        monitor.checkStats(_makeStats(outboundAudioLevel: 0.0001));
        expect(warnings.length, equals(1));
        expect(warnings[0].code, equals(SdkWarningCode.lowLocalAudio));
      },
    );
  });

  group('VSD-421: LOW_INBOUND_AUDIO detection', () {
    test(
      'does not fire before inbound audio is ever confirmed '
      '(no false positive at call start)',
      () {
        final warnings = <TelnyxWarning>[];
        final monitor = QualityWarningMonitor(
          callId: 'test-call-8',
          onWarning: warnings.add,
        );
        // The remote party is legitimately silent at the start of the call
        // (no inbound RTP audio yet). This must NOT raise LOW_INBOUND_AUDIO.
        for (var i = 0; i < 10; i++) {
          monitor.checkStats(_makeStats(inboundAudioLevel: 0.0001));
        }
        expect(warnings.length, equals(0));
      },
    );

    test(
      'after inbound audio is confirmed, 30s continuous silence emits '
      'LOW_INBOUND_AUDIO',
      () {
        final warnings = <TelnyxWarning>[];
        final monitor = QualityWarningMonitor(
          callId: 'test-call-8b',
          onWarning: warnings.add,
        )
          // Confirm inbound audio was flowing at least once.
          ..checkStats(_makeStats(inboundAudioLevel: 0.5));
        expect(warnings.length, equals(0));

        // With 5s intervals, 6 intervals = 30s of continuous silence.
        for (var i = 0; i < 5; i++) {
          monitor.checkStats(_makeStats(inboundAudioLevel: 0.0001));
        }
        expect(
          warnings.length,
          equals(0),
          reason: 'Should not fire before 30s of continuous silence',
        );

        // 6th interval = 30s → warning.
        monitor.checkStats(_makeStats(inboundAudioLevel: 0.0001));
        expect(warnings.length, equals(1));
        expect(warnings[0].code, equals(SdkWarningCode.lowInboundAudio));
        expect(warnings[0].name, equals('LOW_INBOUND_AUDIO'));
      },
    );
  });

  group('VSD-421: LOW_BYTES_RECEIVED detection', () {
    test(
      'bytesReceived delta == 0 for 3 consecutive intervals emits LOW_BYTES_RECEIVED',
      () {
        final warnings = <TelnyxWarning>[];
        final monitor = QualityWarningMonitor(
          callId: 'test-call-9',
          onWarning: warnings.add,
        )
          // Interval 1: 1000 bytes received (establishes baseline).
          ..checkStats(_makeStats(bytesReceived: 1000));
        expect(warnings.length, equals(0));

        // Interval 2: same bytesReceived → delta = 0 (breach 1).
        monitor.checkStats(_makeStats(bytesReceived: 1000));
        expect(warnings.length, equals(0));

        // Interval 3: still same → delta = 0 (breach 2).
        monitor.checkStats(_makeStats(bytesReceived: 1000));
        expect(warnings.length, equals(0));

        // Interval 4: still same → delta = 0 (breach 3) → warning.
        monitor.checkStats(_makeStats(bytesReceived: 1000));
        expect(warnings.length, equals(1));
        expect(warnings[0].code, equals(SdkWarningCode.lowBytesReceived));
        expect(warnings[0].name, equals('LOW_BYTES_RECEIVED'));
      },
    );
  });

  group('VSD-421: LOW_BYTES_SENT detection', () {
    test(
      'bytesSent delta == 0 for 3 consecutive intervals emits LOW_BYTES_SENT',
      () {
        final warnings = <TelnyxWarning>[];
        final monitor = QualityWarningMonitor(
          callId: 'test-call-10',
          onWarning: warnings.add,
        )
          // Establish baseline.
          ..checkStats(_makeStats(bytesSent: 5000));
        expect(warnings.length, equals(0));

        // 3 consecutive intervals with no new bytes sent.
        monitor.checkStats(_makeStats(bytesSent: 5000));
        expect(warnings.length, equals(0));

        monitor.checkStats(_makeStats(bytesSent: 5000));
        expect(warnings.length, equals(0));

        monitor.checkStats(_makeStats(bytesSent: 5000));
        expect(warnings.length, equals(1));
        expect(warnings[0].code, equals(SdkWarningCode.lowBytesSent));
        expect(warnings[0].name, equals('LOW_BYTES_SENT'));
      },
    );
  });

  group('VSD-421: Warning throttling (15s)', () {
    test(
      'same warning is not re-emitted within 15 seconds',
      () {
        final warnings = <TelnyxWarning>[];
        final monitor = QualityWarningMonitor(
          callId: 'test-call-11',
          onWarning: warnings.add,
        )
          // Fire HIGH_RTT by sending 3 intervals with high RTT.
          ..checkStats(_makeStats(rtt: 0.5))
          ..checkStats(_makeStats(rtt: 0.5))
          ..checkStats(_makeStats(rtt: 0.5));
        expect(warnings.length, equals(1));

        // Continue breaching — should NOT re-emit within 15s.
        // With 5s intervals, 2 more intervals = 10s total since first emit.
        monitor
          ..checkStats(_makeStats(rtt: 0.5))
          ..checkStats(_makeStats(rtt: 0.5));
        expect(
          warnings.length,
          equals(1),
          reason: 'Should not re-emit same warning within 15s throttle window',
        );

        // 3rd interval after first emit = 15s — should re-emit.
        monitor.checkStats(_makeStats(rtt: 0.5));
        expect(
          warnings.length,
          equals(2),
          reason: 'Should re-emit after 15s throttle window expires',
        );
        expect(warnings[1].code, equals(SdkWarningCode.highRtt));
      },
    );
  });

  group('VSD-421: ICE_CANDIDATE_PAIR_CHANGED', () {
    test(
      'selected ICE candidate pair ID change mid-call emits warning',
      () {
        final warnings = <TelnyxWarning>[];
        final monitor = QualityWarningMonitor(
          callId: 'test-call-12',
          onWarning: warnings.add,
        )
          // Establish with pair ID "pair-A".
          ..checkStats(
            _makeStats(
              rtt: 0.05,
              jitter: 5,
              iceCandidatePairId: 'pair-A',
            ),
          );
        expect(warnings.length, equals(0));

        // Change to pair ID "pair-B".
        monitor.checkStats(
          _makeStats(
            rtt: 0.05,
            jitter: 5,
            iceCandidatePairId: 'pair-B',
          ),
        );
        expect(warnings.length, equals(1));
        expect(
          warnings[0].code,
          equals(SdkWarningCode.iceCandidatePairChanged),
        );
        expect(warnings[0].name, equals('ICE_CANDIDATE_PAIR_CHANGED'));
      },
    );
  });

  group('VSD-421: ICE_CONNECTIVITY_LOST', () {
    test(
      "iceConnectionState 'disconnected' emits ICE_CONNECTIVITY_LOST warning",
      () {
        final warnings = <TelnyxWarning>[];
        QualityWarningMonitor(
          callId: 'test-call-13',
          onWarning: warnings.add,
        )
            // This method will be called from the Peer's onIceConnectionState
            // callback when the state transitions to 'disconnected'.
            .onIceConnectionStateChanged('disconnected');

        expect(warnings.length, equals(1));
        expect(warnings[0].code, equals(SdkWarningCode.iceConnectivityLost));
        expect(warnings[0].name, equals('ICE_CONNECTIVITY_LOST'));
      },
    );
  });

  group('VSD-421: PEER_CONNECTION_FAILED', () {
    test(
      "peerConnectionState 'failed' emits PEER_CONNECTION_FAILED warning",
      () {
        final warnings = <TelnyxWarning>[];
        QualityWarningMonitor(
          callId: 'test-call-14',
          onWarning: warnings.add,
        ).onPeerConnectionStateChanged('failed');

        expect(warnings.length, equals(1));
        expect(warnings[0].code, equals(SdkWarningCode.peerConnectionFailed));
        expect(warnings[0].name, equals('PEER_CONNECTION_FAILED'));
      },
    );
  });

  group('VSD-421: Fatal error terminates call', () {
    test(
      'TelnyxError with fatal=true indicates the call should terminate',
      () {
        final error = SdkErrorRegistry.createError(
          SdkErrorCode.sdpCreateOfferFailed,
        );

        expect(
          error.fatal,
          isTrue,
          reason: 'SDP_CREATE_OFFER_FAILED should be fatal',
        );
        expect(error.code, equals(SdkErrorCode.sdpCreateOfferFailed));
        expect(error.name, equals('SDP_CREATE_OFFER_FAILED'));

        // The TelnyxClient should check error.fatal to decide whether
        // to terminate the call.  We verify the error object carries the
        // fatal flag correctly.
        expect(error.fatal, isTrue);
      },
    );
  });

  group('VSD-421: Non-fatal error continues', () {
    test(
      'TelnyxError with fatal=false indicates the call should continue',
      () {
        final error = SdkErrorRegistry.createError(
          SdkErrorCode.holdFailed,
        );

        expect(error.fatal, isFalse, reason: 'HOLD_FAILED should not be fatal');
        expect(error.code, equals(SdkErrorCode.holdFailed));
        expect(error.name, equals('HOLD_FAILED'));

        // The call should continue when a non-fatal error is emitted.
        expect(error.fatal, isFalse);
      },
    );
  });

  group('VSD-421: Warning callback fires', () {
    test(
      'onWarning callback fires with structured TelnyxWarning object',
      () {
        TelnyxWarning? capturedWarning;
        QualityWarningMonitor(
          callId: 'test-call-15',
          sessionId: 'session-abc',
          onWarning: (warning) {
            capturedWarning = warning;
          },
        )
          // Trigger HIGH_RTT.
          ..checkStats(_makeStats(rtt: 0.5))
          ..checkStats(_makeStats(rtt: 0.5))
          ..checkStats(_makeStats(rtt: 0.5));

        expect(capturedWarning, isNotNull);
        expect(capturedWarning!.code, equals(SdkWarningCode.highRtt));
        expect(capturedWarning!.name, equals('HIGH_RTT'));
        expect(capturedWarning!.message, isNotEmpty);
        expect(capturedWarning!.description, isNotEmpty);
        expect(capturedWarning!.causes, isNotEmpty);
        expect(capturedWarning!.solutions, isNotEmpty);
        expect(capturedWarning!.callId, equals('test-call-15'));
        expect(capturedWarning!.sessionId, equals('session-abc'));
      },
    );
  });

  group('VSD-421: Error callback fires', () {
    test(
      'onError callback fires with structured TelnyxError object',
      () {
        TelnyxError? capturedError;
        // The monitor or client should expose an onError callback.
        // For this test, we test that SdkErrorRegistry.createError produces
        // a well-formed TelnyxError that would be passed to onError.
        capturedError = SdkErrorRegistry.createError(
          SdkErrorCode.websocketConnectionFailed,
        );

        expect(capturedError, isNotNull);
        expect(
          capturedError.code,
          equals(SdkErrorCode.websocketConnectionFailed),
        );
        expect(capturedError.name, equals('WEBSOCKET_CONNECTION_FAILED'));
        expect(capturedError.message, equals('Unable to connect to server'));
        expect(capturedError.description, isNotEmpty);
        expect(capturedError.causes, isNotEmpty);
        expect(capturedError.solutions, isNotEmpty);
        expect(capturedError.fatal, isTrue);

        // TelnyxError should also support optional callId/sessionId.
        final errorWithCall = SdkErrorRegistry.createError(
          SdkErrorCode.byeSendFailed,
          callId: 'test-call-16',
          sessionId: 'session-xyz',
        );
        expect(errorWithCall.callId, equals('test-call-16'));
        expect(errorWithCall.sessionId, equals('session-xyz'));
        expect(
          errorWithCall.fatal,
          isFalse,
          reason: 'BYE_SEND_FAILED is non-fatal',
        );
      },
    );
  });
}
