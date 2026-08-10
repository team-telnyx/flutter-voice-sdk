import 'dart:async';

/// Result of an ICE restart attempt.
class TriggerIceRestartResult {
  /// Whether the ICE restart was actually started.
  final bool started;

  /// Creates a result indicating whether the ICE restart [started].
  const TriggerIceRestartResult({required this.started});
}

/// Evidence that triggered a peer failure.
enum PeerFailureEvidence {
  /// ICE connectivity checks failed.
  iceFailed,

  /// The peer connection dropped unexpectedly.
  connectionFailed,
}

/// Abstract interface for the session-level operations that
/// [SignalingHealthMonitor] needs to inspect and control.
///
/// In production this is implemented by the class that owns the
/// signaling socket and peer-connection lifecycle (e.g. `Peer`).
///
/// Return types are nullable so that mockito's [Mock] can return `null`
/// before a stub is installed via [when].
abstract class ISignalingHealthSession {
  /// Whether the signaling socket is currently connected.
  bool? get isConnected;

  /// Whether there is at least one active call right now.
  bool? hasActiveCall();

  /// Force-disconnect the signaling socket so the reconnect logic
  /// re-establishes signaling from scratch.
  void socketDisconnect();

  /// Trigger an ICE restart for the given call.
  TriggerIceRestartResult? triggerIceRestart(String? callId);

  /// Send a lightweight signaling probe (a `telnyx_rtc.ping` message) so the
  /// monitor can provoke a response and resolve "unknown" signaling health
  /// instead of waiting passively for organic activity.
  void sendProbe();
}

/// Monitors signaling and peer-connection health, deciding the right
/// recovery action (ICE restart vs. full socket reconnect) based on
/// the combination of symptom and signaling health.
///
/// Decision matrix:
///
/// | Symptom                     | Signaling healthy | Signaling unknown |
/// |-----------------------------|-------------------|-------------------|
/// | Peer failure / no RTP      | ICE restart       | Probe, then decide |
/// | Request timeout (critical) | Socket reconnect  | Socket reconnect   |
/// | ICE restart failed         | Socket reconnect  | Socket reconnect   |
///
/// "Signaling healthy" means we have received socket activity within
/// the last [_signalingHealthyWindow] (3 s).  When unknown, the monitor
/// sends a lightweight probe (telnyx_rtc.ping) and waits for a response
/// before deciding. Unrelated inbound frames prove bytes are flowing but
/// MUST NOT release a pending media recovery that was gated on a probe —
/// only a probe response matching the in-flight request id resolves it.
///
/// Producer status (VSDK-416): the wired production inputs today are
/// [onSocketActivity] (every inbound message), [onPeerFailure] (ICE-failed /
/// peer-connection-failed), [onIceRestartFailed], and [onNoRtp] (bridged from
/// the [QualityWarningMonitor]'s `LOW_BYTES_RECEIVED` / `LOW_BYTES_SENT`
/// signals in `call.dart`). [onRequestTimeout] is an implemented event input
/// without a per-request timeout producer yet — a future request-id→timer
/// source can feed this method directly without changing the recovery logic.
class SignalingHealthMonitor {
  /// Creates a monitor that inspects and controls signaling/peer health
  /// through [session].
  SignalingHealthMonitor(
    this._session, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final ISignalingHealthSession _session;
  final DateTime Function() _now;

  // ── Lifecycle ──────────────────────────────────────────────────────

  Timer? _checkTimer;
  bool _isRunning = false;

  /// Whether the monitor is actively polling.
  bool get isRunning => _isRunning;

  /// Start the periodic health check.  Idempotent.
  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _checkTimer = Timer.periodic(_checkInterval, _onCheck);
  }

  /// Stop the monitor and clear all pending state.  Idempotent.
  void stop() {
    _checkTimer?.cancel();
    _checkTimer = null;
    _isRunning = false;
    _isProbeInFlight = false;
    _probeRequestId = null;
    _lastInboundTimestamp = null;
    _pendingMediaRecovery = null;
    _probeStartedAt = null;
  }

  // ── Socket activity tracking ───────────────────────────────────────

  /// Timestamp of the last inbound socket message.
  DateTime? _lastInboundTimestamp;

  /// Window within which signaling is considered healthy (3 s).
  ///
  /// Aligned with the JS reference (`RECENT_ACTIVITY_THRESHOLD_MS = 3000`):
  /// only *very recent* inbound activity counts as "healthy". Activity older
  /// than this is treated as "unknown", and the monitor resolves it with an
  /// active probe rather than blindly assuming the signaling path is up.
  static const Duration _signalingHealthyWindow = Duration(seconds: 3);

  /// Check interval for the periodic timer (3 s).
  static const Duration _checkInterval = Duration(seconds: 3);

  /// How long a deferred media recovery waits for the probe response before
  /// escalating to a full socket reconnect (5 s after the probe is sent).
  ///
  /// Aligned with the JS reference (`PROBE_TIMEOUT_MS = 5000`).
  static const Duration _probeTimeout = Duration(seconds: 5);

  /// Call this whenever *any* inbound socket message arrives.
  ///
  /// Updates the passive liveness timestamp only. Crucially this does NOT
  /// release an in-flight probe — only a JSON-RPC response matching the
  /// probe's request id does that (see [resolveProbe]). Unrelated inbound
  /// frames prove bytes are flowing, but they must not release pending media
  /// recovery that was gated on a probe response.
  void onSocketActivity() {
    _lastInboundTimestamp = _now();
  }

  bool _isProbeInFlight = false;

  /// Request id of the currently in-flight probe, if any. Set when
  /// [attachProbeRequestId] is called by the probe-sending adapter; cleared
  /// when [resolveProbe] matches it.
  String? _probeRequestId;

  /// Whether a probe is currently in flight.
  bool get isProbeInFlight => _isProbeInFlight;

  /// The request id of the in-flight probe, if known. Exposed for tests and
  /// for the adapter that needs to correlate responses.
  String? get probeRequestId => _probeRequestId;

  /// Attach the JSON-RPC request id of the just-sent probe. Called by the
  /// session adapter right after [ISignalingHealthSession.sendProbe] returns.
  /// The request id is required for [resolveProbe] to release the probe.
  void attachProbeRequestId(String? requestId) {
    _probeRequestId = requestId;
  }

  /// Resolve an in-flight probe when the matching JSON-RPC response arrives.
  ///
  /// Only releases the probe (and any pending media-recovery decision) when
  /// [requestId] matches the in-flight probe request id. A `null` [requestId]
  /// is treated as a legacy "any ping response resolves the probe" path (used
  /// by adapters that cannot correlate responses) — it releases the probe but
  /// is narrower than the JS reference's exact-id matching.
  ///
  /// When the probe resolves and signaling now appears healthy, any deferred
  /// media recovery is executed immediately via [ISignalingHealthSession
  ///.triggerIceRestart].
  void resolveProbe(String? requestId) {
    if (!_isProbeInFlight) return;
    final expected = _probeRequestId;
    if (requestId != null && expected != null && requestId != expected) {
      // Response for a different (stale?) probe — do not release.
      return;
    }
    _isProbeInFlight = false;
    _probeRequestId = null;

    final pending = _pendingMediaRecovery;
    if (pending == null) return;
    _pendingMediaRecovery = null;
    if (_isSignalingHealthy) {
      _session.triggerIceRestart(pending);
      _probeStartedAt = null;
    }
  }

  /// Returns `true` when we have received socket activity within the
  /// healthy window.
  bool get _isSignalingHealthy {
    final ts = _lastInboundTimestamp;
    if (ts == null) return false;
    return _now().difference(ts) < _signalingHealthyWindow;
  }

  // ── Critical method classification ──────────────────────────────────

  /// Methods whose failure indicates a signaling-level problem.
  static const _criticalMethods = <String>{
    'telnyx_rtc.modify',
    'telnyx_rtc.bye',
    'telnyx_rtc.ping',
  };

  /// Whether [method] is a critical signaling method.
  static bool isCriticalMethod(String method) {
    return _criticalMethods.contains(method);
  }

  // ── Request timeout ────────────────────────────────────────────────

  /// Event input: called when a JSON-RPC request times out.
  ///
  /// For critical methods (modify, bye, ping) when connected, triggers a
  /// full socket reconnect.
  ///
  /// NOTE (VSDK-416): this is a *producer-agnostic event input*. The SDK does
  /// not currently track per-request response timeouts (requests are sent
  /// fire-and-forget with no request-id→timer correlation), so there is no
  /// production caller today. A future per-request timeout source can feed this
  /// method directly without any change to the recovery logic here. Do not
  /// synthesize an independent timer to drive it.
  void onRequestTimeout(
    String requestId,
    int timeoutMs,
    String method,
  ) {
    if (!_isRunning) return;
    if (!isCriticalMethod(method)) return;
    if (_session.isConnected != true) return;

    // Critical method timeout → signaling is broken, reconnect.
    _session.socketDisconnect();
  }

  // ── Peer failure / No RTP ──────────────────────────────────────────

  /// Called when a peer failure is detected (e.g. ICE failed, connection
  /// dropped).
  ///
  /// - If signaling is healthy → ICE restart.
  /// - If signaling health is unknown → send a probe and defer.
  /// - If no active call → ignore.
  void onPeerFailure(String callId, PeerFailureEvidence evidence) {
    if (!_isRunning) return;
    if (_session.hasActiveCall() != true) return;

    if (_isSignalingHealthy) {
      // Signaling is fine → ICE restart.
      _session.triggerIceRestart(callId);
    } else {
      // Signaling health unknown → defer the ICE restart and probe.
      _deferMediaRecovery(callId);
    }
  }

  /// Event input: called when no RTP packets are received for a sustained
  /// period.
  ///
  /// Same logic as [onPeerFailure]:
  /// - Healthy signaling → ICE restart.
  /// - Unknown signaling → probe and defer.
  /// - No active call → ignore.
  ///
  /// The production producer for this is the no-RTP bridge wired from the
  /// [QualityWarningMonitor]'s `LOW_BYTES_RECEIVED` (32001 → 'inbound') and
  /// `LOW_BYTES_SENT` (32002 → 'outbound', only when the local audio track is
  /// active/unmuted) warnings. See `call.dart` for the bridge wiring.
  void onNoRtp(String callId, String direction) {
    if (!_isRunning) return;
    if (_session.hasActiveCall() != true) return;

    if (_isSignalingHealthy) {
      _session.triggerIceRestart(callId);
    } else {
      _deferMediaRecovery(callId);
    }
  }

  // ── ICE restart failure ─────────────────────────────────────────────

  /// Called when an ICE restart attempt has failed.
  ///
  /// Always triggers a full socket reconnect regardless of signaling
  /// health, because ICE restart is the "softer" recovery and it failed.
  void onIceRestartFailed(String callId) {
    if (!_isRunning) return;
    _session.socketDisconnect();
  }

  // ── Pending media recovery ──────────────────────────────────────────

  /// Stores the call ID for a pending media-recovery decision so the periodic
  /// check can resolve it (and [stop] can clear it).
  String? _pendingMediaRecovery;

  /// When the current deferred media-recovery probe started, used to bound how
  /// long we wait for signaling to recover before reconnecting.
  DateTime? _probeStartedAt;

  /// Defers a media recovery for [callId] when signaling health is unknown:
  /// marks a probe in flight and lets [_onCheck] decide (ICE restart if
  /// signaling recovers, socket reconnect if it stays unhealthy).
  void _deferMediaRecovery(String callId) {
    _pendingMediaRecovery = callId;
    _probeStartedAt = _now();
    _startProbe();
  }

  /// Marks a probe in flight and actually sends a `telnyx_rtc.ping` so a
  /// response can resolve "unknown" signaling health. Idempotent while a probe
  /// is already outstanding.
  ///
  /// The adapter's [ISignalingHealthSession.sendProbe] implementation is
  /// responsible for calling [attachProbeRequestId] with the JSON-RPC id it
  /// sent so [resolveProbe] can correlate the matching response.
  void _startProbe() {
    if (_isProbeInFlight) return;
    _isProbeInFlight = true;
    _session.sendProbe();
  }

  // ── Periodic check ─────────────────────────────────────────────────

  void _onCheck(Timer timer) {
    if (!_isRunning) return;
    if (_session.isConnected != true) return;
    if (_session.hasActiveCall() != true) return;

    // Handle probe timeout regardless of whether media recovery is pending.
    // If the probe was sent but never resolved (send failed, response lost),
    // the socket must be disconnected to trigger recovery (VSDK-397).
    //
    // Capture the in-flight flag *before* clearing so that a late
    // resolveProbe() that runs between _clearPendingRecovery() and
    // socketDisconnect() cannot cause us to disconnect when the probe
    // was already resolved. The local capture makes the timeout-vs-resolve
    // race explicit (AFK review W1).
    if (_isProbeInFlight) {
      final startedAt = _probeStartedAt;
      if (startedAt != null && _now().difference(startedAt) >= _probeTimeout) {
        final wasProbeInFlight = _isProbeInFlight;
        _clearPendingRecovery();
        if (wasProbeInFlight) {
          _session.socketDisconnect();
        }
        return;
      }
    }

    // Resolve a deferred media recovery once signaling health becomes known,
    // so the recovery is never silently dropped.
    final pending = _pendingMediaRecovery;
    if (pending != null) {
      if (_isSignalingHealthy) {
        // Signaling recovered → perform the deferred ICE restart.
        _clearPendingRecovery();
        _session.triggerIceRestart(pending);
        return;
      }
      final startedAt = _probeStartedAt;
      if (startedAt != null && _now().difference(startedAt) >= _probeTimeout) {
        // Probe window elapsed with signaling still unhealthy → reconnect.
        // Same race guard as the unconditional probe-timeout branch above.
        final wasProbeInFlight = _isProbeInFlight;
        _clearPendingRecovery();
        if (wasProbeInFlight) {
          _session.socketDisconnect();
        }
        return;
      }
      // Still waiting for signaling to recover within the probe window.
      return;
    }

    // If no socket activity within the healthy window and no probe in
    // flight, send a probe.
    if (!_isSignalingHealthy && !_isProbeInFlight) {
      _startProbe();
    }
  }

  void _clearPendingRecovery() {
    _pendingMediaRecovery = null;
    _isProbeInFlight = false;
    _probeRequestId = null;
    _probeStartedAt = null;
  }
}
