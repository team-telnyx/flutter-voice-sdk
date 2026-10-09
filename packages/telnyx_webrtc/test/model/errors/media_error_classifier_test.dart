import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/model/errors/telnyx_error_codes.dart';
import 'package:telnyx_webrtc/model/errors/telnyx_error_factory.dart';

void main() {
  group('VSDK-415: classifyMediaErrorCode', () {
    group('PlatformException classification', () {
      test('maps PlatformException with "permission" in code to 42001', () {
        final exception = PlatformException(
          code: 'permission_denied',
          message: 'Microphone permission denied',
        );

        final code = classifyMediaErrorCode(exception);

        expect(code, equals(TelnyxErrorCodes.mediaMicrophonePermissionDenied));
      });

      test('maps PlatformException with "NotAllowed" in message to 42001', () {
        final exception = PlatformException(
          code: 'audio_error',
          message: 'NotAllowedError: getUserMedia denied',
        );

        final code = classifyMediaErrorCode(exception);

        expect(code, equals(TelnyxErrorCodes.mediaMicrophonePermissionDenied));
      });

      test('maps PlatformException with "NotFound" in code to 42002', () {
        final exception = PlatformException(
          code: 'NotFound',
          message: 'No audio input device found',
        );

        final code = classifyMediaErrorCode(exception);

        expect(code, equals(TelnyxErrorCodes.mediaDeviceNotFound));
      });

      test('maps PlatformException with "Overconstrained" in message to 42002',
          () {
        final exception = PlatformException(
          code: 'device_error',
          message: 'OverconstrainedError: constraint not satisfied',
        );

        final code = classifyMediaErrorCode(exception);

        expect(code, equals(TelnyxErrorCodes.mediaDeviceNotFound));
      });

      test(
          'maps generic PlatformException (no match) to 42003 (getUserMedia failed)',
          () {
        final exception = PlatformException(
          code: 'unknown',
          message: 'Some other error',
        );

        final code = classifyMediaErrorCode(exception);

        expect(code, equals(TelnyxErrorCodes.mediaGetUserMediaFailed));
      });
    });

    group('string classification', () {
      test('maps string containing "NotAllowedError" to 42001', () {
        final code =
            classifyMediaErrorCode('NotAllowedError: permission denied');

        expect(code, equals(TelnyxErrorCodes.mediaMicrophonePermissionDenied));
      });

      test('maps string containing "permission" to 42001', () {
        final code = classifyMediaErrorCode('permission denied by user');

        expect(code, equals(TelnyxErrorCodes.mediaMicrophonePermissionDenied));
      });

      test('maps string containing "NotFoundError" to 42002', () {
        final code = classifyMediaErrorCode('NotFoundError: no device');

        expect(code, equals(TelnyxErrorCodes.mediaDeviceNotFound));
      });

      test('maps string containing "OverconstrainedError" to 42002', () {
        final code = classifyMediaErrorCode('OverconstrainedError');

        expect(code, equals(TelnyxErrorCodes.mediaDeviceNotFound));
      });

      test('maps generic string to 42003', () {
        final code = classifyMediaErrorCode('something unexpected happened');

        expect(code, equals(TelnyxErrorCodes.mediaGetUserMediaFailed));
      });
    });

    group('generic Exception classification', () {
      test('maps generic Exception to 42003', () {
        final code = classifyMediaErrorCode(Exception('generic failure'));

        expect(code, equals(TelnyxErrorCodes.mediaGetUserMediaFailed));
      });

      test('maps null to 42003', () {
        final code = classifyMediaErrorCode(null);

        expect(code, equals(TelnyxErrorCodes.mediaGetUserMediaFailed));
      });
    });
  });
}
