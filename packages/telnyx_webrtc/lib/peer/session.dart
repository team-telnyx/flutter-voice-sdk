import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:telnyx_webrtc/model/call_quality_metrics.dart';
import 'package:telnyx_webrtc/utils/stats/webrtc_stats_reporter.dart';

/// Represents a WebRTC session.
class Session {
  /// Creates a new session with the specified session ID and peer ID.
  Session({required this.sid, required this.pid});

  /// The peer ID for this session.
  String pid;

  /// The session ID for this session.
  String sid;

  /// The peer connection for this session.
  RTCPeerConnection? peerConnection;

  /// The data channel for this session.
  RTCDataChannel? dc;

  /// List of remote ICE candidates.
  List<RTCIceCandidate> remoteCandidates = [];
}
