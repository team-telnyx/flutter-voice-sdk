import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:telnyx_common/telnyx_common.dart';
import 'package:uuid/uuid.dart';
import 'package:telnyx_webrtc/model/push_notification.dart';

/// Configuration for notification display.
class NotificationConfig {
  final String appName;
  final String defaultRingtone;
  final String backgroundColor;
  final String actionColor;
  final String textColor;
  final String iconName;
  final int callTimeoutSeconds;

  const NotificationConfig({
    this.appName = 'Call Received',
    this.defaultRingtone = 'system_ringtone_default',
    this.backgroundColor = '#0955fa',
    this.actionColor = '#4CAF50',
    this.textColor = '#ffffff',
    this.iconName = 'CallKitLogo',
    this.callTimeoutSeconds = 30,
  });
}

/// Unified notification display service that handles platform-specific
/// notification rendering for incoming calls, missed calls, and outgoing calls.
///
/// This service provides a consistent API for displaying notifications
/// across Android and iOS platforms while handling platform-specific
/// differences internally.
class NotificationDisplayService {
  final NotificationConfig _config;
  bool _disposed = false;

  /// Creates a new notification display service with the given configuration.
  NotificationDisplayService({
    NotificationConfig? config,
  }) : _config = config ?? const NotificationConfig();

  /// Initializes the notification display service.
  ///
  /// This method sets up notification channels and prepares the service
  /// for displaying notifications.
  Future<void> initialize() async {
    if (_disposed) return;

    try {
      await _createNotificationChannels();
      print('NotificationDisplayService: Initialized');
    } catch (e) {
      print('NotificationDisplayService: Error during initialization: $e');
    }
  }

  /// Creates platform-specific notification channels.
  Future<void> _createNotificationChannels() async {
    if (Platform.isAndroid) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'telnyx_call_channel',
        'Incoming Calls',
        description: 'Notifications for incoming Telnyx calls.',
        importance: Importance.max,
        playSound: true,
        audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
      );

      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
          FlutterLocalNotificationsPlugin();

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      print('NotificationDisplayService: Android notification channel created');
    } else {
      print(
          'NotificationDisplayService: iOS notification channels not required');
    }
  }

  /// Displays an incoming call notification.
  ///
  /// [callId] - Unique identifier for the call
  /// [callerName] - Name of the caller
  /// [callerNumber] - Phone number of the caller
  /// [extra] - Additional metadata for the call
  Future<void> showIncomingCall({
    required String callId,
    required String callerName,
    required String callerNumber,
    Map<String, dynamic> extra = const {},
  }) async {
    if (_disposed) return;

    try {
      print(
          'NotificationDisplayService: Showing incoming call notification for $callId');

      final CallKitParams callKitParams = CallKitParams(
        id: callId,
        nameCaller: callerName,
        appName: _config.appName,
        handle: callerNumber,
        type: 0, // Audio call
        textAccept: 'Accept',
        textDecline: 'Decline',
        duration: _config.callTimeoutSeconds * 1000,
        extra: extra,
        headers: <String, dynamic>{'platform': 'flutter'},
        android: AndroidParams(
          isCustomNotification: true,
          isShowLogo: false,
          ringtonePath: _config.defaultRingtone,
          backgroundColor: _config.backgroundColor,
          actionColor: _config.actionColor,
          textColor: _config.textColor,
          incomingCallNotificationChannelName: 'Incoming Call',
          missedCallNotificationChannelName: 'Missed Call',
        ),
        ios: IOSParams(
          iconName: _config.iconName,
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
          ringtonePath: _config.defaultRingtone,
        ),
      );

      BackgroundDetector.ignore =
          true; // Ignore lifecycle events during call UI display
      await FlutterCallkitIncoming.showCallkitIncoming(callKitParams);

      print(
          'NotificationDisplayService: Incoming call notification displayed for $callId');
    } catch (e) {
      print(
          'NotificationDisplayService: Error showing incoming call notification: $e');
    }
  }

  /// Displays a missed call notification.
  ///
  /// [callId] - Unique identifier for the call
  /// [callerName] - Name of the caller
  /// [callerNumber] - Phone number of the caller
  /// [extra] - Additional metadata for the call
  Future<void> showMissedCall({
    required String callId,
    required String callerName,
    required String callerNumber,
    Map<String, dynamic> extra = const {},
  }) async {
    if (_disposed) return;

    try {
      print(
          'NotificationDisplayService: Showing missed call notification for $callId');

      // First, end any active incoming call UI
      await endCall(callId);

      final String missedCallId = const Uuid().v4();
      final CallKitParams callKitParams = CallKitParams(
        id: missedCallId,
        nameCaller: callerName,
        appName: _config.appName,
        handle: callerNumber,
        type: 0,
        missedCallNotification: const NotificationParams(
          showNotification: true,
          isShowCallback: true,
          subtitle: 'Missed call',
          callbackText: 'Call back',
        ),
        duration: 0,
        extra: extra,
        headers: <String, dynamic>{'platform': 'flutter'},
        android: AndroidParams(
          isCustomNotification: true,
          isShowLogo: false,
          backgroundColor: '#EF5350',
          actionColor: _config.actionColor,
          textColor: _config.textColor,
          incomingCallNotificationChannelName: 'Incoming Call',
          missedCallNotificationChannelName: 'Missed Call',
        ),
        ios: IOSParams(
          iconName: _config.iconName,
          handleType: 'generic',
          supportsVideo: false,
        ),
      );

      await FlutterCallkitIncoming.showMissCallNotification(callKitParams);

      print(
          'NotificationDisplayService: Missed call notification displayed for $callId');
    } catch (e) {
      print(
          'NotificationDisplayService: Error showing missed call notification: $e');
    }
  }

  /// Displays an outgoing call notification.
  ///
  /// [callId] - Unique identifier for the call
  /// [callerName] - Name of the caller (local user)
  /// [destination] - Destination number being called
  /// [extra] - Additional metadata for the call
  Future<void> showOutgoingCall({
    required String callId,
    required String callerName,
    required String destination,
    Map<String, dynamic> extra = const {},
  }) async {
    if (_disposed) return;

    try {
      print(
          'NotificationDisplayService: Showing outgoing call notification for $callId');

      final CallKitParams callKitParams = CallKitParams(
        id: callId,
        nameCaller: callerName,
        appName: _config.appName,
        handle: destination,
        type: 0,
        extra: extra,
        headers: <String, dynamic>{'platform': 'flutter'},
        android: AndroidParams(
          isCustomNotification: true,
          isShowLogo: false,
          ringtonePath: _config.defaultRingtone,
          backgroundColor: _config.backgroundColor,
          actionColor: _config.actionColor,
          textColor: _config.textColor,
          incomingCallNotificationChannelName: 'Incoming Call',
          missedCallNotificationChannelName: 'Missed Call',
        ),
        ios: IOSParams(
          iconName: _config.iconName,
          handleType: 'generic',
          supportsVideo: false,
          ringtonePath: _config.defaultRingtone,
        ),
      );

      await FlutterCallkitIncoming.startCall(callKitParams);

      print(
          'NotificationDisplayService: Outgoing call notification displayed for $callId');
    } catch (e) {
      print(
          'NotificationDisplayService: Error showing outgoing call notification: $e');
    }
  }

  /// Ends a call notification.
  ///
  /// [callId] - Unique identifier for the call to end
  Future<void> endCall(String callId) async {
    if (_disposed) return;

    try {
      print('NotificationDisplayService: Ending call notification for $callId');

      await FlutterCallkitIncoming.endCall(callId);

      print('NotificationDisplayService: Call notification ended for $callId');
    } catch (e) {
      print('NotificationDisplayService: Error ending call notification: $e');
    }
  }

  /// Parses push notification payload and extracts call information.
  ///
  /// [payload] - Raw push notification payload
  /// Returns extracted call information or null if parsing fails
  CallInfo? parseCallInfo(Map<String, dynamic> payload) {
    try {
      final metadataJson = payload['metadata'];
      if (metadataJson == null) return null;

      final Map<String, dynamic> metadataMap;
      if (metadataJson is String) {
        metadataMap = jsonDecode(metadataJson);
      } else if (metadataJson is Map<String, dynamic>) {
        metadataMap = metadataJson;
      } else {
        return null;
      }

      final pushMetaData = PushMetaData.fromJson(metadataMap);

      // Extract call ID from metadata or custom headers
      String? callId = pushMetaData.callId;
      if (callId == null || callId.isEmpty) {
        final dialogParams = metadataMap['dialogParams'];
        if (dialogParams != null && dialogParams['custom_headers'] != null) {
          final customHeaders = dialogParams['custom_headers'] as List<dynamic>;
          for (final header in customHeaders) {
            if (header['name'] == 'X-RTC-CALLID') {
              callId = header['value'];
              break;
            }
          }
        }
      }

      if (callId == null || callId.isEmpty) return null;

      return CallInfo(
        callId: callId,
        callerName: pushMetaData.callerName ?? 'Unknown Caller',
        callerNumber: pushMetaData.callerNumber ?? 'Unknown Number',
        extra: payload,
      );
    } catch (e) {
      print('NotificationDisplayService: Error parsing call info: $e');
      return null;
    }
  }

  /// Disposes of the notification display service.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    print('NotificationDisplayService: Disposed');
  }
}

/// Information extracted from a push notification about a call.
class CallInfo {
  final String callId;
  final String callerName;
  final String callerNumber;
  final Map<String, dynamic> extra;

  CallInfo({
    required this.callId,
    required this.callerName,
    required this.callerNumber,
    required this.extra,
  });

  @override
  String toString() {
    return 'CallInfo(callId: $callId, callerName: $callerName, callerNumber: $callerNumber)';
  }
}
