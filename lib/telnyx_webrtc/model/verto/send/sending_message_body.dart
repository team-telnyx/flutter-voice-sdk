class SendingMessageBody {
  SendingMessageBody(this.id, this.method, this.params, this.jsonrpc);

  final String id;
  final String method;
  final ParamRequest params;
  final String jsonrpc;

  SendingMessageBody.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        method = json['method'],
        params = json['params'],
        jsonrpc = json['jsonrpc'];

  Map<String, dynamic> toJson() => {
        'id': id,
        'method': method,
        'params': params,
        'jsonrpc': jsonrpc,
      };
}

class ParamRequest {
  ParamRequest._();

  factory ParamRequest.login(String login, String passwd, String userVariables,
      List<String> loginParams) = LoginParam;
}

class LoginParam extends ParamRequest {
  LoginParam(this.login, this.passwd, this.userVariables, this.loginParams)
      : super._();

  final String login;
  final String passwd;
  final String? userVariables;
  final List<String> loginParams;
}
