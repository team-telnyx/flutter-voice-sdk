import 'dart:async';
import 'dart:convert';

import 'package:telnyx_webrtc/model/jsonrpc.dart';
import 'package:telnyx_webrtc/model/socket_method.dart';
import 'package:telnyx_webrtc/model/verto/send/invite_answer_message_body.dart';
import 'package:telnyx_webrtc/model/verto/send/modify_message_body.dart';
import 'package:telnyx_webrtc/src/recovery/call_recovery_monitor.dart';
import 'package:uuid/uuid.dart';

/// Thrown when a recovery request is answered with a JSON-RPC error, or when
/// its answer is unusable.
class RecoverySignalingException implements Exception {
  /// Creates an exception with [message].
  const RecoverySignalingException(this.message);

  /// Description of the failure. Never contains SDP.
  final String message;

  @override
  String toString() => 'RecoverySignalingException: $message';
}

/// Signaling side of per-call recovery (VSDK-680), owned by `TelnyxClient`.
///
/// * Tracks the last inbound frame and the last inbound frame that answered
///   one of our requests, so recovery can tell "recent" from "stale"
///   signaling (iOS / Android / RN parity).
/// * Sends uniquely correlated `telnyx_rtc.ping` probes and
///   `telnyx_rtc.modify` (`updateMedia`) requests. Only the response carrying
///   the same JSON-RPC id resolves them; unrelated traffic never does.
///
/// The wire format is identical to the existing ping and `updateMedia`
/// messages; only the request id correlation is new.
class RecoverySignaling {
  /// Creates the recovery signaling helper. [send] writes a JSON string to
  /// the current socket and may throw when the socket is unavailable.
  RecoverySignaling({
    required void Function(String message) send,
    DateTime Function()? now,
    this.requestExpiry = const Duration(seconds: 30),
  })  : _send = send,
        _now = now ?? DateTime.now;

  final void Function(String message) _send;
  final DateTime Function() _now;

  /// Upper bound on how long an unanswered request is remembered. The
  /// monitor applies its own shorter deadlines; this only bounds memory.
  final Duration requestExpiry;

  DateTime? _lastInboundAt;
  DateTime? _lastConfirmedResponseAt;

  final Map<String, _PendingRequest> _pending = <String, _PendingRequest>{};

  /// Time since the last inbound frame, or `null` if none was seen.
  Duration? get inboundIdle => _since(_lastInboundAt);

  /// Time since an inbound frame last answered one of our requests, or
  /// `null` if none was seen.
  Duration? get confirmedOutboundIdle => _since(_lastConfirmedResponseAt);

  /// Number of requests awaiting a response (for tests).
  int get pendingCount => _pending.length;

  /// Records any inbound WebSocket frame.
  void onInboundFrame() => _lastInboundAt = _now();

  /// Records an inbound JSON-RPC response (`result` or `error`) and resolves
  /// the recovery request with the same [id], if any.
  ///
  /// Returns `true` when the response belonged to a recovery request, so the
  /// caller can skip legacy handling of that response.
  bool onResponse(String? id, Map<String, dynamic> message) {
    _lastConfirmedResponseAt = _now();
    if (id == null) return false;
    final pending = _pending.remove(id);
    if (pending == null) return false;
    pending.complete(message);
    return true;
  }

  /// Sends one correlated `telnyx_rtc.ping`. Any correlated response (result
  /// or error) proves the signaling path is alive.
  Future<SignalingProbeResult> sendProbe() async {
    final id = const Uuid().v4();
    final future = _register(id);
    try {
      _send(
        jsonEncode(<String, dynamic>{
          'jsonrpc': JsonRPCConstant.jsonrpc,
          'id': id,
          'method': SocketMethod.ping,
          'params': <String, dynamic>{},
        }),
      );
    } catch (_) {
      _pending.remove(id)?.cancel();
      return SignalingProbeResult.error;
    }
    try {
      await future;
      return SignalingProbeResult.ok;
    } on TimeoutException {
      return SignalingProbeResult.timeout;
    } catch (_) {
      return SignalingProbeResult.error;
    }
  }

  /// Sends `telnyx_rtc.modify` with `action: updateMedia` carrying [sdp] and
  /// completes with the answer SDP from the matching response.
  Future<String> sendUpdateMedia({
    required String callId,
    required String sessid,
    required String sdp,
  }) async {
    final id = const Uuid().v4();
    final future = _register(id);
    final message = ModifyMessage(
      id: id,
      jsonrpc: JsonRPCConstant.jsonrpc,
      method: SocketMethod.modify,
      params: ModifyParams(
        action: 'updateMedia',
        sessid: sessid,
        dialogParams: DialogParams(callID: callId, customHeaders: {}),
        sdp: sdp,
      ),
    );
    try {
      _send(jsonEncode(message.toJson()));
    } catch (error) {
      _pending.remove(id)?.cancel();
      throw RecoverySignalingException('updateMedia could not be sent: $error');
    }

    final response = await future;
    if (response.containsKey('error')) {
      throw const RecoverySignalingException('updateMedia was rejected');
    }
    final result = response['result'];
    final answer = result is Map ? result['sdp'] : null;
    if (answer is! String || answer.isEmpty) {
      throw const RecoverySignalingException('updateMedia answer has no SDP');
    }
    return answer;
  }

  /// Fails every pending request. Called on disconnect and disposal.
  void reset() {
    final pending = _pending.values.toList();
    _pending.clear();
    for (final request in pending) {
      request.fail(const RecoverySignalingException('signaling reset'));
    }
  }

  Future<Map<String, dynamic>> _register(String id) {
    final request = _PendingRequest(
      Timer(requestExpiry, () {
        _pending.remove(id)?.fail(TimeoutException('recovery request expired'));
      }),
    );
    _pending[id] = request;
    return request.completer.future;
  }

  Duration? _since(DateTime? at) => at == null ? null : _now().difference(at);
}

class _PendingRequest {
  _PendingRequest(this._expiry);

  final Timer _expiry;
  final Completer<Map<String, dynamic>> completer =
      Completer<Map<String, dynamic>>();

  void complete(Map<String, dynamic> message) {
    _expiry.cancel();
    if (!completer.isCompleted) completer.complete(message);
  }

  void fail(Object error) {
    _expiry.cancel();
    if (!completer.isCompleted) completer.completeError(error);
  }

  void cancel() {
    _expiry.cancel();
    // Nobody awaits a cancelled request; swallow so it is not reported as an
    // unhandled error.
    completer.future.ignore();
    if (!completer.isCompleted) {
      completer.completeError(const RecoverySignalingException('cancelled'));
    }
  }
}
