import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/model/audio_constraints.dart';

void main() {
  group('AudioConstraints', () {
    test('should create AudioConstraints with all properties', () {
      const constraints = AudioConstraints(
        echoCancellation: true,
        noiseSuppression: false,
        autoGainControl: true,
      );

      expect(constraints.echoCancellation, equals(true));
      expect(constraints.noiseSuppression, equals(false));
      expect(constraints.autoGainControl, equals(true));
    });

    test('should create AudioConstraints with default values', () {
      const constraints = AudioConstraints();

      expect(constraints.echoCancellation, equals(true));
      expect(constraints.noiseSuppression, equals(true));
      expect(constraints.autoGainControl, equals(true));
    });

    test('should create enabled AudioConstraints', () {
      final constraints = AudioConstraints.enabled();

      expect(constraints.echoCancellation, equals(true));
      expect(constraints.noiseSuppression, equals(true));
      expect(constraints.autoGainControl, equals(true));
    });

    test('should create disabled AudioConstraints', () {
      final constraints = AudioConstraints.disabled();

      expect(constraints.echoCancellation, equals(false));
      expect(constraints.noiseSuppression, equals(false));
      expect(constraints.autoGainControl, equals(false));
    });

    test('should convert to map correctly (default/non-Android)', () {
      final constraints = AudioConstraints(
        echoCancellation: true,
        noiseSuppression: false,
        autoGainControl: true,
      );

      final map = constraints.toMap();

      expect(
          map,
          equals({
            'echoCancellation': true,
            'noiseSuppression': false,
            'autoGainControl': true,
          }));
    });

    test('should convert to map correctly (Android)', () {
      final constraints = AudioConstraints(
        echoCancellation: true,
        noiseSuppression: false,
        autoGainControl: true,
      );

      final map = constraints.toMap(isAndroid: true);

      expect(
          map,
          equals({
            'echoCancellation': true,
            'noiseSuppression': false,
            'autoGainControl': true,
            'googEchoCancellation': true,
            'googNoiseSuppression': false,
            'googAutoGainControl': true,
            'googHighpassFilter': false,
          }));
    });

    test('should convert to map with default values', () {
      const constraints = AudioConstraints();

      final map = constraints.toMap();

      expect(
          map,
          equals({
            'echoCancellation': true,
            'noiseSuppression': true,
            'autoGainControl': true,
          }));
    });

    test('should throw FormatException when fromMap receives invalid types',
        () {
      expect(
        () => AudioConstraints.fromMap({'echoCancellation': 'invalid'}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => AudioConstraints.fromMap({'noiseSuppression': 123}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => AudioConstraints.fromMap({'autoGainControl': []}),
        throwsA(isA<FormatException>()),
      );
    });

    test('should have correct equality', () {
      const constraints1 = AudioConstraints(
        echoCancellation: true,
        noiseSuppression: false,
        autoGainControl: true,
      );

      const constraints2 = AudioConstraints(
        echoCancellation: true,
        noiseSuppression: false,
        autoGainControl: true,
      );

      const constraints3 = AudioConstraints(
        echoCancellation: false,
        noiseSuppression: false,
        autoGainControl: true,
      );

      expect(constraints1, equals(constraints2));
      expect(constraints1, isNot(equals(constraints3)));
    });

    test('should have correct toString', () {
      const constraints = AudioConstraints(
        echoCancellation: true,
        noiseSuppression: false,
        autoGainControl: true,
      );

      expect(
        constraints.toString(),
        equals(
            'AudioConstraints(echoCancellation: true, noiseSuppression: false, autoGainControl: true)'),
      );
    });
  });
}
