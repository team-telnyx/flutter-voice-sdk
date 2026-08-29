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
}
