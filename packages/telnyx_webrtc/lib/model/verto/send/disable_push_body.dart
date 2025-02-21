class DisablePushMessage {
  DisablePushMessage({
    required this.id,
    required this.method,
    required this.params,
    required this.jsonrpc,
  });

  final String id;
  final String method;
  final DisablePushParams params;
  final String jsonrpc;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'method': method,
      'params': params.toJson(),
      'jsonrpc': jsonrpc,
    };
  }
}


class DisablePushParams {
  DisablePushParams({
    this.user,
    this.loginToken,
    required this.userVariables,
  });

  final String? user;
  final String? loginToken;
  final PushUserVariables userVariables;

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'User-Agent': userVariables.toJson(),
    };
    if (user != null) {
      data['user'] = user;
    }
    if (loginToken != null) {
      data['login_token'] = loginToken;
    }
    return data;
  }
}

class PushUserVariables {
  PushUserVariables({
    required this.pushNotificationToken,
    required this.pushNotificationProvider,
  });

  final String pushNotificationToken;
  final String pushNotificationProvider;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'push_notification_token': pushNotificationToken,
      'push_notification_provider': pushNotificationProvider,
    };
  }
}