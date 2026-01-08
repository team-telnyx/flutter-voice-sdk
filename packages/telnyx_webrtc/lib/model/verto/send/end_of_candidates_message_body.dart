class EndOfCandidatesMessage {
  String? id;
  String? jsonrpc;
  String? method;
  EndOfCandidatesParams? params;

  EndOfCandidatesMessage({this.id, this.jsonrpc, this.method, this.params});

  EndOfCandidatesMessage.fromJson(Map<String, dynamic> json) {
    id = json['id'].toString();
    jsonrpc = json['jsonrpc'];
    method = json['method'];
    params = json['params'] != null ? EndOfCandidatesParams.fromJson(json['params']) : null;
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

class EndOfCandidatesParams {
  EndOfCandidatesDialogParams? dialogParams;

  EndOfCandidatesParams({this.dialogParams});

  EndOfCandidatesParams.fromJson(Map<String, dynamic> json) {
    dialogParams = json['dialogParams'] != null
        ? EndOfCandidatesDialogParams.fromJson(json['dialogParams'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (dialogParams != null) {
      data['dialogParams'] = dialogParams!.toJson();
    }
    return data;
  }
}

class EndOfCandidatesDialogParams {
  String? callID;

  EndOfCandidatesDialogParams({this.callID});

  EndOfCandidatesDialogParams.fromJson(Map<String, dynamic> json) {
    callID = json['callID'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['callID'] = callID;
    return data;
  }
}