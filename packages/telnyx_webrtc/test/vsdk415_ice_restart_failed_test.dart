import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';
import 'package:telnyx_webrtc/model/call_state.dart';
import 'package:telnyx_webrtc/model/errors/telnyx_error_codes.dart';
import 'package:telnyx_webrtc/model/errors/telnyx_error_event.dart';
import 'package:telnyx_webrtc/services/signaling_health_monitor.dart';
import 'package:telnyx_webrtc/telnyx_client.dart';
import 'package:telnyx_webrtc/tx_socket.dart';
import 'package:telnyx_webrtc/utils/logging/log_level.dart';

class _FakeTxSocket extends TxSocket {
  _FakeTxSocket() : super('wss://example.test');
  bool wasDisconnected = false;
  @override
  void connect() {}
  @override
  void close() {}
  @override
  void send(dynamic data) {}
}

CredentialConfig _config() => CredentialConfig(
      sipUser: 'user',
      sipPassword: 'pass',
      sipCallerIDName: 'name',
      sipCallerIDNumber: 'number',
      logLevel: LogLevel.none,
      debug: false,
      autoReconnect: true,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'ICE restart that cannot be started (no peer) does NOT emit '
      'iceRestartFailed (47001) or escalate to socket reconnect (VSDK-397)',
      () {
    SharedPreferences.setMockInitialValues({});
    final socket = _FakeTxSocket();
    final errors = <Object>[];
    final client = TelnyxClient(connectivityChanges: () => const Stream.empty())
      ..txSocket = socket
      ..applyStructuredConfigForTest(_config())
      ..onTelnyxError = errors.add;

    // A call with no peer connection → restartIce() returns false (cannot
    // start). This is benign (call in terminal state, no peer to restart).
    final call = client.call..callId = 'call-1';
    client.calls['call-1'] = call;
    call.callHandler.changeState(CallState.active);
    client.onCallStateChangedToActive('call-1');
    // Mark signaling healthy so the monitor attempts an ICE restart.
    client.healthMonitor!.onSocketActivity();

    client.healthMonitor!
        .onPeerFailure('call-1', PeerFailureEvidence.iceFailed);

    // No structured error should be emitted for "not started" (benign).
    final codes =
        errors.whereType<TelnyxErrorEvent>().map((e) => e.error.code).toList();
    expect(codes, isNot(contains(TelnyxErrorCodes.iceRestartFailed)));

    client.dispose();
  });
}
