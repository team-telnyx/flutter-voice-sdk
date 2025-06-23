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
  NORMAL_CLEARING(16),
  USER_BUSY(17),
  CALL_REJECTED(21),
  UNALLOCATED_NUMBER(1),
  INCOMPATIBLE_DESTINATION(88),
  RECOVERY_ON_TIMER_EXPIRE(102),
  MANDATORY_IE_MISSING(96),
  ALLOTTED_TIMEOUT(602),
  NORMAL_TEMPORARY_FAILURE(41),
  INVALID_GATEWAY(608),
  ORIGINATOR_CANCEL(487);

  final int value;
  const CauseCode(this.value);

  static String? getCauseFromCode(int? code) {
    switch (code) {
      case 16:
        return 'NORMAL_CLEARING';
      case 17:
        return 'USER_BUSY';
      case 21:
        return 'CALL_REJECTED';
      case 1:
        return 'UNALLOCATED_NUMBER';
      case 88:
        return 'INCOMPATIBLE_DESTINATION';
      case 102:
        return 'RECOVERY_ON_TIMER_EXPIRE';
      case 96:
        return 'MANDATORY_IE_MISSING';
      case 602:
        return 'ALLOTTED_TIMEOUT';
      case 41:
        return 'NORMAL_TEMPORARY_FAILURE';
      case 608:
        return 'INVALID_GATEWAY';
      case 487:
        return 'ORIGINATOR_CANCEL';
      default:
        return 'UNKNOWN_CAUSE';
    }
  }
}
