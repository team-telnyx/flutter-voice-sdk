

/// A response to an updateMedia modify request containing the new remote SDP for ICE renegotiation
///
/// [action] the action type, should be "updateMedia"
/// [callID] the unique UUID of the call being renegotiated
/// [sdp] the new remote Session Description Protocol for ICE restart
/// [sessid] the session ID for the call
/// [holdState] the hold state of the call (e.g., "active")
class UpdateMediaResponse {
  final String action;
  final String callID;
  final String sdp;
  final String? sessid;
  final String? holdState;

  UpdateMediaResponse({
    required this.action,
    required this.callID,
    required this.sdp,
    this.sessid,
    this.holdState,
  });

  /// Creates an UpdateMediaResponse from a JSON map
  factory UpdateMediaResponse.fromJson(Map<String, dynamic> json) {
    return UpdateMediaResponse(
      action: json['action'] as String,
      callID: json['callID'] as String,
      sdp: json['sdp'] as String,
      sessid: json['sessid'] as String?,
      holdState: json['holdState'] as String?,
    );
  }

  /// Converts the UpdateMediaResponse to a JSON map
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['action'] = action;
    data['callID'] = callID;
    data['sdp'] = sdp;
    if (sessid != null) {
      data['sessid'] = sessid;
    }
    if (holdState != null) {
      data['holdState'] = holdState;
    }
    return data;
  }

  @override
  String toString() {
    return 'UpdateMediaResponse(action: $action, callID: $callID, sdp: ${sdp.length} chars, sessid: $sessid, holdState: $holdState)';
  }
}