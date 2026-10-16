import 'dart:convert';

AttachCallMessage attachCallMessageFromJson(String str) =>
    AttachCallMessage.fromJson(json.decode(str));

String attachCallMessageToJson(AttachCallMessage data) =>
    json.encode(data.toJson());

class AttachCallMessage {
  AttachCallMessage({this.method, this.id, this.params, this.jsonrpc});

  String? method;
  String? id;
  Params? params;
  String? jsonrpc;

  factory AttachCallMessage.fromJson(Map<dynamic, dynamic> json) =>
      AttachCallMessage(
        method: json['method'],
        id: json['id'],
        params: Params.fromJson(json['params']),
        jsonrpc: json['jsonrpc'],
      );

  Map<dynamic, dynamic> toJson() => {
    'method': method,
    'id': id,
    'params': params?.toJson(),
    'jsonrpc': jsonrpc,
  };
}

class Params {
  Params({
    required this.userVariables,
    this.mobileSdkName,
    this.mobileSdkVersion,
  });

  Map<dynamic, dynamic> userVariables;
  String? mobileSdkName;
  String? mobileSdkVersion;

  factory Params.fromJson(Map<dynamic, dynamic> json) => Params(
    userVariables: Map<dynamic, dynamic>.from(json['userVariables']),
    mobileSdkName: json['mobile_sdk_name'],
    mobileSdkVersion: json['mobile_sdk_version'],
  );

  Map<dynamic, dynamic> toJson() => {
    'userVariables': userVariables,
    if (mobileSdkName != null) 'mobile_sdk_name': mobileSdkName,
    if (mobileSdkVersion != null) 'mobile_sdk_version': mobileSdkVersion,
  };
}

//        pushNotificationProvider: json["push_notification_provider"],
