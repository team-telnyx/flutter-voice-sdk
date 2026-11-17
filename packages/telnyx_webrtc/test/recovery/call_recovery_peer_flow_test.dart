import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';
import 'package:telnyx_webrtc/model/call_state.dart';
import 'package:telnyx_webrtc/model/errors/telnyx_warning_codes.dart';
import 'package:telnyx_webrtc/model/errors/telnyx_warning_event.dart';
import 'package:telnyx_webrtc/peer/peer.dart';
import 'package:telnyx_webrtc/src/recovery/call_recovery_monitor.dart';
import 'package:telnyx_webrtc/telnyx_client.dart';
import 'package:telnyx_webrtc/tx_socket.dart';
import 'package:telnyx_webrtc/utils/logging/log_level.dart';

/// End-to-end ICE restart through the real Call → Peer → TelnyxClient wiring,
/// with only the socket and the native peer connection faked.

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

  void emitMessage(Object json) => onMessage(jsonEncode(json));

  void emitOpen() => onOpen();

  List<Map<String, dynamic>> sentWithMethod(String method) => sent
      .map((raw) => jsonDecode(raw))
      .whereType<Map<String, dynamic>>()
      .where((json) => json['method'] == method)
      .toList();
}

class _FakePeerConnection extends RTCPeerConnection {
  RTCIceConnectionState? ice =
      RTCIceConnectionState.RTCIceConnectionStateFailed;
  final List<Map<String, dynamic>?> offerConstraints =
      <Map<String, dynamic>?>[];
  final List<String?> remoteDescriptions = <String?>[];
  int gatheringReads = 0;
  int packets = 100;

  @override
  RTCIceConnectionState? get iceConnectionState => ice;

  @override
  RTCPeerConnectionState? get connectionState =>
      RTCPeerConnectionState.RTCPeerConnectionStateConnected;

  /// Reports `gathering` once, then `complete`.
  @override
  RTCIceGatheringState? get iceGatheringState => gatheringReads++ == 0
      ? RTCIceGatheringState.RTCIceGatheringStateGathering
      : RTCIceGatheringState.RTCIceGatheringStateComplete;

  @override
  RTCSignalingState? get signalingState => null;

  @override
  Map<String, dynamic> get getConfiguration => {};

  @override
  Future<RTCSessionDescription> createOffer([
    Map<String, dynamic>? constraints,
  ]) async {
    offerConstraints.add(constraints);
    return RTCSessionDescription('offer-sdp', 'offer');
  }

  @override
  Future<void> setLocalDescription(RTCSessionDescription description) async {}

  @override
  Future<RTCSessionDescription?> getLocalDescription() async =>
      RTCSessionDescription('offer-sdp-with-new-candidates', 'offer');

  @override
  Future<void> setRemoteDescription(RTCSessionDescription description) async {
    remoteDescriptions.add(description.sdp);
  }

  @override
  Future<List<StatsReport>> getStats([MediaStreamTrack? track]) async {
    packets += 25;
    return <StatsReport>[
      StatsReport('in', 'inbound-rtp', 0, {
        'kind': 'audio',
        'packetsReceived': packets,
      }),
    ];
  }

  // ── Unused surface ──
  @override
  Future<void> dispose() async {}
  @override
  Future<void> setConfiguration(Map<String, dynamic> configuration) async {}
  @override
  Future<RTCSessionDescription> createAnswer([
    Map<String, dynamic>? constraints,
  ]) async =>
      throw UnimplementedError();
  @override
  Future<void> addStream(MediaStream stream) async {}
  @override
  Future<void> removeStream(MediaStream stream) async {}
  @override
  Future<RTCSessionDescription?> getRemoteDescription() async => null;
  @override
  Future<void> addCandidate(RTCIceCandidate candidate) async {}
  @override
  List<MediaStream?> getLocalStreams() => [];
  @override
  List<MediaStream?> getRemoteStreams() => [];
  @override
  Future<RTCDataChannel> createDataChannel(
    String label,
    RTCDataChannelInit dataChannelDict,
  ) async =>
      throw UnimplementedError();
  @override
  Future<void> restartIce() async {}
  @override
  Future<void> close() async {}
  @override
  RTCDTMFSender createDtmfSender(MediaStreamTrack track) =>
      throw UnimplementedError();
  @override
  Future<List<RTCRtpSender>> getSenders() async => [];
  @override
  Future<List<RTCRtpReceiver>> getReceivers() async => [];
  @override
  Future<List<RTCRtpTransceiver>> getTransceivers() async => [];
  @override
  Future<RTCRtpSender> addTrack(
    MediaStreamTrack track, [
    MediaStream? stream,
  ]) async =>
      throw UnimplementedError();
  @override
  Future<bool> removeTrack(RTCRtpSender sender) async => true;
  @override
  Future<RTCRtpTransceiver> addTransceiver({
    MediaStreamTrack? track,
    RTCRtpMediaType? kind,
    RTCRtpTransceiverInit? init,
  }) async =>
      throw UnimplementedError();
}

/// Polls [condition] in real time; the restart path uses short real delays.
Future<void> _until(bool Function() condition) async {
  for (var i = 0; i < 100 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  expect(condition(), isTrue, reason: 'condition not reached in time');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'ICE failure with healthy signaling restarts ICE on the same peer, '
      'applies the correlated answer once, and verifies inbound RTP', () async {
    SharedPreferences.setMockInitialValues({});
    final socket = _RecordingTxSocket();
    final warnings = <TelnyxWarningEvent>[];
    final client = TelnyxClient(connectivityChanges: () => const Stream.empty())
      ..txSocket = socket
      ..onTelnyxWarning = warnings.add
      ..connectWithCredential(
        CredentialConfig(
          sipUser: 'user',
          sipPassword: 'pass',
          sipCallerIDName: 'name',
          sipCallerIDNumber: 'number',
          logLevel: LogLevel.none,
          debug: false,
          autoReconnect: true,
        ),
      );
    addTearDown(client.dispose);
    await pumpEventQueue();
    socket.emitOpen();

    final peerConnection = _FakePeerConnection();
    final peer = Peer(socket, false, client, false, false)
      ..attachPeerConnectionForTest(peerConnection);
    final call = client.call
      ..callId = 'call-1'
      ..peerConnection = peer;
    client.calls['call-1'] = call;
    call.callHandler.changeState(CallState.active);
    final monitor = call.recoveryMonitor!;

    // A confirmed response makes signaling "recent": restart without a probe.
    socket.emitMessage({'jsonrpc': '2.0', 'id': 'login', 'result': {}});
    await pumpEventQueue();
    socket.sent.clear();

    monitor.onIceConnectionStateChanged(
      RTCIceConnectionState.RTCIceConnectionStateFailed,
    );
    await _until(() => socket.sentWithMethod('telnyx_rtc.modify').isNotEmpty);

    expect(socket.sentWithMethod('telnyx_rtc.ping'), isEmpty);
    expect(peerConnection.offerConstraints.single, {
      'mandatory': {'IceRestart': true},
      'optional': [],
    });
    final modify = socket.sentWithMethod('telnyx_rtc.modify').single;
    final params = modify['params'] as Map<String, dynamic>;
    expect(params['action'], 'updateMedia');
    expect(params['sdp'], 'offer-sdp-with-new-candidates');
    expect(call.callState, CallState.active);
    expect(monitor.state, CallRecoveryState.iceRestarting);

    // An unrelated updateMedia response must not be taken as the answer; the
    // matching one is applied exactly once (not again by the legacy handler).
    socket
      ..emitMessage({
        'jsonrpc': '2.0',
        'id': 'someone-else',
        'result': {'action': 'updateMedia', 'callID': 'call-1', 'sdp': 'stale'},
      })
      ..emitMessage({
        'jsonrpc': '2.0',
        'id': modify['id'],
        'result': {
          'action': 'updateMedia',
          'callID': 'call-1',
          'sdp': 'answer',
        },
      });
    await _until(() => monitor.state == CallRecoveryState.verifyingMedia);
    await pumpEventQueue();
    expect(peerConnection.remoteDescriptions, <String?>['answer']);

    peerConnection.ice = RTCIceConnectionState.RTCIceConnectionStateConnected;
    await _until(() => monitor.state == CallRecoveryState.idle);

    // A duplicate of the answered recovery response never reaches the legacy
    // handler either.
    socket.emitMessage({
      'jsonrpc': '2.0',
      'id': modify['id'],
      'result': {'action': 'updateMedia', 'callID': 'call-1', 'sdp': 'dup'},
    });
    await pumpEventQueue();
    expect(peerConnection.remoteDescriptions, <String?>['answer']);

    expect(
      warnings.map((w) => w.warning.code),
      contains(TelnyxWarningCodes.mediaRecoveryRequired),
    );
    expect(
      warnings.map((w) => w.warning.code),
      isNot(contains(TelnyxWarningCodes.signalingRecoveryRequired)),
      reason: 'a successful restart must not fall back to reattach',
    );
  });
}
