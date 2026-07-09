import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/model/errors/sdk_warnings.dart';

void main() {
  group('VSDK-415: sdkWarnings registry', () {
    test('has exactly 26 entries', () {
      expect(sdkWarnings.length, equals(26));
    });

    test('every entry has non-empty name', () {
      for (final entry in sdkWarnings.entries) {
        expect(
          entry.value.name,
          isNotEmpty,
          reason: 'Code ${entry.key} has empty name',
        );
      }
    });

    test('every entry has non-empty message', () {
      for (final entry in sdkWarnings.entries) {
        expect(
          entry.value.message,
          isNotEmpty,
          reason: 'Code ${entry.key} has empty message',
        );
      }
    });

    test('every entry has non-empty description', () {
      for (final entry in sdkWarnings.entries) {
        expect(
          entry.value.description,
          isNotEmpty,
          reason: 'Code ${entry.key} has empty description',
        );
      }
    });

    test('every entry has non-empty causes list', () {
      for (final entry in sdkWarnings.entries) {
        expect(
          entry.value.causes,
          isNotEmpty,
          reason: 'Code ${entry.key} has empty causes',
        );
      }
    });

    test('every entry has non-empty solutions list', () {
      for (final entry in sdkWarnings.entries) {
        expect(
          entry.value.solutions,
          isNotEmpty,
          reason: 'Code ${entry.key} has empty solutions',
        );
      }
    });

    group('code range coverage', () {
      test('contains network quality warnings in 310xx range', () {
        final codes =
            sdkWarnings.keys.where((c) => c >= 31001 && c <= 31099).toList();
        expect(codes, hasLength(6));
      });

      test('contains connection/data-flow warnings in 320xx range', () {
        final codes =
            sdkWarnings.keys.where((c) => c >= 32001 && c <= 32099).toList();
        expect(codes, hasLength(4));
      });

      test('contains call connection warnings in 330xx range', () {
        final codes =
            sdkWarnings.keys.where((c) => c >= 33001 && c <= 33099).toList();
        expect(codes, hasLength(11));
      });

      test('contains authentication warnings in 340xx range', () {
        final codes =
            sdkWarnings.keys.where((c) => c >= 34001 && c <= 34099).toList();
        expect(codes, hasLength(1));
      });

      test('contains session/reconnection warnings in 350xx range', () {
        final codes =
            sdkWarnings.keys.where((c) => c >= 35001 && c <= 35099).toList();
        expect(codes, hasLength(1));
      });

      test('contains signaling health warnings in 360xx range', () {
        final codes =
            sdkWarnings.keys.where((c) => c >= 36001 && c <= 36099).toList();
        expect(codes, hasLength(3));
      });
    });
  });
}
