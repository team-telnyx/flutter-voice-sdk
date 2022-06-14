class ReceiveByeMessage {
  String? jsonrpc;
  int? id;
  String? method;
  ReceiveByeParams? params;

  ReceiveByeMessage({this.jsonrpc, this.id, this.method, this.params});

  ReceiveByeMessage.fromJson(Map<String, dynamic> json) {
    jsonrpc = json['jsonrpc'];
    id = json['id'];
    method = json['method'];
    params = json['params'] != null
        ? ReceiveByeParams.fromJson(json['params'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['jsonrpc'] = jsonrpc;
    data['id'] = id;
    data['method'] = method;
    if (params != null) {
      data['params'] = params!.toJson();
    }
    return data;
  }
}

class ReceiveByeParams {
  String? callID;
  String? sipCallId;
  int? sipCode;
  int? causeCode;
  String? cause;

  ReceiveByeParams(
      {this.callID, this.sipCallId, this.sipCode, this.causeCode, this.cause});

  ReceiveByeParams.fromJson(Map<String, dynamic> json) {
    callID = json['callID'];
    sipCallId = json['sip_call_id'];
    sipCode = json['sipCode'];
    causeCode = json['causeCode'];
    cause = json['cause'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['callID'] = callID;
    data['sip_call_id'] = sipCallId;
    data['sipCode'] = sipCode;
    data['causeCode'] = causeCode;
    data['cause'] = cause;
    return data;
  }
}
