/// Factory for creating [TelnyxWarning] instances from the SDK warning
/// registry.
///
/// Creates a fully-populated [TelnyxWarning] from the registered warning
/// definition. Throws [ArgumentError] when [code] is not in the registry.
///
/// Usage:
/// ```dart
/// final warning = createTelnyxWarning(TelnyxWarningCodes.highRtt);
/// ```
library;

import 'package:telnyx_webrtc/model/errors/telnyx_warning.dart';
import 'package:telnyx_webrtc/model/errors/sdk_warnings.dart';

/// Creates a [TelnyxWarning] from a registered warning [code].
///
/// Looks up [code] in [sdkWarnings] and builds a fully-populated [TelnyxWarning].
///
/// - [message] — overrides the registry default message when provided.
///
/// Throws [ArgumentError] when [code] is not in the registry.
TelnyxWarning createTelnyxWarning(
  int code, {
  String? message,
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
  );
}
