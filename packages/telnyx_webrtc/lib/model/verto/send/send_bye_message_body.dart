// ignore_for_file: constant_identifier_names

class SendByeMessage {
  String? id;
  String? jsonrpc;
  String? method;
  SendByeParams? params;

  SendByeMessage({this.id, this.jsonrpc, this.method, this.params});

  SendByeMessage.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    jsonrpc = json['jsonrpc'];
    method = json['method'];
    params =
        json['params'] != null ? SendByeParams.fromJson(json['params']) : null;
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

class SendByeParams {
  String? cause;
  int? causeCode;
  ByeDialogParams? dialogParams;
  String? sessid;

  SendByeParams({this.cause, this.causeCode, this.dialogParams, this.sessid});

  SendByeParams.fromJson(Map<String, dynamic> json) {
    cause = json['cause'];
    causeCode = json['causeCode'];
    dialogParams = json['dialogParams'] != null
        ? ByeDialogParams.fromJson(json['dialogParams'])
        : null;
    sessid = json['sessid'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['cause'] = cause;
    data['causeCode'] = causeCode;
    if (dialogParams != null) {
      data['dialogParams'] = dialogParams!.toJson();
    }
    data['sessid'] = sessid;
    return data;
  }
}

class ByeDialogParams {
  String? callId;

  ByeDialogParams({this.callId});

  ByeDialogParams.fromJson(Map<String, dynamic> json) {
    callId = json['callId'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['callId'] = callId;
    return data;
  }
}

enum CauseCode {
  USER_BUSY,
  NORMAL_CLEARING,
  INVALID_GATEWAY,
  ORIGINATOR_CANCEL
}
