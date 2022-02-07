class ReceivedMessage {
  String? jsonrpc;
  int? id;
  String? method;
  ReattachedParams? params;

  ReceivedMessage({this.jsonrpc, this.id, this.method, this.params});

  ReceivedMessage.fromJson(Map<String, dynamic> json) {
    jsonrpc = json['jsonrpc'];
    id = json['id'];
    method = json['method'];
    params =
    json['params'] != null ? ReattachedParams.fromJson(json['params']) : null;
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

class ReattachedParams {
  List<void>? reattachedSessions;

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
      data['reattached_sessions'] =
          reattachedSessions!.map((v) => v).toList();
    }
    return data;
  }
}