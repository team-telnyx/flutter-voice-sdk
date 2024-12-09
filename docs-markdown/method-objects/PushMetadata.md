### PushMetaData

This class is used to represent the metadata received from a push notification. It contains a `callerName`, `callerNumber`, `callId`, `voiceSdkId`, `isAnswer` and `isDecline` which are strings representing the metadata received from the push notification.

the `isAnswer` and `isDecline` are boolean values representing the state of the call.

the `callerName`, `callerNumber`, `callId`, `voiceSdkId` are strings representing information about the caller and SDK.

```dart
class PushMetaData {
  PushMetaData({
    this.callerName,
    this.callerNumber,
    this.callId,
    this.voiceSdkId,
  });

  String? callerName;
  String? callerNumber;
  String? callId;
  String? voiceSdkId;
  bool? isAnswer;
  bool? isDecline;

  PushMetaData.fromJson(Map<dynamic, dynamic> json) {
    callerName = json['caller_name'];
    callerNumber = json['caller_number'];
    callId = json['call_id'];
    voiceSdkId = json['voice_sdk_id'];
    isAnswer = json['isAnswer'];
    isDecline = json['isDecline'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['caller_name'] = callerName;
    data['caller_number'] = callerNumber;
    data['call_id'] = callId;
    data['voice_sdk_id'] = voiceSdkId;
    data['isAnswer'] = isAnswer;
    data['isDecline'] = isDecline;
    return data;
  }
}
```