import 'package:telnyx_webrtc/model/errors/sdk_warnings.dart';
import 'package:telnyx_webrtc/model/telnyx_warning.dart';

/// Definition record for a single SDK warning code.
class SdkWarningDefinition {
  /// The numeric SDK warning code.
  final int code;

  /// The machine-readable name in UPPER_SNAKE_CASE.
  final String name;

  /// A short human-readable message for UI alerts.
  final String message;

  /// A fuller explanation of what the warning means.
  final String description;

  /// Possible root causes of the warning.
  final List<String> causes;

  /// Suggested remediation steps for the warning.
  final List<String> solutions;

  /// Creates a warning definition for [code].
  const SdkWarningDefinition({
    required this.code,
    required this.name,
    required this.message,
    required this.description,
    required this.causes,
    required this.solutions,
  });
}

/// Registry of all known SDK warning codes and their metadata.
///
/// This is a thin adapter over the canonical [sdkWarnings] table
/// (`lib/model/errors/sdk_warnings.dart`, ported 1:1 from the JS SDK
/// `constants/warnings.ts`). Sourcing runtime-emitted warnings from that single
/// table guarantees the emitted text (name/message/description/causes/
/// solutions) matches the exported registry for every code — previously this
/// registry carried a second, divergent copy of the text.
class SdkWarningRegistry {
  SdkWarningRegistry._();

  /// Look up the definition for [code], or `null` if not found.
  static SdkWarningDefinition? get(int code) {
    final def = sdkWarnings[code];
    if (def == null) {
      return null;
    }
    return SdkWarningDefinition(
      code: code,
      name: def.name,
      message: def.message,
      description: def.description,
      causes: def.causes,
      solutions: def.solutions,
    );
  }

  /// Create a [TelnyxWarning] from a code, optionally overriding the message.
  static TelnyxWarning createWarning(
    int code, {
    String? message,
    String? callId,
    String? sessionId,
    Map<String, dynamic>? context,
  }) {
    final def = sdkWarnings[code];
    if (def == null) {
      throw ArgumentError('Unknown warning code: $code');
    }
    return TelnyxWarning(
      code: code,
      name: def.name,
      message: message ?? def.message,
      description: def.description,
      causes: def.causes,
      solutions: def.solutions,
      callId: callId,
      sessionId: sessionId,
      context: context,
    );
  }
}
