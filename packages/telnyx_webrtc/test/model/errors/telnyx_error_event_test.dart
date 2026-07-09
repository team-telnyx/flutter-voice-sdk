import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/model/errors/telnyx_error_event.dart';
import 'package:telnyx_webrtc/model/errors/telnyx_error.dart';

void main() {
  group('VSDK-396: TelnyxErrorEvent', () {
    final baseError = TelnyxError(
      code: 45002,
      name: 'WEBSOCKET_ERROR',
      message: 'Connection to server lost',
      description: 'WebSocket error after establishment.',
      causes: ['Network interruption'],
      solutions: ['Check network'],
      fatal: false,
    );

    test('constructs with error, sessionId, and optional callId', () {
      final event = TelnyxErrorEvent(
        error: baseError,
        sessionId: 'session-123',
      );

      expect(event.error, same(baseError));
      expect(event.sessionId, equals('session-123'));
      expect(event.callId, isNull);
    });

    test('callId can be provided', () {
      final event = TelnyxErrorEvent(
        error: baseError,
        sessionId: 'session-123',
        callId: 'call-456',
      );

      expect(event.callId, equals('call-456'));
    });

    test('recoverable is always false for standard error events', () {
      final event = TelnyxErrorEvent(
        error: baseError,
        sessionId: 'session-123',
      );

      expect(event.recoverable, isFalse);
    });
  });

  group('VSDK-396: TelnyxMediaRecoveryErrorEvent', () {
    final mediaError = TelnyxError(
      code: 42001,
      name: 'MEDIA_MICROPHONE_PERMISSION_DENIED',
      message: 'Microphone access denied',
      description: 'Mic permission denied.',
      causes: ['User denied permission'],
      solutions: ['Grant permission'],
      fatal: false,
    );

    test(
        'constructs with error, sessionId, callId, retryDeadline, resume, reject',
        () {
      final event = TelnyxMediaRecoveryErrorEvent(
        error: mediaError,
        sessionId: 'session-789',
        callId: 'call-012',
        retryDeadline: DateTime.now().millisecondsSinceEpoch + 25000,
        resume: () async {},
        reject: () async {},
      );

      expect(event.error, same(mediaError));
      expect(event.sessionId, equals('session-789'));
      expect(event.callId, equals('call-012'));
      expect(
        event.retryDeadline,
        greaterThan(DateTime.now().millisecondsSinceEpoch),
      );
      expect(event.recoverable, isTrue);
    });

    test('resume callback can be invoked', () async {
      var resumed = false;

      final event = TelnyxMediaRecoveryErrorEvent(
        error: mediaError,
        sessionId: 'session-1',
        callId: 'call-1',
        retryDeadline: DateTime.now().millisecondsSinceEpoch + 25000,
        resume: () async {
          resumed = true;
        },
        reject: () async {},
      );

      await event.resume();
      expect(resumed, isTrue);
    });

    test('reject callback can be invoked', () async {
      var rejected = false;

      final event = TelnyxMediaRecoveryErrorEvent(
        error: mediaError,
        sessionId: 'session-1',
        callId: 'call-1',
        retryDeadline: DateTime.now().millisecondsSinceEpoch + 25000,
        resume: () async {},
        reject: () async {
          rejected = true;
        },
      );

      await event.reject();
      expect(rejected, isTrue);
    });

    test('callId is required (not optional) for media recovery events', () {
      // callId is a required String, not optional — this is a compile-time
      // guarantee. We verify the field is present and non-null at runtime.
      final event = TelnyxMediaRecoveryErrorEvent(
        error: mediaError,
        sessionId: 'session-1',
        callId: 'call-required',
        retryDeadline: DateTime.now().millisecondsSinceEpoch + 25000,
        resume: () async {},
        reject: () async {},
      );

      expect(event.callId, isNotNull);
      expect(event.callId, equals('call-required'));
    });
  });

  group('VSDK-396: isMediaRecoveryErrorEvent type guard', () {
    test('returns true for TelnyxMediaRecoveryErrorEvent', () {
      final event = TelnyxMediaRecoveryErrorEvent(
        error: TelnyxError(
          code: 42001,
          name: 'MEDIA_MICROPHONE_PERMISSION_DENIED',
          message: 'Mic denied',
          description: 'desc',
          causes: [],
          solutions: [],
          fatal: false,
        ),
        sessionId: 's1',
        callId: 'c1',
        retryDeadline: 0,
        resume: () async {},
        reject: () async {},
      );

      expect(isMediaRecoveryErrorEvent(event), isTrue);
    });

    test('returns false for TelnyxErrorEvent', () {
      final event = TelnyxErrorEvent(
        error: TelnyxError(
          code: 45002,
          name: 'WEBSOCKET_ERROR',
          message: 'Connection lost',
          description: 'desc',
          causes: [],
          solutions: [],
          fatal: false,
        ),
        sessionId: 's1',
      );

      expect(isMediaRecoveryErrorEvent(event), isFalse);
    });

    test('returns false for arbitrary objects', () {
      expect(isMediaRecoveryErrorEvent('not an event'), isFalse);
      expect(isMediaRecoveryErrorEvent(42), isFalse);
      expect(isMediaRecoveryErrorEvent(null), isFalse);
    });
  });
}
