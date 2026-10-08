// VSDK-432 — pushWhenActive: tests for the Config field that drives
// automatic `answered_device_token` population on answer payloads.
//
// These tests cover the SDK core (Config surface + InviteAnswerMessageBody
// serialization). The end-to-end TelnyxClient.acceptCall auto-population path
// is exercised via the existing integration suites; this file focuses on the
// small, fast-to-run contract that gates regressions.
import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';
import 'package:telnyx_webrtc/model/verto/send/invite_answer_message_body.dart';
import 'package:telnyx_webrtc/model/verto/send/login_message_body.dart';
import 'package:telnyx_webrtc/utils/logging/log_level.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Config.pushWhenActive defaults', () {
    test('CredentialConfig defaults pushWhenActive to false', () {
      final config = CredentialConfig(
        sipUser: 'testuser',
        sipPassword: 'testpass',
        sipCallerIDName: 'Test User',
        sipCallerIDNumber: '+1234567890',
        logLevel: LogLevel.debug,
        debug: false,
      );

      expect(config.pushWhenActive, isFalse);
    });

    test('TokenConfig defaults pushWhenActive to false', () {
      final config = TokenConfig(
        sipToken: 'testtoken',
        sipCallerIDName: 'Test User',
        sipCallerIDNumber: '+1234567890',
        logLevel: LogLevel.debug,
        debug: false,
      );

      expect(config.pushWhenActive, isFalse);
    });

    test('Config base type defaults pushWhenActive to false', () {
      // Direct Config construction is not allowed (the SDK exposes
      // CredentialConfig / TokenConfig as the user-facing surface), but the
      // base default must remain false so older callers who do not opt in see
      // no behavior change. Verified via subclass default behavior above.
      final config = TokenConfig(
        sipToken: 'testtoken',
        sipCallerIDName: 'Test User',
        sipCallerIDNumber: '+1234567890',
        logLevel: LogLevel.none,
        debug: false,
      );
      expect(config.pushWhenActive, isFalse);
    });
  });

  group('Config.pushWhenActive opt-in', () {
    test('CredentialConfig accepts pushWhenActive=true', () {
      final config = CredentialConfig(
        sipUser: 'testuser',
        sipPassword: 'testpass',
        sipCallerIDName: 'Test User',
        sipCallerIDNumber: '+1234567890',
        logLevel: LogLevel.debug,
        debug: false,
        notificationToken: 'push-token-123',
        pushWhenActive: true,
      );

      expect(config.pushWhenActive, isTrue);
      expect(config.notificationToken, equals('push-token-123'));
    });

    test('TokenConfig accepts pushWhenActive=true', () {
      final config = TokenConfig(
        sipToken: 'testtoken',
        sipCallerIDName: 'Test User',
        sipCallerIDNumber: '+1234567890',
        logLevel: LogLevel.debug,
        debug: false,
        notificationToken: 'push-token-456',
        pushWhenActive: true,
      );

      expect(config.pushWhenActive, isTrue);
      expect(config.notificationToken, equals('push-token-456'));
    });

    test('pushWhenActive=false preserves existing config shape (no breakage)',
        () {
      // The flag must be additive: existing callers who pass neither
      // pushWhenActive nor notificationToken should produce a config
      // indistinguishable from the pre-flag shape.
      final config = CredentialConfig(
        sipUser: 'testuser',
        sipPassword: 'testpass',
        sipCallerIDName: 'Test User',
        sipCallerIDNumber: '+1234567890',
        logLevel: LogLevel.debug,
        debug: false,
      );

      expect(config.pushWhenActive, isFalse);
      expect(config.notificationToken, isNull);
    });
  });

  group('InviteAnswerMessageBody.answeredDeviceToken serialization', () {
    // The wire field name MUST remain `answered_device_token` (snake_case)
    // regardless of what the Dart field name is. The backend matches on the
    // wire field name; renaming the JSON key is a breaking change.
    test('omits answered_device_token when null', () {
      final params = InviteParams(
        sdp: 'v=0\r\n',
        sessid: 'sess-1',
      );

      final json = params.toJson();

      expect(json.containsKey('answered_device_token'), isFalse);
    });

    test('omits answered_device_token when empty string', () {
      final params = InviteParams(
        sdp: 'v=0\r\n',
        sessid: 'sess-1',
        answeredDeviceToken: '',
      );

      final json = params.toJson();

      expect(json.containsKey('answered_device_token'), isFalse);
    });

    test('includes answered_device_token when set', () {
      final params = InviteParams(
        sdp: 'v=0\r\n',
        sessid: 'sess-1',
        answeredDeviceToken: 'push-token-abc',
      );

      final json = params.toJson();

      expect(json['answered_device_token'], equals('push-token-abc'));
    });

    test('round-trips answered_device_token through fromJson', () {
      final wire = {
        'sdp': 'v=0\r\n',
        'sessid': 'sess-1',
        'answered_device_token': 'push-token-abc',
      };

      final params = InviteParams.fromJson(wire);

      expect(params.answeredDeviceToken, equals('push-token-abc'));

      final reserialized = params.toJson();
      expect(reserialized['answered_device_token'], equals('push-token-abc'));
    });

    test('InviteAnswerMessage wraps the params with the method name', () {
      final message = InviteAnswerMessage(
        id: '1',
        jsonrpc: '2.0',
        method: 'telnyx_rtc.answer',
        params: InviteParams(
          sdp: 'v=0\r\n',
          sessid: 'sess-1',
          answeredDeviceToken: 'push-token-abc',
        ),
      );

      final json = message.toJson();

      expect(json['method'], equals('telnyx_rtc.answer'));
      expect(
        (json['params'] as Map<String, dynamic>)['answered_device_token'],
        equals('push-token-abc'),
      );
    });
  });

  group('InviteAnswerMessageBody.answeredDeviceToken whitespace handling', () {
    // The resolver/serializer MUST trim the value before deciding whether to
    // emit `answered_device_token`. A whitespace-only token would otherwise be
    // shipped on the wire as `"   "`, which the backend treats as valid and
    // forwards to the callee. Reviewer feedback: the trim guard must live on
    // the serializer side (not just at the acceptCall fallback) so any caller
    // path that constructs `InviteParams` with a stray blank token cannot
    // leak the value onto the wire.
    test('omits answered_device_token when single space', () {
      final params = InviteParams(
        sdp: 'v=0\r\n',
        sessid: 'sess-1',
        answeredDeviceToken: ' ',
      );

      final json = params.toJson();

      expect(json.containsKey('answered_device_token'), isFalse);
    });

    test('omits answered_device_token when only whitespace (tabs/newlines)', () {
      final params = InviteParams(
        sdp: 'v=0\r\n',
        sessid: 'sess-1',
        answeredDeviceToken: '\t \n',
      );

      final json = params.toJson();

      expect(json.containsKey('answered_device_token'), isFalse);
    });

    test('emits answered_device_token when value has surrounding whitespace '
        'but non-blank content', () {
      // A token like " abc " is unusual but conceptually non-blank — we
      // serialize the raw value rather than silently mutating it. The trim
      // guard is for the *gate* (whether to emit), not for reformatting the
      // payload. This matches the contract used by the Android/iOS SDKs.
      final params = InviteParams(
        sdp: 'v=0\r\n',
        sessid: 'sess-1',
        answeredDeviceToken: ' abc ',
      );

      final json = params.toJson();

      expect(json['answered_device_token'], equals(' abc '));
    });
  });

  group('UserVariables login-level opt-in keys', () {
    // Reviewer feedback: ensure `push_when_active` / `pn_late_fanout` keys
    // are emitted on the login payload ONLY when the caller has explicitly
    // opted in. Existing apps that never set these flags must continue to
    // produce a wire payload with only `push_device_token`,
    // `push_notification_provider`, and `push_notification_environment`.
    test('omits push_when_active when null', () {
      final vars = UserVariables(
        pushDeviceToken: 'tok',
        pushNotificationProvider: 'android',
      );

      final json = vars.toJson();

      expect(json.containsKey('push_when_active'), isFalse);
    });

    test('omits pn_late_fanout when null', () {
      final vars = UserVariables(
        pushDeviceToken: 'tok',
        pushNotificationProvider: 'android',
      );

      final json = vars.toJson();

      expect(json.containsKey('pn_late_fanout'), isFalse);
    });

    test('emits push_when_active when true', () {
      final vars = UserVariables(
        pushDeviceToken: 'tok',
        pushNotificationProvider: 'ios',
        pushWhenActive: true,
      );

      final json = vars.toJson();

      expect(json['push_when_active'], isTrue);
    });

    test('emits push_when_active when explicitly false (caller opted in)', () {
      // Even an explicit `false` is a deliberate choice and must round-trip;
      // a caller using pushWhenActive: false is asserting "no, do not enable
      // late fan-out". Omitting the key would be ambiguous.
      final vars = UserVariables(
        pushDeviceToken: 'tok',
        pushNotificationProvider: 'ios',
        pushWhenActive: false,
      );

      final json = vars.toJson();

      expect(json['push_when_active'], isFalse);
    });

    test('round-trips push_when_active through fromJson', () {
      final wire = {
        'push_device_token': 'tok',
        'push_notification_provider': 'ios',
        'push_when_active': true,
        'pn_late_fanout': true,
      };

      final vars = UserVariables.fromJson(wire);

      expect(vars.pushWhenActive, isTrue);
      expect(vars.pnLateFanout, isTrue);

      final reserialized = vars.toJson();
      expect(reserialized['push_when_active'], isTrue);
      expect(reserialized['pn_late_fanout'], isTrue);
    });

    test('legacy payload (no opt-in keys) deserializes cleanly', () {
      // Backwards compatibility: a pre-feature login payload from the wire
      // contains only the legacy three keys. fromJson must not blow up and
      // pushWhenActive / pnLateFanout must default to null (=> no emit).
      final wire = {
        'push_device_token': 'tok',
        'push_notification_provider': 'android',
        'push_notification_environment': 'production',
      };

      final vars = UserVariables.fromJson(wire);

      expect(vars.pushWhenActive, isNull);
      expect(vars.pnLateFanout, isNull);

      final reserialized = vars.toJson();
      expect(reserialized.containsKey('push_when_active'), isFalse);
      expect(reserialized.containsKey('pn_late_fanout'), isFalse);
    });
  });
}
