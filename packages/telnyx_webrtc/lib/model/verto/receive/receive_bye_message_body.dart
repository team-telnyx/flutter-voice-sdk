import 'package:telnyx_webrtc/model/verto/send/send_bye_message_body.dart';

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
    return {
      'jsonrpc': jsonrpc,
      'id': id,
      'method': method,
      'params': params?.toJson(),
    };
  }
}

class ReceiveByeParams {
  String? callID;
  String? sipCallId;
  int? sipCode;
  int? causeCode;
  String? cause;
  String? sipReason;

  ReceiveByeParams({
    this.callID,
    this.sipCallId,
    this.sipCode,
    this.causeCode,
    this.cause,
    this.sipReason,
  });

  ReceiveByeParams.fromJson(Map<String, dynamic> json) {
    callID = json['callID'];
    sipCallId = json['sip_call_id'];
    sipCode = json['sipCode'];
    causeCode = json['causeCode'];
    cause = CauseCode.getCauseFromCode(causeCode);
    sipReason = json['sipReason'];
  }

  Map<String, dynamic> toJson() {
    return {
      'callID': callID,
      'sip_call_id': sipCallId,
      'sipCode': sipCode,
      'causeCode': causeCode,
      'cause': cause ?? CauseCode.getCauseFromCode(causeCode),
      'sipReason': sipReason,
    };
  }
}
