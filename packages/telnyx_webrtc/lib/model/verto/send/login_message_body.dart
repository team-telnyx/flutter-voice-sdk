import 'package:flutter/foundation.dart';
import 'package:telnyx_webrtc/utils/logging/global_logger.dart';

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
  Map<String, String>? loginParams;
  String? passwd;
  UserVariables? userVariables;
  String? sessionId;
  String? userAgent;

  LoginParams({
    this.login,
    this.loginToken,
    this.loginParams,
    this.passwd,
    this.userVariables,
    this.sessionId,
    this.userAgent,
  });

  LoginParams.fromJson(Map<String, dynamic> json) {
    login = json['login'];
    loginToken = json['login_token'];

    if (json['loginParams'] != null) {
      loginParams = Map<String, String>.from(json['loginParams']);
    }

    passwd = json['passwd'];
    sessionId = json['sessid'];
    userVariables = json['userVariables'] != null
        ? UserVariables.fromJson(json['userVariables'])
        : null;
    userAgent = json['User-Agent'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['login'] = login;
    if (loginToken != null) {
      data['login_token'] = loginToken;
    }
    if (loginParams != null) {
      data['loginParams'] = loginParams;
    }
    data['passwd'] = passwd;
    data['sessid'] = sessionId;
    if (userVariables != null) {
      data['userVariables'] = userVariables!.toJson();
    }
    if (userAgent != null) {
      data['User-Agent'] = userAgent;
    }
    return data;
  }
}

class UserVariables {
  String? pushDeviceToken;
  String? pushNotificationProvider;
  bool? pushWhenActive;
  bool? pnLateFanout;

  /// Overrides the `push_notification_environment` value emitted on the login
  /// payload. When non-null, the SDK uses this value verbatim; when null,
  /// the SDK falls back to `kDebugMode ? 'debug' : 'production'`.
  String? pushNotificationEnvironment;

  UserVariables({
    this.pushDeviceToken,
    this.pushNotificationProvider,
    this.pushWhenActive,
    this.pnLateFanout,
    this.pushNotificationEnvironment,
  });

  UserVariables.fromJson(Map<String, dynamic> json) {
    pushDeviceToken = json['push_device_token'];
    pushNotificationProvider = json['push_notification_provider'];
    pushWhenActive = json['push_when_active'];
    pnLateFanout = json['pn_late_fanout'];
    pushNotificationEnvironment = json['push_notification_environment'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['push_device_token'] = pushDeviceToken;
    data['push_notification_provider'] = pushNotificationProvider;
    // push_notification_environment defaults to a `kDebugMode`-derived value
    // for backwards compatibility; callers that build a UserVariables
    // directly (e.g. from the telnyx_client) can override via
    // [pushNotificationEnvironment] when the actual APNs / FCM environment
    // does not match the Flutter build mode (VSUP-278).
    final String pushEnvironment =
        pushNotificationEnvironment ?? (kDebugMode ? 'debug' : 'production');
    data['push_notification_environment'] = pushEnvironment;
    GlobalLogger().d('pushEnvironment: $pushEnvironment');
    // Only emit login-level opt-in flags when they have been set so existing
    // apps (which never set them) keep their current login payload shape.
    if (pushWhenActive != null) {
      data['push_when_active'] = pushWhenActive;
    }
    if (pnLateFanout != null) {
      data['pn_late_fanout'] = pnLateFanout;
    }
    return data;
  }
}
