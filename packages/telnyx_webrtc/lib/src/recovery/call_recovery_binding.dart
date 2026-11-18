import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:telnyx_webrtc/call.dart';
import 'package:telnyx_webrtc/model/errors/telnyx_error_codes.dart';
import 'package:telnyx_webrtc/model/errors/telnyx_warning_codes.dart';
import 'package:telnyx_webrtc/peer/peer.dart'
    if (dart.library.html) 'package:telnyx_webrtc/peer/web/peer.dart';
import 'package:telnyx_webrtc/src/recovery/call_recovery_monitor.dart';
import 'package:telnyx_webrtc/telnyx_client.dart';

/// Connects a [CallRecoveryMonitor] to one [Call].
///
/// The monitor decides; this binding performs the side effects through the
/// call's current [Peer] (same-peer ICE restart, answer, stats) and the
/// [TelnyxClient] (signaling freshness, correlated probes and `updateMedia`,
/// the reconnect / reattach fallback).
class CallRecoveryBinding extends CallRecoveryDelegate {
  /// Creates a binding for [call] owned by [client].
  CallRecoveryBinding(this._call, this._client);

  final Call _call;
  final TelnyxClient _client;

  String get _callId => _call.callId ?? '';

  Peer _requirePeer() {
    final peer = _call.peerConnection;
    if (peer == null) {
      throw StateError('No peer connection for call recovery');
    }
    return peer;
  }

  /// Active, and still the call the client tracks: after a reattach the
  /// replacement call owns recovery and this instance must stay passive.
  @override
  bool get isCallActive =>
      _call.callState.isActive && identical(_client.calls[_call.callId], _call);

  @override
  bool get isSignalingAvailable => _client.isConnected();

  @override
  bool get isClientReconnecting => _client.isRecoveryReconnecting;

  @override
  Duration? get inboundSignalingIdle => _client.recoverySignaling.inboundIdle;

  @override
  Duration? get confirmedOutboundIdle =>
      _client.recoverySignaling.confirmedOutboundIdle;

  @override
  RTCIceConnectionState? get peerIceState =>
      _call.peerConnection?.recoveryIceConnectionState;

  @override
  RTCPeerConnectionState? get peerConnectionState =>
      _call.peerConnection?.recoveryPeerConnectionState;

  @override
  Future<SignalingProbeResult> sendSignalingProbe() =>
      _client.recoverySignaling.sendProbe();

  @override
  Future<String> restartIce({bool applicationRequested = false}) async {
    final peer = _requirePeer();
    if (!applicationRequested) {
      _client.emitWarningCode(
        TelnyxWarningCodes.mediaRecoveryRequired,
        callId: _callId,
        reason: 'Signaling healthy, media degraded — restarting ICE',
        source: 'call_recovery',
      );
    }
    peer.recordRecoveryEvent('ice_restart_started');
    return peer.createIceRestartOffer(_callId);
  }

  @override
  Future<String> sendUpdateMedia(String offerSdp) =>
      _client.recoverySignaling.sendUpdateMedia(
        callId: _callId,
        sessid: _call.sessid,
        sdp: offerSdp,
      );

  @override
  Future<void> applyRemoteAnswer(String answerSdp) async {
    await _requirePeer().applyIceRestartAnswer(_callId, answerSdp);
  }

  @override
  Future<int?> getInboundAudioPackets() async =>
      _call.peerConnection?.inboundAudioPacketsReceived();

  @override
  Future<CandidateEvidence?> getSelectedCandidateEvidence() async =>
      _call.peerConnection?.selectedCandidateEvidence(_callId);

  @override
  void onCandidateEvidenceCaptured(CandidateEvidence evidence) =>
      _client.recordRecoveryCandidateEvidence(_callId, evidence);

  @override
  Future<bool> performReattachFallback() {
    _call.peerConnection?.recordRecoveryEvent('reattach_requested');
    return _client.requestRecoveryReattach(_callId);
  }

  @override
  void onRecovered(RecoveryOutcome outcome) {
    _call.peerConnection?.recordRecoveryEvent('recovered_${outcome.name}');
  }

  @override
  void onRecoveryFailed() {
    _call.peerConnection?.recordRecoveryEvent('recovery_failed');
    _client.emitStructuredErrorCode(
      TelnyxErrorCodes.iceRestartFailed,
      message: 'Call recovery failed after one reconnect/reattach attempt',
      callId: _callId,
    );
  }
}
