class ResultMessage {
  String? jsonrpc;
  String? id;
  Result? result;

  ResultMessage({this.jsonrpc, this.id, this.result});

  ResultMessage.fromJson(Map<String, dynamic> json) {
    jsonrpc = json['jsonrpc'];
    id = json['id'];
    result = json['result'] != null ? Result.fromJson(json['result']) : null;
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

class Result {
  String? message;
  String? sessid;

  Result({this.message, this.sessid});

  Result.fromJson(Map<String, dynamic> json) {
    message = json['message'];
    sessid = json['sessid'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['message'] = message;
    data['sessid'] = sessid;
    return data;
  }
}
