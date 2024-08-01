class PushNotification {
  PushNotification({
    required this.metadata,
    required this.message,
  });

  PushMetaData metadata;
  String message;
}

class PushMetaData {
  PushMetaData({this.caller_name, this.caller_number, this.call_id});

  String? caller_name;
  String? caller_number;
  String? call_id;
  String? voice_sdk_id;
  bool? isAnswer;
  bool? isDecline;


  PushMetaData.fromJson(Map<dynamic, dynamic> json) {
    caller_name = json['caller_name'];
    caller_number = json['caller_number'];
    call_id = json['call_id'];
    voice_sdk_id = json['voice_sdk_id'];
    isAnswer = json['isAnswer'];
    isDecline = json['isDecline'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['caller_name'] = caller_name;
    data['caller_number'] = caller_number;
    data['call_id'] = call_id;
    data['voice_sdk_id'] = voice_sdk_id;
    data['isAnswer'] = isAnswer;
    data['isDecline'] = isDecline;
    return data;
  }
}
