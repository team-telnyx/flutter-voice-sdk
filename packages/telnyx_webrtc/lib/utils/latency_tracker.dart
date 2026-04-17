import 'dart:async';

import 'package:telnyx_webrtc/model/latency_metrics.dart';
import 'package:telnyx_webrtc/utils/logging/global_logger.dart';

/// Tracks and calculates latency metrics for WebRTC call establishment.
///
/// This class provides detailed timing information for:
/// - Registration latency: Time from login to CLIENT_READY
/// - Inbound call latency: Time from acceptCall() to first RTP packet
/// - Outbound call latency: Time from newInvite() to first RTP packet
class LatencyTracker {
  // Milestone names for registration
  static const String milestoneLoginInitiated = 'login_initiated';
  static const String milestoneSocketConnected = 'socket_connected';
  static const String milestoneLoginSent = 'login_sent';
  static const String milestoneClientReady = 'client_ready';

  // Milestone names for calls
  static const String milestoneCallInitiated = 'call_initiated';
  static const String milestonePeerCreated = 'peer_connection_created';
  static const String milestonePeerSetupComplete = 'peer_setup_complete';
  static const String milestoneMediaDevicesAcquired = 'media_devices_acquired';
  static const String milestoneSdpNegotiationStarted = 'sdp_negotiation_started';
  static const String milestoneLocalSdpCreated = 'local_sdp_created';
  static const String milestoneLocalSdpSet = 'local_sdp_set';
  static const String milestoneInviteSent = 'invite_sent';
  static const String milestoneAnswerSent = 'answer_sent';
  static const String milestoneRemoteSdpReceived = 'remote_sdp_received';
  static const String milestoneRemoteSdpSet = 'remote_sdp_set';

  // Inbound call specific milestones
  static const String milestoneInviteReceived = 'invite_received';
  static const String milestoneAnswerInitiated = 'answer_initiated';

  // Outbound call specific milestones
  static const String milestoneRemoteRinging = 'remote_side_ringing';
  static const String milestoneCallAnsweredByRemote = 'call_answered_by_remote';

  // ICE gathering milestones
  static const String milestoneIceGatheringStarted = 'ice_gathering_started';
  static const String milestoneFirstIceCandidate = 'first_ice_candidate';
  static const String milestoneFirstSrflxRelayCandidate =
      'first_srflx_relay_candidate';
  static const String milestoneIceGatheringComplete = 'ice_gathering_complete';

  // ICE connection milestones
  static const String milestoneIceChecking = 'ice_checking';
  static const String milestoneIceConnected = 'ice_connected';
  static const String milestoneIceCompleted = 'ice_completed';

  // DTLS milestones
  static const String milestoneDtlsConnecting = 'dtls_connecting';
  static const String milestoneDtlsConnected = 'dtls_connected';

  // Peer connection milestones
  static const String milestonePeerConnected = 'peer_connected';
  static const String milestoneFirstRtpSent = 'first_rtp_sent';
  static const String milestoneFirstRtpReceived = 'first_rtp_received';
  static const String milestoneMediaActive = 'media_active';
  static const String milestoneCallActive = 'call_active';

  // ===== Registration Tracking =====
  int _registrationStartTime = 0;
  final Map<String, int> _registrationMilestones = {};
  bool _isTrackingRegistration = false;

  /// Whether registration tracking is currently in progress.
  bool get isTrackingRegistration => _isTrackingRegistration;

  // ===== Per-Call Tracking =====
  final Map<String, _CallTrackingState> _callTrackers = {};

  // ===== Listeners =====
  LatencyMetricsCallback? _latencyMetricsListener;

  final StreamController<LatencyMetrics> _latencyMetricsController =
      StreamController<LatencyMetrics>.broadcast();

  /// Stream of latency metrics updates.
  Stream<LatencyMetrics> get latencyMetricsStream =>
      _latencyMetricsController.stream;

  /// Sets the callback for latency metrics updates.
  void setLatencyMetricsListener(LatencyMetricsCallback? listener) {
    _latencyMetricsListener = listener;
  }

  // ===== Registration Tracking =====

  /// Starts tracking registration latency.
  /// Call this when login/connect is initiated.
  void startRegistrationTracking() {
    _registrationStartTime = DateTime.now().millisecondsSinceEpoch;
    _registrationMilestones.clear();
    _isTrackingRegistration = true;
    markRegistrationMilestone(milestoneLoginInitiated);
  }

  /// Records a milestone during registration.
  void markRegistrationMilestone(String milestone) {
    if (!_isTrackingRegistration) return;
    final elapsed =
        DateTime.now().millisecondsSinceEpoch - _registrationStartTime;
    _registrationMilestones[milestone] = elapsed;
  }

  /// Completes registration tracking and emits metrics.
  /// Call this when CLIENT_READY is received.
  void completeRegistrationTracking() {
    if (!_isTrackingRegistration) return;

    markRegistrationMilestone(milestoneClientReady);
    _isTrackingRegistration = false;

    final registrationLatency =
        DateTime.now().millisecondsSinceEpoch - _registrationStartTime;

    final metrics = LatencyMetrics(
      registrationLatencyMs: registrationLatency,
      milestones: Map.unmodifiable(_registrationMilestones),
    );

    _emitMetrics(metrics);
    GlobalLogger().i('Registration completed in ${registrationLatency}ms');
    GlobalLogger().d(metrics.toString());
  }

  // ===== Call Tracking =====

  /// Starts tracking latency for a new call.
  /// [callId] The unique identifier for the call.
  /// [isOutbound] True for outbound calls, false for inbound.
  void startCallTracking(String callId, {bool isOutbound = false}) {
    _callTrackers[callId] = _CallTrackingState(
      startTime: DateTime.now().millisecondsSinceEpoch,
      isOutbound: isOutbound,
    );
    markCallMilestone(callId, milestoneCallInitiated);
  }

  /// Records a milestone for a specific call.
  void markCallMilestone(String callId, String milestone) {
    final state = _callTrackers[callId];
    if (state == null) return;
    final elapsed =
        DateTime.now().millisecondsSinceEpoch - state.startTime;
    state.milestones[milestone] = elapsed;
  }

  /// Marks when the first RTP packet is sent or received.
  void markFirstRtp(String callId, {bool isSent = false}) {
    final milestone =
        isSent ? milestoneFirstRtpSent : milestoneFirstRtpReceived;
    markCallMilestone(callId, milestone);
  }

  /// Marks when an inbound call invite is received.
  /// Call this when the invite arrives, before user answers.
  void markInviteReceived(String callId) {
    markCallMilestone(callId, milestoneInviteReceived);
  }

  /// Marks when the user initiates answering an inbound call.
  /// Call this at the start of acceptCall().
  void markAnswerInitiated(String callId) {
    markCallMilestone(callId, milestoneAnswerInitiated);
  }

  /// Marks when the remote side starts ringing (outbound calls).
  /// Call this when SIP 180 Ringing or equivalent is received.
  void markRemoteRinging(String callId) {
    markCallMilestone(callId, milestoneRemoteRinging);
  }

  /// Marks when the remote side answers the call (outbound calls).
  /// Call this when SIP 200 OK or equivalent is received.
  void markCallAnsweredByRemote(String callId) {
    markCallMilestone(callId, milestoneCallAnsweredByRemote);
  }

  /// Marks when the first server-reflexive or relay ICE candidate is found.
  void markFirstSrflxRelayCandidate(String callId, String candidateType) {
    final state = _callTrackers[callId];
    if (state == null) return;
    // Only mark if not already marked
    if (!state.milestones.containsKey(milestoneFirstSrflxRelayCandidate)) {
      if (candidateType == 'srflx' || candidateType == 'relay') {
        markCallMilestone(callId, milestoneFirstSrflxRelayCandidate);
      }
    }
  }

  /// Marks when media devices (microphone/camera) are acquired.
  void markMediaDevicesAcquired(String callId) {
    markCallMilestone(callId, milestoneMediaDevicesAcquired);
  }

  /// Marks when SDP negotiation starts (createOffer/createAnswer).
  void markSdpNegotiationStarted(String callId) {
    markCallMilestone(callId, milestoneSdpNegotiationStarted);
  }

  /// Marks when peer setup is complete.
  void markPeerSetupComplete(String callId) {
    markCallMilestone(callId, milestonePeerSetupComplete);
  }

  /// Completes call tracking and emits the final metrics.
  /// Call this when the call reaches ACTIVE state.
  void completeCallTracking(String callId) {
    final state = _callTrackers[callId];
    if (state == null) return;

    markCallMilestone(callId, milestoneCallActive);

    final milestones = Map<String, int>.unmodifiable(state.milestones);
    final totalTime =
        DateTime.now().millisecondsSinceEpoch - state.startTime;

    // Calculate derived metrics
    final iceGatheringLatency = _calculateIceGatheringLatency(milestones);
    final signalingLatency =
        _calculateSignalingLatency(milestones, state.isOutbound);
    final mediaEstablishmentLatency =
        _calculateMediaEstablishmentLatency(milestones);
    final timeToFirstRtp = _calculateTimeToFirstRtp(milestones);

    final metrics = LatencyMetrics(
      callId: callId,
      isOutbound: state.isOutbound,
      callSetupLatencyMs: totalTime,
      timeToFirstRtpMs: timeToFirstRtp,
      iceGatheringLatencyMs: iceGatheringLatency,
      signalingLatencyMs: signalingLatency,
      mediaEstablishmentLatencyMs: mediaEstablishmentLatency,
      milestones: milestones,
    );

    _emitMetrics(metrics);
    GlobalLogger().i('Call $callId completed in ${totalTime}ms');
    GlobalLogger().d(metrics.toString());

    // Clean up
    _callTrackers.remove(callId);
  }

  /// Cancels tracking for a call (e.g., if call fails).
  void cancelCallTracking(String callId) {
    _callTrackers.remove(callId);
  }

  /// Gets current metrics snapshot for a call in progress.
  LatencyMetrics? getCurrentCallMetrics(String callId) {
    final state = _callTrackers[callId];
    if (state == null) return null;
    final milestones = Map<String, int>.unmodifiable(state.milestones);
    final currentTime =
        DateTime.now().millisecondsSinceEpoch - state.startTime;

    return LatencyMetrics(
      callId: callId,
      isOutbound: state.isOutbound,
      callSetupLatencyMs: currentTime,
      milestones: milestones,
    );
  }

  /// Calculates the answer delay for inbound calls.
  /// This is the time from invite received to user answering.
  int? calculateAnswerDelay(String callId) {
    final state = _callTrackers[callId];
    if (state == null) return null;
    final inviteReceived = state.milestones[milestoneInviteReceived];
    final answerInitiated = state.milestones[milestoneAnswerInitiated];
    if (inviteReceived == null || answerInitiated == null) return null;
    return answerInitiated - inviteReceived;
  }

  /// Calculates the time for remote side to answer (outbound calls).
  /// This is from invite sent to call answered.
  int? calculateRemoteAnswerTime(String callId) {
    final state = _callTrackers[callId];
    if (state == null) return null;
    final inviteSent = state.milestones[milestoneInviteSent];
    final callAnswered = state.milestones[milestoneCallAnsweredByRemote];
    if (inviteSent == null || callAnswered == null) return null;
    return callAnswered - inviteSent;
  }

  /// Clears all tracking state.
  void reset() {
    _registrationStartTime = 0;
    _registrationMilestones.clear();
    _isTrackingRegistration = false;
    _callTrackers.clear();
  }

  /// Disposes resources.
  void dispose() {
    _latencyMetricsController.close();
  }

  // ===== Private Helpers =====

  void _emitMetrics(LatencyMetrics metrics) {
    _latencyMetricsListener?.call(metrics);
    if (!_latencyMetricsController.isClosed) {
      _latencyMetricsController.add(metrics);
    }
  }

  int? _calculateIceGatheringLatency(Map<String, int> milestones) {
    final start = milestones[milestoneFirstIceCandidate];
    if (start == null) return null;
    final end = milestones[milestoneIceGatheringComplete] ??
        milestones[milestoneIceConnected];
    if (end == null) return null;
    return end - start;
  }

  int? _calculateSignalingLatency(
      Map<String, int> milestones, bool isOutbound) {
    if (isOutbound) {
      final start = milestones[milestoneInviteSent];
      final end = milestones[milestoneRemoteSdpReceived];
      if (start == null || end == null) return null;
      return end - start;
    } else {
      final start = milestones[milestoneCallInitiated];
      final end = milestones[milestoneAnswerSent];
      if (start == null || end == null) return null;
      return end - start;
    }
  }

  int? _calculateMediaEstablishmentLatency(Map<String, int> milestones) {
    final start = milestones[milestoneIceConnected] ??
        milestones[milestonePeerConnected];
    if (start == null) return null;
    final end = milestones[milestoneFirstRtpReceived] ??
        milestones[milestoneFirstRtpSent] ??
        milestones[milestoneMediaActive];
    if (end == null) return null;
    return end > start ? end - start : null;
  }

  int? _calculateTimeToFirstRtp(Map<String, int> milestones) {
    return milestones[milestoneFirstRtpReceived] ??
        milestones[milestoneFirstRtpSent];
  }
}

/// Internal state for per-call tracking.
class _CallTrackingState {
  final int startTime;
  final bool isOutbound;
  final Map<String, int> milestones = {};

  _CallTrackingState({
    required this.startTime,
    required this.isOutbound,
  });
}
