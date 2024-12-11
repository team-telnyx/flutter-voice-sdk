import 'package:flutter_webrtc/flutter_webrtc.dart';

class StatParsingHelpers {
  Map<String, dynamic> parseCandidatePair(Map<String, dynamic> candidate) {
    return {
      'id': candidate['id'],
      'state': candidate['state'],
      'bytesSent': candidate['bytesSent'],
      'bytesReceived': candidate['bytesReceived'],
      'currentRoundTripTime': candidate['currentRoundTripTime'],
      'priority': candidate['priority'],
      'nominated': candidate['nominated'],
    };
  }

  String? parseUsernameFragment(RTCIceCandidate candidate) {
    if (candidate.candidate == null || candidate.candidate!.isEmpty) {
      return null;
    }
    final regex = RegExp(r'ufrag\s+(\w+)');
    final match = regex.firstMatch(candidate.candidate!);
    return match?.group(1);
  }

  String parseSignalingStateChange(RTCSignalingState signalingState) {
    switch (signalingState) {
      case RTCSignalingState.RTCSignalingStateStable:
        return 'stable';
      case RTCSignalingState.RTCSignalingStateHaveLocalOffer:
        return 'have-local-offer';
      case RTCSignalingState.RTCSignalingStateHaveLocalPrAnswer:
        return 'have-local-pr-answer';
      case RTCSignalingState.RTCSignalingStateHaveRemoteOffer:
        return 'have-remote-offer';
      case RTCSignalingState.RTCSignalingStateHaveRemotePrAnswer:
        return 'have-remote-pr-answer';
      case RTCSignalingState.RTCSignalingStateClosed:
        return 'closed';
      default:
        return 'unknown';
    }
  }

  String parseIceGatheringStateChange(RTCIceGatheringState gatheringState) {
    switch (gatheringState) {
      case RTCIceGatheringState.RTCIceGatheringStateNew:
        return 'new';
      case RTCIceGatheringState.RTCIceGatheringStateGathering:
        return 'gathering';
      case RTCIceGatheringState.RTCIceGatheringStateComplete:
        return 'complete';
      default:
        return 'unknown';
    }
  }

  String parseIceConnectionStateChange(RTCIceConnectionState iceConnectionState) {
    switch (iceConnectionState) {
      case RTCIceConnectionState.RTCIceConnectionStateNew:
        return 'new';
      case RTCIceConnectionState.RTCIceConnectionStateChecking:
        return 'checking';
      case RTCIceConnectionState.RTCIceConnectionStateConnected:
        return 'connected';
      case RTCIceConnectionState.RTCIceConnectionStateCompleted:
        return 'completed';
      case RTCIceConnectionState.RTCIceConnectionStateFailed:
        return 'failed';
      case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
        return 'disconnected';
      case RTCIceConnectionState.RTCIceConnectionStateClosed:
        return 'closed';
      case RTCIceConnectionState.RTCIceConnectionStateCount:
        return 'count';
      default:
        return 'unknown';
    }
  }

  String parseConnectionStateChange(RTCPeerConnectionState connectionState) {
    switch (connectionState) {
      case RTCPeerConnectionState.RTCPeerConnectionStateNew:
        return 'new';
      case RTCPeerConnectionState.RTCPeerConnectionStateConnecting:
        return 'connecting';
      case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        return 'connected';
      case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
        return 'disconnected';
      case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        return 'failed';
      case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
        return 'closed';
      default:
        return 'unknown';
    }
  }

  Map<String, dynamic> getPeerConfiguration(
    Map<String, dynamic> configuration,
  ) {
    final iceServers =
        (configuration['iceServers'] as List<dynamic>?)?.map((iceServer) {
      return {
        'urls':
            iceServer['url'] is String ? [iceServer['url']] : iceServer['url'],
        'username': iceServer['username'] ?? '',
        //'credential': iceServer['credential'] ?? '',
      };
    }).toList();

    return {
      'bundlePolicy': 'max-compat',
      'encodedInsertableStreams': false,
      'iceCandidatePoolSize': 0,
      'iceServers': iceServers ?? [],
      'iceTransportPolicy': 'all',
      'rtcpMuxPolicy': 'require',
    };
  }
}
