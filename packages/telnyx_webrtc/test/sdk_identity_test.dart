// VSDK-769 — Flutter SDK: emit mobile SDK identity and allow wrapper override.
//
// Verifies the SDK identity surface introduced by VSDK-769:
// - `Config.effectiveSdkName` / `effectiveSdkVersion` resolve to defaults
//   (`webrtc-flutter` + `VersionUtils.getSDKVersion()`) when the override pair is not
//   supplied, and to the override when it is.
// - Partial overrides (name without version or vice versa) are rejected at
//   construction time via an `assert`.
// - The pair is forwarded from `CredentialConfig` / `TokenConfig` to the base
//   `Config` (no shadowing).
// - `UserVariables.toJson()` emits `mobile_sdk_name` and `mobile_sdk_version`
//   whenever the fields are set; identity is independent of push flags.
import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';
import 'package:telnyx_webrtc/model/verto/send/login_message_body.dart';
import 'package:telnyx_webrtc/model/verto/send/anonymous_login_message.dart';
import 'package:telnyx_webrtc/model/verto/send/invite_answer_message_body.dart';
import 'package:telnyx_webrtc/model/verto/send/attach_call_message.dart';
import 'package:telnyx_webrtc/utils/logging/log_level.dart';
import 'package:telnyx_webrtc/utils/version_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sdkVersion = VersionUtils.getSDKVersion();

  group('Config SDK identity defaults', () {
    test('CredentialConfig defaults to webrtc-flutter + package version', () {
      final config = CredentialConfig(
        sipUser: 'user',
        sipPassword: 'pass',
        sipCallerIDName: 'Test User',
        sipCallerIDNumber: '+123****7890',
        logLevel: LogLevel.debug,
        debug: false,
      );

      expect(config.mobileSdkName, isNull);
      expect(config.mobileSdkVersion, isNull);
      expect(config.effectiveSdkName, equals('webrtc-flutter'));
      expect(config.effectiveSdkVersion, equals(sdkVersion));
    });

    test('TokenConfig defaults to webrtc-flutter + package version', () {
      final config = TokenConfig(
        sipToken: 'token',
        sipCallerIDName: 'Test User',
        sipCallerIDNumber: '+123****7890',
        logLevel: LogLevel.debug,
        debug: false,
      );

      expect(config.mobileSdkName, isNull);
      expect(config.mobileSdkVersion, isNull);
      expect(config.effectiveSdkName, equals('webrtc-flutter'));
      expect(config.effectiveSdkVersion, equals(sdkVersion));
    });

    test('effectiveSdkVersion matches VersionUtils.getSDKVersion()', () {
      // Sanity check: the resolver does not introduce a drift between the
      // SDK's identity wire field and the package version constant.
      final config = TokenConfig(
        sipToken: 'token',
        sipCallerIDName: 'Test User',
        sipCallerIDNumber: '+123****7890',
        logLevel: LogLevel.none,
        debug: false,
      );
      expect(config.effectiveSdkVersion, equals(VersionUtils.getSDKVersion()));
    });
  });

  group('Config SDK identity overrides', () {
    test('CredentialConfig accepts wrapper identity pair', () {
      final config = CredentialConfig(
        sipUser: 'user',
        sipPassword: 'pass',
        sipCallerIDName: 'Test User',
        sipCallerIDNumber: '+123****7890',
        logLevel: LogLevel.debug,
        debug: false,
        mobileSdkName: 'webrtc-flutter-commons',
        mobileSdkVersion: '1.2.3',
      );

      expect(config.mobileSdkName, equals('webrtc-flutter-commons'));
      expect(config.mobileSdkVersion, equals('1.2.3'));
      expect(config.effectiveSdkName, equals('webrtc-flutter-commons'));
      expect(config.effectiveSdkVersion, equals('1.2.3'));
    });

    test('TokenConfig accepts wrapper identity pair', () {
      final config = TokenConfig(
        sipToken: 'token',
        sipCallerIDName: 'Test User',
        sipCallerIDNumber: '+123****7890',
        logLevel: LogLevel.debug,
        debug: false,
        mobileSdkName: 'webrtc-flutter-commons',
        mobileSdkVersion: '1.2.3',
      );

      expect(config.mobileSdkName, equals('webrtc-flutter-commons'));
      expect(config.mobileSdkVersion, equals('1.2.3'));
      expect(config.effectiveSdkName, equals('webrtc-flutter-commons'));
      expect(config.effectiveSdkVersion, equals('1.2.3'));
    });
  });

  group('top-level Verto params identity', () {
    void expectIdentity(Map<dynamic, dynamic> params) {
      expect(params['mobile_sdk_name'], equals('webrtc-flutter'));
      expect(params['mobile_sdk_version'], equals(sdkVersion));
    }

    test('credential and token login params emit identity at top level', () {
      for (final params in [
        LoginParams(
          login: 'user',
          passwd: 'pass',
          mobileSdkName: 'webrtc-flutter',
          mobileSdkVersion: sdkVersion,
        ),
        LoginParams(
          loginToken: 'token',
          mobileSdkName: 'webrtc-flutter',
          mobileSdkVersion: sdkVersion,
        ),
      ]) {
        expectIdentity(params.toJson());
      }
    });

    test('anonymous login params emit identity at top level', () {
      expectIdentity(
        AnonymousLoginParams(
          targetType: 'ai_assistant',
          targetId: 'target',
          mobileSdkName: 'webrtc-flutter',
          mobileSdkVersion: sdkVersion,
        ).toJson(),
      );
    });

    test('invite, answer, and attach params emit identity at top level', () {
      expectIdentity(
        InviteParams(
          mobileSdkName: 'webrtc-flutter',
          mobileSdkVersion: sdkVersion,
        ).toJson(),
      );
      expectIdentity(
        Params(
          userVariables: const {},
          mobileSdkName: 'webrtc-flutter',
          mobileSdkVersion: sdkVersion,
        ).toJson(),
      );
    });
  });

  group('Config SDK identity partial-override rejection', () {
    test('name without version throws AssertionError', () {
      expect(
        () => TokenConfig(
          sipToken: 'token',
          sipCallerIDName: 'Test User',
          sipCallerIDNumber: '+123****7890',
          logLevel: LogLevel.none,
          debug: false,
          mobileSdkName: 'wrapper',
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('version without name throws AssertionError', () {
      expect(
        () => CredentialConfig(
          sipUser: 'user',
          sipPassword: 'pass',
          sipCallerIDName: 'Test User',
          sipCallerIDNumber: '+123****7890',
          logLevel: LogLevel.none,
          debug: false,
          mobileSdkVersion: '9.9.9',
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('UserVariables SDK identity serialization', () {
    test('emits mobile_sdk_name and mobile_sdk_version when set', () {
      final vars = UserVariables(
        mobileSdkName: 'flutter',
        mobileSdkVersion: sdkVersion,
      );

      final json = vars.toJson();
      expect(json['mobile_sdk_name'], equals('flutter'));
      expect(json['mobile_sdk_version'], equals(sdkVersion));
    });

    test('emits wrapper identity when overridden', () {
      final vars = UserVariables(
        mobileSdkName: 'telnyx_flutter_commons',
        mobileSdkVersion: '1.2.3',
      );

      final json = vars.toJson();
      expect(json['mobile_sdk_name'], equals('telnyx_flutter_commons'));
      expect(json['mobile_sdk_version'], equals('1.2.3'));
    });

    test('omits mobile_sdk_* when fields are null', () {
      final vars = UserVariables();

      final json = vars.toJson();
      expect(json.containsKey('mobile_sdk_name'), isFalse);
      expect(json.containsKey('mobile_sdk_version'), isFalse);
    });

    test('round-trips mobile_sdk_* through fromJson', () {
      final json = {
        'mobile_sdk_name': 'wrapper',
        'mobile_sdk_version': '4.5.0',
      };

      final vars = UserVariables.fromJson(json);
      expect(vars.mobileSdkName, equals('wrapper'));
      expect(vars.mobileSdkVersion, equals('4.5.0'));
    });

    test('emits identity independently of push flags', () {
      // VSDK-769 identity emission must not regress the push-flag opt-in
      // behavior — when pushWhenActive is null the flag is suppressed but
      // identity fields, when set, are still emitted.
      final vars = UserVariables(
        mobileSdkName: 'flutter',
        mobileSdkVersion: sdkVersion,
      );

      final json = vars.toJson();
      expect(json.containsKey('push_when_active'), isFalse);
      expect(json.containsKey('pn_late_fanout'), isFalse);
      expect(json['mobile_sdk_name'], equals('flutter'));
      expect(json['mobile_sdk_version'], equals(sdkVersion));
    });
  });
}
