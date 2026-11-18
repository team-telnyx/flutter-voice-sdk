import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:telnyx_webrtc/utils/logging/global_logger.dart';

/// Phases of the per-call recovery state machine (VSDK-680).
///
/// ```text
///   idle ──(ICE failed / disconnected > 3 s)──▶ probing ──▶ iceRestarting
///                                                           │
///                     ┌─────────────────────────────────────┤
///                     ▼                                     ▼
///              verifyingMedia                          reattaching
///                     │                                     │
///                     ├── RTP growth ──▶ idle (success)     ├── replacement call ──▶ idle
///                     └── no growth ──▶ reattaching         └── attempt failed ──▶ idle
/// ```
enum CallRecoveryState {
  /// No recovery in flight.
  idle,

  /// A failure was observed (or signaling looks stale) and the monitor is
  /// probing signaling before choosing between ICE restart and reattach.
  probing,

  /// An ICE restart offer / `updateMedia` exchange is in flight on the same
  /// peer connection.
  iceRestarting,

  /// The restart answer has been applied; waiting for inbound RTP growth.
  verifyingMedia,

  /// The single per-episode reconnect / reattach fallback is running.
  reattaching,
}

/// The kind of media failure observed on the peer.
enum RecoveryFailureKind {
  /// Definitive failure: recovery starts immediately.
  failed,

  /// Transient failure: recovery starts only after the disconnected delay.
  disconnected,
}

/// Which recovery path restored the call.
enum RecoveryOutcome {
  /// Same-peer ICE restart, confirmed by inbound RTP growth.
  iceRestart,

  /// Client-owned reconnect / reattach produced a replacement call.
  reattach,
}

/// Result of a correlated `telnyx_rtc.ping` signaling probe.
enum SignalingProbeResult {
  /// The gateway answered this exact request (with a result or an error).
  ok,

  /// No correlated answer arrived in time.
  timeout,

  /// The probe could not be sent.
  error,
}

/// Selected ICE candidate pair captured when media failed. Used to decide
/// whether the replacement call should carry a one-shot relay-only override.
/// Without explicit evidence the SDK fails closed and does not alter the
/// transport policy.
class CandidateEvidence {
  /// Creates candidate evidence for [callId].
  const CandidateEvidence({
    this.callId,
    this.localCandidateType,
    this.remoteCandidateType,
    this.localNetworkType,
    this.localAddress,
    this.localProtocol,
  });

  /// The call the evidence was captured for.
  final String? callId;

  /// Local candidate type (`host`, `srflx`, `prflx`, `relay`).
  final String? localCandidateType;

  /// Remote candidate type (`host`, `srflx`, `prflx`, `relay`).
  final String? remoteCandidateType;

  /// Network type reported for the local candidate (e.g. `vpn`, `wifi`).
  final String? localNetworkType;

  /// Local candidate address. Never logged.
  final String? localAddress;

  /// Local candidate transport protocol (`udp` / `tcp`).
  final String? localProtocol;
}

/// Timing configuration. Defaults match the iOS / Android / React Native
/// `SignalingHealthMonitor`.
class CallRecoveryConfig {
  /// Creates a recovery configuration.
  const CallRecoveryConfig({
    this.iceRestartTimeout = const Duration(seconds: 15),
    this.signalingProbeTimeout = const Duration(seconds: 5),
    this.recentInboundActivityThreshold = const Duration(seconds: 3),
    this.confirmedOutboundActivityThreshold = const Duration(seconds: 45),
    this.staleInboundActivityThreshold = const Duration(seconds: 20),
    this.signalingHealthCheckInterval = const Duration(seconds: 3),
    this.postIceRestartMediaTimeout = const Duration(seconds: 5),
    this.postIceRestartMediaPoll = const Duration(seconds: 1),
    this.peerDisconnectedRecoveryDelay = const Duration(seconds: 3),
    this.candidateEvidenceTimeout = const Duration(seconds: 1),
  });

  /// Bound on a single ICE restart attempt (offer → answer applied).
  final Duration iceRestartTimeout;

  /// Bound on a correlated signaling probe.
  final Duration signalingProbeTimeout;

  /// Inbound signaling at most this old permits an immediate ICE restart.
  final Duration recentInboundActivityThreshold;

  /// A confirmed request/response at most this old counts as recent and
  /// not stale.
  final Duration confirmedOutboundActivityThreshold;

  /// Inbound signaling at least this old is stale for the periodic check.
  final Duration staleInboundActivityThreshold;

  /// How often the owner should call
  /// [CallRecoveryMonitor.checkSignalingHealth] while the call is active.
  final Duration signalingHealthCheckInterval;

  /// How long to wait for inbound RTP growth after the answer is applied.
  final Duration postIceRestartMediaTimeout;

  /// Poll interval for inbound RTP packet counters during verification.
  final Duration postIceRestartMediaPoll;

  /// How long ICE or the peer connection may stay `disconnected` before
  /// recovery starts.
  final Duration peerDisconnectedRecoveryDelay;

  /// Bound on the candidate-evidence stats read before a reattach, so a
  /// stalled `getStats()` cannot block the fallback.
  final Duration candidateEvidenceTimeout;
}

/// Side-effect surface used by [CallRecoveryMonitor]. The monitor owns the
/// recovery decisions and deadlines; `Peer` owns WebRTC renegotiation and
/// `TelnyxClient` owns the socket reconnect / reattach.
abstract class CallRecoveryDelegate {
  /// True while the monitored call is in the active state.
  bool get isCallActive;

  /// True when the signaling socket is currently connected.
  bool get isSignalingAvailable;

  /// True while the client-level reconnect flow owns recovery.
  bool get isClientReconnecting;

  /// Time since the last inbound signaling frame, or `null` if none.
  Duration? get inboundSignalingIdle;

  /// Time since an inbound frame last answered one of our requests, or
  /// `null` if none.
  Duration? get confirmedOutboundIdle;

  /// Current ICE connection state of the live peer, or `null` if disposed.
  RTCIceConnectionState? get peerIceState;

  /// Current peer connection state of the live peer, or `null` if disposed.
  RTCPeerConnectionState? get peerConnectionState;

  /// Sends one uniquely correlated `telnyx_rtc.ping`. Only the response to
  /// this exact request id may resolve it; any correlated response (result
  /// or error) proves the signaling path is alive.
  Future<SignalingProbeResult> sendSignalingProbe();

  /// Creates an ICE-restart offer on the existing peer connection and
  /// returns the local offer SDP. [applicationRequested] distinguishes a
  /// manual restart from automatic media recovery.
  Future<String> restartIce({bool applicationRequested = false});

  /// Sends `telnyx_rtc.modify` (`updateMedia`) with [offerSdp] and returns
  /// the answer SDP from the matching response.
  Future<String> sendUpdateMedia(String offerSdp);

  /// Applies [answerSdp] to the same peer connection. Must throw when the
  /// answer cannot be applied.
  Future<void> applyRemoteAnswer(String answerSdp);

  /// Latest inbound audio RTP packet counter, or `null` when unavailable.
  Future<int?> getInboundAudioPackets();

  /// Client-owned fallback: one reconnect / register / reattach. Completes
  /// with `true` when the backend attach for this call was received.
  Future<bool> performReattachFallback();

  /// Selected candidate-pair evidence from live stats, if available.
  Future<CandidateEvidence?> getSelectedCandidateEvidence() async => null;

  /// Called before the fallback so the client can carry a relay override.
  void onCandidateEvidenceCaptured(CandidateEvidence evidence) {}

  /// Called when an episode recovered the call.
  void onRecovered(RecoveryOutcome outcome) {}

  /// Called when the single reattach fallback failed.
  void onRecoveryFailed() {}
}

/// Creates a one-shot timer. Injectable so tests can drive deadlines
/// deterministically.
typedef RecoveryTimerFactory = Timer Function(
  Duration duration,
  void Function() callback,
);

enum _FailureSource { ice, peerConnection }

enum _ProbePurpose { mediaRecovery, healthCheck }

/// Per-call signaling-health and ICE-recovery monitor (VSDK-680).
///
/// Dart port of the `SignalingHealthMonitor` shared by the iOS, Android
/// (telnyx-webrtc-android #868) and React Native (react-native-voice-commons
/// #133) SDKs:
///
/// * ICE `failed` / peer-connection `failed` start an episode immediately;
///   `disconnected` starts one only if it persists for 3 s (judged at fire
///   time against the live peer state).
/// * Recently confirmed signaling → ICE restart; stale signaling → correlated
///   probe first; no signaling → reattach.
/// * The restart is bounded by 15 s and is confirmed by inbound RTP growth
///   within 5 s after the answer is applied.
/// * Any failure falls back to exactly one reconnect / reattach. After that
///   fallback fails, no new episode starts until media is seen connected.
/// * The periodic [checkSignalingHealth] probes stale signaling even while
///   media looks healthy.
///
/// Every asynchronous continuation captures the recovery generation, so a
/// stale timer, probe, or answer can never affect a newer attempt.
class CallRecoveryMonitor {
  /// Creates a monitor for [callId].
  CallRecoveryMonitor({
    required this.callId,
    required CallRecoveryDelegate delegate,
    this.config = const CallRecoveryConfig(),
    RecoveryTimerFactory? createTimer,
  })  : _delegate = delegate,
        _createTimer = createTimer ?? Timer.new;

  /// The call this monitor is scoped to.
  final String callId;

  /// Timing configuration.
  final CallRecoveryConfig config;

  final CallRecoveryDelegate _delegate;
  final RecoveryTimerFactory _createTimer;

  CallRecoveryState _state = CallRecoveryState.idle;
  int _generation = 0;
  bool _disposed = false;

  Timer? _iceDisconnectedTimer;
  Timer? _peerDisconnectedTimer;
  Timer? _restartTimeoutTimer;
  Timer? _verifyPollTimer;
  Timer? _verifyDeadlineTimer;

  _FailureSource? _episodeSource;
  _ProbePurpose? _probePurpose;

  /// Media failures observed while a signaling health probe was in flight,
  /// kept per source and acted on when that probe settles instead of being
  /// dropped. Per source so an ICE recovery cannot erase a peer connection
  /// that is still failed (Android upgrades the probe and never downgrades
  /// it; RN #133 keeps a single slot).
  final Map<_FailureSource, RecoveryFailureKind> _pendingMediaRecovery =
      <_FailureSource, RecoveryFailureKind>{};

  int? _verifyBaseline;

  /// One recovery attempt per failure period: set when the reattach fallback
  /// fails, cleared when ICE or the peer connection is seen connected again.
  bool _recoveryFailedLatch = false;

  /// Media-failure episodes may carry a relay override into the replacement
  /// call; signaling health-check episodes never do.
  bool _shouldEvaluateRelayFallback = false;

  /// Current recovery state.
  CallRecoveryState get state => _state;

  /// Monotonic recovery generation; bumps when an episode starts and on
  /// [cancel].
  int get generation => _generation;

  /// Whether an episode is running.
  bool get isRecoveryActive => _state != CallRecoveryState.idle;

  /// Whether [dispose] has been called.
  bool get isDisposed => _disposed;

  // ── Public inputs ──────────────────────────────────────────────────

  /// Starts an ICE restart requested explicitly by the application.
  ///
  /// Uses the same timeout, answer handling, RTP verification and single
  /// reattach fallback as automatic recovery. Accepted only for an active
  /// call with connected signaling, outside the client reconnect flow, and
  /// with no recovery already running.
  bool requestIceRestart() {
    if (_disposed) {
      _log('ICE restart request ignored; recovery monitor is disposed');
      return false;
    }
    if (!_delegate.isCallActive) {
      _log('ICE restart request ignored; call is not active');
      return false;
    }
    if (_state != CallRecoveryState.idle) {
      _log(
        'ICE restart request ignored; recovery is already in progress '
        '(state=${_state.name})',
      );
      return false;
    }
    if (!_delegate.isSignalingAvailable) {
      _log('ICE restart request ignored; signaling is unavailable');
      return false;
    }
    if (_delegate.isClientReconnecting) {
      _log('ICE restart request ignored; client reconnect is in progress');
      return false;
    }
    _cancelIceDisconnectedTimer();
    _cancelPeerDisconnectedTimer();
    _recoveryFailedLatch = false;
    _generation += 1;
    _episodeSource = _FailureSource.ice;
    _shouldEvaluateRelayFallback = true;
    _log('ICE restart requested by application');
    unawaited(_runRestart(applicationRequested: true));
    return true;
  }

  /// Observes an ICE connection state change on the monitored peer.
  void onIceConnectionStateChanged(RTCIceConnectionState state) {
    if (_disposed) return;
    switch (state) {
      case RTCIceConnectionState.RTCIceConnectionStateFailed:
        _notifyIceFailure(RecoveryFailureKind.failed);
      case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
        _notifyIceFailure(RecoveryFailureKind.disconnected);
      case RTCIceConnectionState.RTCIceConnectionStateConnected:
      case RTCIceConnectionState.RTCIceConnectionStateCompleted:
        _notifyIceConnected();
      default:
        return;
    }
  }

  /// Observes an `RTCPeerConnection.connectionState` change. A
  /// peer-connection failure is definitive even while ICE still reports
  /// connected (for example a DTLS failure).
  void onPeerConnectionStateChanged(RTCPeerConnectionState state) {
    if (_disposed) return;
    switch (state) {
      case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        _cancelPeerDisconnectedTimer();
        if (_canObserveFailure(_FailureSource.peerConnection)) {
          _requestMediaRecovery(
            RecoveryFailureKind.failed,
            _FailureSource.peerConnection,
          );
        }
      case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
        _startPeerDisconnectedDelay();
      case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        _recoveryFailedLatch = false;
        _cancelPeerDisconnectedTimer();
        _clearPendingMediaRecovery(_FailureSource.peerConnection);
      default:
        return;
    }
  }

  /// Observes sustained missing RTP while the transport still looks
  /// connected (the `LOW_BYTES_RECEIVED` / `LOW_BYTES_SENT` quality
  /// warnings, VSDK-416).
  ///
  /// Starts an episode only when idle: while an episode runs, RTP
  /// verification is the arbiter, and lingering low-byte intervals from
  /// before the restart must not force a premature fallback. Like a
  /// peer-connection failure, it bypasses the ICE already-connected guard.
  void onMediaStalled() {
    if (_disposed || _state != CallRecoveryState.idle) return;
    _requestMediaRecovery(
      RecoveryFailureKind.failed,
      _FailureSource.peerConnection,
    );
  }

  /// Hands recovery over to the client-owned reconnect that follows a
  /// network path change (Android `onNetworkPathDidChange`): any running
  /// episode is cancelled, so it can neither reattach a second time nor carry
  /// a relay override for an expected path switch. New failures stay ignored
  /// while the client reconnect flow runs.
  void onNetworkPathChanged() {
    if (_disposed) return;
    cancel('network-path-changed');
  }

  /// Periodic active-call signaling health check. The owner calls this every
  /// [CallRecoveryConfig.signalingHealthCheckInterval] while the call is
  /// active. It intentionally ignores ICE state: media can stay connected
  /// while the WebSocket is silently dead.
  ///
  /// * socket unavailable → reattach immediately
  /// * inbound idle ≥ 20 s or confirmed request/response idle ≥ 45 s →
  ///   probe; an answered probe returns to idle, an unanswered one reattaches
  void checkSignalingHealth() {
    if (_disposed ||
        !_delegate.isCallActive ||
        _delegate.isClientReconnecting) {
      return;
    }
    if (_state != CallRecoveryState.idle || _recoveryFailedLatch) return;

    if (!_delegate.isSignalingAvailable) {
      _generation += 1;
      _shouldEvaluateRelayFallback = false;
      _log('Signaling socket unavailable during an active call', warn: true);
      unawaited(_performFallback('active-call-signaling-unavailable'));
      return;
    }

    if (!_isSignalingStale) return;

    _generation += 1;
    _setState(CallRecoveryState.probing);
    _shouldEvaluateRelayFallback = false;
    _log(
      'Signaling activity is stale during an active call; probing',
      warn: true,
    );
    unawaited(_runProbe(_ProbePurpose.healthCheck));
  }

  /// Cancels all recovery work: terminal call states, hangup, peer disposal,
  /// client disconnect / logout, and replacement-call activation. Bumps the
  /// generation so stale async continuations become no-ops.
  void cancel(String reason) {
    _cancelIceDisconnectedTimer();
    _cancelPeerDisconnectedTimer();
    _cancelRestartTimeout();
    _cancelVerifyTimers();
    if (_state != CallRecoveryState.idle) {
      _log('Recovery cancelled (reason=$reason, state=${_state.name})');
    }
    _recoveryFailedLatch = false;
    _shouldEvaluateRelayFallback = false;
    _episodeSource = null;
    _probePurpose = null;
    _pendingMediaRecovery.clear();
    _generation += 1;
    _state = CallRecoveryState.idle;
  }

  /// Cancels all recovery work and ignores every later input.
  void dispose() {
    if (_disposed) return;
    cancel('disposed');
    _disposed = true;
  }

  // ── Failure routing ────────────────────────────────────────────────

  void _notifyIceFailure(RecoveryFailureKind kind) {
    if (!_canObserveFailure(_FailureSource.ice)) return;

    if (kind == RecoveryFailureKind.disconnected) {
      if (_iceDisconnectedTimer != null) return;
      _log('ICE disconnected, scheduling recovery delay');
      _iceDisconnectedTimer = _createTimer(
        config.peerDisconnectedRecoveryDelay,
        () {
          // Judged at fire time rather than by generation, so a health probe
          // answered inside the window does not drop it.
          _iceDisconnectedTimer = null;
          if (_disposed) return;
          if (_isMediaTransportConnected(_FailureSource.ice)) {
            _log('Transient ICE disconnect recovered before the delay');
            return;
          }
          _requestMediaRecovery(
            RecoveryFailureKind.disconnected,
            _FailureSource.ice,
          );
        },
      );
      return;
    }

    _requestMediaRecovery(RecoveryFailureKind.failed, _FailureSource.ice);
  }

  /// Cancels a pending ICE-disconnect delay and abandons an ICE-triggered
  /// probing phase. Running restart / verification episodes keep going: the
  /// in-flight exchange and RTP verification are the arbiter.
  void _notifyIceConnected() {
    _recoveryFailedLatch = false;
    if (_iceDisconnectedTimer != null) {
      _cancelIceDisconnectedTimer();
      _log('Transient ICE disconnect cleared, delay cancelled');
    }
    _clearPendingMediaRecovery(_FailureSource.ice);
    if (_state == CallRecoveryState.probing &&
        _episodeSource == _FailureSource.ice) {
      // A peer-connection episode is not cleared by ICE: ICE can report
      // connected while the peer connection itself has failed.
      cancel('ice-recovered-before-restart');
    }
  }

  /// Shared guard for ICE and peer-connection failures. Ignores failures on
  /// non-active calls and while the client reconnect flow owns recovery; a
  /// failure during media verification falls back immediately.
  bool _canObserveFailure(_FailureSource source) {
    if (!_delegate.isCallActive || _delegate.isClientReconnecting) {
      return false;
    }
    if (_state == CallRecoveryState.verifyingMedia) {
      _log(
        '${_describe(source)} failed again during verification, falling back',
        warn: true,
      );
      unawaited(
        _performFallback(
          source == _FailureSource.ice
              ? 'ice-failed-during-verification'
              : 'peer-connection-failed-during-verification',
        ),
      );
      return false;
    }
    return true;
  }

  /// Starts an episode when idle, defers the failure behind an in-flight
  /// signaling health probe, or lets the running media episode cover it.
  void _requestMediaRecovery(
    RecoveryFailureKind kind,
    _FailureSource source,
  ) {
    if (_state == CallRecoveryState.idle) {
      _startEpisode(kind, source);
      return;
    }

    if (_state == CallRecoveryState.probing &&
        _probePurpose == _ProbePurpose.healthCheck) {
      _pendingMediaRecovery[source] = kind;
      _shouldEvaluateRelayFallback = true;
      _log(
        'Media failure during a signaling health probe; recovery deferred '
        '(kind=${kind.name}, source=${source.name})',
      );
      return;
    }

    if (source == _FailureSource.peerConnection &&
        _episodeSource == _FailureSource.ice) {
      // The running ICE episode now also covers a failed peer connection, so
      // a later ICE `connected` must not cancel it.
      _episodeSource = _FailureSource.peerConnection;
      _log('Peer connection failed during an ICE recovery episode');
    }
  }

  void _clearPendingMediaRecovery(_FailureSource source) {
    if (_pendingMediaRecovery.remove(source) == null) return;
    if (_pendingMediaRecovery.isEmpty) _shouldEvaluateRelayFallback = false;
    _log('${_describe(source)} reconnected; deferred recovery cleared');
  }

  /// A peer connection that stays disconnected for the delay starts
  /// recovery. Only a peer-connection `connected` (or failure / cancel)
  /// clears it; ICE state does not.
  void _startPeerDisconnectedDelay() {
    // Armed whatever the monitor is doing, so a disconnect seen during a
    // signaling health probe is not dropped; _requestMediaRecovery decides
    // what to do with it when the delay fires.
    if (!_delegate.isCallActive || _delegate.isClientReconnecting) return;
    _cancelPeerDisconnectedTimer();
    _log('Peer connection disconnected, scheduling recovery delay');
    _peerDisconnectedTimer = _createTimer(
      config.peerDisconnectedRecoveryDelay,
      () {
        _peerDisconnectedTimer = null;
        if (_disposed) return;
        if (_isMediaTransportConnected(_FailureSource.peerConnection)) {
          _log('Peer connection recovered before the disconnected delay');
          return;
        }
        _log(
          'Peer connection stayed disconnected for '
          '${config.peerDisconnectedRecoveryDelay.inMilliseconds} ms; '
          'starting recovery',
          warn: true,
        );
        _requestMediaRecovery(
          RecoveryFailureKind.disconnected,
          _FailureSource.peerConnection,
        );
      },
    );
  }

  // ── Episode machinery ──────────────────────────────────────────────

  void _startEpisode(RecoveryFailureKind kind, _FailureSource source) {
    if (_state != CallRecoveryState.idle) return;
    if (!_delegate.isCallActive || _delegate.isClientReconnecting) return;

    if (source == _FailureSource.ice &&
        _isMediaTransportConnected(_FailureSource.ice)) {
      // Already-connected guard: media re-established on its own.
      _log('ICE already connected, skipping recovery episode');
      _recoveryFailedLatch = false;
      return;
    }
    if (_recoveryFailedLatch) {
      _log('Recovery already exhausted, waiting for media to reconnect');
      return;
    }

    _generation += 1;
    _setState(CallRecoveryState.probing);
    _episodeSource = source;
    _shouldEvaluateRelayFallback = true;
    _log(
      'Recovery episode started (kind=${kind.name}, source=${source.name})',
    );
    _beginMediaRecovery('${_describe(source)} ${kind.name}');
  }

  /// Reattach when signaling is unavailable, restart ICE immediately when
  /// signaling was recently confirmed, otherwise probe signaling first.
  void _beginMediaRecovery(String trigger) {
    if (!_delegate.isSignalingAvailable) {
      _log(
        '$trigger with signaling unavailable; starting reconnect/reattach',
        warn: true,
      );
      unawaited(_performFallback('signaling-unavailable'));
      return;
    }
    if (_hasRecentSignalingActivity) {
      _log('$trigger with signaling available; starting ICE restart');
      unawaited(_runRestart());
      return;
    }
    _log('$trigger with stale signaling; probing before ICE restart');
    unawaited(_runProbe(_ProbePurpose.mediaRecovery));
  }

  Future<void> _runProbe(_ProbePurpose purpose) async {
    final generation = _generation;
    _probePurpose = purpose;
    _log('Sending correlated signaling probe (purpose=${purpose.name})');

    SignalingProbeResult result;
    try {
      result = await _withTimeout(
        _delegate.sendSignalingProbe(),
        config.signalingProbeTimeout,
        SignalingProbeResult.timeout,
      );
    } catch (_) {
      result = SignalingProbeResult.error;
    }

    if (!_isCurrent(generation, CallRecoveryState.probing)) return;
    _probePurpose = null;
    // Re-evaluate every deferred source against the live transport state. A
    // failed peer connection outranks ICE: ICE can report connected while the
    // peer connection itself has failed.
    final pending = purpose != _ProbePurpose.healthCheck
        ? null
        : <_FailureSource>[
            _FailureSource.peerConnection,
            _FailureSource.ice,
          ]
            .where(
              (source) =>
                  _pendingMediaRecovery.containsKey(source) &&
                  !_isMediaTransportConnected(source),
            )
            .firstOrNull;
    _pendingMediaRecovery.clear();

    if (result != SignalingProbeResult.ok) {
      // A deferred media failure keeps relay evaluation on for this fallback.
      _log(
        'Signaling probe not answered (${result.name}), falling back',
        warn: true,
      );
      await _performFallback('signaling-probe-${result.name}');
      return;
    }

    if (purpose == _ProbePurpose.healthCheck) {
      if (pending != null) {
        // The answered probe proved signaling is alive, so the deferred media
        // failure goes straight to an ICE restart.
        _episodeSource = pending;
        _log('Health probe answered; starting deferred media recovery');
        await _runRestart();
        return;
      }
      _log('Signaling health probe answered, returning to idle');
      _shouldEvaluateRelayFallback = false;
      _setState(CallRecoveryState.idle);
      return;
    }

    _log('Signaling probe answered, proceeding to ICE restart');
    await _runRestart();
  }

  Future<void> _runRestart({bool applicationRequested = false}) async {
    final generation = _generation;
    _setState(CallRecoveryState.iceRestarting);
    _cancelRestartTimeout();
    _restartTimeoutTimer = _createTimer(config.iceRestartTimeout, () {
      _restartTimeoutTimer = null;
      if (!_isCurrent(generation, CallRecoveryState.iceRestarting)) return;
      _log('ICE restart timed out, re-checking peer state', warn: true);
      if (_isMediaTransportConnected(_episodeSource)) {
        // Media came back without a completed exchange; RTP verification is
        // the final arbiter.
        unawaited(_runVerification());
        return;
      }
      unawaited(_performFallback('restart-timeout'));
    });

    // Each step re-checks that this exchange still owns the episode. A restart
    // timeout that handed over to verification still lets the late answer be
    // applied; one that fell back to reattach must not touch the peer again.
    bool ownsExchange() =>
        !_disposed &&
        generation == _generation &&
        (_state == CallRecoveryState.iceRestarting ||
            _state == CallRecoveryState.verifyingMedia);

    try {
      final offerSdp = await _delegate.restartIce(
        applicationRequested: applicationRequested,
      );
      if (!ownsExchange()) return;
      final answerSdp = await _delegate.sendUpdateMedia(offerSdp);
      if (!ownsExchange()) return;
      await _delegate.applyRemoteAnswer(answerSdp);
    } catch (error) {
      if (!ownsExchange()) return;
      _log('ICE restart exchange failed ($error), falling back', warn: true);
      await _performFallback('restart-failed');
      return;
    }

    if (!_isCurrent(generation, CallRecoveryState.iceRestarting)) return;
    await _runVerification();
  }

  Future<void> _runVerification() async {
    final generation = _generation;
    _cancelRestartTimeout();
    _setState(CallRecoveryState.verifyingMedia);

    // Arm the deadline on entry so a slow or stalled stats read cannot
    // extend the window or leave it without a deadline.
    _verifyDeadlineTimer = _createTimer(config.postIceRestartMediaTimeout, () {
      _verifyDeadlineTimer = null;
      if (!_isCurrent(generation, CallRecoveryState.verifyingMedia)) return;
      _log('No inbound RTP growth within verification window', warn: true);
      unawaited(_performFallback('no-rtp-growth'));
    });

    // Sample immediately so the window starts from a known point, then poll.
    // The first poll is a warm-up: restarted media needs a moment to produce
    // packets, so growth is judged from the second poll onward. If a read is
    // unavailable, the first later usable counter becomes the baseline
    // (iOS / Android take the first post-answer sample); the deadline above
    // is never extended.
    final baseline = await _readInboundPackets();
    if (!_isCurrent(generation, CallRecoveryState.verifyingMedia)) return;
    _verifyBaseline = baseline;

    var pollsCompleted = 0;
    late void Function() poll;
    poll = () {
      _verifyPollTimer = null;
      if (!_isCurrent(generation, CallRecoveryState.verifyingMedia)) return;
      unawaited(() async {
        final fresh = await _readInboundPackets();
        if (!_isCurrent(generation, CallRecoveryState.verifyingMedia)) return;
        pollsCompleted += 1;
        final base = _verifyBaseline;
        if (base == null) {
          _verifyBaseline = fresh;
        } else if (pollsCompleted > 1 && fresh != null && fresh > base) {
          _log('Inbound RTP verified, recovery succeeded');
          _cancelVerifyTimers();
          _setState(CallRecoveryState.idle);
          _delegate.onRecovered(RecoveryOutcome.iceRestart);
          return;
        }
        _verifyPollTimer = _createTimer(config.postIceRestartMediaPoll, poll);
      }());
    };
    _verifyPollTimer = _createTimer(config.postIceRestartMediaPoll, poll);
  }

  Future<void> _performFallback(String reason) async {
    if (_state == CallRecoveryState.reattaching) return;
    final generation = _generation;
    _cancelRestartTimeout();
    _cancelVerifyTimers();
    _setState(CallRecoveryState.reattaching);
    _log('Falling back to reconnect/reattach (reason=$reason)');

    final evaluateRelayFallback = _shouldEvaluateRelayFallback;
    _shouldEvaluateRelayFallback = false;
    CandidateEvidence? evidence;
    if (evaluateRelayFallback) {
      try {
        evidence = await _withTimeout<CandidateEvidence?>(
          _delegate.getSelectedCandidateEvidence(),
          config.candidateEvidenceTimeout,
          null,
        );
      } catch (error) {
        _log('Unable to capture selected candidate evidence ($error)');
      }
    }
    if (!_isCurrent(generation, CallRecoveryState.reattaching) ||
        !_delegate.isCallActive) {
      return;
    }
    if (evidence != null) {
      _delegate.onCandidateEvidenceCaptured(evidence);
    }

    bool reattached;
    try {
      reattached = await _delegate.performReattachFallback();
    } catch (error) {
      _log('Reattach fallback threw ($error)', warn: true);
      reattached = false;
    }

    if (generation != _generation) return;

    if (reattached) {
      _log('Reattach accepted by backend, replacement call initiated');
      _setState(CallRecoveryState.idle);
      _delegate.onRecovered(RecoveryOutcome.reattach);
      return;
    }

    _log('Reattach fallback failed after one attempt', warn: true);
    _recoveryFailedLatch = true;
    _setState(CallRecoveryState.idle);
    _delegate.onRecoveryFailed();
  }

  // ── Helpers ────────────────────────────────────────────────────────

  bool _isCurrent(int generation, CallRecoveryState expected) =>
      !_disposed && generation == _generation && _state == expected;

  bool get _hasRecentSignalingActivity =>
      _isWithin(
        _delegate.inboundSignalingIdle,
        config.recentInboundActivityThreshold,
      ) &&
      _isWithin(
        _delegate.confirmedOutboundIdle,
        config.confirmedOutboundActivityThreshold,
      );

  bool get _isSignalingStale =>
      !_isBelow(
        _delegate.inboundSignalingIdle,
        config.staleInboundActivityThreshold,
      ) ||
      !_isBelow(
        _delegate.confirmedOutboundIdle,
        config.confirmedOutboundActivityThreshold,
      );

  /// `idle <= threshold`, treating a missing timestamp as infinitely old.
  static bool _isWithin(Duration? idle, Duration threshold) =>
      idle != null && idle <= threshold;

  /// `idle < threshold`, treating a missing timestamp as infinitely old.
  static bool _isBelow(Duration? idle, Duration threshold) =>
      idle != null && idle < threshold;

  /// Whether [source] (default: ICE) reports connected. A peer-connection
  /// failure is judged by the peer connection: ICE can stay connected while
  /// the peer connection has failed.
  bool _isMediaTransportConnected(_FailureSource? source) {
    if (source == _FailureSource.peerConnection) {
      return _delegate.peerConnectionState ==
          RTCPeerConnectionState.RTCPeerConnectionStateConnected;
    }
    final ice = _delegate.peerIceState;
    return ice == RTCIceConnectionState.RTCIceConnectionStateConnected ||
        ice == RTCIceConnectionState.RTCIceConnectionStateCompleted;
  }

  Future<int?> _readInboundPackets() async {
    try {
      return await _delegate.getInboundAudioPackets();
    } catch (_) {
      return null;
    }
  }

  void _setState(CallRecoveryState next) {
    if (_state != next) {
      _log('State ${_state.name} → ${next.name}');
    }
    if (next == CallRecoveryState.idle) {
      _episodeSource = null;
      _probePurpose = null;
      _pendingMediaRecovery.clear();
    }
    _state = next;
  }

  void _cancelIceDisconnectedTimer() {
    _iceDisconnectedTimer?.cancel();
    _iceDisconnectedTimer = null;
  }

  void _cancelPeerDisconnectedTimer() {
    _peerDisconnectedTimer?.cancel();
    _peerDisconnectedTimer = null;
  }

  void _cancelRestartTimeout() {
    _restartTimeoutTimer?.cancel();
    _restartTimeoutTimer = null;
  }

  void _cancelVerifyTimers() {
    _verifyPollTimer?.cancel();
    _verifyPollTimer = null;
    _verifyDeadlineTimer?.cancel();
    _verifyDeadlineTimer = null;
    _verifyBaseline = null;
  }

  /// Races [future] against an injected-timer timeout. Settles at most once;
  /// the loser's continuation is a no-op.
  Future<T> _withTimeout<T>(Future<T> future, Duration timeout, T onTimeout) {
    final completer = Completer<T>();
    final timer = _createTimer(timeout, () {
      if (!completer.isCompleted) completer.complete(onTimeout);
    });
    future.then(
      (value) {
        timer.cancel();
        if (!completer.isCompleted) completer.complete(value);
      },
      onError: (Object error, StackTrace stackTrace) {
        timer.cancel();
        if (!completer.isCompleted) completer.completeError(error, stackTrace);
      },
    );
    return completer.future;
  }

  static String _describe(_FailureSource source) =>
      source == _FailureSource.ice ? 'ICE' : 'Peer connection';

  /// Sanitized log line: only the call-id prefix and generation, never SDP,
  /// addresses or credentials.
  void _log(String message, {bool warn = false}) {
    final prefix = callId.length > 8 ? callId.substring(0, 8) : callId;
    final line = '[CallRecoveryMonitor:$prefix gen=$_generation] $message';
    if (warn) {
      GlobalLogger().w(line);
    } else {
      GlobalLogger().i(line);
    }
  }
}
