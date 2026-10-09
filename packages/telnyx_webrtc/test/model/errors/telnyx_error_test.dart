import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/model/errors/telnyx_error.dart';

void main() {
  group('VSDK-396: TelnyxError', () {
    group('construction', () {
      test('constructs with all required fields', () {
        final error = TelnyxError(
          code: 40001,
          name: 'SDP_CREATE_OFFER_FAILED',
          message: 'Failed to create call offer',
          description: 'The browser was unable to generate a local SDP offer.',
          causes: ['Browser WebRTC API error', 'Invalid media constraints'],
          solutions: ['Check getUserMedia permissions'],
          fatal: true,
        );

        expect(error.code, equals(40001));
        expect(error.name, equals('SDP_CREATE_OFFER_FAILED'));
        expect(error.message, equals('Failed to create call offer'));
        expect(error.description, isNotEmpty);
        expect(error.causes, hasLength(2));
        expect(error.solutions, hasLength(1));
        expect(error.fatal, isTrue);
      });

      test('originalError is optional and defaults to null', () {
        final error = TelnyxError(
          code: 49001,
          name: 'UNEXPECTED_ERROR',
          message: 'An unexpected error occurred',
          description: 'Catch-all for unclassified failures.',
          causes: ['Unknown'],
          solutions: ['Report the issue'],
          fatal: true,
        );

        expect(error.originalError, isNull);
      });

      test('originalError can be set to any object', () {
        final original = Exception('something went wrong');
        final error = TelnyxError(
          code: 45002,
          name: 'WEBSOCKET_ERROR',
          message: 'Connection to server lost',
          description: 'WebSocket error after establishment.',
          causes: ['Network interruption'],
          solutions: ['Check network'],
          originalError: original,
          fatal: false,
        );

        expect(error.originalError, isNotNull);
        expect(error.originalError, same(original));
      });

      test('fatal flag can be false', () {
        final error = TelnyxError(
          code: 45002,
          name: 'WEBSOCKET_ERROR',
          message: 'Connection to server lost',
          description: 'WebSocket error after establishment.',
          causes: ['Network interruption'],
          solutions: ['Check network'],
          fatal: false,
        );

        expect(error.fatal, isFalse);
      });
    });

    group('toString', () {
      test('returns "[code] name: message" format', () {
        final error = TelnyxError(
          code: 42001,
          name: 'MEDIA_MICROPHONE_PERMISSION_DENIED',
          message: 'Microphone access denied',
          description: 'Mic permission denied by user or OS.',
          causes: ['User denied permission'],
          solutions: ['Ask user to grant permission'],
          fatal: true,
        );

        expect(
          error.toString(),
          equals(
            '[42001] MEDIA_MICROPHONE_PERMISSION_DENIED: Microphone access denied',
          ),
        );
      });
    });

    group('toJson', () {
      test('includes all fields in the JSON output', () {
        final error = TelnyxError(
          code: 46001,
          name: 'LOGIN_FAILED',
          message: 'Authentication failed',
          description: 'Login request was rejected by the server.',
          causes: ['Invalid credentials', 'Expired token'],
          solutions: ['Verify credentials', 'Generate new token'],
          fatal: true,
        );

        final json = error.toJson();

        expect(json['code'], equals(46001));
        expect(json['name'], equals('LOGIN_FAILED'));
        expect(json['message'], equals('Authentication failed'));
        expect(json['description'], isNotEmpty);
        expect(json['causes'], isA<List>());
        expect(json['causes'], hasLength(2));
        expect(json['solutions'], isA<List>());
        expect(json['solutions'], hasLength(2));
        expect(json['fatal'], isTrue);
      });

      test('includes originalError as string when present', () {
        final error = TelnyxError(
          code: 40001,
          name: 'SDP_CREATE_OFFER_FAILED',
          message: 'Failed to create call offer',
          description: 'SDP offer creation failed.',
          causes: ['Browser error'],
          solutions: ['Retry'],
          originalError: Exception('inner failure'),
          fatal: true,
        );

        final json = error.toJson();

        expect(json, contains('originalError'));
        expect(json['originalError'], isA<String>());
      });

      test('omits originalError when not present', () {
        final error = TelnyxError(
          code: 40001,
          name: 'SDP_CREATE_OFFER_FAILED',
          message: 'Failed to create call offer',
          description: 'SDP offer creation failed.',
          causes: ['Browser error'],
          solutions: ['Retry'],
          fatal: true,
        );

        final json = error.toJson();

        expect(json, isNot(contains('originalError')));
      });
    });

    group('implements Exception', () {
      test('can be thrown and caught as Exception', () {
        final error = TelnyxError(
          code: 49001,
          name: 'UNEXPECTED_ERROR',
          message: 'An unexpected error occurred',
          description: 'Catch-all.',
          causes: ['Unknown'],
          solutions: ['Report'],
          fatal: true,
        );

        try {
          throw error;
        } on TelnyxError catch (e) {
          expect(e.code, equals(49001));
        } on Exception {
          fail('Should be caught as TelnyxError before Exception');
        }
      });
    });
  });
}
