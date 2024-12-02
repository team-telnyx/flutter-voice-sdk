import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:uuid/uuid.dart';
import 'package:logger/logger.dart';
import 'package:telnyx_webrtc/model/push_notification.dart';

class NotificationService {
  static Future showNotification(RemoteMessage message) async {
    var logger = Logger();
    print('Received Incoming NotificationService!');
    logger.i('Received Incoming NotificationService! from background');
    var metadata = PushMetaData.fromJson(jsonDecode(message.data["metadata"]));
    var received = message.data["message"];
    var currentUuid = const Uuid().v4();

    CallKitParams callKitParams = CallKitParams(
      id: currentUuid,
      nameCaller: metadata.caller_name,
      appName: 'Telnyx Flutter Voice',
      avatar: 'https://i.pravatar.cc/100',
      handle: metadata.caller_number,
      type: 0,
      textAccept: 'Accept',
      textDecline: 'Decline',
      missedCallNotification: const NotificationParams(
        showNotification: true,
        isShowCallback: true,
        subtitle: 'Missed call',
        callbackText: 'Call back',
      ),
      duration: 30000,
      extra: message.data,
      headers: <String, dynamic>{'platform': 'flutter'},
      android: const AndroidParams(
          isCustomNotification: true,
          isShowLogo: false,
          ringtonePath: 'system_ringtone_default',
          backgroundColor: '#0955fa',
          backgroundUrl: 'https://i.pravatar.cc/500',
          actionColor: '#4CAF50',
          textColor: '#ffffff',
          incomingCallNotificationChannelName: "Incoming Call",
          missedCallNotificationChannelName: "Missed Call"),
      ios: const IOSParams(
        iconName: 'CallKitLogo',
        handleType: 'generic',
        supportsVideo: true,
        maximumCallGroups: 2,
        maximumCallsPerCallGroup: 1,
        audioSessionMode: 'default',
        audioSessionActive: true,
        audioSessionPreferredSampleRate: 44100.0,
        audioSessionPreferredIOBufferDuration: 0.005,
        supportsDTMF: true,
        supportsHolding: true,
        supportsGrouping: false,
        supportsUngrouping: false,
        ringtonePath: 'system_ringtone_default',
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(callKitParams);
  }

  static Future showMissedCallNotification(RemoteMessage message) async {
    var logger = Logger();
    print('Received Incoming NotificationService!');
    logger.i('Received Incoming NotificationService! from background');
    var metadata = PushMetaData.fromJson(jsonDecode(message.data["metadata"]));
    var received = message.data["message"];
    var currentUuid = const Uuid().v4();

    CallKitParams callKitParams = CallKitParams(
      id: currentUuid,
      nameCaller: metadata.caller_name,
      appName: 'Telnyx Flutter Voice',
      avatar: 'https://i.pravatar.cc/100',
      handle: metadata.caller_number,
      type: 0,
      textAccept: 'Accept',
      textDecline: 'Decline',
      missedCallNotification: const NotificationParams(
        showNotification: true,
        isShowCallback: true,
        subtitle: 'Missed call',
        callbackText: 'Call back',
      ),
      duration: 30000,
      extra: message.data,
      headers: <String, dynamic>{'platform': 'flutter'},
      android: const AndroidParams(
          isCustomNotification: true,
          isShowLogo: false,
          ringtonePath: 'system_ringtone_default',
          backgroundColor: '#0955fa',
          backgroundUrl: 'https://i.pravatar.cc/500',
          actionColor: '#4CAF50',
          textColor: '#ffffff',
          incomingCallNotificationChannelName: "Incoming Call",
          missedCallNotificationChannelName: "Missed Call"),
      ios: const IOSParams(
        iconName: 'CallKitLogo',
        handleType: 'generic',
        supportsVideo: true,
        maximumCallGroups: 2,
        maximumCallsPerCallGroup: 1,
        audioSessionMode: 'default',
        audioSessionActive: true,
        audioSessionPreferredSampleRate: 44100.0,
        audioSessionPreferredIOBufferDuration: 0.005,
        supportsDTMF: true,
        supportsHolding: true,
        supportsGrouping: false,
        supportsUngrouping: false,
        ringtonePath: 'system_ringtone_default',
      ),
    );

    await FlutterCallkitIncoming.showMissCallNotification(callKitParams);
  }
}
