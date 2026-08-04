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

// Helper method to create standard CallKitParams for incoming/outgoing calls
CallKitParams _getStandardCallKitParams({
  required String id,
  required String nameCaller,
  required String handle,
  required Map<String, dynamic> extra,
  int duration = 30000,
  String textAccept = 'Accept',
  String textDecline = 'Decline',
  String appName = 'Telnyx Flutter Voice',
  int type = 0, // 0 for audio call
}) {
  return CallKitParams(
    id: id,
    nameCaller: nameCaller,
    appName: appName,
    handle: handle,
    type: type,
    textAccept: textAccept,
    textDecline: textDecline,
    duration: duration,
    extra: extra,
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
}

class NotificationService {
  /// Helper method to extract call ID from metadata with fallback to X-RTC-CALLID in custom headers
  static String? _extractCallId(
    Map<String, dynamic> metadataMap,
    PushMetaData metadata,
    Logger logger,
    String methodName,
  ) {
    String? telnyxCallId = metadata.callId;

    // If callId is missing or empty, check for X-RTC-CALLID in custom headers
    if (telnyxCallId == null || telnyxCallId.isEmpty) {
      try {
        final dialogParams = metadataMap['dialogParams'];
        if (dialogParams != null && dialogParams['custom_headers'] != null) {
          final customHeaders = dialogParams['custom_headers'] as List<dynamic>;
          for (final header in customHeaders) {
            if (header['name'] == 'X-RTC-CALLID') {
              telnyxCallId = header['value'];
              logger.i(
                'NotificationService.$methodName: Found call ID in X-RTC-CALLID header: $telnyxCallId',
              );
              break;
            }
          }
        }
      } catch (e) {
        logger.w(
          'NotificationService.$methodName: Error parsing custom headers for X-RTC-CALLID: $e',
        );
      }
    }

    return telnyxCallId;
  }

  static Future showNotification(RemoteMessage message) async {
    final logger = Logger()
      ..i(
        'NotificationService.showNotification: Received message: ${message.data}',
      );

    try {
      // Use a default map if metadata is missing or invalid
      final Map<String, dynamic> metadataMap =
          message.data.containsKey('metadata')
          ? jsonDecode(message.data['metadata'] ?? '{}')
          : {};
      final metadata = PushMetaData.fromJson(metadataMap);

      // Check for the actual call ID from Telnyx metadata (using camelCase)
      final String? telnyxCallId = _extractCallId(
        metadataMap,
        metadata,
        logger,
        'showNotification',
      );

      // Check for incorrect notification type, ie missed call message
      if (message.data.containsKey('message') &&
          message.data['message'] == 'Missed call!') {
        logger.i(
          'NotificationService.showNotification: Received a message flagged as "Missed call!", aborting showing incoming UI.',
        );
        return;
      }

      // Check for Stale Notification
      if (message.sentTime != null) {
        final DateTime nowTime = DateTime.now();
        final Duration difference = nowTime.difference(message.sentTime!);
        logger.i(
          'NotificationService.showNotification: Time difference since sent: ${difference.inSeconds} seconds.',
        );
        if (difference.inSeconds > _CALL_MISSED_TIMEOUT_SECONDS) {
          logger.w(
            'NotificationService.showNotification: Notification is stale (>${_CALL_MISSED_TIMEOUT_SECONDS}s). Showing missed call instead. ID: $telnyxCallId',
          );
          await showMissedCallNotification(message);
          return;
        }
      } else {
        logger.w(
          'NotificationService.showNotification: message.sentTime is null, cannot check for staleness.',
        );
      }

      if (telnyxCallId == null || telnyxCallId.isEmpty) {
        logger.e(
          'NotificationService.showNotification: Missing or empty callId in metadata. Cannot show CallKit notification.',
        ); // Corrected log
        return; // Cannot proceed without a valid ID
      }

      logger.i(
        'NotificationService.showNotification: Showing CallKit incoming UI for call ID: $telnyxCallId',
      );
      BackgroundDetector.ignore = true;
      final CallKitParams callKitParams = _getStandardCallKitParams(
        id: telnyxCallId,
        nameCaller: metadata.callerName ?? 'Unknown Caller',
        handle: metadata.callerNumber ?? 'Unknown Number',
        extra: message.data,
        // Default values for duration, textAccept, textDecline, appName, type are used from helper
      );

      await FlutterCallkitIncoming.showCallkitIncoming(callKitParams);
      logger.i(
        'NotificationService.showNotification: CallKit incoming UI displayed for $telnyxCallId.',
      );
    } catch (e) {
      logger.e(
        'NotificationService.showNotification: Error processing notification: $e',
      );
      TelnyxClient.clearPushMetaData();
    }
  }

  static Future startOutgoingCallNotification({
    required String callId,
    required String callerName,
    required String
    handle, // This is the destination number for an outgoing call
    Map<String, dynamic> extra = const {}, // Optional extra data
  }) async {
    final logger = Logger()
      ..i(
        'NotificationService.startOutgoingCallNotification: Displaying CallKit UI for outgoing call ID: $callId',
      );
    try {
      final CallKitParams callKitParams = _getStandardCallKitParams(
        id: callId,
        nameCaller: callerName,
        // For outgoing, this is often the local user's name or number
        handle: handle,
        // For outgoing, this is the number/ID being called
        extra: extra,
        // textAccept and textDecline are not typically shown for outgoing calls initiated by startCall,
        // but CallKitParams requires them. Defaults from helper are fine.
      );
      await FlutterCallkitIncoming.startCall(callKitParams);
      logger.i(
        'NotificationService.startOutgoingCallNotification: CallKit UI displayed for outgoing call ID: $callId.',
      );
    } catch (e) {
      logger.e(
        'NotificationService.startOutgoingCallNotification: Error displaying CallKit UI: $e',
      );
    }
  }

  static Future showMissedCallNotification(RemoteMessage message) async {
    final logger = Logger()
      ..i(
        'NotificationService.showMissedCallNotification: Received message: ${message.data}',
      );

    try {
      final Map<String, dynamic> metadataMap =
          message.data.containsKey('metadata')
          ? jsonDecode(message.data['metadata'] ?? '{}')
          : {};
      final metadata = PushMetaData.fromJson(metadataMap);
      final String? telnyxCallId = _extractCallId(
        metadataMap,
        metadata,
        logger,
        'showMissedCallNotification',
      );

      if (telnyxCallId == null || telnyxCallId.isEmpty) {
        logger.e(
          'NotificationService.showMissedCallNotification: Missing or empty callId in metadata. Cannot process missed call accurately.',
        ); // Corrected log
        return;
      }

      logger.i(
        'NotificationService.showMissedCallNotification: Ending potentially active incoming CallKit UI for ID: $telnyxCallId',
      );
      await FlutterCallkitIncoming.endCall(telnyxCallId);
      logger.i(
        'NotificationService.showMissedCallNotification: endCall sent for ID: $telnyxCallId',
      );

      // Now, show the specific missed call notification (e.g., for system logs / recents)
      final String missedCallEntryUuid = const Uuid().v4();
      logger.i(
        'NotificationService.showMissedCallNotification: Showing missed call notification entry with UUID: $missedCallEntryUuid for original call ID: $telnyxCallId',
      );

      final CallKitParams callKitParams = CallKitParams(
        id: missedCallEntryUuid,
        // ID for the missed call notification/log entry
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
      logger.i(
        'NotificationService.showMissedCallNotification: showMissCallNotification called for UUID $missedCallEntryUuid.',
      );
    } catch (e) {
      logger.e(
        'NotificationService.showMissedCallNotification: Error processing missed call notification: $e',
      );
    }
  }

  static Future showIncomingCallUi({
    required String callId,
    required String callerName,
    required String callerNumber,
    Map<String, dynamic> extra = const {},
  }) async {
    final logger = Logger()
      ..i(
        'NotificationService.showIncomingCallUi: Displaying CallKit UI for incoming call ID: $callId',
      );
    try {
      BackgroundDetector.ignore = true;
      final CallKitParams callKitParams = _getStandardCallKitParams(
        id: callId,
        nameCaller: callerName,
        handle: callerNumber,
        extra: extra,
      );
      await FlutterCallkitIncoming.showCallkitIncoming(callKitParams);
      logger.i(
        'NotificationService.showIncomingCallUi: CallKit UI displayed for incoming call ID: $callId.',
      );
    } catch (e) {
      logger.e(
        'NotificationService.showIncomingCallUi: Error displaying CallKit UI: $e',
      );
    }
  }
}
