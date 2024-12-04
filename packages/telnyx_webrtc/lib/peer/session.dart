import 'package:flutter_webrtc/flutter_webrtc.dart';

class Session {
  Session({required this.sid, required this.pid});

  String pid;
  String sid;
  RTCPeerConnection? peerConnection;
  RTCDataChannel? dc;
  List<RTCIceCandidate> remoteCandidates = [];
}
