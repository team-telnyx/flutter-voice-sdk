import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';
import 'package:telnyx_webrtc/model/errors/sdk_errors.dart';
import 'package:telnyx_webrtc/model/errors/sdk_warnings.dart';
import 'package:telnyx_webrtc/model/errors/telnyx_error.dart';
import 'package:telnyx_webrtc/model/errors/telnyx_error_codes.dart';
import 'package:telnyx_webrtc/model/errors/telnyx_error_event.dart';
import 'package:telnyx_webrtc/model/errors/telnyx_warning_codes.dart';
import 'package:telnyx_webrtc/model/errors/telnyx_warning_event.dart';
import 'package:telnyx_webrtc/model/sdk_error_codes.dart';
import 'package:telnyx_webrtc/model/sdk_warning_codes.dart';
import 'package:telnyx_webrtc/model/telnyx_socket_error.dart';
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
}

CredentialConfig _config({bool enableStructuredErrors = true}) =>
    CredentialConfig(
      sipUser: 'user',
      sipPassword: 'pass',
      sipCallerIDName: 'name',
      sipCallerIDNumber: 'number',
      logLevel: LogLevel.none,
      debug: false,
      enableStructuredErrors: enableStructuredErrors,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TelnyxClient client;
  late _FakeTxSocket socket;
  late List<Object> structuredErrors;
  late List<TelnyxWarningEvent> warnings;
  late List<TelnyxSocketError> legacyErrors;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    socket = _FakeTxSocket();
    structuredErrors = <Object>[];
    warnings = <TelnyxWarningEvent>[];
    legacyErrors = <TelnyxSocketError>[];
    client = TelnyxClient(connectivityChanges: () => const Stream.empty())
      ..txSocket = socket
      ..onTelnyxError = structuredErrors.add
      ..onTelnyxWarning = warnings.add
      ..onSocketErrorReceived = legacyErrors.add;
  });

  tearDown(() => client.dispose());

  group('VSDK-415: callback surface + config', () {
    test('onTelnyxError/onTelnyxWarning are optional (default null)', () {
      final fresh =
          TelnyxClient(connectivityChanges: () => const Stream.empty());
      expect(fresh.onTelnyxError, isNull);
      expect(fresh.onTelnyxWarning, isNull);
      fresh.dispose();
    });

    test('Config exposes enableStructuredErrors defaulting to true', () {
      expect(_config().enableStructuredErrors, isTrue);
      expect(
        _config(enableStructuredErrors: false).enableStructuredErrors,
        isFalse,
      );
    });
  });

  group('VSDK-415: emit helpers', () {
    test('emitStructuredErrorCode fires onTelnyxError with a structured event',
        () {
      client
        ..applyStructuredConfigForTest(_config())
        ..emitStructuredErrorCode(
          TelnyxErrorCodes.loginFailed,
          callId: 'call-9',
        );

      expect(structuredErrors, hasLength(1));
      final event = structuredErrors.single as TelnyxErrorEvent;
      expect(event.error.code, TelnyxErrorCodes.loginFailed);
      expect(event.callId, 'call-9');
      expect(event.recoverable, isFalse);
    });

    test('emitWarningCode fires onTelnyxWarning', () {
      client
        ..applyStructuredConfigForTest(_config())
        ..emitWarningCode(
          TelnyxWarningCodes.signalingRecoveryRequired,
          reason: 'unhealthy',
          source: 'health_monitor',
        );

      expect(warnings, hasLength(1));
      expect(
        warnings.single.warning.code,
        TelnyxWarningCodes.signalingRecoveryRequired,
      );
      expect(warnings.single.source, 'health_monitor');
    });

    test('feature flag disabled suppresses structured error + warning', () {
      client
        ..applyStructuredConfigForTest(
          _config(enableStructuredErrors: false),
        )
        ..emitStructuredErrorCode(TelnyxErrorCodes.loginFailed)
        ..emitWarningCode(TelnyxWarningCodes.highRtt);

      expect(structuredErrors, isEmpty);
      expect(warnings, isEmpty);
    });

    test('a throwing app callback does not break the SDK', () {
      client
        ..applyStructuredConfigForTest(_config())
        ..onTelnyxError = (_) => throw StateError('boom');

      expect(
        () => client.emitStructuredErrorCode(TelnyxErrorCodes.loginFailed),
        returnsNormally,
      );
    });
  });

  group('VSDK-415: runtime error emission (real socket path)', () {
    test('server error message emits structured error AND legacy callback',
        () async {
      client.connectWithCredential(_config());
      await pumpEventQueue();

      socket.emitMessage(
        '{"jsonrpc":"2.0","id":"1",'
        '"error":{"code":-32001,"message":"Credential registration error"}}',
      );
      await pumpEventQueue();

      // Legacy behavior preserved.
      expect(legacyErrors, hasLength(1));
      expect(legacyErrors.single.errorCode, -32001);
      // Structured error fired alongside.
      expect(structuredErrors, hasLength(1));
      final event = structuredErrors.single as TelnyxErrorEvent;
      expect(event.error.code, TelnyxErrorCodes.invalidCredentials);
    });

    test('token error maps to authenticationRequired', () async {
      client.connectWithCredential(_config());
      await pumpEventQueue();

      socket.emitMessage(
        '{"jsonrpc":"2.0","id":"1",'
        '"error":{"code":-32000,"message":"Token registration error"}}',
      );
      await pumpEventQueue();

      expect(legacyErrors, hasLength(1));
      final event = structuredErrors.single as TelnyxErrorEvent;
      expect(event.error.code, TelnyxErrorCodes.authenticationRequired);
    });

    test(
        'unknown server error maps to unexpectedError (not loginFailed) and '
        'preserves the raw server context', () async {
      client.connectWithCredential(_config());
      await pumpEventQueue();

      socket.emitMessage(
        '{"jsonrpc":"2.0","id":"1",'
        '"error":{"code":-32099,"message":"Some unexpected server failure"}}',
      );
      await pumpEventQueue();

      expect(legacyErrors.single.errorCode, -32099);
      final event = structuredErrors.single as TelnyxErrorEvent;
      expect(
        event.error.code,
        TelnyxErrorCodes.unexpectedError,
        reason: 'a non-auth/non-gateway error must not masquerade as a login '
            'failure',
      );
      expect(
        event.error.originalError.toString(),
        contains('Some unexpected server failure'),
        reason: 'the raw server message must be preserved',
      );
    });

    test('disabled flag: legacy fires, structured does not', () async {
      client.connectWithCredential(_config(enableStructuredErrors: false));
      await pumpEventQueue();

      socket.emitMessage(
        '{"jsonrpc":"2.0","id":"1",'
        '"error":{"code":-32001,"message":"Credential registration error"}}',
      );
      await pumpEventQueue();

      expect(legacyErrors, hasLength(1));
      expect(structuredErrors, isEmpty);
    });
  });

  group('VSDK-415: registry reconciliation', () {
    test('public TelnyxErrorCodes match internal SdkErrorCode values', () {
      expect(
        TelnyxErrorCodes.sdpCreateOfferFailed,
        SdkErrorCode.sdpCreateOfferFailed,
      );
      expect(
        TelnyxErrorCodes.invalidCredentials,
        SdkErrorCode.invalidCredentials,
      );
      expect(
        TelnyxErrorCodes.sessionNotReattached,
        SdkErrorCode.sessionNotReattached,
      );
      expect(TelnyxErrorCodes.unexpectedError, SdkErrorCode.unexpectedError);
    });

    test('public TelnyxWarningCodes match internal SdkWarningCode values', () {
      expect(
        TelnyxWarningCodes.signalingRecoveryRequired,
        SdkWarningCode.signalingRecoveryRequired,
      );
      expect(
        TelnyxWarningCodes.mediaRecoveryRequired,
        SdkWarningCode.mediaRecoveryRequired,
      );
      expect(
        TelnyxWarningCodes.peerConnectionFailed,
        SdkWarningCode.peerConnectionFailed,
      );
    });

    test('every public error/warning code resolves in its registry', () {
      final error = TelnyxError(
        code: TelnyxErrorCodes.gatewayFailed,
        name: 'x',
        message: 'x',
        description: 'x',
        causes: const [],
        solutions: const [],
        fatal: true,
      );
      expect(error.code, 45004);
      expect(sdkErrors.containsKey(TelnyxErrorCodes.gatewayFailed), isTrue);
      expect(
        sdkWarnings.containsKey(TelnyxWarningCodes.mediaRecoveryRequired),
        isTrue,
      );
    });
  });
}
