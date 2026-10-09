/// Factory methods for creating [TelnyxError] instances from the SDK
/// error registry.
///
/// Usage:
/// ```dart
/// final error = createTelnyxError(TelnyxErrorCodes.sdpCreateOfferFailed);
/// throw error;
/// ```
library;

import 'package:telnyx_webrtc/model/errors/telnyx_error.dart';
import 'package:telnyx_webrtc/model/errors/sdk_errors.dart';
export 'media_error_classifier.dart' show classifyMediaErrorCode;

/// Creates a [TelnyxError] from a registered error [code].
///
/// Looks up [code] in [sdkErrors] and builds a fully-populated [TelnyxError].
///
/// - [message] — overrides the registry default message when provided.
/// - [fatal] — overrides the registry default fatal flag when provided.
/// - [originalError] — the underlying error/exception that triggered this,
///   preserved on the returned [TelnyxError]. Strings are wrapped in an
///   [Error] so [TelnyxError.originalError] is never a bare [String].
///
/// Throws [ArgumentError] when [code] is not in the registry.
TelnyxError createTelnyxError(
  int code, {
  String? message,
  bool? fatal,
  Object? originalError,
}) {
  final def = sdkErrors[code];
  if (def == null) {
    throw ArgumentError('Unknown error code: $code');
  }

  // Wrap string originalError in an Error object so originalError is
  // always an Error or Exception, never a bare String.
  Object? wrappedOriginal;
  if (originalError != null) {
    if (originalError is String) {
      wrappedOriginal = StateError(originalError);
    } else {
      wrappedOriginal = originalError;
    }
  }

  return TelnyxError(
    code: code,
    name: def.name,
    message: message ?? def.message,
    description: def.description,
    causes: def.causes,
    solutions: def.solutions,
    originalError: wrappedOriginal,
    fatal: fatal ?? def.fatal,
  );
}
