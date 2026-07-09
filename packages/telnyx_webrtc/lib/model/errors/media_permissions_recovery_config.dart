/// Configuration for media permissions recovery on inbound calls.
///
/// When enabled and the initial getUserMedia call fails while answering,
/// the SDK emits a recoverable error event with [resume] and [reject]
/// callbacks so the app can prompt the user to fix permissions.
class MediaPermissionsRecoveryConfig {
  /// Enable the recovery flow.
  final bool enabled;

  /// Maximum time in ms to wait for the app to call resume() or reject().
  /// Recommended max 25000.
  final int timeout;

  /// Called when the retry getUserMedia succeeds after resume().
  final void Function()? onSuccess;

  /// Called when retry fails, timeout expires, or the app calls reject().
  final void Function(Object error)? onError;

  /// Creates a media permissions recovery configuration.
  const MediaPermissionsRecoveryConfig({
    required this.enabled,
    required this.timeout,
    this.onSuccess,
    this.onError,
  });
}
