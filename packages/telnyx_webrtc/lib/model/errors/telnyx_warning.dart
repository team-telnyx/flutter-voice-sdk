/// Structured warning matching JS SDK's `ITelnyxWarning`.
///
/// Warnings represent degraded conditions that may cause unstable
/// connections or bad call quality. Unlike errors, warnings are
/// never fatal and do not implement [Exception].
class TelnyxWarning {
  /// Numeric warning code (e.g. 31001).
  final int code;

  /// Machine-readable name in UPPER_SNAKE_CASE.
  final String name;

  /// Short human-readable message for UI alerts.
  final String message;

  /// Full explanation of the warning.
  final String description;

  /// Possible root causes.
  final List<String> causes;

  /// Suggested remediation steps.
  final List<String> solutions;

  /// The call ID this warning is associated with.
  final String? callId;

  /// The session ID this warning is associated with.
  final String? sessionId;

  /// ISO-8601 timestamp when the warning was emitted.
  final String? timestamp;

  /// Optional context map with extra details.
  final Map<String, dynamic>? context;

  /// Creates a structured Telnyx warning.
  const TelnyxWarning({
    required this.code,
    required this.name,
    required this.message,
    required this.description,
    required this.causes,
    required this.solutions,
    this.callId,
    this.sessionId,
    this.timestamp,
    this.context,
  });

  /// Serializes this warning to a JSON-encodable map.
  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'message': message,
        'description': description,
        'causes': causes,
        'solutions': solutions,
        if (callId != null) 'callId': callId,
        if (sessionId != null) 'sessionId': sessionId,
        if (timestamp != null) 'timestamp': timestamp,
        if (context != null) 'context': context,
      };
}
