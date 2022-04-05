class GatewayRequestMessage {
  String? id;
  String? jsonrpc;
  String? method;
  GatewayRequestStateParams? params;

  GatewayRequestMessage({this.id, this.jsonrpc, this.method, this.params});

  GatewayRequestMessage.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    jsonrpc = json['jsonrpc'];
    method = json['method'];
    params = json['params'] != null
        ? GatewayRequestStateParams.fromJson(json['params'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = this.id;
    data['jsonrpc'] = this.jsonrpc;
    data['method'] = this.method;
    if (this.params != null) {
      data['params'] = this.params!.toJson();
    }
    return data;
  }
}

class GatewayRequestStateParams {
  List<void>? gatewayRequestParams;

  GatewayRequestStateParams({this.gatewayRequestParams});

  GatewayRequestStateParams.fromJson(Map<String, dynamic> json) {
    if (json['reattached_sessions'] != null) {
      gatewayRequestParams = <Null>[];
      json['reattached_sessions'].forEach((v) {
        gatewayRequestParams!.add(v);
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (gatewayRequestParams != null) {
      data['reattached_sessions'] =
          gatewayRequestParams!.map((v) => v).toList();
    }
    return data;
  }

  @override
  String toString() {
    return 'Reattached Params : $gatewayRequestParams';
  }
}
