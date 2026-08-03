import 'package:permission_handler/permission_handler.dart';
import 'package:telnyx_webrtc/model/errors/telnyx_error_event.dart';

/// Requests a permission and reports whether it was granted. Injectable so the
/// resume/reject decision can be unit-tested without the platform channel.
typedef MicPermissionRequester = Future<bool> Function();

/// Default microphone-permission requester backed by `permission_handler`.
Future<bool> requestMicrophonePermission() async {
  final status = await Permission.microphone.request();
  return status.isGranted;
}

/// Resolves an inbound [TelnyxMediaRecoveryErrorEvent] (VSDK-417) by requesting
/// the microphone permission and, when granted, calling [event.resume] to retry
/// media acquisition — otherwise [event.reject] to abort the call.
///
/// Fail-safe: any thrown error results in a best-effort [event.reject] so the
/// call never hangs waiting for the SDK's safety timeout. Logs no sensitive
/// data (the caller decides what, if anything, to log).
Future<void> resolveMediaRecovery(
  TelnyxMediaRecoveryErrorEvent event, {
  MicPermissionRequester requestMicPermission = requestMicrophonePermission,
}) async {
  try {
    final granted = await requestMicPermission();
    if (granted) {
      await event.resume();
    } else {
      await event.reject();
    }
  } catch (_) {
    // Never let a recovery-callback failure propagate; reject as a last resort.
    try {
      await event.reject();
    } catch (_) {
      // Nothing else we can safely do.
    }
  }
}
