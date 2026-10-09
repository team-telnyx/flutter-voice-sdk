import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/model/errors/telnyx_error_codes.dart';
import 'package:telnyx_webrtc/model/errors/sdk_errors.dart';

void main() {
  group('VSDK-415: TelnyxErrorCodes', () {
    group('SDP errors (400xx)', () {
      test('has sdpCreateOfferFailed = 40001', () {
        expect(TelnyxErrorCodes.sdpCreateOfferFailed, equals(40001));
      });

      test('has sdpCreateAnswerFailed = 40002', () {
        expect(TelnyxErrorCodes.sdpCreateAnswerFailed, equals(40002));
      });

      test('has sdpSetLocalDescriptionFailed = 40003', () {
        expect(TelnyxErrorCodes.sdpSetLocalDescriptionFailed, equals(40003));
      });

      test('has sdpSetRemoteDescriptionFailed = 40004', () {
        expect(TelnyxErrorCodes.sdpSetRemoteDescriptionFailed, equals(40004));
      });

      test('has sdpSendFailed = 40005', () {
        expect(TelnyxErrorCodes.sdpSendFailed, equals(40005));
      });
    });

    group('Media errors (420xx)', () {
      test('has mediaMicrophonePermissionDenied = 42001', () {
        expect(TelnyxErrorCodes.mediaMicrophonePermissionDenied, equals(42001));
      });

      test('has mediaDeviceNotFound = 42002', () {
        expect(TelnyxErrorCodes.mediaDeviceNotFound, equals(42002));
      });

      test('has mediaGetUserMediaFailed = 42003', () {
        expect(TelnyxErrorCodes.mediaGetUserMediaFailed, equals(42003));
      });
    });

    group('Call-control errors (440xx)', () {
      test('has holdFailed = 44001', () {
        expect(TelnyxErrorCodes.holdFailed, equals(44001));
      });

      test('has invalidCallParameters = 44002', () {
        expect(TelnyxErrorCodes.invalidCallParameters, equals(44002));
      });

      test('has byeSendFailed = 44003', () {
        expect(TelnyxErrorCodes.byeSendFailed, equals(44003));
      });

      test('has subscribeFailed = 44004', () {
        expect(TelnyxErrorCodes.subscribeFailed, equals(44004));
      });

      test('has peerClosedDuringInit = 44005', () {
        expect(TelnyxErrorCodes.peerClosedDuringInit, equals(44005));
      });
    });

    group('WebSocket errors (450xx)', () {
      test('has webSocketConnectionFailed = 45001', () {
        expect(TelnyxErrorCodes.webSocketConnectionFailed, equals(45001));
      });

      test('has webSocketError = 45002', () {
        expect(TelnyxErrorCodes.webSocketError, equals(45002));
      });

      test('has reconnectionExhausted = 45003', () {
        expect(TelnyxErrorCodes.reconnectionExhausted, equals(45003));
      });

      test('has gatewayFailed = 45004', () {
        expect(TelnyxErrorCodes.gatewayFailed, equals(45004));
      });
    });

    group('Authentication errors (460xx)', () {
      test('has loginFailed = 46001', () {
        expect(TelnyxErrorCodes.loginFailed, equals(46001));
      });

      test('has invalidCredentials = 46002', () {
        expect(TelnyxErrorCodes.invalidCredentials, equals(46002));
      });

      test('has authenticationRequired = 46003', () {
        expect(TelnyxErrorCodes.authenticationRequired, equals(46003));
      });
    });

    group('ICE restart errors (470xx)', () {
      test('has iceRestartFailed = 47001', () {
        expect(TelnyxErrorCodes.iceRestartFailed, equals(47001));
      });
    });

    group('Network errors (480xx)', () {
      test('has networkOffline = 48001', () {
        expect(TelnyxErrorCodes.networkOffline, equals(48001));
      });
    });

    group('Session errors (485xx)', () {
      test('has sessionNotReattached = 48501', () {
        expect(TelnyxErrorCodes.sessionNotReattached, equals(48501));
      });
    });

    group('General errors (490xx)', () {
      test('has unexpectedError = 49001', () {
        expect(TelnyxErrorCodes.unexpectedError, equals(49001));
      });
    });

    group('registry completeness', () {
      test('every code in TelnyxErrorCodes exists in sdkErrors map', () {
        final codes = <int>[
          TelnyxErrorCodes.sdpCreateOfferFailed,
          TelnyxErrorCodes.sdpCreateAnswerFailed,
          TelnyxErrorCodes.sdpSetLocalDescriptionFailed,
          TelnyxErrorCodes.sdpSetRemoteDescriptionFailed,
          TelnyxErrorCodes.sdpSendFailed,
          TelnyxErrorCodes.mediaMicrophonePermissionDenied,
          TelnyxErrorCodes.mediaDeviceNotFound,
          TelnyxErrorCodes.mediaGetUserMediaFailed,
          TelnyxErrorCodes.holdFailed,
          TelnyxErrorCodes.invalidCallParameters,
          TelnyxErrorCodes.byeSendFailed,
          TelnyxErrorCodes.subscribeFailed,
          TelnyxErrorCodes.peerClosedDuringInit,
          TelnyxErrorCodes.webSocketConnectionFailed,
          TelnyxErrorCodes.webSocketError,
          TelnyxErrorCodes.reconnectionExhausted,
          TelnyxErrorCodes.gatewayFailed,
          TelnyxErrorCodes.loginFailed,
          TelnyxErrorCodes.invalidCredentials,
          TelnyxErrorCodes.authenticationRequired,
          TelnyxErrorCodes.iceRestartFailed,
          TelnyxErrorCodes.networkOffline,
          TelnyxErrorCodes.sessionNotReattached,
          TelnyxErrorCodes.unexpectedError,
        ];

        for (final code in codes) {
          expect(
            sdkErrors.containsKey(code),
            isTrue,
            reason: 'Code $code is missing from sdkErrors map',
          );
        }
      });

      test('all error codes are unique', () {
        final codes = <int>[
          TelnyxErrorCodes.sdpCreateOfferFailed,
          TelnyxErrorCodes.sdpCreateAnswerFailed,
          TelnyxErrorCodes.sdpSetLocalDescriptionFailed,
          TelnyxErrorCodes.sdpSetRemoteDescriptionFailed,
          TelnyxErrorCodes.sdpSendFailed,
          TelnyxErrorCodes.mediaMicrophonePermissionDenied,
          TelnyxErrorCodes.mediaDeviceNotFound,
          TelnyxErrorCodes.mediaGetUserMediaFailed,
          TelnyxErrorCodes.holdFailed,
          TelnyxErrorCodes.invalidCallParameters,
          TelnyxErrorCodes.byeSendFailed,
          TelnyxErrorCodes.subscribeFailed,
          TelnyxErrorCodes.peerClosedDuringInit,
          TelnyxErrorCodes.webSocketConnectionFailed,
          TelnyxErrorCodes.webSocketError,
          TelnyxErrorCodes.reconnectionExhausted,
          TelnyxErrorCodes.gatewayFailed,
          TelnyxErrorCodes.loginFailed,
          TelnyxErrorCodes.invalidCredentials,
          TelnyxErrorCodes.authenticationRequired,
          TelnyxErrorCodes.iceRestartFailed,
          TelnyxErrorCodes.networkOffline,
          TelnyxErrorCodes.sessionNotReattached,
          TelnyxErrorCodes.unexpectedError,
        ];

        expect(
          codes.toSet().length,
          equals(codes.length),
          reason: 'Duplicate error codes detected',
        );
      });

      test('has exactly 24 error codes', () {
        expect(sdkErrors.length, equals(24));
      });
    });
  });
}
