class SendingMessageBody {
  SendingMessageBody(this.id, this.method, this.params);

  final String id;
  final String method;
  final ParamRequest params;
  final String jsonrpc = "2.0";
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
