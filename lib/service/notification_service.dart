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
import 'package:telnyx_webrtc/telnyx_client.dart';

const int _CALL_MISSED_TIMEOUT_SECONDS = 30;

class NotificationService {
  static Future showNotification(RemoteMessage message) async {
    final logger = Logger()
    ..i('NotificationService.showNotification: Received message: ${message.data}');

    try {
      // Use a default map if metadata is missing or invalid
      final Map<String, dynamic> metadataMap = message.data.containsKey('metadata')
          ? jsonDecode(message.data['metadata'] ?? '{}') 
          : {}; 
      final metadata = PushMetaData.fromJson(metadataMap); 

      // Check for the actual call ID from Telnyx metadata (using camelCase)
      final String? telnyxCallId = metadata.callId;

      // Check for incorrect notification type, ie missed call message
      if (message.data.containsKey('message') && message.data['message'] == 'Missed call!') {
        logger.i('NotificationService.showNotification: Received a message flagged as "Missed call!", aborting showing incoming UI.');
        return;
      }

      // Check for Stale Notification
      if (message.sentTime != null) {
        final DateTime nowTime = DateTime.now();
        final Duration difference = nowTime.difference(message.sentTime!); 
        logger.i('NotificationService.showNotification: Time difference since sent: ${difference.inSeconds} seconds.');
        if (difference.inSeconds > _CALL_MISSED_TIMEOUT_SECONDS) {
          logger.w('NotificationService.showNotification: Notification is stale (>${_CALL_MISSED_TIMEOUT_SECONDS}s). Showing missed call instead. ID: $telnyxCallId');
          await showMissedCallNotification(message);
          return;
        }
      } else {
         logger.w('NotificationService.showNotification: message.sentTime is null, cannot check for staleness.');
      }

      if (telnyxCallId == null || telnyxCallId.isEmpty) {
        logger.e('NotificationService.showNotification: Missing or empty callId in metadata. Cannot show CallKit notification.'); // Corrected log
        return; // Cannot proceed without a valid ID
      }

      logger.i('NotificationService.showNotification: Showing CallKit incoming UI for call ID: $telnyxCallId');
      BackgroundDetector.ignore = true;
      final CallKitParams callKitParams = CallKitParams(
        id: telnyxCallId,
        nameCaller: metadata.callerName,
        appName: 'Telnyx Flutter Voice',
        handle: metadata.callerNumber,
        type: 0, // 0 for audio call, 1 for video call
        textAccept: 'Accept',
        textDecline: 'Decline',
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
      logger.i('NotificationService.showNotification: CallKit incoming UI displayed for $telnyxCallId.');

    } catch (e) {
      logger.e('NotificationService.showNotification: Error processing notification: $e');
      TelnyxClient.clearPushMetaData();
    }
  }

  static Future showMissedCallNotification(RemoteMessage message) async {
    final logger = Logger()
    ..i('NotificationService.showMissedCallNotification: Received message: ${message.data}');
    
    try {
      final Map<String, dynamic> metadataMap = message.data.containsKey('metadata') 
          ? jsonDecode(message.data['metadata'] ?? '{}') 
          : {};
      final metadata = PushMetaData.fromJson(metadataMap);
      final String? telnyxCallId = metadata.callId;

      if (telnyxCallId == null || telnyxCallId.isEmpty) {
        logger.e('NotificationService.showMissedCallNotification: Missing or empty callId in metadata. Cannot process missed call accurately.'); // Corrected log
        return;
      }

      logger.i('NotificationService.showMissedCallNotification: Ending potentially active incoming CallKit UI for ID: $telnyxCallId');
      await FlutterCallkitIncoming.endCall(telnyxCallId); 
      logger.i('NotificationService.showMissedCallNotification: endCall sent for ID: $telnyxCallId');

      // Now, show the specific missed call notification (e.g., for system logs / recents)
      final String missedCallEntryUuid = const Uuid().v4(); 
      logger.i('NotificationService.showMissedCallNotification: Showing missed call notification entry with UUID: $missedCallEntryUuid for original call ID: $telnyxCallId');

      final CallKitParams callKitParams = CallKitParams(
        id: missedCallEntryUuid, // ID for the missed call notification/log entry
        nameCaller: metadata.callerName,
        appName: 'Telnyx Flutter Voice',
        handle: metadata.callerNumber,
        type: 0,
        missedCallNotification: const NotificationParams(
          showNotification: true,
          isShowCallback: true,
          subtitle: 'Missed call',
          callbackText: 'Call back',
        ),
        duration: 0, 
        extra: message.data,
        headers: <String, dynamic>{'platform': 'flutter'},
        android: const AndroidParams(
          isCustomNotification: true,
          isShowLogo: false,
          backgroundColor: '#EF5350',
          actionColor: '#0955fa',
          textColor: '#ffffff',
          incomingCallNotificationChannelName: 'Incoming Call',
          missedCallNotificationChannelName: 'Missed Call', 
        ),
        ios: const IOSParams(
          iconName: 'CallKitLogo',
          handleType: 'generic',
          supportsVideo: false,
        ),
      );

      await FlutterCallkitIncoming.showMissCallNotification(callKitParams);
      logger.i('NotificationService.showMissedCallNotification: showMissCallNotification called for UUID $missedCallEntryUuid.');

    } catch (e) {
      logger.e('NotificationService.showMissedCallNotification: Error processing missed call notification: $e');
    }
  }
}
