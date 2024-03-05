
import 'dart:convert';

AttachCallMessage attachCallMessageFromJson(String str) => AttachCallMessage.fromJson(json.decode(str));

String attachCallMessageToJson(AttachCallMessage data) => json.encode(data.toJson());

class AttachCallMessage {
    AttachCallMessage({
        this.method,
        this.id,
        this.params,
        this.jsonrpc,
    });

    String? method;
    String? id;
    Params? params;
    String? jsonrpc;

    factory AttachCallMessage.fromJson(Map<dynamic, dynamic> json) => AttachCallMessage(
        method: json["method"],
        id: json["id"],
        params: Params.fromJson(json["params"]),
        jsonrpc: json["jsonrpc"],
    );

    Map<dynamic, dynamic> toJson() => {
        "method": method,
        "id": id,
        "params": params?.toJson(),
        "jsonrpc": jsonrpc,
    };
}

class Params {
    Params({
        required this.pushNotificationProvider,
        required this.userVariables,
        required this.loginParams,
    });

    String pushNotificationProvider;
    Map<dynamic, dynamic> userVariables;
    Map<dynamic, dynamic> loginParams;

    factory Params.fromJson(Map<dynamic, dynamic> json) => Params(
        pushNotificationProvider: json["push_notification_provider"],
        userVariables: Map<dynamic, dynamic>.from(json["userVariables"]),
        loginParams: Map<dynamic, dynamic>.from(json["loginParams"]),
    );

    Map<dynamic, dynamic> toJson() => {
        "push_notification_provider": pushNotificationProvider,
        "userVariables": userVariables,
        "loginParams": loginParams,
    };
}


