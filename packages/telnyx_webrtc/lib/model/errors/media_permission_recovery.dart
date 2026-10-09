import 'dart:async';

import 'package:telnyx_webrtc/model/errors/media_permissions_recovery_config.dart';
import 'package:telnyx_webrtc/model/errors/telnyx_error.dart';
import 'package:telnyx_webrtc/model/errors/telnyx_error_event.dart';

/// Result of a media permission recovery attempt.
enum MediaRecoveryResult {
  /// The app called [MediaPermissionRecovery.resume] and the retry
  /// `getUserMedia` succeeded.
  resumed,

  /// The app called [MediaPermissionRecovery.reject].
  rejected,

  /// The recovery timeout expired before the app called either callback.
  timedOut,

  /// The retry `getUserMedia` failed after [MediaPermissionRecovery.resume].
  retryFailed,
}

/// Encapsulates the media-permission recovery flow for a single failed
/// `getUserMedia` call during an inbound call answer.
///
/// Implements a Completer-based resume/reject gate:
///
/// - [resume] — the app signals the user has fixed permissions; the SDK
///   retries `getUserMedia`.
/// - [reject] — the app aborts the call.
/// - A safety [Timer] auto-rejects when [MediaPermissionsRecoveryConfig.timeout]
///   elapses with no app response.
///
/// The flow is:
/// 1. `getUserMedia` throws during `Peer.createStream(isAnswer: true)`.
/// 2. [MediaPermissionRecovery] is created; a [TelnyxMediaRecoveryErrorEvent]
///   is emitted with the `resume` / `reject` callbacks.
/// 3. The app calls `resume()` → SDK retries `getUserMedia`.
/// 4. On success → `onSuccess` callback, returns the new [MediaStream].
/// 5. On failure / reject / timeout → `onError` callback, rethrows.
class MediaPermissionRecovery {
  MediaPermissionRecovery._({
    required this.config,
    required this.error,
    required this.sessionId,
    required this.callId,
  });

  /// Create a new recovery flow and return the event to emit plus the
  /// recovery handle.
  ///
  /// [config] — the recovery configuration from `TelnyxClient`.
  /// [error] — the classified [TelnyxError] for the failed `getUserMedia`.
  /// [sessionId] — current SDK session ID.
  /// [callId] — inbound call ID being recovered.
  static MediaPermissionRecovery start({
    required MediaPermissionsRecoveryConfig config,
    required TelnyxError error,
    required String sessionId,
    required String callId,
  }) {
    final recovery = MediaPermissionRecovery._(
      config: config,
      error: error,
      sessionId: sessionId,
      callId: callId,
    );

    return recovery.._startTimer();
  }

  /// The recovery configuration.
  final MediaPermissionsRecoveryConfig config;

  /// The classified media error from the failed `getUserMedia`.
  final TelnyxError error;

  /// Current SDK session ID.
  final String sessionId;

  /// Inbound call ID being recovered.
  final String callId;

  /// Completer that resolves when the app calls [resume] or [reject].
  final Completer<MediaRecoveryResult> _completer =
      Completer<MediaRecoveryResult>();

  /// Safety timer that auto-rejects after [config.timeout] ms.
  Timer? _safetyTimer;

  /// Whether the recovery flow has already been resolved.
  bool get isResolved => _completer.isCompleted;

  /// The epoch timestamp (ms) after which the SDK stops waiting.
  late final int retryDeadline =
      DateTime.now().millisecondsSinceEpoch + config.timeout;

  /// Build the [TelnyxMediaRecoveryErrorEvent] to emit to the app.
  TelnyxMediaRecoveryErrorEvent toEvent() {
    return TelnyxMediaRecoveryErrorEvent(
      error: error,
      sessionId: sessionId,
      callId: callId,
      retryDeadline: retryDeadline,
      resume: resume,
      reject: reject,
    );
  }

  /// App calls this to signal the user has fixed permissions and the SDK
  /// should retry `getUserMedia`.
  Future<void> resume() async {
    if (isResolved) return;
    _cancelTimer();
    _completer.complete(MediaRecoveryResult.resumed);
  }

  /// App calls this to abort the call.
  Future<void> reject() async {
    if (isResolved) return;
    _cancelTimer();
    _completer.complete(MediaRecoveryResult.rejected);
  }

  /// Wait for the recovery flow to resolve (resume, reject, or timeout).
  Future<MediaRecoveryResult> get result => _completer.future;

  void _startTimer() {
    _safetyTimer = Timer(
      Duration(milliseconds: config.timeout),
      () {
        if (!isResolved) {
          _completer.complete(MediaRecoveryResult.timedOut);
        }
      },
    );
  }

  void _cancelTimer() {
    _safetyTimer?.cancel();
    _safetyTimer = null;
  }

  /// Clean up resources (call after the flow completes, regardless of result).
  void dispose() {
    _cancelTimer();
  }
}
