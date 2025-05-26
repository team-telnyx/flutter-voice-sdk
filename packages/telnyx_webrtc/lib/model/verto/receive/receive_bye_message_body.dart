/// Enum for Cause Codes from Telnyx documentation
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
