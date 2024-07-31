
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
        required this.userVariables,
    });

    Map<dynamic, dynamic> userVariables;

    factory Params.fromJson(Map<dynamic, dynamic> json) => Params(
        userVariables: Map<dynamic, dynamic>.from(json["userVariables"]),
    );

    Map<dynamic, dynamic> toJson() => {
        "userVariables": userVariables,
    };
}


//        pushNotificationProvider: json["push_notification_provider"],