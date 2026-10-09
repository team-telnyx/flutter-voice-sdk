import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';
import 'package:telnyx_webrtc/model/errors/telnyx_error_codes.dart';
import 'package:telnyx_webrtc/model/errors/telnyx_error_event.dart';
import 'package:telnyx_webrtc/peer/peer.dart';
import 'package:telnyx_webrtc/telnyx_client.dart';
import 'package:telnyx_webrtc/tx_socket.dart';
import 'package:telnyx_webrtc/utils/logging/log_level.dart';

class _FakeMediaStream extends Fake implements MediaStream {}

CredentialConfig _config({
  bool recoveryEnabled = true,
  int timeout = 25000,
  void Function()? onSuccess,
  void Function(Object error)? onError,
  bool enableStructuredErrors = true,
}) {
  return CredentialConfig(
    sipUser: 'user',
    sipPassword: 'pass',
    sipCallerIDName: 'name',
    sipCallerIDNumber: 'number',
    logLevel: LogLevel.none,
    debug: false,
    enableStructuredErrors: enableStructuredErrors,
    enableSignalingHealthMonitor: false,
    mediaPermissionsRecovery: MediaPermissionsRecoveryConfig(
      enabled: recoveryEnabled,
      timeout: timeout,
      onSuccess: onSuccess,
      onError: onError,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TelnyxClient client;
  late Peer peer;
  late List<Object> capturedErrors;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    capturedErrors = <Object>[];
    client = TelnyxClient(connectivityChanges: () => const Stream.empty())
      ..onTelnyxError = capturedErrors.add;
    peer = Peer(TxSocket('wss://example.test'), false, client, false, false);
  });

  tearDown(() => client.dispose());

  PlatformException permissionError() =>
      PlatformException(code: 'NotAllowedError', message: 'permission denied');

  group('VSDK-417: Media permission recovery in Peer.createStream', () {
    test(
        'recovery enabled + isAnswer=true emits recoverable '
        'TelnyxMediaRecoveryErrorEvent on getUserMedia failure', () async {
      client.applyStructuredConfigForTest(_config());
      peer.getUserMediaOverride = (_) async => throw permissionError();

      final future = peer.createStream('audio', isAnswer: true, callId: 'c1');
      // Swallow the eventual failure — we assert on the emitted event.
      unawaited(future.catchError((_) => _FakeMediaStream()));
      await pumpEventQueue();

      expect(capturedErrors, hasLength(1));
      final event = capturedErrors.single;
      expect(event, isA<TelnyxMediaRecoveryErrorEvent>());
      final recovery = event as TelnyxMediaRecoveryErrorEvent;
      expect(recovery.recoverable, isTrue);
      expect(recovery.callId, 'c1');
      expect(
        recovery.error.code,
        TelnyxErrorCodes.mediaMicrophonePermissionDenied,
      );
      expect(
        recovery.error.fatal,
        isFalse,
        reason: 'recovery active => non-fatal override',
      );
      expect(
        recovery.retryDeadline,
        greaterThan(DateTime.now().millisecondsSinceEpoch),
      );

      await recovery.reject();
      await expectLater(future, throwsA(anything));
    });

    test('resume() retries getUserMedia, returns stream, invokes onSuccess',
        () async {
      var successCalls = 0;
      client.applyStructuredConfigForTest(
        _config(onSuccess: () => successCalls++),
      );
      final fakeStream = _FakeMediaStream();
      var attempts = 0;
      peer.getUserMediaOverride = (_) async {
        attempts++;
        if (attempts == 1) throw permissionError();
        return fakeStream;
      };

      final future = peer.createStream('audio', isAnswer: true, callId: 'c1');
      await pumpEventQueue();
      final recovery = capturedErrors.single as TelnyxMediaRecoveryErrorEvent;

      await recovery.resume();
      final stream = await future;

      expect(stream, same(fakeStream));
      expect(successCalls, 1);
      expect(attempts, 2);
    });

    test('reject() invokes onError exactly once and propagates failure',
        () async {
      final errors = <Object>[];
      client.applyStructuredConfigForTest(_config(onError: errors.add));
      peer.getUserMediaOverride = (_) async => throw permissionError();

      final future = peer.createStream('audio', isAnswer: true, callId: 'c1');
      unawaited(future.catchError((_) => _FakeMediaStream()));
      await pumpEventQueue();
      final recovery = capturedErrors.single as TelnyxMediaRecoveryErrorEvent;

      await recovery.reject();
      await expectLater(future, throwsA(anything));
      expect(errors, hasLength(1));
    });

    test('timeout invokes onError once and propagates failure', () async {
      final errors = <Object>[];
      client.applyStructuredConfigForTest(
        _config(timeout: 40, onError: errors.add),
      );
      peer.getUserMediaOverride = (_) async => throw permissionError();

      final future = peer.createStream('audio', isAnswer: true, callId: 'c1');

      await expectLater(future, throwsA(anything));
      expect(errors, hasLength(1));
    });

    test('retry failure after resume invokes onError once and rethrows',
        () async {
      final errors = <Object>[];
      client.applyStructuredConfigForTest(_config(onError: errors.add));
      peer.getUserMediaOverride = (_) async => throw permissionError();

      final future = peer.createStream('audio', isAnswer: true, callId: 'c1');
      unawaited(future.catchError((_) => _FakeMediaStream()));
      await pumpEventQueue();
      final recovery = capturedErrors.single as TelnyxMediaRecoveryErrorEvent;

      await recovery.resume(); // retry still throws
      await expectLater(future, throwsA(anything));
      expect(errors, hasLength(1));
    });

    test('recovery disabled emits standard structured error, no recoverable',
        () async {
      client.applyStructuredConfigForTest(_config(recoveryEnabled: false));
      peer.getUserMediaOverride = (_) async => throw permissionError();

      await expectLater(
        peer.createStream('audio', isAnswer: true, callId: 'c1'),
        throwsA(anything),
      );

      expect(capturedErrors, hasLength(1));
      final event = capturedErrors.single;
      expect(event, isA<TelnyxErrorEvent>());
      expect((event as TelnyxErrorEvent).recoverable, isFalse);
      expect(
        event.error.code,
        TelnyxErrorCodes.mediaMicrophonePermissionDenied,
      );
    });

    test('recovery enabled but outbound (isAnswer=false) is not recoverable',
        () async {
      client.applyStructuredConfigForTest(_config());
      peer.getUserMediaOverride = (_) async => throw permissionError();

      await expectLater(
        peer.createStream('audio', isAnswer: false, callId: 'c1'),
        throwsA(anything),
      );

      expect(capturedErrors, hasLength(1));
      expect(capturedErrors.single, isA<TelnyxErrorEvent>());
    });

    test('successful getUserMedia does not trigger recovery', () async {
      client.applyStructuredConfigForTest(_config());
      final fakeStream = _FakeMediaStream();
      peer.getUserMediaOverride = (_) async => fakeStream;

      final stream =
          await peer.createStream('audio', isAnswer: true, callId: 'c1');

      expect(stream, same(fakeStream));
      expect(capturedErrors, isEmpty);
    });

    test('feature flag disabled suppresses structured error emission',
        () async {
      client.applyStructuredConfigForTest(
        _config(recoveryEnabled: false, enableStructuredErrors: false),
      );
      peer.getUserMediaOverride = (_) async => throw permissionError();

      await expectLater(
        peer.createStream('audio', isAnswer: true, callId: 'c1'),
        throwsA(anything),
      );

      expect(capturedErrors, isEmpty);
    });
  });
}
