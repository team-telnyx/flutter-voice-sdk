/// Indicates that a signaling request timed out waiting for a server
/// response. Carries the request ID, timeout duration, and Verto method
/// name so callers can decide whether to trigger signaling recovery.
class RequestTimeoutError implements Exception {
  /// The request ID that timed out.
  final String requestId;

  /// Timeout duration in milliseconds.
  final int timeoutMs;

  /// Verto method name (e.g. `'telnyx_rtc.modify'`), or empty string if unknown.
  final String method;

  /// Creates a request timeout error for the given request and duration.
  RequestTimeoutError(this.requestId, this.timeoutMs, [this.method = '']);

  @override
  String toString() =>
      'Signaling request timed out (id=$requestId, method=${method.isEmpty ? 'unknown' : method}, timeout=${timeoutMs}ms)';
}

/// Indicates that a request's timeout fired after the WebSocket was replaced
/// by a newer connection (socket generation mismatch). The request is
/// effectively cancelled — its promise is settled with this error so callers
/// never hang, but signaling recovery must NOT be triggered since the new
/// socket is healthy.
class StaleRequestError implements Exception {
  /// The request ID that was cancelled.
  final String requestId;

  /// The generation of the stale socket.
  final int staleGeneration;

  /// The current (replacement) socket generation.
  final int currentGeneration;

  /// Creates a stale request error for a cancelled, superseded request.
  StaleRequestError(
    this.requestId,
    this.staleGeneration,
    this.currentGeneration,
  );

  @override
  String toString() =>
      'Stale request cancelled (id=$requestId, gen=$staleGeneration, current=$currentGeneration)';
}
