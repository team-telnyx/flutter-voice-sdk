import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';
import 'package:telnyx_webrtc/model/errors/telnyx_warning_codes.dart';
import 'package:telnyx_webrtc/model/errors/telnyx_warning_event.dart';
import 'package:telnyx_webrtc/telnyx_client.dart';
import 'package:telnyx_webrtc/tx_socket.dart';
import 'package:telnyx_webrtc/utils/logging/log_level.dart';

class _FakeTxSocket extends TxSocket {
  _FakeTxSocket() : super('wss://example.test');

  @override
  void connect() {}

  @override
  void close() {}

  @override
  void send(dynamic data) {}

  void emitMessage(dynamic data) => onMessage(data);

  void emitClose(int code, String reason) => onClose(code, reason);
}

TokenConfig _tokenConfig({
  required String token,
  bool autoReconnect = true,
}) =>
    TokenConfig(
      sipToken: token,
      sipCallerIDName: 'name',
      sipCallerIDNumber: 'number',
      logLevel: LogLevel.none,
      debug: false,
      autoReconnect: autoReconnect,
    );

CredentialConfig _credentialConfig({bool autoReconnect = true}) =>
    CredentialConfig(
      sipUser: 'user',
      sipPassword: 'pass',
      sipCallerIDName: 'name',
      sipCallerIDNumber: 'number',
      logLevel: LogLevel.none,
      debug: false,
      autoReconnect: autoReconnect,
    );

/// Build a mock JWT with a given [expEpoch] (Unix seconds).
String _mockJwt({required int expEpoch}) {
  final header = base64Url.encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'));
  final payload = base64Url.encode(utf8.encode('{"exp":$expEpoch}'));
  final signature = base64Url.encode(utf8.encode('sig'));
  return '${header.replaceAll('=', '')}.'
      '${payload.replaceAll('=', '')}.'
      '${signature.replaceAll('=', '')}';
}

/// Emit a socket message inside a guarded zone so async WebRTC plugin errors
/// (MissingPluginException) don't fail the test. The warning we care about
/// is emitted synchronously before the async acceptCall path runs.
void _emitGuarded(_FakeTxSocket socket, String json) {
  runZonedGuarded(() {
    socket.emitMessage(json);
  }, (error, stack) {
    // Swallow MissingPluginException from flutter_webrtc not being
    // available in the test environment.
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TelnyxClient client;
  late _FakeTxSocket socket;
  late List<TelnyxWarningEvent> warnings;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    socket = _FakeTxSocket();
    warnings = <TelnyxWarningEvent>[];
    client = TelnyxClient(connectivityChanges: () => const Stream.empty())
      ..txSocket = socket
      ..onTelnyxWarning = warnings.add;
  });

  tearDown(() => client.dispose());

  group('VSDK-397: TOKEN_EXPIRING_SOON (34001)', () {
    test(
      'emits immediately when token expires within 120 s '
      '(deterministic, no timer needed)',
      () {
        // Token expiring in 60 seconds — well within the 120 s warning window.
        final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final jwt = _mockJwt(expEpoch: nowSec + 60);

        client
          ..applyStructuredConfigForTest(_tokenConfig(token: jwt))
          ..tokenLogin(_tokenConfig(token: jwt));

        // The warning should fire synchronously through _checkTokenExpiry →
        // _emitTokenExpiryWarning → emitWarningCode → onTelnyxWarning.
        expect(warnings, hasLength(1));
        expect(
          warnings.single.warning.code,
          TelnyxWarningCodes.tokenExpiringSoon,
        );
        expect(warnings.single.source, 'auth');
      },
    );

    test('does NOT emit when token is not a JWT (plain string)', () {
      client
        ..applyStructuredConfigForTest(_tokenConfig(token: 'not-a-jwt-token'))
        ..tokenLogin(_tokenConfig(token: 'not-a-jwt-token'));

      expect(
        warnings,
        isEmpty,
        reason: 'non-JWT tokens should be skipped silently',
      );
    });

    test('does NOT emit when token is already expired', () {
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final jwt = _mockJwt(expEpoch: nowSec - 10); // expired 10s ago

      client
        ..applyStructuredConfigForTest(_tokenConfig(token: jwt))
        ..tokenLogin(_tokenConfig(token: jwt));

      expect(
        warnings,
        isEmpty,
        reason: 'already-expired tokens skip the warning; '
            'the login error handler will fire instead',
      );
    });
  });

  group('VSDK-397: RECONNECTION_FAILED_WITH_NO_AUTO_RECONNECT (36005)', () {
    test(
      'emits on abrupt close when autoReconnect is disabled and no '
      'explicit disconnect is in progress',
      () async {
        // Use credential config with autoReconnect: false.
        client
          ..applyStructuredConfigForTest(
            _credentialConfig(autoReconnect: false),
          )
          ..connectWithCredential(_credentialConfig(autoReconnect: false));
        await pumpEventQueue();

        // Simulate an abrupt (non-clean) socket close.
        socket.emitClose(1006, 'abnormal closure');

        final reconnectionWarnings = warnings
            .where(
              (w) =>
                  w.warning.code ==
                  TelnyxWarningCodes.reconnectionFailedWithNoAutoReconnect,
            )
            .toList();
        expect(reconnectionWarnings, hasLength(1));
        expect(reconnectionWarnings.single.source, 'socket_close');
        expect(reconnectionWarnings.single.reason, 'auto_reconnect_disabled');
      },
    );

    test('does NOT emit on abrupt close when autoReconnect is enabled',
        () async {
      client
        ..applyStructuredConfigForTest(_credentialConfig())
        ..connectWithCredential(_credentialConfig());
      await pumpEventQueue();

      socket.emitClose(1006, 'abnormal closure');

      final reconnectionWarnings = warnings
          .where(
            (w) =>
                w.warning.code ==
                TelnyxWarningCodes.reconnectionFailedWithNoAutoReconnect,
          )
          .toList();
      expect(
        reconnectionWarnings,
        isEmpty,
        reason: 'auto-reconnect enabled means the SDK will retry; '
            'no "failed with no auto-reconnect" warning',
      );
    });

    test('does NOT emit on clean close', () async {
      client
        ..applyStructuredConfigForTest(
          _credentialConfig(autoReconnect: false),
        )
        ..connectWithCredential(_credentialConfig(autoReconnect: false));
      await pumpEventQueue();

      // Clean close — wasClean=true in _onClose.
      socket.emitClose(1000, 'normal closure');

      final reconnectionWarnings = warnings
          .where(
            (w) =>
                w.warning.code ==
                TelnyxWarningCodes.reconnectionFailedWithNoAutoReconnect,
          )
          .toList();
      expect(
        reconnectionWarnings,
        isEmpty,
        reason: 'clean close should not trigger reconnection-failed warning',
      );
    });
  });

  group('VSDK-397: UNKNOWN_REATTACHED_SESSION (35002)', () {
    test(
      'emits when Attach arrives with a callID not in active calls '
      'and calls map is non-empty',
      () async {
        client
          ..applyStructuredConfigForTest(_credentialConfig())
          ..connectWithCredential(_credentialConfig());
        await pumpEventQueue();

        // Simulate that we have one active call with a different callID.
        final activeCall = client.call..callId = 'existing-call-id';
        client.calls['existing-call-id'] = activeCall;

        // Emit an Attach message with a *different* callID.
        // The warning is emitted synchronously before the async acceptCall
        // path, so it's in the warnings list even though acceptCall will fail.
        _emitGuarded(
          socket,
          '{"jsonrpc":"2.0","id":"1","method":"telnyx_rtc.attach",'
          '"params":{"callID":"unknown-call-id",'
          '"caller_id_name":"test","caller_id_number":"100",'
          '"sdp":"v=0\\r\\n"}}',
        );
        await pumpEventQueue();

        final unknownAttachWarnings = warnings
            .where(
              (w) =>
                  w.warning.code == TelnyxWarningCodes.unknownReattachedSession,
            )
            .toList();
        expect(
          unknownAttachWarnings,
          hasLength(1),
          reason: 'Attach with unknown callID while calls exist '
              'should emit UNKNOWN_REATTACHED_SESSION',
        );
        expect(unknownAttachWarnings.single.callId, 'unknown-call-id');
        expect(unknownAttachWarnings.single.source, 'attach');
        // The reason should include the active call count (AFK review N3).
        expect(unknownAttachWarnings.single.reason, contains('1 active'));
      },
    );

    test(
      'does NOT emit when Attach callID matches an existing active call',
      () async {
        client
          ..applyStructuredConfigForTest(_credentialConfig())
          ..connectWithCredential(_credentialConfig());
        await pumpEventQueue();

        final activeCall = client.call..callId = 'matching-call-id';
        client.calls['matching-call-id'] = activeCall;

        _emitGuarded(
          socket,
          '{"jsonrpc":"2.0","id":"1","method":"telnyx_rtc.attach",'
          '"params":{"callID":"matching-call-id",'
          '"caller_id_name":"test","caller_id_number":"100",'
          '"sdp":"v=0\\r\\n"}}',
        );
        await pumpEventQueue();

        final unknownAttachWarnings = warnings
            .where(
              (w) =>
                  w.warning.code == TelnyxWarningCodes.unknownReattachedSession,
            )
            .toList();
        expect(
          unknownAttachWarnings,
          isEmpty,
          reason: 'Attach matching an existing call should NOT emit warning',
        );
      },
    );

    test('does NOT emit when calls map is empty (first call)', () async {
      client
        ..applyStructuredConfigForTest(_credentialConfig())
        ..connectWithCredential(_credentialConfig());
      await pumpEventQueue();

      // No existing calls — this is the first Attach.
      _emitGuarded(
        socket,
        '{"jsonrpc":"2.0","id":"1","method":"telnyx_rtc.attach",'
        '"params":{"callID":"first-call-id",'
        '"caller_id_name":"test","caller_id_number":"100",'
        '"sdp":"v=0\\r\\n"}}',
      );
      await pumpEventQueue();

      final unknownAttachWarnings = warnings
          .where(
            (w) =>
                w.warning.code == TelnyxWarningCodes.unknownReattachedSession,
          )
          .toList();
      expect(
        unknownAttachWarnings,
        isEmpty,
        reason: 'Attach with empty calls map is normal (first call), '
            'should NOT emit warning',
      );
    });
  });
}
