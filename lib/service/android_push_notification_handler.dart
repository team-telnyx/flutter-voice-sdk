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
import 'package:flutter_local_notifications/flutter_local_notifications.dart';


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
  _backgroundLogger.i('[AndroidBackgroundHandler] Received background message: ${message.data}');

  // Ensure Firebase is initialized for this isolate
  try {
    await Firebase.initializeApp();
  } catch (e) {
    _backgroundLogger.e('[AndroidBackgroundHandler] Firebase initialization failed: $e');
    return;
  }

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

    // Create high importance channel using flutter_local_notifications
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'telnyx_call_channel', // id
      'Incoming Calls', // name
      description: 'Notifications for incoming Telnyx calls.',
      importance: Importance.max, // Crucial for heads-up display
      playSound: true, // Ensure sound plays (adjust as needed)
      // Add other properties like sound, vibration pattern if desired
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    try {
       await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
       _logger.i('[PushNotificationHandler-Android] High importance notification channel created/updated.');
    } catch (e) {
       _logger.e('[PushNotificationHandler-Android] Failed to create notification channel: $e');
    }

    // Setup foreground message listener
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _logger.i('[PushNotificationHandler-Android] onMessage: Received foreground message: ${message.data}');
      if (message.data['message'] != null && message.data['message'].toString().toLowerCase() == 'missed call!') {
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

    // Set foreground presentation options
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Add CallKit listener for Android foreground/active state interactions
    // This catches events from notifications created by NotificationService
    _logger.i('[PushNotificationHandler-Android] Setting up CallKit event listener...');
    FlutterCallkitIncoming.onEvent.listen((CallEvent? event) async {
      _logger.i('[PushNotificationHandler-Android] onEvent: ${event?.event} :: ${event?.body}');
      // Use similar logic as iOS handler for Accept/Decline actions from CallKit UI
      switch (event!.event) {
        case Event.actionCallAccept:
          _logger.i('[PushNotificationHandler-Android] actionCallAccept: Received. Metadata: ${event.body?['extra']?['metadata']}');
          if (txClientViewModel.incomingInvitation != null) {
            _logger.i('[PushNotificationHandler-Android] actionCallAccept: ViewModel has existing incomingInvitation. Accepting directly.');
            await txClientViewModel.accept();
          } else {
            final metadata = event.body['extra']?['metadata'];
            if (metadata == null) {
              _logger.i('[PushNotificationHandler-Android] actionCallAccept: Metadata missing. Accepting without push context.');
              await txClientViewModel.accept();
            } else {
              _logger.i('[PushNotificationHandler-Android] actionCallAccept: Metadata present. Calling processIncomingCallAction. Metadata: $metadata');
              var decodedMetadata = metadata;
              if (metadata is String) {
                try {
                  decodedMetadata = jsonDecode(metadata);
                } catch (e) {
                  _logger.e('[PushNotificationHandler-Android] actionCallAccept: Error decoding metadata JSON: $e. Attempting direct accept.');
                  await txClientViewModel.accept(); // Fallback
                  return;
                }
              }
              // Call the handler's method to process the action, which will augment and call handlePush
              await processIncomingCallAction(decodedMetadata as Map<dynamic, dynamic>, isAnswer: true);
            }
          }
          break;

        case Event.actionCallDecline:
          _logger.i('[PushNotificationHandler-Android] actionCallDecline: Received. Metadata: ${event.body?['extra']?['metadata']}');
          final metadata = event.body['extra']?['metadata'];
          if (txClientViewModel.incomingInvitation != null || txClientViewModel.currentCall != null) {
             _logger.i('[PushNotificationHandler-Android] actionCallDecline: Main client has existing call/invite. Using txClientViewModel.endCall().');
            txClientViewModel.endCall();
          } else if (metadata == null) {
             _logger.i('[PushNotificationHandler-Android] actionCallDecline: No metadata and no active call/invite in ViewModel.');
             // Maybe end the callkit call? 
             // FlutterCallkitIncoming.endCall(event.body['id']); // Requires getting ID from event
          } else {
             _logger.i('[PushNotificationHandler-Android] actionCallDecline: Metadata present. Using temporary client for decline. Metadata: $metadata');
             // Use temporary client logic (same as iOS)
            var decodedMetadata = metadata;
             if (metadata is String) {
               try {
                 decodedMetadata = jsonDecode(metadata);
               } catch (e) {
                 _logger.e('[PushNotificationHandler-Android] actionCallDecline: Error decoding metadata JSON: $e.');
                 return;
               }
             }
             final Map<dynamic, dynamic> eventData = Map<dynamic, dynamic>.from(decodedMetadata as Map);
             final PushMetaData pushMetaData = PushMetaData.fromJson(eventData)..isDecline = true;
             final tempDeclineClient = TelnyxClient();
             tempDeclineClient
              ..onSocketMessageReceived = (TelnyxMessage msg) {
                 if (msg.socketMethod == SocketMethod.bye) {
                   _logger.i('[PushNotificationHandler-Android] actionCallDecline: Temp client received BYE, disconnecting.');
                   tempDeclineClient.disconnect();
                 }
               }
              ..onSocketErrorReceived = (TelnyxSocketError error) {
                 _logger.e('[PushNotificationHandler-Android] actionCallDecline: Temp client error: ${error.errorMessage}');
                 tempDeclineClient.disconnect();
             };
             final config = await _getBackgroundTelnyxConfig(); // Use background config getter
             _logger.i('[PushNotificationHandler-Android] actionCallDecline: Temp client attempting handlePushNotification.');
             if (config != null) {
               tempDeclineClient.handlePushNotification(
                 pushMetaData,
                 config is CredentialConfig ? config : null,
                 config is TokenConfig ? config : null,
               );
             } else {
               _logger.e('[PushNotificationHandler-Android] actionCallDecline: Could not get config for temp client.');
             }
          }
          break;

        // Handle other events like ended, timeout if needed from foreground CallKit interactions
         case Event.actionCallEnded:
           _logger.i('[PushNotificationHandler-Android] actionCallEnded: Call ended event from CallKit.');
           txClientViewModel.endCall();
           break;
         case Event.actionCallTimeout:
           _logger.i('[PushNotificationHandler-Android] actionCallTimeout: Call timeout event from CallKit.');
           txClientViewModel.endCall(); 
           break;

        default:
          _logger.i('[PushNotificationHandler-Android] Unhandled CallKit event in foreground: ${event.event}');
          break;
      }
    });
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
      //await processIncomingCallAction(initialMessage.data, isAnswer: false, isDecline: false);
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