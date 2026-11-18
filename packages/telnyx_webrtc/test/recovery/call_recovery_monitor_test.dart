import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:telnyx_webrtc/src/recovery/call_recovery_monitor.dart';

// ── Test doubles ─────────────────────────────────────────────────────

class _FakeTimer implements Timer {
  _FakeTimer(this.deadline, this._callback);

  final Duration deadline;
  final void Function() _callback;
  bool _active = true;

  void fire() {
    if (!_active) return;
    _active = false;
    _callback();
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;
}

/// Virtual clock: timers only fire inside [elapse], and microtasks are
/// drained after each fire so async continuations settle deterministically.
class _FakeTimers {
  Duration _now = Duration.zero;
  final List<_FakeTimer> _timers = <_FakeTimer>[];

  Timer create(Duration duration, void Function() callback) {
    final timer = _FakeTimer(_now + duration, callback);
    _timers.add(timer);
    return timer;
  }

  int get pending => _timers.where((t) => t.isActive).length;

  Future<void> elapse(Duration duration) async {
    final target = _now + duration;
    await _flush();
    while (true) {
      final due = _timers
          .where((t) => t.isActive && t.deadline <= target)
          .toList()
        ..sort((a, b) => a.deadline.compareTo(b.deadline));
      if (due.isEmpty) break;
      final next = due.first;
      _now = next.deadline;
      next.fire();
      await _flush();
    }
    _now = target;
  }
}

Future<void> _flush() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _FakeDelegate extends CallRecoveryDelegate {
  @override
  bool isCallActive = true;

  @override
  bool isSignalingAvailable = true;

  @override
  bool isClientReconnecting = false;

  @override
  Duration? inboundSignalingIdle = const Duration(seconds: 1);

  @override
  Duration? confirmedOutboundIdle = const Duration(seconds: 1);

  @override
  RTCIceConnectionState? peerIceState =
      RTCIceConnectionState.RTCIceConnectionStateFailed;

  @override
  RTCPeerConnectionState? peerConnectionState =
      RTCPeerConnectionState.RTCPeerConnectionStateConnected;

  /// When set, `sendSignalingProbe` waits on it; otherwise returns
  /// [probeResult] immediately.
  Completer<SignalingProbeResult>? probeCompleter;
  SignalingProbeResult probeResult = SignalingProbeResult.ok;
  int probeCalls = 0;

  Completer<String>? restartCompleter;
  Object? restartError;
  int restartCalls = 0;
  final List<bool> applicationRequestedRestarts = <bool>[];

  Completer<String>? updateMediaCompleter;
  final List<String> sentOffers = <String>[];

  Object? applyAnswerError;
  final List<String> appliedAnswers = <String>[];

  /// Successive values returned by `getInboundAudioPackets`; the last value
  /// repeats once exhausted.
  List<int?> packetSamples = <int?>[100];
  int packetReads = 0;

  Completer<bool>? reattachCompleter;
  bool reattachResult = true;
  int reattachCalls = 0;

  Completer<CandidateEvidence?>? evidenceCompleter;
  CandidateEvidence? evidence;
  int evidenceCalls = 0;
  final List<CandidateEvidence> capturedEvidence = <CandidateEvidence>[];

  final List<RecoveryOutcome> recovered = <RecoveryOutcome>[];
  int recoveryFailedCalls = 0;

  @override
  Future<SignalingProbeResult> sendSignalingProbe() {
    probeCalls += 1;
    return probeCompleter?.future ?? Future.value(probeResult);
  }

  @override
  Future<String> restartIce({bool applicationRequested = false}) {
    restartCalls += 1;
    applicationRequestedRestarts.add(applicationRequested);
    if (restartError != null) return Future.error(restartError!);
    return restartCompleter?.future ?? Future.value('offer-$restartCalls');
  }

  @override
  Future<String> sendUpdateMedia(String offerSdp) {
    sentOffers.add(offerSdp);
    return updateMediaCompleter?.future ?? Future.value('answer-for-$offerSdp');
  }

  @override
  Future<void> applyRemoteAnswer(String answerSdp) async {
    if (applyAnswerError != null) throw applyAnswerError!;
    appliedAnswers.add(answerSdp);
  }

  @override
  Future<int?> getInboundAudioPackets() async {
    final index = packetReads < packetSamples.length
        ? packetReads
        : packetSamples.length - 1;
    packetReads += 1;
    return packetSamples[index];
  }

  @override
  Future<bool> performReattachFallback() {
    reattachCalls += 1;
    return reattachCompleter?.future ?? Future.value(reattachResult);
  }

  @override
  Future<CandidateEvidence?> getSelectedCandidateEvidence() {
    evidenceCalls += 1;
    return evidenceCompleter?.future ?? Future.value(evidence);
  }

  @override
  void onCandidateEvidenceCaptured(CandidateEvidence evidence) =>
      capturedEvidence.add(evidence);

  @override
  void onRecovered(RecoveryOutcome outcome) => recovered.add(outcome);

  @override
  void onRecoveryFailed() => recoveryFailedCalls += 1;
}

const _iceFailed = RTCIceConnectionState.RTCIceConnectionStateFailed;
const _iceDisconnected =
    RTCIceConnectionState.RTCIceConnectionStateDisconnected;
const _iceConnected = RTCIceConnectionState.RTCIceConnectionStateConnected;
const _pcFailed = RTCPeerConnectionState.RTCPeerConnectionStateFailed;
const _pcDisconnected =
    RTCPeerConnectionState.RTCPeerConnectionStateDisconnected;
const _pcConnected = RTCPeerConnectionState.RTCPeerConnectionStateConnected;

Duration _s(num seconds) => Duration(milliseconds: (seconds * 1000).round());

void main() {
  late _FakeTimers timers;
  late _FakeDelegate delegate;
  late CallRecoveryMonitor monitor;

  setUp(() {
    timers = _FakeTimers();
    delegate = _FakeDelegate();
    monitor = CallRecoveryMonitor(
      callId: 'call-1234567890',
      delegate: delegate,
      createTimer: timers.create,
    );
  });

  tearDown(() => monitor.dispose());

  /// Moves a restarted call through verification with RTP growth.
  Future<void> verifyWithGrowth() async {
    // Baseline read, warm-up poll, then a growing sample.
    delegate.packetSamples = <int?>[100, 100, 150];
    await timers.elapse(_s(2));
  }

  group('ICE failure with healthy signaling', () {
    test('restarts ICE on the same peer and verifies RTP growth', () async {
      delegate.packetSamples = <int?>[100, 100, 150];

      monitor.onIceConnectionStateChanged(_iceFailed);
      await timers.elapse(Duration.zero);

      expect(delegate.probeCalls, 0);
      expect(delegate.restartCalls, 1);
      expect(delegate.sentOffers, <String>['offer-1']);
      expect(delegate.appliedAnswers, <String>['answer-for-offer-1']);
      expect(monitor.state, CallRecoveryState.verifyingMedia);

      await timers.elapse(_s(2));

      expect(monitor.state, CallRecoveryState.idle);
      expect(delegate.recovered, <RecoveryOutcome>[RecoveryOutcome.iceRestart]);
      expect(delegate.reattachCalls, 0);
      expect(timers.pending, 0);
    });

    test('stays in iceRestarting until the answer is applied', () async {
      delegate.updateMediaCompleter = Completer<String>();

      monitor.onIceConnectionStateChanged(_iceFailed);
      await timers.elapse(_s(5));
      expect(monitor.state, CallRecoveryState.iceRestarting);

      delegate.updateMediaCompleter!.complete('late-answer');
      await timers.elapse(Duration.zero);
      expect(delegate.appliedAnswers, <String>['late-answer']);
      expect(monitor.state, CallRecoveryState.verifyingMedia);
    });

    test('duplicate failures during an episode start one restart', () async {
      delegate.updateMediaCompleter = Completer<String>();

      monitor
        ..onIceConnectionStateChanged(_iceFailed)
        ..onIceConnectionStateChanged(_iceFailed)
        ..onPeerConnectionStateChanged(_pcFailed);
      await timers.elapse(_s(1));

      expect(delegate.restartCalls, 1);
      expect(monitor.generation, 1);
    });

    test('skips the episode when ICE is already connected', () async {
      delegate.peerIceState = _iceConnected;

      monitor.onIceConnectionStateChanged(_iceFailed);
      await timers.elapse(Duration.zero);

      expect(monitor.state, CallRecoveryState.idle);
      expect(delegate.restartCalls, 0);
    });

    test('ignores failures on non-active calls and during client reconnect',
        () async {
      delegate.isCallActive = false;
      monitor.onIceConnectionStateChanged(_iceFailed);
      await timers.elapse(Duration.zero);
      expect(delegate.restartCalls, 0);

      delegate
        ..isCallActive = true
        ..isClientReconnecting = true;
      monitor.onIceConnectionStateChanged(_iceFailed);
      await timers.elapse(Duration.zero);
      expect(delegate.restartCalls, 0);
      expect(monitor.state, CallRecoveryState.idle);
    });
  });

  group('signaling gating', () {
    test('stale signaling probes before restarting', () async {
      delegate
        ..inboundSignalingIdle = _s(10)
        ..probeCompleter = Completer<SignalingProbeResult>();

      monitor.onIceConnectionStateChanged(_iceFailed);
      await timers.elapse(Duration.zero);
      expect(monitor.state, CallRecoveryState.probing);
      expect(delegate.probeCalls, 1);
      expect(delegate.restartCalls, 0);

      delegate.probeCompleter!.complete(SignalingProbeResult.ok);
      await timers.elapse(Duration.zero);
      expect(delegate.restartCalls, 1);
    });

    test('missing signaling timestamps count as stale', () async {
      delegate
        ..inboundSignalingIdle = null
        ..confirmedOutboundIdle = null;

      monitor.onIceConnectionStateChanged(_iceFailed);
      await timers.elapse(Duration.zero);

      expect(delegate.probeCalls, 1);
    });

    test('an unanswered probe falls back to one reattach after 5 s', () async {
      delegate
        ..inboundSignalingIdle = _s(10)
        ..probeCompleter = Completer<SignalingProbeResult>();

      monitor.onIceConnectionStateChanged(_iceFailed);
      await timers.elapse(_s(4.9));
      expect(delegate.reattachCalls, 0);

      await timers.elapse(_s(0.1));
      expect(delegate.reattachCalls, 1);
      expect(delegate.restartCalls, 0);
      expect(delegate.recovered, <RecoveryOutcome>[RecoveryOutcome.reattach]);
      expect(monitor.state, CallRecoveryState.idle);
    });

    test('a probe error falls back to reattach', () async {
      delegate
        ..inboundSignalingIdle = _s(10)
        ..probeResult = SignalingProbeResult.error;

      monitor.onIceConnectionStateChanged(_iceFailed);
      await timers.elapse(Duration.zero);

      expect(delegate.reattachCalls, 1);
    });

    test('unavailable signaling reattaches without restarting', () async {
      delegate.isSignalingAvailable = false;

      monitor.onIceConnectionStateChanged(_iceFailed);
      await timers.elapse(Duration.zero);

      expect(delegate.probeCalls, 0);
      expect(delegate.restartCalls, 0);
      expect(delegate.reattachCalls, 1);
    });
  });

  group('disconnected delay', () {
    test('ICE reconnecting inside 3 s cancels the delay', () async {
      monitor.onIceConnectionStateChanged(_iceDisconnected);
      await timers.elapse(_s(2));
      monitor.onIceConnectionStateChanged(_iceConnected);
      await timers.elapse(_s(5));

      expect(monitor.state, CallRecoveryState.idle);
      expect(delegate.restartCalls, 0);
      expect(timers.pending, 0);
    });

    test('ICE still disconnected after 3 s starts recovery', () async {
      delegate.peerIceState = _iceDisconnected;

      monitor.onIceConnectionStateChanged(_iceDisconnected);
      await timers.elapse(_s(2.9));
      expect(delegate.restartCalls, 0);

      await timers.elapse(_s(0.1));
      expect(delegate.restartCalls, 1);
    });

    test('the delay is judged against the live ICE state at fire time',
        () async {
      monitor.onIceConnectionStateChanged(_iceDisconnected);
      // ICE recovered without a callback reaching the monitor.
      delegate.peerIceState = _iceConnected;
      await timers.elapse(_s(3));

      expect(delegate.restartCalls, 0);
      expect(monitor.state, CallRecoveryState.idle);
    });

    test('a peer connection disconnected for 3 s starts recovery', () async {
      delegate.peerConnectionState = _pcDisconnected;

      monitor.onPeerConnectionStateChanged(_pcDisconnected);
      await timers.elapse(_s(3));

      expect(delegate.restartCalls, 1);
    });

    test('peer connection reconnecting cancels its delay', () async {
      monitor.onPeerConnectionStateChanged(_pcDisconnected);
      await timers.elapse(_s(1));
      monitor.onPeerConnectionStateChanged(_pcConnected);
      await timers.elapse(_s(5));

      expect(delegate.restartCalls, 0);
    });
  });

  group('peer-connection failures', () {
    test('start recovery even while ICE reports connected', () async {
      delegate
        ..peerIceState = _iceConnected
        ..peerConnectionState = _pcFailed;

      monitor.onPeerConnectionStateChanged(_pcFailed);
      await timers.elapse(Duration.zero);

      expect(delegate.restartCalls, 1);
    });

    test('ICE connected does not cancel a peer-connection probing episode',
        () async {
      delegate
        ..peerIceState = _iceConnected
        ..peerConnectionState = _pcFailed
        ..inboundSignalingIdle = _s(10)
        ..probeCompleter = Completer<SignalingProbeResult>();

      monitor.onPeerConnectionStateChanged(_pcFailed);
      await timers.elapse(Duration.zero);
      monitor.onIceConnectionStateChanged(_iceConnected);
      expect(monitor.state, CallRecoveryState.probing);

      delegate.probeCompleter!.complete(SignalingProbeResult.ok);
      await timers.elapse(Duration.zero);
      expect(delegate.restartCalls, 1);
    });

    test('ICE connected cancels an ICE probing episode', () async {
      delegate
        ..inboundSignalingIdle = _s(10)
        ..probeCompleter = Completer<SignalingProbeResult>();

      monitor.onIceConnectionStateChanged(_iceFailed);
      await timers.elapse(Duration.zero);
      monitor.onIceConnectionStateChanged(_iceConnected);
      expect(monitor.state, CallRecoveryState.idle);

      // The late probe answer belongs to a cancelled generation.
      delegate.probeCompleter!.complete(SignalingProbeResult.ok);
      await timers.elapse(Duration.zero);
      expect(delegate.restartCalls, 0);
    });
  });

  group('restart failures and timeouts', () {
    test('an exchange failure falls back to exactly one reattach', () async {
      delegate.restartError = StateError('createOffer failed');

      monitor.onIceConnectionStateChanged(_iceFailed);
      await timers.elapse(Duration.zero);

      expect(delegate.reattachCalls, 1);
      expect(delegate.recovered, <RecoveryOutcome>[RecoveryOutcome.reattach]);
    });

    test('an answer that cannot be applied falls back', () async {
      delegate.applyAnswerError = StateError('setRemoteDescription failed');

      monitor.onIceConnectionStateChanged(_iceFailed);
      await timers.elapse(Duration.zero);

      expect(delegate.reattachCalls, 1);
      expect(delegate.packetReads, 0);
    });

    test('a hung restart falls back after 15 s', () async {
      delegate.restartCompleter = Completer<String>();

      monitor.onIceConnectionStateChanged(_iceFailed);
      await timers.elapse(_s(14.9));
      expect(delegate.reattachCalls, 0);

      await timers.elapse(_s(0.1));
      expect(delegate.reattachCalls, 1);

      // The late offer belongs to the old generation and is ignored.
      delegate.restartCompleter!.complete('late-offer');
      await timers.elapse(Duration.zero);
      expect(delegate.sentOffers, isEmpty);
    });

    test('restart timeout with media reconnected hands over to verification',
        () async {
      delegate.restartCompleter = Completer<String>();

      monitor.onIceConnectionStateChanged(_iceFailed);
      await timers.elapse(Duration.zero);
      delegate.peerIceState = _iceConnected;
      await timers.elapse(_s(15));

      expect(monitor.state, CallRecoveryState.verifyingMedia);
      expect(delegate.reattachCalls, 0);

      await verifyWithGrowth();
      expect(delegate.recovered, <RecoveryOutcome>[RecoveryOutcome.iceRestart]);
    });

    test('a late answer is still applied after handover to verification',
        () async {
      delegate.updateMediaCompleter = Completer<String>();

      monitor.onIceConnectionStateChanged(_iceFailed);
      await timers.elapse(Duration.zero);
      delegate.peerIceState = _iceConnected;
      await timers.elapse(_s(15));
      expect(monitor.state, CallRecoveryState.verifyingMedia);

      delegate.updateMediaCompleter!.complete('late-answer');
      await timers.elapse(Duration.zero);
      expect(delegate.appliedAnswers, <String>['late-answer']);
      expect(monitor.state, CallRecoveryState.verifyingMedia);
    });
  });

  group('media verification', () {
    test('no inbound RTP growth falls back after 5 s', () async {
      delegate.packetSamples = <int?>[100];

      monitor.onIceConnectionStateChanged(_iceFailed);
      await timers.elapse(_s(4.9));
      expect(monitor.state, CallRecoveryState.verifyingMedia);

      await timers.elapse(_s(0.1));
      expect(delegate.reattachCalls, 1);
    });

    test('growth on the warm-up poll is not counted', () async {
      // Baseline 100, warm-up 150 (ignored), then 150 again: no growth
      // relative to the baseline is judged until the second poll.
      delegate.packetSamples = <int?>[100, 150, 150];

      monitor.onIceConnectionStateChanged(_iceFailed);
      await timers.elapse(_s(1));
      expect(monitor.state, CallRecoveryState.verifyingMedia);

      await timers.elapse(_s(1));
      expect(monitor.state, CallRecoveryState.idle);
      expect(delegate.recovered, <RecoveryOutcome>[RecoveryOutcome.iceRestart]);
    });

    test('unavailable packet counters cannot confirm recovery', () async {
      delegate.packetSamples = <int?>[null];

      monitor.onIceConnectionStateChanged(_iceFailed);
      await timers.elapse(_s(5));

      expect(delegate.recovered, <RecoveryOutcome>[RecoveryOutcome.reattach]);
    });

    test('an unavailable first read takes the next usable counter as baseline',
        () async {
      delegate.packetSamples = <int?>[null, 100, 150, 200, 250, 300];

      monitor.onIceConnectionStateChanged(_iceFailed);
      await timers.elapse(_s(1));
      expect(monitor.state, CallRecoveryState.verifyingMedia);

      await timers.elapse(_s(1));
      expect(monitor.state, CallRecoveryState.idle);
      expect(delegate.recovered, <RecoveryOutcome>[RecoveryOutcome.iceRestart]);
      expect(delegate.reattachCalls, 0);
    });

    test('a late baseline still requires growth and keeps the deadline',
        () async {
      // Counters only become readable at 4 s and never grow afterwards.
      delegate.packetSamples = <int?>[null, null, null, null, 100];

      monitor.onIceConnectionStateChanged(_iceFailed);
      await timers.elapse(_s(4.9));
      expect(monitor.state, CallRecoveryState.verifyingMedia);

      await timers.elapse(_s(0.1));
      expect(delegate.reattachCalls, 1);
      expect(delegate.recovered, <RecoveryOutcome>[RecoveryOutcome.reattach]);
    });

    test('a new failure during verification falls back immediately', () async {
      monitor.onIceConnectionStateChanged(_iceFailed);
      await timers.elapse(Duration.zero);
      expect(monitor.state, CallRecoveryState.verifyingMedia);

      monitor.onIceConnectionStateChanged(_iceFailed);
      await timers.elapse(Duration.zero);

      expect(delegate.reattachCalls, 1);
    });
  });

  group('reattach fallback', () {
    test('fires at most once per episode', () async {
      delegate
        ..reattachCompleter = Completer<bool>()
        ..isSignalingAvailable = false;

      monitor.onIceConnectionStateChanged(_iceFailed);
      await timers.elapse(Duration.zero);
      monitor
        ..onIceConnectionStateChanged(_iceFailed)
        ..onPeerConnectionStateChanged(_pcFailed)
        ..checkSignalingHealth();
      await timers.elapse(_s(30));

      expect(delegate.reattachCalls, 1);
      expect(monitor.state, CallRecoveryState.reattaching);
    });

    test('a failed reattach latches until media reconnects', () async {
      delegate
        ..isSignalingAvailable = false
        ..reattachResult = false;

      monitor.onIceConnectionStateChanged(_iceFailed);
      await timers.elapse(Duration.zero);
      expect(delegate.recoveryFailedCalls, 1);
      expect(monitor.state, CallRecoveryState.idle);

      monitor
        ..onIceConnectionStateChanged(_iceFailed)
        ..checkSignalingHealth();
      await timers.elapse(Duration.zero);
      expect(delegate.reattachCalls, 1);

      // ICE seen connected again clears the latch.
      monitor
        ..onIceConnectionStateChanged(_iceConnected)
        ..onIceConnectionStateChanged(_iceFailed);
      await timers.elapse(Duration.zero);
      expect(delegate.reattachCalls, 2);
    });

    test('media episodes pass relay evidence before reattaching', () async {
      const evidence = CandidateEvidence(
        callId: 'call-1234567890',
        localCandidateType: 'host',
        localNetworkType: 'vpn',
      );
      delegate
        ..evidence = evidence
        ..isSignalingAvailable = false;

      monitor.onIceConnectionStateChanged(_iceFailed);
      await timers.elapse(Duration.zero);

      expect(delegate.evidenceCalls, 1);
      expect(delegate.capturedEvidence, <CandidateEvidence>[evidence]);
      expect(delegate.reattachCalls, 1);
    });

    test('a stalled evidence read cannot block the reattach', () async {
      delegate
        ..evidenceCompleter = Completer<CandidateEvidence?>()
        ..isSignalingAvailable = false;

      monitor.onIceConnectionStateChanged(_iceFailed);
      await timers.elapse(_s(0.9));
      expect(delegate.reattachCalls, 0);

      await timers.elapse(_s(0.1));
      expect(delegate.reattachCalls, 1);
      expect(delegate.capturedEvidence, isEmpty);
    });

    test('a call that ended during evidence capture is not reattached',
        () async {
      delegate
        ..evidenceCompleter = Completer<CandidateEvidence?>()
        ..isSignalingAvailable = false;

      monitor.onIceConnectionStateChanged(_iceFailed);
      await timers.elapse(Duration.zero);
      delegate
        ..isCallActive = false
        ..evidenceCompleter!.complete(null);
      await timers.elapse(Duration.zero);

      expect(delegate.reattachCalls, 0);
    });
  });

  group('periodic signaling health check', () {
    test('does nothing while signaling is fresh', () async {
      monitor.checkSignalingHealth();
      await timers.elapse(Duration.zero);

      expect(delegate.probeCalls, 0);
      expect(monitor.state, CallRecoveryState.idle);
    });

    test('probes stale signaling and returns to idle when answered', () async {
      delegate
        ..peerIceState = _iceConnected
        ..inboundSignalingIdle = _s(20);

      monitor.checkSignalingHealth();
      await timers.elapse(Duration.zero);

      expect(delegate.probeCalls, 1);
      expect(delegate.restartCalls, 0);
      expect(monitor.state, CallRecoveryState.idle);
    });

    test('treats 45 s without a confirmed response as stale', () async {
      delegate
        ..peerIceState = _iceConnected
        ..confirmedOutboundIdle = _s(45);

      monitor.checkSignalingHealth();
      await timers.elapse(Duration.zero);

      expect(delegate.probeCalls, 1);
    });

    test('an unanswered health probe reattaches without relay evidence',
        () async {
      delegate
        ..peerIceState = _iceConnected
        ..inboundSignalingIdle = _s(20)
        ..probeResult = SignalingProbeResult.timeout;

      monitor.checkSignalingHealth();
      await timers.elapse(Duration.zero);

      expect(delegate.reattachCalls, 1);
      expect(delegate.evidenceCalls, 0);
    });

    test('reattaches immediately when the socket is unavailable', () async {
      delegate.isSignalingAvailable = false;

      monitor.checkSignalingHealth();
      await timers.elapse(Duration.zero);

      expect(delegate.reattachCalls, 1);
      expect(delegate.evidenceCalls, 0);
    });

    test('a media failure during a health probe is deferred, not dropped',
        () async {
      delegate
        ..peerIceState = _iceConnected
        ..inboundSignalingIdle = _s(20)
        ..probeCompleter = Completer<SignalingProbeResult>();

      monitor.checkSignalingHealth();
      await timers.elapse(Duration.zero);

      delegate.peerIceState = _iceFailed;
      monitor.onIceConnectionStateChanged(_iceFailed);
      await timers.elapse(Duration.zero);
      expect(delegate.restartCalls, 0);

      delegate.probeCompleter!.complete(SignalingProbeResult.ok);
      await timers.elapse(Duration.zero);
      expect(delegate.restartCalls, 1);
    });

    test('ICE recovering does not erase a still-failed peer connection',
        () async {
      delegate
        ..peerIceState = _iceConnected
        ..inboundSignalingIdle = _s(20)
        ..probeCompleter = Completer<SignalingProbeResult>();

      monitor.checkSignalingHealth();
      await timers.elapse(Duration.zero);

      delegate.peerConnectionState = _pcFailed;
      monitor.onPeerConnectionStateChanged(_pcFailed);
      delegate.peerIceState = _iceFailed;
      monitor.onIceConnectionStateChanged(_iceFailed);
      delegate.peerIceState = _iceConnected;
      monitor.onIceConnectionStateChanged(_iceConnected);
      await timers.elapse(Duration.zero);
      expect(delegate.restartCalls, 0);

      delegate.probeCompleter!.complete(SignalingProbeResult.ok);
      await timers.elapse(Duration.zero);
      expect(delegate.restartCalls, 1);

      // The episode is owned by the peer connection, so ICE `connected`
      // cannot cancel it.
      expect(monitor.state, isNot(CallRecoveryState.idle));
    });

    test('a deferred failure cleared by reconnect returns to idle', () async {
      delegate
        ..peerIceState = _iceConnected
        ..inboundSignalingIdle = _s(20)
        ..probeCompleter = Completer<SignalingProbeResult>();

      monitor.checkSignalingHealth();
      await timers.elapse(Duration.zero);
      monitor
        ..onIceConnectionStateChanged(_iceFailed)
        ..onIceConnectionStateChanged(_iceConnected);

      delegate.probeCompleter!.complete(SignalingProbeResult.ok);
      await timers.elapse(Duration.zero);
      expect(delegate.restartCalls, 0);
      expect(monitor.state, CallRecoveryState.idle);
    });
  });

  group('application-requested ICE restart', () {
    test('restarts immediately without probing', () async {
      delegate
        ..peerIceState = _iceConnected
        ..inboundSignalingIdle = _s(10);

      expect(monitor.requestIceRestart(), isTrue);
      await timers.elapse(Duration.zero);

      expect(delegate.probeCalls, 0);
      expect(delegate.restartCalls, 1);
      expect(delegate.applicationRequestedRestarts, <bool>[true]);
      expect(monitor.state, CallRecoveryState.verifyingMedia);

      await verifyWithGrowth();
      expect(delegate.recovered, <RecoveryOutcome>[RecoveryOutcome.iceRestart]);
    });

    test('is rejected when preconditions fail', () {
      delegate.isCallActive = false;
      expect(monitor.requestIceRestart(), isFalse);

      delegate
        ..isCallActive = true
        ..isSignalingAvailable = false;
      expect(monitor.requestIceRestart(), isFalse);

      delegate
        ..isSignalingAvailable = true
        ..isClientReconnecting = true;
      expect(monitor.requestIceRestart(), isFalse);
      expect(delegate.restartCalls, 0);
    });

    test('is rejected while recovery is already running', () async {
      delegate.restartCompleter = Completer<String>();

      expect(monitor.requestIceRestart(), isTrue);
      expect(monitor.requestIceRestart(), isFalse);
      await timers.elapse(Duration.zero);
      expect(delegate.restartCalls, 1);
    });
  });

  group('generations and cleanup', () {
    test('cancel invalidates in-flight continuations', () async {
      delegate.updateMediaCompleter = Completer<String>();

      monitor.onIceConnectionStateChanged(_iceFailed);
      await timers.elapse(Duration.zero);
      final generation = monitor.generation;

      monitor.cancel('call-ended');
      expect(monitor.generation, greaterThan(generation));
      expect(monitor.state, CallRecoveryState.idle);

      delegate.updateMediaCompleter!.complete('late-answer');
      await timers.elapse(_s(30));
      expect(delegate.appliedAnswers, isEmpty);
      expect(delegate.reattachCalls, 0);
      expect(timers.pending, 0);
    });

    test('a late answer from a cancelled episode cannot touch a new one',
        () async {
      final first = Completer<String>();
      delegate.updateMediaCompleter = first;

      monitor.onIceConnectionStateChanged(_iceFailed);
      await timers.elapse(Duration.zero);
      monitor.cancel('superseded');

      final second = Completer<String>();
      delegate.updateMediaCompleter = second;
      monitor.onIceConnectionStateChanged(_iceFailed);
      await timers.elapse(Duration.zero);

      first.complete('stale-answer');
      await timers.elapse(Duration.zero);
      expect(delegate.appliedAnswers, isEmpty);
      expect(monitor.state, CallRecoveryState.iceRestarting);

      second.complete('fresh-answer');
      await timers.elapse(Duration.zero);
      expect(delegate.appliedAnswers, <String>['fresh-answer']);
    });

    test('a network path change hands an episode to the client reconnect',
        () async {
      delegate.updateMediaCompleter = Completer<String>();

      monitor.onIceConnectionStateChanged(_iceFailed);
      await timers.elapse(Duration.zero);
      expect(monitor.state, CallRecoveryState.iceRestarting);

      monitor.onNetworkPathChanged();
      expect(monitor.state, CallRecoveryState.idle);

      delegate.updateMediaCompleter!.complete('late-answer');
      await timers.elapse(_s(30));
      expect(delegate.appliedAnswers, isEmpty);
      expect(delegate.reattachCalls, 0);
      expect(delegate.evidenceCalls, 0);
    });

    test('dispose cancels timers and ignores later inputs', () async {
      monitor
        ..onIceConnectionStateChanged(_iceDisconnected)
        ..onPeerConnectionStateChanged(_pcDisconnected);
      expect(timers.pending, 2);

      monitor.dispose();
      expect(timers.pending, 0);
      expect(monitor.isDisposed, isTrue);

      monitor
        ..onIceConnectionStateChanged(_iceFailed)
        ..checkSignalingHealth();
      expect(monitor.requestIceRestart(), isFalse);
      await timers.elapse(_s(30));
      expect(delegate.restartCalls, 0);
      expect(delegate.reattachCalls, 0);
    });
  });
}
