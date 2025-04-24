import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:telnyx_flutter_webrtc/utils/background_detector.dart';
import 'package:uuid/uuid.dart';
import 'package:logger/logger.dart';
import 'package:telnyx_webrtc/model/push_notification.dart';

class NotificationService {
  static Future showNotification(RemoteMessage message) async {
    Logger().i('Received Incoming NotificationService! from background ${message.data}');

    final data = message.data.containsKey('extra') ? jsonDecode(message.data['extra']) : {};
    final alert = data['aps']?['alert'] ?? 'No alert';

    if (alert == 'Missed call!') {
      Logger().i('Missed call notification, do not show call kit');
      return;
    }

    final metadata = PushMetaData.fromJson(jsonDecode(message.data['metadata']));
    final currentUuid = const Uuid().v4();

    BackgroundDetector.ignore = true;
    final CallKitParams callKitParams = CallKitParams(
      id: currentUuid,
      nameCaller: metadata.callerName,
      appName: 'Telnyx Flutter Voice',
      handle: metadata.callerNumber,
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
        actionColor: '#4CAF50',
        textColor: '#ffffff',
        incomingCallNotificationChannelName: 'Incoming Call',
        missedCallNotificationChannelName: 'Missed Call',
      ),
      ios: const IOSParams(
        iconName: 'CallKitLogo',
        handleType: 'generic',
        supportsVideo: false,
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
    Logger().i('Received Incoming NotificationService! from background');
    final metadata =
        PushMetaData.fromJson(jsonDecode(message.data['metadata']));
    final currentUuid = const Uuid().v4();

    final CallKitParams callKitParams = CallKitParams(
      id: currentUuid,
      nameCaller: metadata.callerName,
      appName: 'Telnyx Flutter Voice',
      handle: metadata.callerNumber,
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
        actionColor: '#4CAF50',
        textColor: '#ffffff',
        incomingCallNotificationChannelName: 'Incoming Call',
        missedCallNotificationChannelName: 'Missed Call',
      ),
      ios: const IOSParams(
        iconName: 'CallKitLogo',
        handleType: 'generic',
        supportsVideo: false,
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
