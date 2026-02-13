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
  String? callReportId;

  GatewayStateParams({this.state, this.callReportId});

  GatewayStateParams.fromJson(Map<String, dynamic> json) {
    state = json['state'];
    callReportId = json['call_report_id'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['state'] = state;
    if (callReportId != null) {
      data['call_report_id'] = callReportId;
    }
    return data;
  }
}
