import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/model/call_termination_reason.dart';

void main() {
  group('CallTerminationReason', () {
    test('should create CallTerminationReason with all parameters', () {
      const reason = CallTerminationReason(
        cause: 'CALL_REJECTED',
        causeCode: 21,
        sipCode: 403,
        sipReason: 'Dialed number is not included in whitelisted countries',
      );

      expect(reason.cause, equals('CALL_REJECTED'));
      expect(reason.causeCode, equals(21));
      expect(reason.sipCode, equals(403));
      expect(
        reason.sipReason,
        equals('Dialed number is not included in whitelisted countries'),
      );
    });

    test('should create CallTerminationReason with minimal parameters', () {
      const reason = CallTerminationReason();

      expect(reason.cause, isNull);
      expect(reason.causeCode, isNull);
      expect(reason.sipCode, isNull);
      expect(reason.sipReason, isNull);
    });

    test('should create CallTerminationReason with partial parameters', () {
      const reason = CallTerminationReason(
        sipCode: 404,
        sipReason: 'Not Found',
      );

      expect(reason.cause, isNull);
      expect(reason.causeCode, isNull);
      expect(reason.sipCode, equals(404));
      expect(reason.sipReason, equals('Not Found'));
    });

    group('toString', () {
      test('should format string with SIP code and reason', () {
        const reason = CallTerminationReason(
          sipCode: 403,
          sipReason: 'Forbidden',
        );

        expect(reason.toString(), equals('SIP 403: Forbidden'));
      });

      test(
        'should format string with SIP code and cause when no SIP reason',
        () {
          const reason = CallTerminationReason(
            cause: 'CALL_REJECTED',
            sipCode: 403,
          );

          expect(reason.toString(), equals('SIP 403: CALL_REJECTED'));
        },
      );

      test(
        'should format string with only SIP code when no reason or cause',
        () {
          const reason = CallTerminationReason(sipCode: 404);

          expect(reason.toString(), equals('SIP 404'));
        },
      );

      test('should format string with cause when no SIP code', () {
        const reason = CallTerminationReason(cause: 'NETWORK_ERROR');

        expect(reason.toString(), equals('NETWORK_ERROR'));
      });

      test('should return "Unknown reason" when all fields are null', () {
        const reason = CallTerminationReason();

        expect(reason.toString(), equals('Unknown reason'));
      });

      test('should return "Unknown reason" when all fields are empty', () {
        const reason = CallTerminationReason(cause: '', sipReason: '');

        expect(reason.toString(), equals('Unknown reason'));
      });

      test('should prefer SIP reason over cause when both are present', () {
        const reason = CallTerminationReason(
          cause: 'CALL_REJECTED',
          sipCode: 403,
          sipReason: 'Forbidden Access',
        );

        expect(reason.toString(), equals('SIP 403: Forbidden Access'));
      });

      test('should handle empty SIP reason and fall back to cause', () {
        const reason = CallTerminationReason(
          cause: 'TIMEOUT',
          sipCode: 408,
          sipReason: '',
        );

        expect(reason.toString(), equals('SIP 408: TIMEOUT'));
      });

      test('should handle complex real-world scenarios', () {
        const reason1 = CallTerminationReason(
          cause: 'CALL_REJECTED',
          causeCode: 21,
          sipCode: 403,
          sipReason: 'Dialed number is not included in whitelisted countries',
        );

        expect(
          reason1.toString(),
          equals(
            'SIP 403: Dialed number is not included in whitelisted countries',
          ),
        );

        const reason2 = CallTerminationReason(
          cause: 'USER_BUSY',
          causeCode: 17,
          sipCode: 486,
          sipReason: 'Busy Here',
        );

        expect(reason2.toString(), equals('SIP 486: Busy Here'));
      });
    });
  });
}
