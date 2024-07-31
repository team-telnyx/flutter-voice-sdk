import 'package:flutter/foundation.dart';

class LoginMessage {
  String? id;
  String? jsonrpc;
  String? method;
  LoginParams? params;

  LoginMessage({this.id, this.jsonrpc, this.method, this.params});

  LoginMessage.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    jsonrpc = json['jsonrpc'];
    method = json['method'];
    params =
        json['params'] != null ? LoginParams.fromJson(json['params']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['jsonrpc'] = jsonrpc;
    data['method'] = method;
    if (params != null) {
      data['params'] = params!.toJson();
    }
    return data;
  }
}

class LoginParams {
  String? login;
  String? loginToken;
  List<String>? loginParams;
  String? passwd;
  UserVariables? userVariables;
  String? sessionId;
  String? attachCall = "true";
  LoginParams(
      {this.login,
      this.loginToken,
      this.loginParams,
      this.passwd,
      this.userVariables,
      this.sessionId,
      this.attachCall});

  LoginParams.fromJson(Map<String, dynamic> json) {
    login = json['login'];
    loginToken = json['login_token'];
    attachCall = "true";
    if (json['loginParams'] != null) {
      loginParams = <String>[];
      json['loginParams'].forEach((v) {
        loginParams!.add((v));
      });
    }
    passwd = json['passwd'];
    sessionId = json['sessid'];
    userVariables = json['userVariables'] != null
        ? UserVariables.fromJson(json['userVariables'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['login'] = login;
    if (loginToken != null) {
      data['login_token'] = loginToken;
    }
    if (loginParams != null) {
      data['loginParams'] = loginParams!.map((v) => v).toList();
    }
    data['passwd'] = passwd;
    data['sessid'] = sessionId;
    data['attachCall'] = attachCall;
    if (userVariables != null) {
      data['userVariables'] = userVariables!.toJson();
    }
    return data;
  }
}

class UserVariables {
  String? pushDeviceToken;
  String? pushNotificationProvider;

  UserVariables({this.pushDeviceToken, this.pushNotificationProvider});

  UserVariables.fromJson(Map<String, dynamic> json) {
    pushDeviceToken = json['push_device_token'];
    pushNotificationProvider = json['push_notification_provider'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['push_device_token'] = pushDeviceToken;
    data['push_notification_provider'] = pushNotificationProvider;
    String pushEnvironment = kDebugMode ? "debug" : "production";
    data['push_notification_environment'] = pushEnvironment;
    print("pushEnvironment: $pushEnvironment");
    return data;
  }
}
