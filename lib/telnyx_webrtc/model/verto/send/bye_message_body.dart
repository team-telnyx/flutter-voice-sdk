// ignore_for_file: constant_identifier_names

class ByeMessage {
  String? id;
  String? jsonrpc;
  String? method;
  ByeParams? params;

  ByeMessage({this.id, this.jsonrpc, this.method, this.params});

  ByeMessage.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    jsonrpc = json['jsonrpc'];
    method = json['method'];
    params =
    json['params'] != null ? ByeParams.fromJson(json['params']) : null;
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

class ByeParams {
  String? cause;
  int? causeCode;
  ByeDialogParams? dialogParams;
  String? sessionId;

  ByeParams({this.cause, this.causeCode, this.dialogParams, this.sessionId});

  ByeParams.fromJson(Map<String, dynamic> json) {
    cause = json['cause'];
    causeCode = json['causeCode'];
    dialogParams = json['dialogParams'] != null
        ? ByeDialogParams.fromJson(json['dialogParams'])
        : null;
    sessionId = json['sessionId'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['cause'] = cause;
    data['causeCode'] = causeCode;
    if (dialogParams != null) {
      data['dialogParams'] = dialogParams!.toJson();
    }
    data['sessionId'] = sessionId;
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