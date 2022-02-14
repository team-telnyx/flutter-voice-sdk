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
  Variables? variables;
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
        this.variables,
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
    variables = json['variables'] != null
        ? Variables.fromJson(json['variables'])
        : null;
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
    if (variables != null) {
      data['variables'] = variables!.toJson();
    }
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

class Variables {
  String? eventName;
  String? coreUUID;
  String? freeSWITCHHostname;
  String? freeSWITCHSwitchname;
  String? freeSWITCHIPv4;
  String? freeSWITCHIPv6;
  String? eventDateLocal;
  String? eventDateGMT;
  String? eventDateTimestamp;
  String? eventCallingFile;
  String? eventCallingFunction;
  String? eventCallingLineNumber;
  String? eventSequence;

  Variables(
      {this.eventName,
        this.coreUUID,
        this.freeSWITCHHostname,
        this.freeSWITCHSwitchname,
        this.freeSWITCHIPv4,
        this.freeSWITCHIPv6,
        this.eventDateLocal,
        this.eventDateGMT,
        this.eventDateTimestamp,
        this.eventCallingFile,
        this.eventCallingFunction,
        this.eventCallingLineNumber,
        this.eventSequence});

  Variables.fromJson(Map<String, dynamic> json) {
    eventName = json['Event-Name'];
    coreUUID = json['Core-UUID'];
    freeSWITCHHostname = json['FreeSWITCH-Hostname'];
    freeSWITCHSwitchname = json['FreeSWITCH-Switchname'];
    freeSWITCHIPv4 = json['FreeSWITCH-IPv4'];
    freeSWITCHIPv6 = json['FreeSWITCH-IPv6'];
    eventDateLocal = json['Event-Date-Local'];
    eventDateGMT = json['Event-Date-GMT'];
    eventDateTimestamp = json['Event-Date-Timestamp'];
    eventCallingFile = json['Event-Calling-File'];
    eventCallingFunction = json['Event-Calling-Function'];
    eventCallingLineNumber = json['Event-Calling-Line-Number'];
    eventSequence = json['Event-Sequence'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['Event-Name'] = eventName;
    data['Core-UUID'] = coreUUID;
    data['FreeSWITCH-Hostname'] = freeSWITCHHostname;
    data['FreeSWITCH-Switchname'] = freeSWITCHSwitchname;
    data['FreeSWITCH-IPv4'] = freeSWITCHIPv4;
    data['FreeSWITCH-IPv6'] = freeSWITCHIPv6;
    data['Event-Date-Local'] = eventDateLocal;
    data['Event-Date-GMT'] = eventDateGMT;
    data['Event-Date-Timestamp'] = eventDateTimestamp;
    data['Event-Calling-File'] = eventCallingFile;
    data['Event-Calling-Function'] = eventCallingFunction;
    data['Event-Calling-Line-Number'] = eventCallingLineNumber;
    data['Event-Sequence'] = eventSequence;
    return data;
  }
}
