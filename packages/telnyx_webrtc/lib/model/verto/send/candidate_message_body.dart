class CandidateMessage {
  String? id;
  String? jsonrpc;
  String? method;
  CandidateParams? params;

  CandidateMessage({this.id, this.jsonrpc, this.method, this.params});

  CandidateMessage.fromJson(Map<String, dynamic> json) {
    id = json['id'].toString();
    jsonrpc = json['jsonrpc'];
    method = json['method'];
    params = json['params'] != null ? CandidateParams.fromJson(json['params']) : null;
  }

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

class CandidateParams {
  CandidateDialogParams? dialogParams;
  String? candidate;
  String? sdpMid;
  int? sdpMLineIndex;

  CandidateParams({this.dialogParams, this.candidate, this.sdpMid, this.sdpMLineIndex});

  CandidateParams.fromJson(Map<String, dynamic> json) {
    dialogParams = json['dialogParams'] != null
        ? CandidateDialogParams.fromJson(json['dialogParams'])
        : null;
    candidate = json['candidate'];
    sdpMid = json['sdpMid'];
    sdpMLineIndex = json['sdpMLineIndex'];
  }

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

class CandidateDialogParams {
  String? callID;

  CandidateDialogParams({this.callID});

  CandidateDialogParams.fromJson(Map<String, dynamic> json) {
    callID = json['callID'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['callID'] = callID;
    return data;
  }
}