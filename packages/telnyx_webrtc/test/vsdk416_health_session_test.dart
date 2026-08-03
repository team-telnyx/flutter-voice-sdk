import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telnyx_webrtc/call.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';
import 'package:telnyx_webrtc/model/call_state.dart';
import 'package:telnyx_webrtc/model/errors/telnyx_warning_codes.dart';
import 'package:telnyx_webrtc/model/errors/telnyx_warning_event.dart';
import 'package:telnyx_webrtc/services/signaling_health_monitor.dart';
import 'package:telnyx_webrtc/telnyx_client.dart';
import 'package:telnyx_webrtc/tx_socket.dart';
import 'package:telnyx_webrtc/utils/logging/log_level.dart';

class _FakeTxSocket extends TxSocket {
  _FakeTxSocket() : super('wss://example.test');
  int connectCount = 0;
  @override
  void connect() => connectCount++;
  @override
  void close() {}
  @override
  void send(dynamic data) {}
  void emitMessage(dynamic data) => onMessage(data);
  void emitOpen() => onOpen();
}

CredentialConfig _config({
  bool healthMonitor = true,
  bool? autoReconnect = true,
}) =>
    CredentialConfig(
      sipUser: 'user',
      sipPassword: 'pass',
      sipCallerIDName: 'name',
      sipCallerIDNumber: 'number',
      logLevel: LogLevel.none,
      debug: false,
      autoReconnect: autoReconnect,
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

  Call addActiveCall(String id) {
    final call = client.call..callId = id;
    client.calls[id] = call;
    call.callHandler.changeState(CallState.active);
    return call;
  }

  group('VSDK-416: monitor ownership', () {
    test('monitor is instantiated only when enabled', () {
      client.applyStructuredConfigForTest(_config(healthMonitor: false));
      expect(client.healthMonitor, isNull);

      client.applyStructuredConfigForTest(_config());
      expect(client.healthMonitor, isNotNull);
    });

    test('monitor starts when a call is active and stops when none remain',
        () async {
      client.applyStructuredConfigForTest(_config());

      addActiveCall('call-1');
      client.onCallStateChangedToActive('call-1');
      expect(client.healthMonitor!.isRunning, isTrue);

      // Move the call out of an active state → monitor stops.
      client.calls['call-1']!.callHandler.changeState(CallState.done);
      client.onCallStateChangedToActive('call-1');
      expect(client.healthMonitor!.isRunning, isFalse);
    });

    test('disconnect stops a running monitor', () {
      client.applyStructuredConfigForTest(_config());
      addActiveCall('call-1');
      client.onCallStateChangedToActive('call-1');
      expect(client.healthMonitor!.isRunning, isTrue);

      client.disconnect();

      expect(client.healthMonitor!.isRunning, isFalse);
    });

    test('connect config immediately replaces a stale autoReconnect policy',
        () {
      client.applyStructuredConfigForTest(_config(autoReconnect: false));
      expect(client.autoReconnectLoginForTest, isFalse);

      client.applyStructuredConfigForTest(_config());
      expect(client.autoReconnectLoginForTest, isTrue);

      client.applyStructuredConfigForTest(_config(autoReconnect: null));
      expect(client.autoReconnectLoginForTest, isTrue);
    });

    testWidgets(
        'config reapplication clears deferred recovery without a duplicate ICE restart',
        (tester) async {
      client.applyStructuredConfigForTest(_config());
      addActiveCall('call-1');
      client.onCallStateChangedToActive('call-1');
      final monitor = client.healthMonitor!;

      // Kept separate from onSocketActivity so the pre-reset probe state is
      // asserted before configuration clears it.
      // ignore: cascade_invocations
      monitor.onPeerFailure('call-1', PeerFailureEvidence.iceFailed);
      expect(monitor.isProbeInFlight, isTrue);

      client.applyStructuredConfigForTest(_config());
      expect(monitor.isRunning, isTrue);
      expect(monitor.isProbeInFlight, isFalse);

      monitor.onSocketActivity();
      warnings.clear();
      await tester.pump(const Duration(seconds: 3));

      expect(
        warnings.where(
          (event) =>
              event.warning.code == TelnyxWarningCodes.mediaRecoveryRequired,
        ),
        isEmpty,
        reason: 'the prior session must not trigger a deferred ICE restart',
      );
      monitor.stop();
    });
  });

  group('VSDK-416: single recovery authority', () {
    test(
        'critical request timeout (connected + active) triggers signaling '
        'recovery only', () async {
      client.connectWithCredential(_config());
      await pumpEventQueue();
      socket.emitOpen(); // marks the client connected
      addActiveCall('call-1');
      client.onCallStateChangedToActive('call-1');
      expect(client.healthMonitor!.isRunning, isTrue);

      client.healthMonitor!.onRequestTimeout('req-1', 5000, 'telnyx_rtc.bye');

      final codes = warnings.map((w) => w.warning.code).toList();
      expect(codes, contains(TelnyxWarningCodes.signalingRecoveryRequired));
      expect(
        codes,
        isNot(contains(TelnyxWarningCodes.mediaRecoveryRequired)),
        reason: 'unhealthy signaling must never also restart ICE',
      );
    });

    test('non-critical request timeout triggers no recovery', () async {
      client.connectWithCredential(_config());
      await pumpEventQueue();
      socket.emitOpen();
      addActiveCall('call-1');
      client.onCallStateChangedToActive('call-1');

      final connectBefore = socket.connectCount;
      client.healthMonitor!.onRequestTimeout('req-1', 5000, 'telnyx_rtc.info');

      expect(warnings, isEmpty);
      expect(socket.connectCount, connectBefore);
    });
  });

  group('VSDK-416: inbound activity feeds the monitor', () {
    test(
        'an inbound socket message marks signaling healthy so a peer failure '
        'chooses ICE restart (media recovery)', () async {
      client.connectWithCredential(_config());
      await pumpEventQueue();
      socket.emitOpen();
      addActiveCall('call-1');
      client.onCallStateChangedToActive('call-1');

      // Any inbound message routes through _onMessage → onSocketActivity().
      socket
          .emitMessage('{"jsonrpc":"2.0","id":"x","method":"telnyx_rtc.ping"}');
      await pumpEventQueue();

      warnings.clear();
      client.healthMonitor!
          .onPeerFailure('call-1', PeerFailureEvidence.iceFailed);

      final codes = warnings.map((w) => w.warning.code).toList();
      expect(
        codes,
        contains(TelnyxWarningCodes.mediaRecoveryRequired),
        reason: 'healthy signaling + peer failure => ICE restart',
      );
    });
  });
}
