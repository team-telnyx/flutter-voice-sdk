/// Verto message carrying a single trickle ICE candidate to the server.
class CandidateMessage {
  /// JSON-RPC request identifier.
  String? id;

  /// JSON-RPC protocol version.
  String? jsonrpc;

  /// Verto method name for this message.
  String? method;

  /// Candidate parameters payload.
  CandidateParams? params;

  /// Creates a candidate message from its individual fields.
  CandidateMessage({this.id, this.jsonrpc, this.method, this.params});

  /// Creates a candidate message from a decoded JSON map.
  CandidateMessage.fromJson(Map<String, dynamic> json) {
    id = json['id'].toString();
    jsonrpc = json['jsonrpc'];
    method = json['method'];
    params = json['params'] != null
        ? CandidateParams.fromJson(json['params'])
        : null;
  }

  /// Serializes this message to a JSON-encodable map.
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['jsonrpc'] = jsonrpc;
    data['method'] = method;
    if (params != null) {
      data['params'] = params!.toJson();
    }
    return data;
  }
}

/// Parameters describing a single ICE candidate for a call.
class CandidateParams {
  /// Dialog parameters identifying the call this candidate belongs to.
  CandidateDialogParams? dialogParams;

  /// The SDP candidate string.
  String? candidate;

  /// The SDP media stream identifier.
  String? sdpMid;

  /// The SDP media line index.
  int? sdpMLineIndex;

  /// Creates candidate parameters from their individual fields.
  CandidateParams({
    this.dialogParams,
    this.candidate,
    this.sdpMid,
    this.sdpMLineIndex,
  });

  /// Creates candidate parameters from a decoded JSON map.
  CandidateParams.fromJson(Map<String, dynamic> json) {
    dialogParams = json['dialogParams'] != null
        ? CandidateDialogParams.fromJson(json['dialogParams'])
        : null;
    candidate = json['candidate'];
    sdpMid = json['sdpMid'];
    sdpMLineIndex = json['sdpMLineIndex'];
  }

  /// Serializes these parameters to a JSON-encodable map.
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (dialogParams != null) {
      data['dialogParams'] = dialogParams!.toJson();
    }
    data['candidate'] = candidate;
    data['sdpMid'] = sdpMid;
    data['sdpMLineIndex'] = sdpMLineIndex;
    return data;
  }
}

/// Dialog parameters identifying the call for an ICE candidate message.
class CandidateDialogParams {
  /// The unique identifier of the call.
  String? callID;

  /// Creates dialog parameters from the call identifier.
  CandidateDialogParams({this.callID});

  /// Creates dialog parameters from a decoded JSON map.
  CandidateDialogParams.fromJson(Map<String, dynamic> json) {
    callID = json['callID'];
  }

  /// Serializes these dialog parameters to a JSON-encodable map.
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['callID'] = callID;
    return data;
  }
}
