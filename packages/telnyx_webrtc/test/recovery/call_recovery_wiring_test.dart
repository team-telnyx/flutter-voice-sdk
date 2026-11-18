import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telnyx_webrtc/call.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';
import 'package:telnyx_webrtc/model/call_state.dart';
import 'package:telnyx_webrtc/model/errors/telnyx_error_codes.dart';
import 'package:telnyx_webrtc/model/errors/telnyx_error_event.dart';
import 'package:telnyx_webrtc/model/errors/telnyx_warning_codes.dart';
import 'package:telnyx_webrtc/model/errors/telnyx_warning_event.dart';
import 'package:telnyx_webrtc/peer/peer.dart';
import 'package:telnyx_webrtc/src/recovery/call_recovery_monitor.dart';
import 'package:telnyx_webrtc/telnyx_client.dart';
import 'package:telnyx_webrtc/tx_socket.dart';
import 'package:telnyx_webrtc/utils/logging/log_level.dart';

class _RecordingTxSocket extends TxSocket {
  _RecordingTxSocket() : super('wss://example.test');

  final List<String> sent = <String>[];
  int connectCount = 0;

  @override
  void connect() => connectCount++;

  @override
  void close() {}

  @override
  void send(dynamic data) => sent.add(data.toString());

  void emitMessage(String data) => onMessage(data);

  void emitOpen() => onOpen();

  List<Map<String, dynamic>> sentWithMethod(String method) => sent
      .map((raw) => jsonDecode(raw))
      .whereType<Map<String, dynamic>>()
      .where((json) => json['method'] == method)
      .toList();
}

/// A [Call] that counts legacy ICE-restart requests.
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
  int iceRestartCount = 0;

  @override
  bool startLegacyIceRenegotiation() {
    restartCount++;
    return true;
  }

  @override
  bool iceRestart() {
    iceRestartCount++;
    return true;
  }
}

CredentialConfig _config({
  bool recovery = true,
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
      enableSignalingHealthMonitor: recovery,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TelnyxClient client;
  late _RecordingTxSocket socket;
  late List<TelnyxWarningEvent> warnings;
  late List<Object> errors;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    socket = _RecordingTxSocket();
    warnings = <TelnyxWarningEvent>[];
    errors = <Object>[];
    client = TelnyxClient(connectivityChanges: () => const Stream.empty())
      ..txSocket = socket
      ..onTelnyxWarning = warnings.add
      ..onTelnyxError = errors.add;
  });

  tearDown(() => client.dispose());

  Future<void> connect({bool recovery = true, bool? autoReconnect = true}) {
    client.connectWithCredential(
      _config(recovery: recovery, autoReconnect: autoReconnect),
    );
    return pumpEventQueue().then((_) => socket.emitOpen());
  }

  T activate<T extends Call>(T call, String id) {
    call.callId = id;
    client.calls[id] = call;
    call.callHandler.changeState(CallState.active);
    return call;
  }

  Call addActiveCall(String id) => activate(client.call, id);

  Iterable<int> warningCodes() => warnings.map((w) => w.warning.code);

  test('the deprecated healthMonitor getter stays source compatible', () async {
    await connect();

    // Existing callers such as `client.healthMonitor?.stop()` still compile;
    // the client-wide monitor no longer exists, so it is always null.
    // ignore: deprecated_member_use_from_same_package
    client.healthMonitor?.stop();
    // ignore: deprecated_member_use_from_same_package
    expect(client.healthMonitor, isNull);
  });

  group('monitor lifecycle', () {
    test('runs while active, pauses while held, and is disposed when done', () {
      client.applyStructuredConfigForTest(_config());
      final call = addActiveCall('call-1');
      final monitor = call.recoveryMonitor;
      expect(monitor, isNotNull);

      call.callHandler.changeState(CallState.held);
      expect(call.recoveryMonitor, same(monitor));
      expect(monitor!.state, CallRecoveryState.idle);

      call.callHandler.changeState(CallState.active);
      expect(call.recoveryMonitor, same(monitor));

      call.callHandler.changeState(CallState.done);
      expect(call.recoveryMonitor, isNull);
      expect(monitor.isDisposed, isTrue);
    });

    test('is not created when recovery is disabled', () {
      client.applyStructuredConfigForTest(_config(recovery: false));

      expect(addActiveCall('call-1').recoveryMonitor, isNull);
    });

    test('client dispose releases call recovery', () {
      client.applyStructuredConfigForTest(_config());
      final call = addActiveCall('call-1');
      final monitor = call.recoveryMonitor!;

      client.dispose();

      expect(call.recoveryMonitor, isNull);
      expect(monitor.isDisposed, isTrue);
    });
  });

  group('peer failure entry points', () {
    test('recovery enabled: the monitor owns recovery, no legacy restart', () {
      client.applyStructuredConfigForTest(_config());
      final call = activate(_SpyCall(socket, client), 'call-1');

      client.handlePeerIceConnectionFailed('call-1', afterDisconnect: true);

      expect(call.restartCount, 0);
      expect(warningCodes(), contains(TelnyxWarningCodes.peerConnectionFailed));
    });

    test('recovery disabled + failure after disconnect: one legacy restart',
        () {
      client.applyStructuredConfigForTest(_config(recovery: false));
      final call = activate(_SpyCall(socket, client), 'call-1');

      client.handlePeerIceConnectionFailed('call-1', afterDisconnect: true);

      expect(call.restartCount, 1);
    });

    test('recovery disabled + failure without disconnect: no restart', () {
      client.applyStructuredConfigForTest(_config(recovery: false));
      final call = activate(_SpyCall(socket, client), 'call-1');

      client.handlePeerIceConnectionFailed('call-1', afterDisconnect: false);

      expect(call.restartCount, 0);
    });

    test('peer connection failure emits peerConnectionFailed', () {
      client.applyStructuredConfigForTest(_config());
      addActiveCall('call-1');

      client.handlePeerConnectionFailed('call-1');

      expect(warningCodes(), contains(TelnyxWarningCodes.peerConnectionFailed));
    });
  });

  group('signaling gating through the client', () {
    test('stale signaling sends one correlated ping probe on the socket',
        () async {
      await connect();
      final monitor = addActiveCall('call-1').recoveryMonitor!;
      socket.sent.clear();

      monitor.onIceConnectionStateChanged(
        RTCIceConnectionState.RTCIceConnectionStateFailed,
      );
      await pumpEventQueue();

      final probes = socket.sentWithMethod('telnyx_rtc.ping');
      expect(probes, hasLength(1));
      expect(probes.single['id'], isA<String>());
      expect(monitor.state, CallRecoveryState.probing);
    });

    test('only the response with the probe id resolves it', () async {
      await connect();
      final monitor = addActiveCall('call-1').recoveryMonitor!;
      socket.sent.clear();
      monitor.onIceConnectionStateChanged(
        RTCIceConnectionState.RTCIceConnectionStateFailed,
      );
      await pumpEventQueue();
      final probeId = socket.sentWithMethod('telnyx_rtc.ping').single['id'];

      socket.emitMessage(
        jsonEncode({'jsonrpc': '2.0', 'id': 'unrelated', 'result': {}}),
      );
      await pumpEventQueue();
      expect(monitor.state, CallRecoveryState.probing);

      warnings.clear();
      socket.emitMessage(
        jsonEncode({'jsonrpc': '2.0', 'id': probeId, 'result': {}}),
      );
      await pumpEventQueue();

      // Probe answered → ICE restart; this call has no peer, so the restart
      // fails and recovery falls back to one reconnect / reattach.
      expect(monitor.state, CallRecoveryState.reattaching);
      expect(
        warningCodes(),
        contains(TelnyxWarningCodes.signalingRecoveryRequired),
      );
      expect(client.isRecoveryReconnecting, isTrue);
    });

    test('recently confirmed signaling skips the probe', () async {
      await connect();
      final monitor = addActiveCall('call-1').recoveryMonitor!;
      socket
        ..emitMessage(
          jsonEncode({'jsonrpc': '2.0', 'id': 'any', 'result': {}}),
        )
        ..sent.clear();
      await pumpEventQueue();

      monitor.onIceConnectionStateChanged(
        RTCIceConnectionState.RTCIceConnectionStateFailed,
      );
      await pumpEventQueue();

      expect(socket.sentWithMethod('telnyx_rtc.ping'), isEmpty);
    });

    test('an ICE restart that cannot start does not emit iceRestartFailed',
        () async {
      await connect();
      final monitor = addActiveCall('call-1').recoveryMonitor!;
      socket.emitMessage(
        jsonEncode({'jsonrpc': '2.0', 'id': 'any', 'result': {}}),
      );
      await pumpEventQueue();

      monitor.onIceConnectionStateChanged(
        RTCIceConnectionState.RTCIceConnectionStateFailed,
      );
      await pumpEventQueue();

      final codes =
          errors.whereType<TelnyxErrorEvent>().map((event) => event.error.code);
      expect(codes, isNot(contains(TelnyxErrorCodes.iceRestartFailed)));
    });
  });

  group('critical request timeouts', () {
    test('force a signaling reconnect while a call is active', () async {
      await connect();
      addActiveCall('call-1');

      client.onRequestTimeoutForTest('telnyx_rtc.bye', 'req-1', 5000);

      expect(
        warningCodes(),
        contains(TelnyxWarningCodes.signalingRecoveryRequired),
      );
      expect(
        warningCodes(),
        isNot(contains(TelnyxWarningCodes.mediaRecoveryRequired)),
      );
    });

    test('non-critical timeouts trigger no recovery', () async {
      await connect();
      addActiveCall('call-1');
      final connects = socket.connectCount;

      client.onRequestTimeoutForTest('telnyx_rtc.info', 'req-1', 5000);

      expect(warnings, isEmpty);
      expect(socket.connectCount, connects);
    });

    test('without an active call no reconnect is forced', () async {
      await connect();

      client.onRequestTimeoutForTest('telnyx_rtc.bye', 'req-1', 5000);

      expect(
        warningCodes(),
        isNot(contains(TelnyxWarningCodes.signalingRecoveryRequired)),
      );
    });
  });

  group('reattach fallback', () {
    test('is refused when auto-reconnect is off', () async {
      await connect(autoReconnect: false);

      expect(await client.requestRecoveryReattach('call-1'), isFalse);
    });

    test('a repeated request shares the pending reattach', () async {
      await connect();
      addActiveCall('call-1');

      final first = client.requestRecoveryReattach('call-1');
      final second = client.requestRecoveryReattach('call-1');

      expect(identical(first, second), isTrue);
      expect(
        warningCodes()
            .where((c) => c == TelnyxWarningCodes.signalingRecoveryRequired),
        hasLength(1),
      );
    });

    test('an explicit disconnect fails the pending reattach', () async {
      await connect();
      addActiveCall('call-1');
      final pending = client.requestRecoveryReattach('call-1');

      client.disconnect();

      expect(await pending, isFalse);
    });
  });

  test('a replaced call stays passive', () async {
    await connect();
    final original = addActiveCall('call-1');
    final monitor = original.recoveryMonitor!;

    // A reattach replaced the call object tracked by the client.
    client.calls['call-1'] = _SpyCall(socket, client)..callId = 'call-1';

    expect(monitor.requestIceRestart(), isFalse);
  });

  group('Call.iceRestart()', () {
    Call activeCallWithPeer(String id) {
      final call = client.call
        ..peerConnection = Peer(socket, false, client, false, false);
      return activate(call, id);
    }

    test('starts a coordinated restart through the recovery monitor', () async {
      await connect();
      final call = activeCallWithPeer('call-1');

      expect(call.iceRestart(), isTrue);
      expect(call.recoveryMonitor!.state, isNot(CallRecoveryState.idle));
      await pumpEventQueue();
      expect(
        warningCodes(),
        isNot(contains(TelnyxWarningCodes.mediaRecoveryRequired)),
        reason: 'a manual restart is not evidence of degraded media',
      );
      expect(
        call.iceRestart(),
        isFalse,
        reason: 'a recovery is already running',
      );
    });

    test('is rejected when the call is not active', () async {
      await connect();
      final call = activeCallWithPeer('call-1');
      call.callHandler.changeState(CallState.held);

      expect(call.iceRestart(), isFalse);
    });

    test('is rejected when signaling is not connected', () {
      client.applyStructuredConfigForTest(_config());
      final call = activeCallWithPeer('call-1');

      expect(call.iceRestart(), isFalse);
    });

    test('is rejected without a peer connection', () async {
      await connect();

      expect(addActiveCall('call-1').iceRestart(), isFalse);
    });

    test('is forwarded to the call that replaced it after a reattach',
        () async {
      await connect();
      final original = activeCallWithPeer('call-1');
      final replacement = _SpyCall(socket, client)..callId = 'call-1';
      client.calls['call-1'] = replacement;

      expect(original.iceRestart(), isTrue);
      expect(replacement.iceRestartCount, 1);
    });

    test('uses the legacy renegotiation when recovery is disabled', () async {
      await connect(recovery: false);
      final call = activeCallWithPeer('call-1');

      expect(call.recoveryMonitor, isNull);
      expect(call.iceRestart(), isTrue);
    });
  });
}
