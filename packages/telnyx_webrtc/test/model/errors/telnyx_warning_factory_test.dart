import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/model/errors/telnyx_warning.dart';
import 'package:telnyx_webrtc/model/errors/telnyx_warning_codes.dart';
import 'package:telnyx_webrtc/model/errors/telnyx_warning_factory.dart';

void main() {
  group('VSDK-415: createTelnyxWarning factory', () {
    test('returns TelnyxWarning with correct fields from registry', () {
      final warning = createTelnyxWarning(TelnyxWarningCodes.highRtt);

      expect(warning.code, equals(31001));
      expect(warning.name, equals('HIGH_RTT'));
      expect(warning.message, isNotEmpty);
      expect(warning.description, isNotEmpty);
      expect(warning.causes, isNotEmpty);
      expect(warning.solutions, isNotEmpty);
    });

    test('returns TelnyxWarning for ICE connectivity lost', () {
      final warning =
          createTelnyxWarning(TelnyxWarningCodes.iceConnectivityLost);

      expect(warning.code, equals(33001));
      expect(warning.name, equals('ICE_CONNECTIVITY_LOST'));
    });

    test('returns TelnyxWarning for signaling recovery required', () {
      final warning =
          createTelnyxWarning(TelnyxWarningCodes.signalingRecoveryRequired);

      expect(warning.code, equals(36003));
      expect(warning.name, equals('SIGNALING_RECOVERY_REQUIRED'));
    });

    test('throws ArgumentError for unknown code', () {
      expect(
        () => createTelnyxWarning(99999),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('overrides message when provided', () {
      final warning = createTelnyxWarning(
        TelnyxWarningCodes.highRtt,
        message: 'Custom warning message',
      );

      expect(warning.message, equals('Custom warning message'));
    });

    test('uses registry default message when not overridden', () {
      final warning = createTelnyxWarning(TelnyxWarningCodes.highJitter);

      expect(warning.message, isNotEmpty);
      expect(warning.message, isNot(equals('')));
    });

    test('returns a TelnyxWarning', () {
      final warning = createTelnyxWarning(TelnyxWarningCodes.lowMos);

      expect(warning, isA<TelnyxWarning>());
    });
  });
}
