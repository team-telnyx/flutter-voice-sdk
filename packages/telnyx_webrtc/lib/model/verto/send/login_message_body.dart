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
    params = json['params'] != null
        ? LoginParams.fromJson(json['params'])
        : null;
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
  String? mobileSdkName;
  String? mobileSdkVersion;

  LoginParams({
    this.login,
    this.loginToken,
    this.loginParams,
    this.passwd,
    this.userVariables,
    this.sessionId,
    this.userAgent,
    this.mobileSdkName,
    this.mobileSdkVersion,
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
    mobileSdkName = json['mobile_sdk_name'];
    mobileSdkVersion = json['mobile_sdk_version'];
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
    if (mobileSdkName != null) {
      data['mobile_sdk_name'] = mobileSdkName;
    }
    if (mobileSdkVersion != null) {
      data['mobile_sdk_version'] = mobileSdkVersion;
    }
    return data;
  }
}

class UserVariables {
  String? pushDeviceToken;
  String? pushNotificationProvider;
  bool? pushWhenActive;
  bool? pnLateFanout;

  /// SDK identity name emitted on the wire as `mobile_sdk_name`.
  ///
  /// Resolved from [Config.effectiveSdkName] (defaults to `flutter` when the
  /// caller does not supply an override). See VSDK-769.
  String? mobileSdkName;

  /// SDK identity version emitted on the wire as `mobile_sdk_version`.
  ///
  /// Resolved from [Config.effectiveSdkVersion] (defaults to the authoritative
  /// package version when the caller does not supply an override). See
  /// VSDK-769.
  String? mobileSdkVersion;

  UserVariables({
    this.pushDeviceToken,
    this.pushNotificationProvider,
    this.pushWhenActive,
    this.pnLateFanout,
    this.mobileSdkName,
    this.mobileSdkVersion,
  });

  UserVariables.fromJson(Map<String, dynamic> json)
    : pushWhenActive = _jsonBool(json['push_when_active']),
      pnLateFanout = _jsonBool(json['pn_late_fanout']) {
    pushDeviceToken = json['push_device_token'];
    pushNotificationProvider = json['push_notification_provider'];
    mobileSdkName = json['mobile_sdk_name'];
    mobileSdkVersion = json['mobile_sdk_version'];
  }

  static bool? _jsonBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['push_device_token'] = pushDeviceToken;
    data['push_notification_provider'] = pushNotificationProvider;
    const String pushEnvironment = kDebugMode ? 'debug' : 'production';
    data['push_notification_environment'] = pushEnvironment;
    GlobalLogger().d('pushEnvironment: $pushEnvironment');
    // Mobile SDK identity (VSDK-769) — `mobile_sdk_name` and
    // `mobile_sdk_version` are always emitted together. Defaults are resolved
    // at the SDK layer (Config.effectiveSdkName / effectiveSdkVersion) so this
    // serializer never has to special-case the override path.
    if (mobileSdkName != null) {
      data['mobile_sdk_name'] = mobileSdkName;
    }
    if (mobileSdkVersion != null) {
      data['mobile_sdk_version'] = mobileSdkVersion;
    }
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
