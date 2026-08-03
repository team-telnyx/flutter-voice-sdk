import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telnyx_webrtc/call.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';
import 'package:telnyx_webrtc/model/call_state.dart';
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
}

/// A [Call] that counts ICE-restart requests so tests can assert the recovery
/// authority triggers *exactly one* renegotiation.
class _SpyCall extends Call {
  _SpyCall(TxSocket socket, TelnyxClient client)
      : super(
          socket,
          client,
          'sess',
          '',
          '',
          CallHandler((_) {}, null),
          () {},
          false,
        ) {
    callHandler.call = this;
  }

  int restartCount = 0;

  @override
  bool restartIce() {
    restartCount++;
    return true;
  }
}

CredentialConfig _config({bool healthMonitor = true}) => CredentialConfig(
      sipUser: 'user',
      sipPassword: 'pass',
      sipCallerIDName: 'name',
      sipCallerIDNumber: 'number',
      logLevel: LogLevel.none,
      debug: false,
      autoReconnect: true,
      enableSignalingHealthMonitor: healthMonitor,
    );

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

  _SpyCall addActiveSpyCall(String id) {
    final call = _SpyCall(socket, client)..callId = id;
    client.calls[id] = call;
    call.callHandler.changeState(CallState.active);
    return call;
  }

  group('VSDK-416: peer ICE failure is a single recovery authority', () {
    test(
        'monitor enabled + healthy signaling → exactly one ICE restart '
        '(no duplicate direct renegotiation)', () {
      client.applyStructuredConfigForTest(_config());
      final call = addActiveSpyCall('call-1');
      client.onCallStateChangedToActive('call-1');
      // Mark signaling healthy so the monitor chooses an ICE restart.
      client.healthMonitor!.onSocketActivity();

      client.handlePeerIceConnectionFailed('call-1', afterDisconnect: true);

      expect(
        call.restartCount,
        1,
        reason: 'the monitor is the sole authority — the peer must not also '
            'renegotiate directly',
      );
      expect(
        warnings.map((w) => w.warning.code),
        contains(TelnyxWarningCodes.peerConnectionFailed),
      );
    });

    test(
        'monitor disabled + failure after disconnect → exactly one direct '
        'ICE restart (legacy self-heal preserved)', () {
      client.applyStructuredConfigForTest(_config(healthMonitor: false));
      final call = addActiveSpyCall('call-1');

      client.handlePeerIceConnectionFailed('call-1', afterDisconnect: true);

      expect(call.restartCount, 1);
    });

    test('monitor disabled + failure without prior disconnect → no ICE restart',
        () {
      client.applyStructuredConfigForTest(_config(healthMonitor: false));
      final call = addActiveSpyCall('call-1');

      client.handlePeerIceConnectionFailed('call-1', afterDisconnect: false);

      expect(call.restartCount, 0);
    });
  });

  group('VSDK-416: peer connection failure routing', () {
    test('emits peerConnectionFailed warning and routes to the monitor', () {
      client.applyStructuredConfigForTest(_config());
      addActiveSpyCall('call-1');
      client
        ..onCallStateChangedToActive('call-1')
        ..handlePeerConnectionFailed('call-1');

      expect(
        warnings.map((w) => w.warning.code),
        contains(TelnyxWarningCodes.peerConnectionFailed),
      );
    });
  });
}
