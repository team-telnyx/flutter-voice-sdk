import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/model/errors/telnyx_warning_codes.dart';
import 'package:telnyx_webrtc/model/errors/sdk_warnings.dart';

void main() {
  group('VSDK-415: TelnyxWarningCodes', () {
    group('Network quality warnings (310xx)', () {
      test('has highRtt = 31001', () {
        expect(TelnyxWarningCodes.highRtt, equals(31001));
      });

      test('has highJitter = 31002', () {
        expect(TelnyxWarningCodes.highJitter, equals(31002));
      });

      test('has highPacketLoss = 31003', () {
        expect(TelnyxWarningCodes.highPacketLoss, equals(31003));
      });

      test('has lowMos = 31004', () {
        expect(TelnyxWarningCodes.lowMos, equals(31004));
      });

      test('has lowLocalAudio = 31005', () {
        expect(TelnyxWarningCodes.lowLocalAudio, equals(31005));
      });

      test('has lowInboundAudio = 31006', () {
        expect(TelnyxWarningCodes.lowInboundAudio, equals(31006));
      });
    });

    group('Connection / data-flow warnings (320xx)', () {
      test('has lowBytesReceived = 32001', () {
        expect(TelnyxWarningCodes.lowBytesReceived, equals(32001));
      });

      test('has lowBytesSent = 32002', () {
        expect(TelnyxWarningCodes.lowBytesSent, equals(32002));
      });

      test('has recordingUnavailable = 32003', () {
        expect(TelnyxWarningCodes.recordingUnavailable, equals(32003));
      });

      test('has recordingBufferOverflow = 32004', () {
        expect(TelnyxWarningCodes.recordingBufferOverflow, equals(32004));
      });
    });

    group('Call connection warnings (330xx)', () {
      test('has iceConnectivityLost = 33001', () {
        expect(TelnyxWarningCodes.iceConnectivityLost, equals(33001));
      });

      test('has iceGatheringTimeout = 33002', () {
        expect(TelnyxWarningCodes.iceGatheringTimeout, equals(33002));
      });

      test('has iceGatheringEmpty = 33003', () {
        expect(TelnyxWarningCodes.iceGatheringEmpty, equals(33003));
      });

      test('has peerConnectionFailed = 33004', () {
        expect(TelnyxWarningCodes.peerConnectionFailed, equals(33004));
      });

      test('has onlyHostIceCandidates = 33005', () {
        expect(TelnyxWarningCodes.onlyHostIceCandidates, equals(33005));
      });

      test('has answerWhilePeerActive = 33006', () {
        expect(TelnyxWarningCodes.answerWhilePeerActive, equals(33006));
      });

      test('has duplicateInboundAnswer = 33007', () {
        expect(TelnyxWarningCodes.duplicateInboundAnswer, equals(33007));
      });

      test('has iceCandidatePairChanged = 33008', () {
        expect(TelnyxWarningCodes.iceCandidatePairChanged, equals(33008));
      });

      test('has audioInputDeviceChangeSkipped = 33009', () {
        expect(TelnyxWarningCodes.audioInputDeviceChangeSkipped, equals(33009));
      });

      test('has multipleActiveCallsDetected = 33010', () {
        expect(TelnyxWarningCodes.multipleActiveCallsDetected, equals(33010));
      });

      test('has sharedRemoteElementOverwrite = 33011', () {
        expect(TelnyxWarningCodes.sharedRemoteElementOverwrite, equals(33011));
      });
    });

    group('Authentication warnings (340xx)', () {
      test('has tokenExpiringSoon = 34001', () {
        expect(TelnyxWarningCodes.tokenExpiringSoon, equals(34001));
      });
    });

    group('Session / reconnection warnings (350xx)', () {
      test('has unknownReattachedSession = 35002', () {
        expect(TelnyxWarningCodes.unknownReattachedSession, equals(35002));
      });
    });

    group('Signaling health warnings (360xx)', () {
      test('has signalingRecoveryRequired = 36003', () {
        expect(TelnyxWarningCodes.signalingRecoveryRequired, equals(36003));
      });

      test('has mediaRecoveryRequired = 36004', () {
        expect(TelnyxWarningCodes.mediaRecoveryRequired, equals(36004));
      });

      test('has reconnectionFailedWithNoAutoReconnect = 36005', () {
        expect(
          TelnyxWarningCodes.reconnectionFailedWithNoAutoReconnect,
          equals(36005),
        );
      });
    });

    group('registry completeness', () {
      test('every code in TelnyxWarningCodes exists in sdkWarnings map', () {
        final codes = <int>[
          TelnyxWarningCodes.highRtt,
          TelnyxWarningCodes.highJitter,
          TelnyxWarningCodes.highPacketLoss,
          TelnyxWarningCodes.lowMos,
          TelnyxWarningCodes.lowLocalAudio,
          TelnyxWarningCodes.lowInboundAudio,
          TelnyxWarningCodes.lowBytesReceived,
          TelnyxWarningCodes.lowBytesSent,
          TelnyxWarningCodes.recordingUnavailable,
          TelnyxWarningCodes.recordingBufferOverflow,
          TelnyxWarningCodes.iceConnectivityLost,
          TelnyxWarningCodes.iceGatheringTimeout,
          TelnyxWarningCodes.iceGatheringEmpty,
          TelnyxWarningCodes.peerConnectionFailed,
          TelnyxWarningCodes.onlyHostIceCandidates,
          TelnyxWarningCodes.answerWhilePeerActive,
          TelnyxWarningCodes.iceCandidatePairChanged,
          TelnyxWarningCodes.audioInputDeviceChangeSkipped,
          TelnyxWarningCodes.multipleActiveCallsDetected,
          TelnyxWarningCodes.duplicateInboundAnswer,
          TelnyxWarningCodes.sharedRemoteElementOverwrite,
          TelnyxWarningCodes.tokenExpiringSoon,
          TelnyxWarningCodes.unknownReattachedSession,
          TelnyxWarningCodes.signalingRecoveryRequired,
          TelnyxWarningCodes.mediaRecoveryRequired,
          TelnyxWarningCodes.reconnectionFailedWithNoAutoReconnect,
        ];

        for (final code in codes) {
          expect(
            sdkWarnings.containsKey(code),
            isTrue,
            reason: 'Warning code $code is missing from sdkWarnings map',
          );
        }
      });

      test('all warning codes are unique', () {
        final codes = <int>[
          TelnyxWarningCodes.highRtt,
          TelnyxWarningCodes.highJitter,
          TelnyxWarningCodes.highPacketLoss,
          TelnyxWarningCodes.lowMos,
          TelnyxWarningCodes.lowLocalAudio,
          TelnyxWarningCodes.lowInboundAudio,
          TelnyxWarningCodes.lowBytesReceived,
          TelnyxWarningCodes.lowBytesSent,
          TelnyxWarningCodes.recordingUnavailable,
          TelnyxWarningCodes.recordingBufferOverflow,
          TelnyxWarningCodes.iceConnectivityLost,
          TelnyxWarningCodes.iceGatheringTimeout,
          TelnyxWarningCodes.iceGatheringEmpty,
          TelnyxWarningCodes.peerConnectionFailed,
          TelnyxWarningCodes.onlyHostIceCandidates,
          TelnyxWarningCodes.answerWhilePeerActive,
          TelnyxWarningCodes.iceCandidatePairChanged,
          TelnyxWarningCodes.audioInputDeviceChangeSkipped,
          TelnyxWarningCodes.multipleActiveCallsDetected,
          TelnyxWarningCodes.duplicateInboundAnswer,
          TelnyxWarningCodes.sharedRemoteElementOverwrite,
          TelnyxWarningCodes.tokenExpiringSoon,
          TelnyxWarningCodes.unknownReattachedSession,
          TelnyxWarningCodes.signalingRecoveryRequired,
          TelnyxWarningCodes.mediaRecoveryRequired,
          TelnyxWarningCodes.reconnectionFailedWithNoAutoReconnect,
        ];

        expect(
          codes.toSet().length,
          equals(codes.length),
          reason: 'Duplicate warning codes detected',
        );
      });

      test('has exactly 26 warning codes', () {
        expect(sdkWarnings.length, equals(26));
      });
    });
  });
}
