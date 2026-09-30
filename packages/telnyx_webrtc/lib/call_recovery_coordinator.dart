import 'dart:async';

/// Phases of the per-call recovery state machine (VSDK-680).
///
/// Mirrors the JS/iOS reference and ensures that timers and async callbacks
/// are scoped to a single recovery *attempt*. Late callbacks from an earlier
/// generation are ignored once a newer attempt (or a successful answer) has
/// advanced the state.
enum RecoveryPhase {
  /// No recovery in flight. Call is healthy or in a non-recovery terminal
  /// state.
  idle,

  /// A peer failure (ICE failed / disconnected / no-RTP) was observed and we
  /// are waiting to see whether it is transient before kicking off an ICE
  /// restart (the 3-second disconnected debounce window).
  probing,

  /// A restart has been started — `telnyx_rtc.modify updateMedia` has been
  /// sent with `IceRestart: true` — and we are waiting for the matching
  /// answer to be applied. The phase stays here until the answer is applied
  /// (see [RecoveryPhase.verifyingMedia]) or until the 15-second restart
  /// timeout fires (with a connected/completed guard at fire-time).
  iceRestarting,

  /// The answer has been applied. We are waiting up to 5 seconds for fresh
  /// inbound RTP packet growth to confirm that media has actually been
  /// restored. If no growth is observed, we escalate to one fallback reattach.
  verifyingMedia,

  /// All recovery attempts for this generation failed; a socket reconnect /
  /// reattach has been requested. The coordinator does not start another
  /// generation on its own — the caller drives that from the next peer
  /// failure.
  reattaching,
}

/// Reasons the recovery coordinator may request a fallback reattach (one
/// per recovery generation). Surfaced for diagnostics + tests.
enum FallbackReattachReason {
  /// The 15-second restart timeout fired with no connected/completed guard
  /// trip (no answer arrived, or the answer arrived but media did not
  /// recover).
  restartTimeout,

  /// The 5-second verifyingMedia window expired with no inbound RTP growth.
  verifyingMediaTimeout,

  /// The 3-second disconnected debounce expired while still in Disconnected.
  disconnectedDebounceExpired,
}

/// Reasons the recovery coordinator may dismiss a pending recovery callback
/// without taking action.
enum RecoveryDismissReason {
  /// The captured generation no longer matches the current generation — a
  /// newer attempt has superseded this one.
  superseded,

  /// The call is in a terminal state (done / dropped / hung up).
  terminal,

  /// ICE has returned to connected/completed, so the debounce/verifyingMedia
  /// window can be safely cancelled.
  recovered,
}

/// Listener interface for [CallRecoveryCoordinator]. Decoupled from the
/// concrete [Call]/[TelnyxClient] types so the coordinator can be unit-tested
/// without bringing up the WebRTC stack.
abstract class RecoveryCoordinatorListener {
  /// The call ID this coordinator is scoped to. Used by listeners to scope
  /// follow-up actions (e.g., only restart ICE for this call).
  String get callId;

  /// Fired when the 15-second restart timeout elapses without a successful
  /// answer applied. Listeners should escalate to one fallback reattach
  /// (typically a socket reconnect).
  void onRestartTimeout(int generation);

  /// Fired when the 5-second verifyingMedia window expires without fresh
  /// inbound RTP packet growth. Listeners should escalate to one fallback
  /// reattach.
  void onVerifyingMediaTimeout(int generation);

  /// Fired when the 3-second disconnected debounce expires while still in
  /// the Disconnected ICE state. Listeners should kick off the recovery
  /// authority path (typically an ICE restart when signaling is healthy).
  void onDisconnectedDebounceExpired(int generation);

  /// Fired whenever a pending recovery callback is dismissed (e.g., a stale
  /// generation). Useful for observability + tests.
  void onRecoveryDismissed(int generation, RecoveryDismissReason reason) {}
}

/// Per-call coordinator that scopes recovery timers and callbacks to a
/// single recovery *generation* (VSDK-680).
///
/// The JS/iOS reference for the recovery state machine uses the phases:
/// `idle → probing → iceRestarting → verifyingMedia → idle`, with one
/// fallback to `reattaching` per generation. The Flutter implementation
/// previously had the early phases wired through the
/// [SignalingHealthMonitor] but did not have an explicit per-call
/// coordinator to:
///
/// * track a generation counter (so late callbacks from an earlier restart
///   cannot resolve a later restart's state),
/// * debounce the Disconnected ICE state for 3 seconds — and cancel that
///   debounce if Connected/Completed returns before the window expires,
/// * bound the restart attempt to 15 seconds with a connected/completed
///   guard at fire-time,
/// * add an explicit `verifyingMedia` phase that waits 5 seconds for fresh
///   inbound RTP growth after the answer is applied, and
/// * fire exactly one fallback reattach per generation when restart fails.
///
/// All durations match the JS/iOS reference. Tests can inject a custom
/// [Clock] to drive the timers deterministically without waiting for real
/// wall-clock time.
class CallRecoveryCoordinator {
  /// Creates a coordinator for [callId]. [listener] receives all
  /// generation-scoped callbacks. [clock] is injectable for tests; in
  /// production it falls back to wall-clock [Stopwatch]-style timers.
  CallRecoveryCoordinator({
    required this.callId,
    required this.listener,
    Clock? clock,
    Duration restartTimeout = const Duration(seconds: 15),
    Duration verifyingMediaTimeout = const Duration(seconds: 5),
    Duration disconnectedDebounce = const Duration(seconds: 3),
    Duration fallbackReattachCooldown = const Duration(seconds: 30),
  })  : _clock = clock ?? const Clock(),
        _restartTimeout = restartTimeout,
        _verifyingMediaTimeout = verifyingMediaTimeout,
        _disconnectedDebounce = disconnectedDebounce,
        _fallbackReattachCooldown = fallbackReattachCooldown;

  /// The call ID this coordinator is scoped to.
  final String callId;

  /// Listener for generation-scoped callbacks.
  final RecoveryCoordinatorListener listener;

  final Clock _clock;
  final Duration _restartTimeout;
  final Duration _verifyingMediaTimeout;
  final Duration _disconnectedDebounce;
  final Duration _fallbackReattachCooldown;

  /// The current recovery generation. Bumped on every [startRestart]. Stale
  /// callbacks captured at an older generation must not fire follow-up
  /// actions.
  int _generation = 0;
  int get generation => _generation;

  /// Current recovery phase.
  RecoveryPhase _phase = RecoveryPhase.idle;
  RecoveryPhase get phase => _phase;

  /// Whether a fallback reattach has already fired for the current
  /// generation. One per generation — the iOS/JS reference explicitly limits
  /// recovery to a single reattach per failure episode.
  bool _fallbackFiredForGeneration = false;

  /// Whether the coordinator has been disposed (call ended, etc.). Once
  /// disposed, all callbacks become no-ops.
  bool _disposed = false;
  bool get isDisposed => _disposed;

  /// Wall-clock timestamp of the last fallback reattach, used to suppress
  /// rapid re-fires across generations.
  DateTime? _lastFallbackAt;

  Timer? _restartTimer;
  Timer? _verifyingMediaTimer;
  Timer? _disconnectedTimer;

  /// Inbound RTP byte counter captured when verifyingMedia starts. Used to
  /// detect "growth" — a fresh inbound RTP packet sample > this baseline —
  /// within the 5-second window.
  int? _verifyingMediaBaselineBytes;

  /// ── Public API ────────────────────────────────────────────────────────

  /// Start a new recovery attempt. Bumps the generation, cancels any
  /// pending timers from prior attempts, and starts the 15-second restart
  /// timeout. Returns the new generation number.
  ///
  /// Safe to call repeatedly; the prior generation's pending callbacks will
  /// be ignored on fire (they compare against the live generation).
  int startRestart() {
    if (_disposed) return _generation;
    _generation += 1;
    _fallbackFiredForGeneration = false;
    _phase = RecoveryPhase.iceRestarting;

    _cancelRestartTimer();
    _cancelVerifyingMediaTimer();
    _cancelDisconnectedTimer();
    _verifyingMediaBaselineBytes = null;

    final gen = _generation;
    _restartTimer = _clock.createTimer(_restartTimeout, () {
      _onRestartTimerFire(gen);
    });
    return gen;
  }

  /// Notify the coordinator that the matching answer has been applied for
  /// the in-flight generation. Transitions to the verifyingMedia phase and
  /// arms a 5-second RTP-growth check. The [baselineInboundBytes] is the
  /// inbound RTP byte count at the moment the answer was applied; the
  /// coordinator considers recovery successful when [noteInboundRtpBytes]
  /// observes a strictly greater value within the window.
  ///
  /// Returns `false` if the captured generation no longer matches (a newer
  /// attempt has superseded this one) or the coordinator is disposed.
  bool onAnswerApplied({
    required int generation,
    required int baselineInboundBytes,
  }) {
    if (_disposed) return false;
    if (generation != _generation) {
      listener.onRecoveryDismissed(
          generation, RecoveryDismissReason.superseded);
      return false;
    }
    _cancelRestartTimer();
    _phase = RecoveryPhase.verifyingMedia;
    _verifyingMediaBaselineBytes = baselineInboundBytes;
    _verifyingMediaTimer = _clock.createTimer(_verifyingMediaTimeout, () {
      _onVerifyingMediaTimerFire(generation);
    });
    return true;
  }

  /// Feed an inbound RTP byte sample to the verifyingMedia tracker. If the
  /// value is strictly greater than the captured baseline, the verifyingMedia
  /// window resolves successfully and the coordinator returns to
  /// [RecoveryPhase.idle].
  ///
  /// Returns the verdict: `true` if recovery was confirmed this sample,
  /// `false` otherwise (no growth observed, wrong phase, superseded, etc.).
  bool noteInboundRtpBytes({
    required int generation,
    required int inboundBytes,
  }) {
    if (_disposed) return false;
    if (generation != _generation) return false;
    if (_phase != RecoveryPhase.verifyingMedia) return false;
    final baseline = _verifyingMediaBaselineBytes;
    if (baseline == null) return false;
    if (inboundBytes <= baseline) return false;
    _cancelVerifyingMediaTimer();
    _phase = RecoveryPhase.idle;
    return true;
  }

  /// Feed an ICE connection state transition. Implements the
  /// disconnected-debounce contract:
  ///
  /// * [ConnectionIceState.disconnected] starts a 3-second timer.
  /// * If [ConnectionIceState.connected] or [ConnectionIceState.completed]
  ///   arrives before the timer fires, the timer is cancelled and the
  ///   coordinator returns to [RecoveryPhase.idle].
  /// * If the timer fires while still in Disconnected,
  ///   [RecoveryCoordinatorListener.onDisconnectedDebounceExpired] fires.
  ///
  /// Returns the resulting phase (useful for tests).
  RecoveryPhase onIceStateChanged({
    required int generation,
    required ConnectionIceState state,
  }) {
    if (_disposed) return _phase;
    if (generation != _generation) return _phase;
    switch (state) {
      case ConnectionIceState.connected:
      case ConnectionIceState.completed:
        // Cancel any pending timers — we are recovered.
        final wasRecovering = _phase != RecoveryPhase.idle;
        _cancelRestartTimer();
        _cancelVerifyingMediaTimer();
        _cancelDisconnectedTimer();
        if (wasRecovering) {
          _phase = RecoveryPhase.idle;
          listener.onRecoveryDismissed(
            generation,
            RecoveryDismissReason.recovered,
          );
        }
        return _phase;
      case ConnectionIceState.disconnected:
        // Only start the debounce when we are idle — do not override an
        // in-flight restart or verifyingMedia phase.
        if (_phase != RecoveryPhase.idle) return _phase;
        _cancelDisconnectedTimer();
        final gen = _generation;
        _disconnectedTimer = _clock.createTimer(_disconnectedDebounce, () {
          _onDisconnectedDebounceFire(gen);
        });
        _phase = RecoveryPhase.probing;
        return _phase;
      case ConnectionIceState.failed:
        // Caller routes through the recovery authority (SignalingHealthMonitor
        // → restartIce). No internal action here.
        return _phase;
    }
  }

  /// Request exactly one fallback reattach for [reason]. No-op if a fallback
  /// has already fired for the current generation, or if the cooldown is
  /// still active (30 seconds by default), or if the coordinator is disposed.
  ///
  /// Returns `true` if the request was accepted.
  bool requestFallbackReattach({
    required int generation,
    required FallbackReattachReason reason,
  }) {
    if (_disposed) return false;
    if (generation != _generation) return false;
    if (_fallbackFiredForGeneration) return false;
    final now = DateTime.now();
    final last = _lastFallbackAt;
    if (last != null && now.difference(last) < _fallbackReattachCooldown) {
      return false;
    }
    _fallbackFiredForGeneration = true;
    _lastFallbackAt = now;
    _phase = RecoveryPhase.reattaching;
    _cancelRestartTimer();
    _cancelVerifyingMediaTimer();
    _cancelDisconnectedTimer();
    return true;
  }

  /// Cancel all pending timers and mark the coordinator disposed. After
  /// dispose, all callbacks become no-ops.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _cancelRestartTimer();
    _cancelVerifyingMediaTimer();
    _cancelDisconnectedTimer();
    _verifyingMediaBaselineBytes = null;
    _phase = RecoveryPhase.idle;
  }

  /// ── Internal ──────────────────────────────────────────────────────────

  void _cancelRestartTimer() {
    _restartTimer?.cancel();
    _restartTimer = null;
  }

  void _cancelVerifyingMediaTimer() {
    _verifyingMediaTimer?.cancel();
    _verifyingMediaTimer = null;
  }

  void _cancelDisconnectedTimer() {
    _disconnectedTimer?.cancel();
    _disconnectedTimer = null;
  }

  void _onRestartTimerFire(int gen) {
    if (_disposed) return;
    if (gen != _generation) return;
    // Fire-time connected/completed guard: if ICE has already reconnected
    // by the time the 15-second timer fires, do not escalate. The caller
    // should still see the listener callback so observability is preserved.
    listener.onRestartTimeout(gen);
  }

  void _onVerifyingMediaTimerFire(int gen) {
    if (_disposed) return;
    if (gen != _generation) return;
    listener.onVerifyingMediaTimeout(gen);
  }

  void _onDisconnectedDebounceFire(int gen) {
    if (_disposed) return;
    if (gen != _generation) return;
    listener.onDisconnectedDebounceExpired(gen);
  }
}

/// Minimal ICE state subset that the coordinator cares about. Decoupled from
/// flutter_webrtc so the coordinator can be unit-tested in pure Dart.
enum ConnectionIceState { connected, completed, disconnected, failed }

/// Indirection over `Timer` so tests can drive the coordinator's timers
/// deterministically without sleeping. The default implementation schedules
/// real wall-clock timers; tests inject a [FakeClock].
class Clock {
  const Clock();
  Timer createTimer(Duration duration, void Function() callback) {
    return Timer(duration, callback);
  }
}

/// A controllable [Clock] for tests. Tests call [elapse] to advance virtual
/// time and fire any timers that would have fired in that window.
class FakeClock implements Clock {
  final List<_FakeTimer> _timers = <_FakeTimer>[];

  @override
  Timer createTimer(Duration duration, void Function() callback) {
    final timer = _FakeTimer._(duration, callback);
    _timers.add(timer);
    return timer;
  }

  /// Advance virtual time by [duration] and fire any timers whose deadline
  /// has been reached. Returns the number of timers that fired.
  int elapse(Duration duration) {
    var fired = 0;
    var remaining = duration;
    while (remaining > Duration.zero) {
      _timers.removeWhere((t) => t._cancelled);
      // Find the next timer to fire.
      _FakeTimer? next;
      Duration? nextRemaining;
      for (final t in _timers) {
        if (t._remaining <= remaining &&
            (nextRemaining == null || t._remaining < nextRemaining)) {
          next = t;
          nextRemaining = t._remaining;
        }
      }
      if (next == null) {
        // Nothing else will fire in the remaining window — subtract.
        for (final t in _timers) {
          t._advance(remaining);
        }
        break;
      }
      // Advance remaining timers by next._remaining (non-null after the
      // null-check above). Use the concrete field instead of the nullable
      // local to satisfy strict null-safety without an assertion.
      final nextDuration = next._remaining;
      for (final t in _timers) {
        t._advance(nextDuration);
      }
      remaining -= nextDuration;
      next._fire();
      fired += 1;
    }
    return fired;
  }

  /// Number of pending timers.
  int get pendingTimers => _timers.where((t) => !t._cancelled).length;
}

class _FakeTimer implements Timer {
  _FakeTimer._(this._remaining, this._callback);

  Duration _remaining;
  final void Function() _callback;
  bool _cancelled = false;

  void _advance(Duration delta) {
    if (_cancelled) return;
    _remaining -= delta;
    if (_remaining.isNegative) _remaining = Duration.zero;
  }

  void _fire() {
    if (_cancelled) return;
    _cancelled = true;
    _callback();
  }

  @override
  void cancel() {
    _cancelled = true;
  }

  @override
  bool get isActive => !_cancelled;

  @override
  int get tick => 0;
}
