import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:telnyx_flutter_webrtc/main.dart'; // For logger, txClientViewModel, handlePush, CALL_MISSED_TIMEOUT
import 'package:telnyx_flutter_webrtc/service/notification_service.dart';
import 'package:telnyx_flutter_webrtc/service/push_notification_handler.dart';
import 'package:telnyx_webrtc/telnyx_client.dart';
import 'package:telnyx_webrtc/model/push_notification.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:telnyx_webrtc/model/socket_method.dart';
import 'package:telnyx_webrtc/model/telnyx_message.dart';
import 'package:telnyx_webrtc/model/telnyx_socket_error.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telnyx_webrtc/utils/logging/log_level.dart';
import 'package:telnyx_flutter_webrtc/utils/custom_sdk_logger.dart';


// Define logger at the top level for access by the background handler function
final _backgroundLogger = Logger(); 

// --- Static utility methods to fetch config --- 
// (Keep _getBackgroundCredentialConfig, _getBackgroundTokenConfig, _getBackgroundTelnyxConfig as static helpers)
// Static utility methods to fetch config from SharedPreferences for background isolate
Future<CredentialConfig?> _getBackgroundCredentialConfig() async {
  final prefs = await SharedPreferences.getInstance();
  final sipUser = prefs.getString('sipUser');
  final sipPassword = prefs.getString('sipPassword');
  final sipName = prefs.getString('sipName');
  final sipNumber = prefs.getString('sipNumber');
  final notificationToken = prefs.getString('notificationToken');

  if (sipUser != null && sipPassword != null && sipName != null && sipNumber != null) {
    return CredentialConfig(
      sipCallerIDName: sipName,
      sipCallerIDNumber: sipNumber,
      sipUser: sipUser,
      sipPassword: sipPassword,
      notificationToken: notificationToken, 
      logLevel: LogLevel.all,
      customLogger: CustomSDKLogger(),
      debug: false, 
    );
  }
  return null;
}

Future<TokenConfig?> _getBackgroundTokenConfig() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
  final sipName = prefs.getString('sipName');
  final sipNumber = prefs.getString('sipNumber');
  final notificationToken = prefs.getString('notificationToken');

  if (token != null && sipName != null && sipNumber != null) {
    return TokenConfig(
      sipCallerIDName: sipName,
      sipCallerIDNumber: sipNumber,
      sipToken: token,
      notificationToken: notificationToken,
      logLevel: LogLevel.all,
      customLogger: CustomSDKLogger(),
      debug: false, 
    );
  }
  return null;
}

Future<Object?> _getBackgroundTelnyxConfig() async { 
  Object? config = await _getBackgroundCredentialConfig();
  config ??= await _getBackgroundTokenConfig();
  return config;
}
// --- End of static config helpers ---


// --- Top-level Background Message Handler ---
// This function MUST be annotated with @pragma('vm:entry-point')
@pragma('vm:entry-point')
Future<void> androidBackgroundMessageHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized for this isolate
  await Firebase.initializeApp();
  _backgroundLogger.i('[AndroidBackgroundHandler] Received background message: ${message.data}');
  
  // Show the notification first
  await NotificationService.showNotification(message);

  // Setup CallKit listener for background actions
  FlutterCallkitIncoming.onEvent.listen((CallEvent? event) async {
    _backgroundLogger.i('[AndroidBackgroundHandler] CallKit event: ${event?.event}');
    switch (event!.event) {
      case Event.actionCallDecline:
        _backgroundLogger.i('[AndroidBackgroundHandler] Call declined via CallKit from background.');
        if (message.data['metadata'] != null) {
          try {
            final Map<String, dynamic> metadataMap = jsonDecode(message.data['metadata']);
            final PushMetaData pushMetaData = PushMetaData.fromJson(metadataMap)..isDecline = true;
            final tempDeclineClient = TelnyxClient();
            tempDeclineClient
              ..onSocketMessageReceived = (TelnyxMessage msg) {
                if (msg.socketMethod == SocketMethod.bye) {
                  _backgroundLogger.i('[AndroidBackgroundHandler] Temp client received BYE, disconnecting.');
                  tempDeclineClient.disconnect();
                }
              }
              ..onSocketErrorReceived = (TelnyxSocketError error) {
                _backgroundLogger.e('[AndroidBackgroundHandler] Temp client error: ${error.errorMessage}');
                tempDeclineClient.disconnect();
              };
              
            final config = await _getBackgroundTelnyxConfig();
            if (config != null) {
              _backgroundLogger.i('[AndroidBackgroundHandler] Found config for decline.');
              tempDeclineClient.handlePushNotification(
                pushMetaData,
                config is CredentialConfig ? config : null,
                config is TokenConfig ? config : null,
              );
            } else {
              _backgroundLogger.e('[AndroidBackgroundHandler] Could not retrieve config from SharedPreferences. Cannot decline call.');
            }
          } catch (e) {
             _backgroundLogger.e('[AndroidBackgroundHandler] Error processing decline: $e');
          }
        } else {
           _backgroundLogger.i('[AndroidBackgroundHandler] No metadata for decline action.');
        }
        break;
      case Event.actionCallAccept:
        _backgroundLogger.i('[AndroidBackgroundHandler] Call accepted via CallKit from background.');
        // Store the accept intent for when the main app processes the initial data
        TelnyxClient.setPushMetaData(message.data, isAnswer: true, isDecline: false);
        break;
      default:
        break;
    }
  });
}
// --- End of Top-level Background Message Handler ---


/// Android specific implementation of [PushNotificationHandler].
/// Note: The background handling logic is now in the top-level [androidBackgroundMessageHandler].
class AndroidPushNotificationHandler implements PushNotificationHandler {
  // Use a logger instance for the class methods (foreground)
  final _logger = Logger();

  @override
  Future<void> initialize() async {
    _logger.i('[PushNotificationHandler-Android] Initialize');
    // Setup foreground message listener
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _logger.i('[PushNotificationHandler-Android] onMessage: Received foreground message: ${message.data}');
      if (message.notification?.title != null && message.notification!.title!.contains('Missed')) {
        _logger.i('[PushNotificationHandler-Android] onMessage: Missed call notification');
        NotificationService.showMissedCallNotification(message);
        return;
      }
      NotificationService.showNotification(message);
      TelnyxClient.setPushMetaData(message.data); // Sets it for later retrieval if needed
    });

    // Setup message opened app listener
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _logger.i('[PushNotificationHandler-Android] onMessageOpenedApp: Message data: ${message.data}');
    });

    // Set background message handler in main isolate initialization
    // This points to the new top-level annotated function
    FirebaseMessaging.onBackgroundMessage(androidBackgroundMessageHandler);

    // Set foreground presentation options
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  @override
  Future<void> processIncomingCallAction(Map<dynamic, dynamic> payload, {bool isAnswer = false, bool isDecline = false}) async {
    _logger.i('[PushNotificationHandler-Android] processIncomingCallAction. Payload: $payload, Answer: $isAnswer, Decline: $isDecline');
    // This method will be called from _MyAppState after getInitialPushData
    // or potentially from onMessageOpenedApp if specific action is needed there.
    final Map<dynamic, dynamic> mutablePayload = Map.from(payload);
    if (isAnswer) mutablePayload['isAnswer'] = true;
    if (isDecline) mutablePayload['isDecline'] = true;

    await handlePush(mutablePayload);
  }
  
  @override
  Future<void> displayIncomingCallUi(Map<dynamic, dynamic> payload) async {
    _logger.i('[PushNotificationHandler-Android] displayIncomingCallUi: Calling NotificationService.showNotification. Payload: $payload');
    // For Android, NotificationService.showNotification creates the system notification which acts as the incoming call UI.
    // Ensure the payload structure matches what showNotification expects (likely message.data format).
    // Creating a RemoteMessage. This might need adjustment if the payload structure differs.
    try {
      final remoteMessage = RemoteMessage(data: Map<String, String>.from(payload.map((key, value) => MapEntry(key.toString(), value.toString()))));
      await NotificationService.showNotification(remoteMessage);
    } catch (e) {
       _logger.e('[PushNotificationHandler-Android] displayIncomingCallUi: Error creating RemoteMessage or showing notification: $e');
    }
  }

  @override
  Future<String?> getPushToken() async {
    _logger.i('[PushNotificationHandler-Android] getPushToken');
    return FirebaseMessaging.instance.getToken();
  }

  @override
  Future<Map<String, dynamic>?> getInitialPushData() async {
    _logger.i('[PushNotificationHandler-Android] getInitialPushData');
    final RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _logger.i('[PushNotificationHandler-Android] getInitialPushData: Found initial message: ${initialMessage.data}');
      // TelnyxClient.setPushMetaData(initialMessage.data); // Ensure this is set before processIncomingCallAction
      return initialMessage.data;
    }
    // Fallback to getPushData from TelnyxClient for consistency with old flow, though getInitialMessage is preferred for FCM.
    return TelnyxClient.getPushData(); 
  }

  @override
  Future<void> showMissedCallNotification(Map<dynamic, dynamic> payload) async {
    _logger.i('[PushNotificationHandler-Android] showMissedCallNotification. Payload: $payload');
    // Assuming payload is message.data for FCM
    await NotificationService.showMissedCallNotification(RemoteMessage(data: Map<String,String>.from(payload.map((key, value) => MapEntry(key.toString(), value.toString())))));
  }

  @override
  void clearPushData() {
    _logger.i('[PushNotificationHandler-Android] clearPushData');
    TelnyxClient.clearPushMetaData();
  }

  @override
  bool isFirebaseInitialized() {
    // Android handler's initialize() method ensures Firebase is setup for foreground.
    // The androidBackgroundMessageHandler also calls Firebase.initializeApp().
    // So, if handler is used, we can assume it tries to init Firebase.
    // A more robust check would be `Firebase.apps.isNotEmpty`, but that might require
    // ensuring Firebase is init before this check is made if called very early.
    // For simplicity here, if this handler is active, it means init was attempted.
    // However, the background isolate is separate.
    // This check is more for the main isolate context.
    final bool initialized = Firebase.apps.isNotEmpty;
    _logger.i('[PushNotificationHandler-Android] isFirebaseInitialized: Returning $initialized');
    return initialized;
  }
} 