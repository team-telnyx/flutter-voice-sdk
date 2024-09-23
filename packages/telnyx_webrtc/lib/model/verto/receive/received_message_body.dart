import 'package:logger/logger.dart';
import '../send/invite_answer_message_body.dart';
import 'package:telnyx_webrtc/model/telnyx_socket_error.dart';

class ReceivedMessage {
  String? jsonrpc;
  int? id;
  String? method;
  ReattachedParams? reattachedParams;
  StateParams? stateParams;
  IncomingInviteParams? inviteParams;
  DialogParams? dialogParams;

  ReceivedMessage(
      {this.jsonrpc,
      this.id,
      this.method,
      this.reattachedParams,
      this.stateParams,
      this.inviteParams,
      this.dialogParams
      });

  ReceivedMessage.fromJson(Map<String, dynamic> json) {
    jsonrpc = json['jsonrpc'];
    id = json['id'];
    method = json['method'];
    reattachedParams = json['params'] != null
        ? ReattachedParams.fromJson(json['params'])
        : null;
    stateParams =
        json['params'] != null ? StateParams.fromJson(json['params']) : null;
    inviteParams = json['params'] != null
        ? IncomingInviteParams.fromJson(json['params'])
        : null;
    if(json['params']['dialogParams'] != null){
      dialogParams = DialogParams.fromJson(json['params']['dialogParams']);
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['jsonrpc'] = jsonrpc;
    data['id'] = id;
    data['method'] = method;
    if (reattachedParams != null) {
      data['params'] = reattachedParams!.toJson();
    }
    if (stateParams != null) {
      data['params'] = stateParams!.toJson();
    }
    if (inviteParams != null) {
      data['params'] = inviteParams!.toJson();
    }
    if (dialogParams != null) {
      data['dialogParams'] = dialogParams!.toJson();
    }
    return data;
  }

  @override
  String toString() {
    return 'Received Message: {jsonrpc: $jsonrpc, id: $id method: $method, reattachedParams: $reattachedParams, stateParams: $stateParams}';
  }
}

class ReceivedResult {
  String? jsonrpc;
  String? id;
  ResultParams? resultParams;
  String? sessId;
  TelnyxSocketError? error;

  ReceivedResult(
      {this.jsonrpc,
        this.id,
        this.resultParams});

  ReceivedResult.fromJson(Map<String, dynamic> json) {
    jsonrpc = json['jsonrpc'];
    id = json['id'];
    resultParams =
    json['result'] != null ? ResultParams.fromJson(json['result']) : null;
    sessId = json['sessid'];
    error = json['error'] != null
        ? TelnyxSocketError.fromJson(json['error'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['jsonrpc'] = jsonrpc;
    data['id'] = id;

    if (resultParams != null) {
      data['params'] = resultParams!.toJson();
    }
    return data;
  }

  @override
  String toString() {
    return 'Received Message: {jsonrpc: $jsonrpc, id: $id, stateParams: ${resultParams?.toJson()}}';
  }
}


class ReattachedParams {
  List<dynamic>? reattachedSessions;

  ReattachedParams({this.reattachedSessions});

  ReattachedParams.fromJson(Map<String, dynamic> json) {
    if (json['reattached_sessions'] != null) {
      reattachedSessions = <Null>[];
      json['reattached_sessions'].forEach((v) {
        reattachedSessions!.add(v);
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (reattachedSessions != null) {
      data['reattached_sessions'] = reattachedSessions!.map((v) => v).toList();
    }
    return data;
  }

  @override
  String toString() {
    return 'Reattached Params : $reattachedSessions';
  }
}

class ResultParams {
  StateParams? stateParams;

  ResultParams(
      {this.stateParams});

  ResultParams.fromJson(Map<String, dynamic> json) {
    stateParams =
    json['params'] != null ? StateParams.fromJson(json['params']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (stateParams != null) {
      data['params'] = stateParams!.toJson();
    }
    return data;
  }
}
class StateParams {
  String? state;

  StateParams({this.state});

  StateParams.fromJson(Map<String, dynamic> json) {
    state = json['state'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['state'] = state;
    return data;
  }

  @override
  String toString() {
    return 'State Params : $state';
  }
}

class IncomingInviteParams {
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

  IncomingInviteParams(
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

  IncomingInviteParams.fromJson(Map<String, dynamic> json) {
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
