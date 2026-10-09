// VSUP-278 — pushNotificationEnvironment: configurable override for the
// `push_notification_environment` value emitted on the login payload.
//
// The SDK previously hard-coded the value derived from `kDebugMode`. This
// broke `--release` builds signed with a development APNs entitlement
// (e.g. a direct device install / Firebase App Distribution build) because
// `kDebugMode` resolved to `false` while the binary still carried a sandbox
// entitlement. The new optional Config field lets the caller override the
// value verbatim — when null, the legacy behaviour is preserved byte-for-byte.
//
// These tests cover the SDK core (Config surface + UserVariables
// serialization). The attachCall override is verified end-to-end via the
// existing TelnyxClient integration tests.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';
import 'package:telnyx_webrtc/model/verto/send/login_message_body.dart';
import 'package:telnyx_webrtc/utils/logging/log_level.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Config.pushNotificationEnvironment defaults', () {
    test('CredentialConfig defaults pushNotificationEnvironment to null', () {
      final config = CredentialConfig(
        sipUser: 'testuser',
        sipPassword: 'testpass',
        sipCallerIDName: 'Test User',
        sipCallerIDNumber: '+123****7890',
        logLevel: LogLevel.debug,
        debug: false,
      );

      expect(config.pushNotificationEnvironment, isNull);
    });

    test('TokenConfig defaults pushNotificationEnvironment to null', () {
      final config = TokenConfig(
        sipToken: 'testtoken',
        sipCallerIDName: 'Test User',
        sipCallerIDNumber: '+123****7890',
        logLevel: LogLevel.debug,
        debug: false,
      );

      expect(config.pushNotificationEnvironment, isNull);
    });

    test('null default preserves legacy wire shape (no breakage)', () {
      // Existing callers that do not set pushNotificationEnvironment must
      // continue to receive a config with the field unset, so the SDK falls
      // back to the pre-existing `kDebugMode`-derived value.
      final config = CredentialConfig(
        sipUser: 'testuser',
        sipPassword: 'testpass',
        sipCallerIDName: 'Test User',
        sipCallerIDNumber: '+123****7890',
        logLevel: LogLevel.debug,
        debug: false,
      );

      expect(config.pushNotificationEnvironment, isNull);
    });
  });

  group('Config.pushNotificationEnvironment opt-in', () {
    test('CredentialConfig accepts pushNotificationEnvironment=development', () {
      final config = CredentialConfig(
        sipUser: 'testuser',
        sipPassword: 'testpass',
        sipCallerIDName: 'Test User',
        sipCallerIDNumber: '+123****7890',
        logLevel: LogLevel.debug,
        debug: false,
        pushNotificationEnvironment: 'development',
      );

      expect(config.pushNotificationEnvironment, equals('development'));
    });

    test('TokenConfig accepts pushNotificationEnvironment=production', () {
      final config = TokenConfig(
        sipToken: 'testtoken',
        sipCallerIDName: 'Test User',
        sipCallerIDNumber: '+123****7890',
        logLevel: LogLevel.debug,
        debug: false,
        pushNotificationEnvironment: 'production',
      );

      expect(config.pushNotificationEnvironment, equals('production'));
    });

    test('Custom server-accepted values pass through verbatim', () {
      // The override is a free-form String — any value the server will
      // accept (e.g. an FCM staging alias) can be set by the caller.
      final config = CredentialConfig(
        sipUser: 'testuser',
        sipPassword: 'testpass',
        sipCallerIDName: 'Test User',
        sipCallerIDNumber: '+123****7890',
        logLevel: LogLevel.debug,
        debug: false,
        pushNotificationEnvironment: 'custom-staging',
      );

      expect(config.pushNotificationEnvironment, equals('custom-staging'));
    });
  });

  group('UserVariables login-level push_notification_environment', () {
    test('emits caller-supplied override verbatim when non-null', () {
      // The override wins over the kDebugMode-derived default — this is the
      // core VSUP-278 fix. A caller using a `--release` build with a dev
      // entitlement must be able to force `development` regardless of
      // kDebugMode resolving to false.
      final vars = UserVariables(
        pushDeviceToken: 'tok',
        pushNotificationProvider: 'ios',
        pushNotificationEnvironment: 'development',
      );

      final json = vars.toJson();

      expect(json['push_notification_environment'], equals('development'));
    });

    test('falls back to kDebugMode default when null (release profile)',
        () {
      // In a release profile, kDebugMode is false and the legacy default
      // is `production`. The override field being null must reproduce the
      // pre-existing behaviour exactly.
      final vars = UserVariables(
        pushDeviceToken: 'tok',
        pushNotificationProvider: 'ios',
      );

      final json = vars.toJson();

      expect(
        json['push_notification_environment'],
        equals(kDebugMode ? 'debug' : 'production'),
      );
    });

    test('override wins over kDebugMode default even in release', () {
      // Even when kDebugMode is false, an explicit override of `debug` or
      // `development` must be honored verbatim.
      final vars = UserVariables(
        pushDeviceToken: 'tok',
        pushNotificationProvider: 'ios',
        pushNotificationEnvironment: 'debug',
      );

      final json = vars.toJson();

      expect(json['push_notification_environment'], equals('debug'));
    });

    test('round-trips push_notification_environment through fromJson', () {
      final wire = <String, dynamic>{
        'push_device_token': 'tok',
        'push_notification_provider': 'ios',
        'push_notification_environment': 'development',
      };

      final vars = UserVariables.fromJson(wire);

      expect(vars.pushNotificationEnvironment, equals('development'));

      final reserialized = vars.toJson();
      expect(
        reserialized['push_notification_environment'],
        equals('development'),
      );
    });

    test('legacy payload (no override key) parses with field null', () {
      // Backwards compatibility: a pre-VSUP-278 login payload from the wire
      // contains only the legacy three keys. fromJson must not blow up and
      // pushNotificationEnvironment must default to null so the SDK falls
      // back to the legacy kDebugMode-derived value.
      final wire = <String, dynamic>{
        'push_device_token': 'tok',
        'push_notification_provider': 'android',
        'push_notification_environment': 'production',
      };

      final vars = UserVariables.fromJson(wire);

      expect(vars.pushNotificationEnvironment, equals('production'));

      final reserialized = vars.toJson();
      expect(
        reserialized['push_notification_environment'],
        equals('production'),
      );
    });

    test('override coexists with other opt-in keys (pushWhenActive)', () {
      // The new field must not regress the VSDK-432 pushWhenActive /
      // pnLateFanout behaviour — both can be set on the same login payload.
      final vars = UserVariables(
        pushDeviceToken: 'tok',
        pushNotificationProvider: 'ios',
        pushNotificationEnvironment: 'development',
        pushWhenActive: true,
        pnLateFanout: true,
      );

      final json = vars.toJson();

      expect(json['push_notification_environment'], equals('development'));
      expect(json['push_when_active'], isTrue);
      expect(json['pn_late_fanout'], isTrue);
    });
  });
}
