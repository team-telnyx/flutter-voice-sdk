import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/model/errors/sdk_errors.dart';

void main() {
  group('VSDK-415: sdkErrors registry', () {
    test('has exactly 24 entries', () {
      expect(sdkErrors.length, equals(24));
    });

    test('every entry has non-empty name', () {
      for (final entry in sdkErrors.entries) {
        expect(
          entry.value.name,
          isNotEmpty,
          reason: 'Code ${entry.key} has empty name',
        );
      }
    });

    test('every entry has non-empty message', () {
      for (final entry in sdkErrors.entries) {
        expect(
          entry.value.message,
          isNotEmpty,
          reason: 'Code ${entry.key} has empty message',
        );
      }
    });

    test('every entry has non-empty description', () {
      for (final entry in sdkErrors.entries) {
        expect(
          entry.value.description,
          isNotEmpty,
          reason: 'Code ${entry.key} has empty description',
        );
      }
    });

    test('every entry has non-empty causes list', () {
      for (final entry in sdkErrors.entries) {
        expect(
          entry.value.causes,
          isNotEmpty,
          reason: 'Code ${entry.key} has empty causes',
        );
      }
    });

    test('every entry has non-empty solutions list', () {
      for (final entry in sdkErrors.entries) {
        expect(
          entry.value.solutions,
          isNotEmpty,
          reason: 'Code ${entry.key} has empty solutions',
        );
      }
    });

    test('every entry has a fatal: bool field', () {
      for (final entry in sdkErrors.entries) {
        // fatal is a bool — we just need it to be a valid boolean
        expect(entry.value.fatal, isA<bool>());
      }
    });

    group('fatal flag correctness', () {
      test('SDP errors (400xx) are fatal: true', () {
        for (final code in [40001, 40002, 40003, 40004, 40005]) {
          expect(
            sdkErrors[code]!.fatal,
            isTrue,
            reason: 'Code $code should be fatal',
          );
        }
      });

      test('media errors (420xx) are fatal: true by default', () {
        for (final code in [42001, 42002, 42003]) {
          expect(
            sdkErrors[code]!.fatal,
            isTrue,
            reason: 'Code $code should be fatal by default',
          );
        }
      });

      test('WebSocket error 45002 is fatal: false', () {
        expect(sdkErrors[45002]!.fatal, isFalse);
      });

      test('gateway failed 45004 is fatal: false', () {
        expect(sdkErrors[45004]!.fatal, isFalse);
      });

      test('authentication required 46003 is fatal: false', () {
        expect(sdkErrors[46003]!.fatal, isFalse);
      });

      test('ICE restart failed 47001 is fatal: false', () {
        expect(sdkErrors[47001]!.fatal, isFalse);
      });

      test('network offline 48001 is fatal: false', () {
        expect(sdkErrors[48001]!.fatal, isFalse);
      });

      test('session not reattached 48501 is fatal: true', () {
        expect(sdkErrors[48501]!.fatal, isTrue);
      });

      test('unexpected error 49001 is fatal: true', () {
        expect(sdkErrors[49001]!.fatal, isTrue);
      });

      test('login failed 46001 is fatal: true', () {
        expect(sdkErrors[46001]!.fatal, isTrue);
      });

      test('invalid credentials 46002 is fatal: true', () {
        expect(sdkErrors[46002]!.fatal, isTrue);
      });

      test('reconnection exhausted 45003 is fatal: true', () {
        expect(sdkErrors[45003]!.fatal, isTrue);
      });

      test('webSocket connection failed 45001 is fatal: true', () {
        expect(sdkErrors[45001]!.fatal, isTrue);
      });

      test('invalid call parameters 44002 is fatal: true', () {
        expect(sdkErrors[44002]!.fatal, isTrue);
      });

      test('peer closed during init 44005 is fatal: true', () {
        expect(sdkErrors[44005]!.fatal, isTrue);
      });
    });

    group('code range coverage', () {
      test('contains SDP errors in 400xx range', () {
        final sdpCodes =
            sdkErrors.keys.where((c) => c >= 40001 && c <= 40099).toList();
        expect(sdpCodes, hasLength(5));
      });

      test('contains media errors in 420xx range', () {
        final mediaCodes =
            sdkErrors.keys.where((c) => c >= 42001 && c <= 42099).toList();
        expect(mediaCodes, hasLength(3));
      });

      test('contains call-control errors in 440xx range', () {
        final callCodes =
            sdkErrors.keys.where((c) => c >= 44001 && c <= 44099).toList();
        expect(callCodes, hasLength(5));
      });

      test('contains WebSocket errors in 450xx range', () {
        final wsCodes =
            sdkErrors.keys.where((c) => c >= 45001 && c <= 45099).toList();
        expect(wsCodes, hasLength(4));
      });

      test('contains auth errors in 460xx range', () {
        final authCodes =
            sdkErrors.keys.where((c) => c >= 46001 && c <= 46099).toList();
        expect(authCodes, hasLength(3));
      });

      test('contains ICE restart errors in 470xx range', () {
        final iceCodes =
            sdkErrors.keys.where((c) => c >= 47001 && c <= 47099).toList();
        expect(iceCodes, hasLength(1));
      });

      test('contains network errors in 480xx range', () {
        final netCodes =
            sdkErrors.keys.where((c) => c >= 48001 && c <= 48099).toList();
        expect(netCodes, hasLength(1));
      });

      test('contains session errors in 485xx range', () {
        final sessionCodes =
            sdkErrors.keys.where((c) => c >= 48501 && c <= 48599).toList();
        expect(sessionCodes, hasLength(1));
      });

      test('contains general errors in 490xx range', () {
        final generalCodes =
            sdkErrors.keys.where((c) => c >= 49001 && c <= 49099).toList();
        expect(generalCodes, hasLength(1));
      });
    });
  });
}
