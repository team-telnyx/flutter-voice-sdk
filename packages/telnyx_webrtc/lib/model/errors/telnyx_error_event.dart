import 'package:telnyx_webrtc/model/errors/telnyx_error.dart';

/// Standard (non-recoverable) error event.
///
/// Emitted via `onTelnyxError` when an error occurs that has no
/// app-facing recovery flow.
class TelnyxErrorEvent {
  /// Structured SDK error.
  final TelnyxError error;

  /// Current SDK session identifier.
  final String sessionId;

  /// Call identifier when the error is associated with a call.
  final String? callId;

  /// Always `false` for standard error events.
  final bool recoverable = false;

  /// Creates a standard (non-recoverable) error event.
  TelnyxErrorEvent({
    required this.error,
    required this.sessionId,
    this.callId,
  });
}

/// Media recovery error event — emitted when getUserMedia fails during
/// inbound call answer and mediaPermissionsRecovery is enabled.
///
/// The app can call [resume] to retry media acquisition after fixing
/// permissions, or [reject] to abort the call.
class TelnyxMediaRecoveryErrorEvent {
  /// Structured media error for the failed initial getUserMedia attempt.
  final TelnyxError error;

  /// Current SDK session identifier.
  final String sessionId;

  /// Inbound call being recovered.
  final String callId;

  /// Always `true` for media recovery events.
  final bool recoverable = true;

  /// Epoch timestamp in ms after which the SDK will stop waiting.
  final int retryDeadline;

  /// Retry media acquisition after the app resolves permissions.
  final Future<void> Function() resume;

  /// Abort recovery and let the call fail immediately.
  final Future<void> Function() reject;

  /// Creates a media recovery error event with resume and reject callbacks.
  TelnyxMediaRecoveryErrorEvent({
    required this.error,
    required this.sessionId,
    required this.callId,
    required this.retryDeadline,
    required this.resume,
    required this.reject,
  });
}

/// Type guard for media recovery events.
bool isMediaRecoveryErrorEvent(Object? event) =>
    event is TelnyxMediaRecoveryErrorEvent;
