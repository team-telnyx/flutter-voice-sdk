import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_flutter_webrtc/utils/media_recovery_helper.dart';
import 'package:telnyx_webrtc/model/errors/telnyx_error_codes.dart';
import 'package:telnyx_webrtc/model/errors/telnyx_error_event.dart';
import 'package:telnyx_webrtc/model/errors/telnyx_error_factory.dart';

TelnyxMediaRecoveryErrorEvent _event({
  required void Function() onResume,
  required void Function() onReject,
}) => TelnyxMediaRecoveryErrorEvent(
  error: createTelnyxError(TelnyxErrorCodes.mediaMicrophonePermissionDenied),
  sessionId: 'sess',
  callId: 'call-1',
  retryDeadline: 0,
  resume: () async => onResume(),
  reject: () async => onReject(),
);

void main() {
  group('VSDK-417 demo media recovery decision', () {
    test('permission granted → resume() called, reject() not', () async {
      var resumed = false, rejected = false;
      final event = _event(
        onResume: () => resumed = true,
        onReject: () => rejected = true,
      );

      await resolveMediaRecovery(event, requestMicPermission: () async => true);

      expect(resumed, isTrue);
      expect(rejected, isFalse);
    });

    test('permission denied → reject() called, resume() not', () async {
      var resumed = false, rejected = false;
      final event = _event(
        onResume: () => resumed = true,
        onReject: () => rejected = true,
      );

      await resolveMediaRecovery(
        event,
        requestMicPermission: () async => false,
      );

      expect(resumed, isFalse);
      expect(rejected, isTrue);
    });

    test('requester throws → fail-safe reject() called', () async {
      var resumed = false, rejected = false;
      final event = _event(
        onResume: () => resumed = true,
        onReject: () => rejected = true,
      );

      await resolveMediaRecovery(
        event,
        requestMicPermission: () async => throw StateError('boom'),
      );

      expect(resumed, isFalse);
      expect(rejected, isTrue);
    });
  });
}
