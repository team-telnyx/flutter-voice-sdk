class LoginMessageBody {
  LoginMessageBody(this.id, this.method, this.params, this.jsonrpc);

  final String id;
  final String method;
  final String params;
  final String jsonrpc;

  LoginMessageBody.fromJson(Map<String, dynamic> json)
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

class LoginParam {
  LoginParam(this.login, this.passwd, this.userVariables, this.loginParams);

  final String login;
  final String passwd;
  final String? userVariables;
  final List<String> loginParams;

  LoginParam.fromJson(Map<String, dynamic> json)
      : login = json['login'],
        passwd = json['passwd'],
        userVariables = json['userVariables'],
        loginParams = json['loginParams'];

  Map<String, dynamic> toJson() => {
    'login': login,
    'passwd': passwd,
    'userVariables': userVariables,
    'loginParams': loginParams,
  };
}

class NotificationParam {
  NotificationParam(this.pushDeviceToken, this.pushNotificationProvider);

  final String pushDeviceToken;
  final String pushNotificationProvider;

  NotificationParam.fromJson(Map<String, dynamic> json)
      : pushDeviceToken = json['push_device_token'],
        pushNotificationProvider = json['push_notification_provider'];

  Map<String, dynamic> toJson() => {
    'push_device_token': pushDeviceToken,
    'push_notification_provider': pushNotificationProvider,
  };
}
