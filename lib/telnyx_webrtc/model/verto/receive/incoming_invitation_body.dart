/*class IncomingInvitation {
  String? jsonrpc;
  int? id;
  String? method;
  InviteParams? params;

  IncomingInvitation({this.jsonrpc, this.id, this.method, this.params});

  IncomingInvitation.fromJson(Map<String, dynamic> json) {
    jsonrpc = json['jsonrpc'];
    id = json['id'];
    method = json['method'];
    params =
    json['params'] != null ? InviteParams.fromJson(json['params']) : null;
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
}*/


