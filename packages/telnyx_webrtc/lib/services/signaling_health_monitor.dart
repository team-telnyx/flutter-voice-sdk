import 'dart:async';

/// Result of an ICE restart attempt.
class TriggerIceRestartResult {
  /// Whether the ICE restart was actually started.
  final bool started;

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
/// the last [_signalingHealthyWindow] (20 s).  When unknown, the monitor
/// sends a lightweight probe (telnyx_rtc.ping) and waits for a response
/// before deciding.
class SignalingHealthMonitor {
  SignalingHealthMonitor(this._session);

  final ISignalingHealthSession _session;

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
    _lastInboundTimestamp = null;
    _pendingMediaRecovery = null;
  }

  // ── Socket activity tracking ───────────────────────────────────────

  /// Timestamp of the last inbound socket message.
  DateTime? _lastInboundTimestamp;

  /// Window within which signaling is considered healthy (20 s).
  static const Duration _signalingHealthyWindow = Duration(seconds: 20);

  /// Check interval for the periodic timer (3 s).
  static const Duration _checkInterval = Duration(seconds: 3);

  /// Call this whenever *any* inbound socket message arrives.
  void onSocketActivity() {
    _lastInboundTimestamp = DateTime.now();
    // If a probe was in flight, a response has arrived — clear it.
    _isProbeInFlight = false;
  }

  bool _isProbeInFlight = false;

  /// Whether a probe is currently in flight.
  bool get isProbeInFlight => _isProbeInFlight;

  /// Returns `true` when we have received socket activity within the
  /// healthy window.
  bool get _isSignalingHealthy {
    final ts = _lastInboundTimestamp;
    if (ts == null) return false;
    return DateTime.now().difference(ts) < _signalingHealthyWindow;
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

  /// Called when a JSON-RPC request times out.
  ///
  /// For critical methods (modify, bye, ping) when connected, triggers a
  /// full socket reconnect.
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
      // Signaling health unknown → probe first.
      _isProbeInFlight = true;
    }
  }

  /// Called when no RTP packets are received for a sustained period.
  ///
  /// Same logic as [onPeerFailure]:
  /// - Healthy signaling → ICE restart.
  /// - Unknown signaling → probe and defer.
  /// - No active call → ignore.
  void onNoRtp(String callId, String direction) {
    if (!_isRunning) return;
    if (_session.hasActiveCall() != true) return;

    if (_isSignalingHealthy) {
      _session.triggerIceRestart(callId);
    } else {
      _isProbeInFlight = true;
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

  /// Stores call ID for a pending media-recovery decision so [stop] can
  /// clear it.
  String? _pendingMediaRecovery;

  // ── Periodic check ─────────────────────────────────────────────────

  void _onCheck(Timer timer) {
    if (!_isRunning) return;
    if (_session.isConnected != true) return;
    if (_session.hasActiveCall() != true) return;

    // If no socket activity for > 20s and no probe in flight, send a probe.
    if (!_isSignalingHealthy && !_isProbeInFlight) {
      _isProbeInFlight = true;
    }
  }
}
