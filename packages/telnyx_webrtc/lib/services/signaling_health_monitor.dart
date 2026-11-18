/// Compatibility shim for the removed client-wide signaling health monitor.
///
/// Recovery now runs per call (ICE restart, correlated probes, media
/// verification and a single reattach fallback) and is controlled by
/// `enableSignalingHealthMonitor` on the config. `TelnyxClient.healthMonitor`
/// always returns `null`, so `client.healthMonitor?.stop()` keeps compiling
/// and does nothing.
library;

/// No-op replacement for the former client-wide monitor.
@Deprecated(
  'Call recovery is per call and is controlled by '
  'enableSignalingHealthMonitor. This class does nothing and will be '
  'removed in the next major version.',
)
class SignalingHealthMonitor {
  /// Creates an inert monitor.
  @Deprecated('Not used by the SDK; will be removed in the next major version.')
  const SignalingHealthMonitor();

  /// Always `false`.
  bool get isRunning => false;

  /// Always `false`.
  bool get isProbeInFlight => false;

  /// Always `null`.
  String? get probeRequestId => null;

  /// Does nothing.
  void start() {}

  /// Does nothing.
  void stop() {}
}
