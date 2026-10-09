/// Verto message signalling that ICE candidate trickling has completed.
class EndOfCandidatesMessage {
  /// JSON-RPC request identifier.
  String? id;

  /// JSON-RPC protocol version.
  String? jsonrpc;

  /// Verto method name for this message.
  String? method;

  /// End-of-candidates parameters payload.
  EndOfCandidatesParams? params;

  /// Creates an end-of-candidates message from its individual fields.
  EndOfCandidatesMessage({this.id, this.jsonrpc, this.method, this.params});

  /// Creates an end-of-candidates message from a decoded JSON map.
  EndOfCandidatesMessage.fromJson(Map<String, dynamic> json) {
    id = json['id'].toString();
    jsonrpc = json['jsonrpc'];
    method = json['method'];
    params = json['params'] != null
        ? EndOfCandidatesParams.fromJson(json['params'])
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

/// Parameters for the end-of-candidates message.
class EndOfCandidatesParams {
  /// Dialog parameters identifying the call this signal belongs to.
  EndOfCandidatesDialogParams? dialogParams;

  /// Creates end-of-candidates parameters from their individual fields.
  EndOfCandidatesParams({this.dialogParams});

  /// Creates end-of-candidates parameters from a decoded JSON map.
  EndOfCandidatesParams.fromJson(Map<String, dynamic> json) {
    dialogParams = json['dialogParams'] != null
        ? EndOfCandidatesDialogParams.fromJson(json['dialogParams'])
        : null;
  }

  /// Serializes these parameters to a JSON-encodable map.
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (dialogParams != null) {
      data['dialogParams'] = dialogParams!.toJson();
    }
    return data;
  }
}

/// Dialog parameters identifying the call for an end-of-candidates message.
class EndOfCandidatesDialogParams {
  /// The unique identifier of the call.
  String? callID;

  /// Creates dialog parameters from the call identifier.
  EndOfCandidatesDialogParams({this.callID});

  /// Creates dialog parameters from a decoded JSON map.
  EndOfCandidatesDialogParams.fromJson(Map<String, dynamic> json) {
    callID = json['callID'];
  }

  /// Serializes these dialog parameters to a JSON-encodable map.
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['callID'] = callID;
    return data;
  }
}
