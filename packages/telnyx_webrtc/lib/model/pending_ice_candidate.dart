/// Represents a pending ICE candidate that needs to be processed
/// after the remote description is set.
class PendingIceCandidate {
  /// The call ID this candidate belongs to
  final String callId;
  
  /// The SDP media identifier
  final String sdpMid;
  
  /// The SDP media line index
  final int sdpMLineIndex;
  
  /// The original candidate string
  final String candidateString;
  
  /// The enhanced candidate string (will be set later when ICE parameters are available)
  final String enhancedCandidateString;

  PendingIceCandidate({
    required this.callId,
    required this.sdpMid,
    required this.sdpMLineIndex,
    required this.candidateString,
    required this.enhancedCandidateString,
  });

  @override
  String toString() {
    return 'PendingIceCandidate(callId: $callId, sdpMid: $sdpMid, sdpMLineIndex: $sdpMLineIndex, candidate: $candidateString)';
  }
}