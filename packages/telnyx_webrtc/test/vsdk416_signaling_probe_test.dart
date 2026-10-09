import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';
import 'package:telnyx_webrtc/model/call_state.dart';
import 'package:telnyx_webrtc/services/signaling_health_monitor.dart';
import 'package:telnyx_webrtc/telnyx_client.dart';
import 'package:telnyx_webrtc/tx_socket.dart';
import 'package:telnyx_webrtc/utils/logging/log_level.dart';

/// Records every payload sent on the socket so tests can assert the real
/// production send path is exercised.
class _RecordingTxSocket extends TxSocket {
  _RecordingTxSocket() : super('wss://example.test');
  final List<String> sent = <String>[];
  @override
  void connect() {}
  @override
  void close() {}
  @override
  void send(dynamic data) => sent.add(data.toString());
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

  late TelnyxClient client;
  late _RecordingTxSocket socket;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    socket = _RecordingTxSocket();
    client = TelnyxClient(connectivityChanges: () => const Stream.empty())
      ..txSocket = socket;
  });

  tearDown(() => client.dispose());

  test(
      'unknown signaling + peer failure sends a real telnyx_rtc.ping probe '
      'through the production socket adapter', () {
    client.applyStructuredConfigForTest(_config());
    final call = client.call..callId = 'call-1';
    client.calls['call-1'] = call;
    call.callHandler.changeState(CallState.active);
    client.onCallStateChangedToActive('call-1');
    expect(client.healthMonitor!.isRunning, isTrue);

    // No inbound socket activity → signaling health is unknown, so a peer
    // failure must defer with a probe rather than restarting ICE blindly.
    client.healthMonitor!
        .onPeerFailure('call-1', PeerFailureEvidence.iceFailed);

    expect(client.healthMonitor!.isProbeInFlight, isTrue);
    expect(
      socket.sent,
      contains(
        predicate<String>(
          (s) => s.contains('"method":"telnyx_rtc.ping"'),
          'a telnyx_rtc.ping probe',
        ),
      ),
      reason: 'the probe must actually be sent on the socket, not just flagged',
    );
  });
}
