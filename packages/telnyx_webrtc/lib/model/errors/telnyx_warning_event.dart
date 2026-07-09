import 'telnyx_warning.dart';

/// Warning event emitted via `onTelnyxWarning`.
class TelnyxWarningEvent {
  /// Structured SDK warning.
  final TelnyxWarning warning;

  /// Optional reason text explaining why the warning was emitted.
  final String? reason;

  /// Source of the warning: `'probe'`, `'request'`, `'peer_failure'`, or `'no_rtp'`.
  final String? source;

  /// Current SDK session identifier.
  final String sessionId;

  /// Call identifier when the warning is associated with a call.
  final String? callId;

  const TelnyxWarningEvent({
    required this.warning,
    this.reason,
    this.source,
    required this.sessionId,
    this.callId,
  });
}
