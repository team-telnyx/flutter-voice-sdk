/// Message to acknowledge receipt of a ringing event
class RingingAckMessage {
  String? jsonrpc;
  dynamic id;
  RingingAckResult? result;

  RingingAckMessage({this.jsonrpc, this.id, this.result});

  RingingAckMessage.fromJson(Map<String, dynamic> json) {
    jsonrpc = json['jsonrpc'];
    id = json['id'];
    result = json['result'] != null
        ? RingingAckResult.fromJson(json['result'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['jsonrpc'] = jsonrpc;
    data['id'] = id;
    if (result != null) {
      data['result'] = result!.toJson();
    }
    return data;
  }
}

/// Result object for ringing acknowledgement
class RingingAckResult {
  String? method;

  RingingAckResult({this.method});

  RingingAckResult.fromJson(Map<String, dynamic> json) {
    method = json['method'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['method'] = method;
    return data;
  }
}
