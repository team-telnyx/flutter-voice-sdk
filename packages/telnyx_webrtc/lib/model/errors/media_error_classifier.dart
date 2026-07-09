/// Classifies platform media errors (PlatformException, strings, generic
/// exceptions) into the appropriate [TelnyxErrorCodes] value.
///
/// This bridges the gap between raw platform/WebRTC errors and the
/// structured SDK error registry, so callers can always map any
/// getUserMedia failure to a known error code.
library;

import 'package:flutter/services.dart';

import 'package:telnyx_webrtc/model/errors/telnyx_error_codes.dart';

/// Classifies [error] — a PlatformException, string, or generic object —
/// into the matching [TelnyxErrorCodes] media code.
///
/// Classification rules (case-insensitive substring match):
/// - Contains "permission", "NotAllowed" → 42001 (microphone permission denied)
/// - Contains "NotFound", "Overconstrained" → 42002 (device not found)
/// - Everything else → 42003 (getUserMedia failed)
int classifyMediaErrorCode(Object? error) {
  final String text;

  if (error == null) {
    return TelnyxErrorCodes.mediaGetUserMediaFailed;
  }

  if (error is PlatformException) {
    final code = error.code.toLowerCase();
    final message = error.message?.toLowerCase() ?? '';
    text = '$code $message';
  } else if (error is String) {
    text = error.toLowerCase();
  } else {
    // Generic Exception or any other object — fall through to default.
    return TelnyxErrorCodes.mediaGetUserMediaFailed;
  }

  if (text.contains('permission') || text.contains('notallowed')) {
    return TelnyxErrorCodes.mediaMicrophonePermissionDenied;
  }

  if (text.contains('notfound') || text.contains('overconstrained')) {
    return TelnyxErrorCodes.mediaDeviceNotFound;
  }

  return TelnyxErrorCodes.mediaGetUserMediaFailed;
}
