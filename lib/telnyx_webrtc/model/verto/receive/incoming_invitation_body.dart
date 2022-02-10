class IncomingInvitation {
  String? jsonrpc;
  int? id;
  String? method;
  Params? params;

  IncomingInvitation({this.jsonrpc, this.id, this.method, this.params});

  IncomingInvitation.fromJson(Map<String, dynamic> json) {
    jsonrpc = json['jsonrpc'];
    id = json['id'];
    method = json['method'];
    params =
    json['params'] != null ? Params.fromJson(json['params']) : null;
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

class Params {
  String? callID;
  String? sdp;
  String? callerIdName;
  String? callerIdNumber;
  String? calleeIdName;
  String? calleeIdNumber;
  String? telnyxSessionId;
  String? telnyxLegId;
  String? displayDirection;

  Params(
      {this.callID,
        this.sdp,
        this.callerIdName,
        this.callerIdNumber,
        this.calleeIdName,
        this.calleeIdNumber,
        this.telnyxSessionId,
        this.telnyxLegId,
        this.displayDirection});

  Params.fromJson(Map<String, dynamic> json) {
    callID = json['callID'];
    sdp = json['sdp'];
    callerIdName = json['caller_id_name'];
    callerIdNumber = json['caller_id_number'];
    calleeIdName = json['callee_id_name'];
    calleeIdNumber = json['callee_id_number'];
    telnyxSessionId = json['telnyx_session_id'];
    telnyxLegId = json['telnyx_leg_id'];
    displayDirection = json['display_direction'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['callID'] = callID;
    data['sdp'] = sdp;
    data['caller_id_name'] = callerIdName;
    data['caller_id_number'] = callerIdNumber;
    data['callee_id_name'] = calleeIdName;
    data['callee_id_number'] = calleeIdNumber;
    data['telnyx_session_id'] = telnyxSessionId;
    data['telnyx_leg_id'] = telnyxLegId;
    data['display_direction'] = displayDirection;
    return data;
  }
}