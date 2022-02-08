class ReceivedMessage {
  String? jsonrpc;
  int? id;
  String? method;
  ReattachedParams? reattachedParams;
  StateParams? stateParams;

  ReceivedMessage(
      {this.jsonrpc,
      this.id,
      this.method,
      this.reattachedParams,
      this.stateParams});

  ReceivedMessage.fromJson(Map<String, dynamic> json) {
    jsonrpc = json['jsonrpc'];
    id = json['id'];
    method = json['method'];
    reattachedParams = json['params'] != null
        ? ReattachedParams.fromJson(json['params'])
        : null;
    stateParams =
        json['params'] != null ? StateParams.fromJson(json['params']) : null;
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
    return data;
  }

  @override
  String toString() {
    return 'Received Message: {jsonrpc: $jsonrpc, id: $id method: $method, reattachedParams: $reattachedParams, stateParams: $stateParams}';
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
      data['reattached_sessions'] = reattachedSessions!.map((v) => v).toList();
    }
    return data;
  }

  @override
  String toString() {
    return 'Reattached Params : $reattachedSessions';
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
