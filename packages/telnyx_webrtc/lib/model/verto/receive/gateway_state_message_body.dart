class GatewayStateMessage {
  String? jsonrpc;
  int? id;
  String? method;
  GatewayStateParams? stateParams;

  GatewayStateMessage({this.jsonrpc, this.id, this.method, this.stateParams});

  GatewayStateMessage.fromJson(Map<String, dynamic> json) {
    jsonrpc = json['jsonrpc'];
    id = json['id'];
    method = json['method'];
    stateParams = json['params'] != null
        ? GatewayStateParams.fromJson(json['params'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['jsonrpc'] = jsonrpc;
    data['id'] = id;
    data['method'] = method;
    if (stateParams != null) {
      data['params'] = stateParams!.toJson();
    }
    return data;
  }
}

class GatewayStateParams {
  String? state;

  GatewayStateParams({this.state});

  GatewayStateParams.fromJson(Map<String, dynamic> json) {
    state = json['state'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['state'] = state;
    return data;
  }
}
