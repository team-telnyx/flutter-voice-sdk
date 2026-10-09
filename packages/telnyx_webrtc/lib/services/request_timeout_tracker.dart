import 'dart:async';

/// Tracks per-request timeouts for critical JSON-RPC methods.
///
/// Each call to [track] starts a [Timer] keyed by the request ID. If the
/// timer fires before [resolve] is called for that ID, the [onTimeout]
/// callback is invoked with the method name, request ID, and timeout
/// duration. This enables the [SignalingHealthMonitor] to detect stalled
/// signaling and trigger recovery.
///
/// Design notes:
/// - Optional: only instantiated when the health monitor is enabled.
/// - Only critical methods (modify, bye, ping) should be tracked —
///   non-critical fire-and-forget requests must not trigger recovery.
/// - Callers are responsible for calling [resolve] when a response arrives
///   and [cancelAll] during dispose/cleanup.
class RequestTimeoutTracker {
  /// Creates a tracker that fires [onTimeout] when a tracked request
  /// exceeds its timeout.
  ///
  /// [defaultTimeoutMs] is used when [track] is called without an explicit
  /// `timeoutMs` override. Defaults to 10 seconds.
  RequestTimeoutTracker({
    required this.onTimeout,
    this.defaultTimeoutMs = 10000,
  });

  /// Called when a tracked request's timeout expires before a response
  /// arrives. Parameters are (method, requestId, timeoutMs).
  final void Function(String method, String requestId, int timeoutMs) onTimeout;

  /// Default timeout in milliseconds when not overridden per-request.
  final int defaultTimeoutMs;

  final Map<String, Timer> _timers = {};

  /// The number of currently pending (unresolved) timers.
  int get pendingCount => _timers.length;

  /// Whether any timers are active.
  bool get hasPending => _timers.isNotEmpty;

  /// Start tracking a request. Call this right before sending the request.
  ///
  /// If a timer already exists for [requestId], it is replaced (the old
  /// timer is cancelled).
  void track(String requestId, String method, {int? timeoutMs}) {
    // Cancel any existing timer for this ID (defensive).
    _timers[requestId]?.cancel();

    final timeout = timeoutMs ?? defaultTimeoutMs;
    _timers[requestId] = Timer(Duration(milliseconds: timeout), () {
      _timers.remove(requestId);
      onTimeout(method, requestId, timeout);
    });
  }

  /// Resolve a request — cancels its timeout timer.
  ///
  /// Call this when a response (result or error) arrives for the request.
  /// Safe to call for unknown IDs (no-op).
  void resolve(String requestId) {
    final timer = _timers.remove(requestId);
    timer?.cancel();
  }

  /// Cancel all pending timers and clear the tracker.
  ///
  /// Called during dispose or when the socket disconnects to prevent
  /// stale timeouts from firing against a new session.
  void cancelAll() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }
}
