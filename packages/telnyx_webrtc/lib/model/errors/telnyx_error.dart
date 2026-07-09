/// Structured error class matching JS SDK's `TelnyxError`.
///
/// Implements [Exception] so it can be thrown and caught in Dart.
class TelnyxError implements Exception {
  /// Numeric error code (e.g. 40001).
  final int code;

  /// Machine-readable error name in UPPER_SNAKE_CASE.
  final String name;

  /// Short human-readable message suitable for UI alerts.
  final String message;

  /// Full explanation of the error — what happened and why.
  final String description;

  /// Possible root causes.
  final List<String> causes;

  /// Suggested remediation steps.
  final List<String> solutions;

  /// The original error that triggered this, if any.
  final Object? originalError;

  /// `true` when the situation is terminal — operation/call/session
  /// is dead and the client should stop. `false` when the SDK is handling
  /// recovery or the failure is benign enough to ignore.
  final bool fatal;

  /// The call ID this error is associated with.
  final String? callId;

  /// The session ID this error is associated with.
  final String? sessionId;

  /// ISO-8601 timestamp when the error was emitted.
  final String? timestamp;

  /// Optional context map with extra details.
  final Map<String, dynamic>? context;

  /// Creates a structured Telnyx error.
  TelnyxError({
    required this.code,
    required this.name,
    required this.message,
    required this.description,
    required this.causes,
    required this.solutions,
    this.originalError,
    required this.fatal,
    this.callId,
    this.sessionId,
    this.timestamp,
    this.context,
  });

  @override
  String toString() => '[$code] $name: $message';

  /// Serializes this error to a JSON-encodable map.
  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'message': message,
        'description': description,
        'causes': causes,
        'solutions': solutions,
        'fatal': fatal,
        if (originalError != null) 'originalError': originalError.toString(),
        if (callId != null) 'callId': callId,
        if (sessionId != null) 'sessionId': sessionId,
        if (timestamp != null) 'timestamp': timestamp,
        if (context != null) 'context': context,
      };
}
