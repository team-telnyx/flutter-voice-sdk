import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:logger/logger.dart';
import 'package:telnyx_flutter_webrtc/main.dart'; // For logger, txClientViewModel, handlePush, CALL_MISSED_TIMEOUT
import 'package:telnyx_flutter_webrtc/service/notification_service.dart';
import 'package:telnyx_flutter_webrtc/service/push_notification_handler.dart';
import 'package:telnyx_webrtc/telnyx_client.dart';
import 'package:telnyx_webrtc/model/push_notification.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:telnyx_flutter_webrtc/utils/config_helper.dart';

// Define logger at the top level for access by the background handler function
final _backgroundLogger = Logger();

// This function MUST be annotated with @pragma('vm:entry-point') and be a top level function
@pragma('vm:entry-point')
Future<void> androidBackgroundMessageHandler(RemoteMessage message) async {
  _backgroundLogger.i(
    '[AndroidBackgroundHandler] Received background message: ${message.data}',
  );

  // Ensure Firebase is initialized for this isolate
  try {
    await Firebase.initializeApp();
  } catch (e) {
    _backgroundLogger.e(
      '[AndroidBackgroundHandler] Firebase initialization failed: $e',
    );
    return;
  }

  // Check if the message is a missed call notification
  if (message.data['message'] != null &&
      message.data['message'].toString().toLowerCase() == 'missed call!') {
    _backgroundLogger.i(
      '[AndroidBackgroundHandler] Missed call notification, not showing CallKit.',
    );
    await NotificationService.showMissedCallNotification(message);
    return;
  }

  // Show the notification first
  await NotificationService.showNotification(message);

  // Setup CallKit listener for background actions
  FlutterCallkitIncoming.onEvent.listen((CallEvent? event) async {
    _backgroundLogger.i(
      '[AndroidBackgroundHandler] CallKit event: ${event?.event}',
    );
    switch (event!.event) {
      case Event.actionCallDecline:
        _backgroundLogger.i(
          '[AndroidBackgroundHandler] Call declined via CallKit from background.',
        );
        if (message.data['metadata'] != null) {
          try {
            final Map<String, dynamic> metadataMap = jsonDecode(
              message.data['metadata'],
            );
            final PushMetaData pushMetaData = PushMetaData.fromJson(metadataMap)
              ..isDecline = true;

            // Use simplified decline logic with decline_push parameter
            final tempDeclineClient = TelnyxClient();
            final config = await ConfigHelper.getTelnyxConfigFromPrefs();
            if (config != null) {
              _backgroundLogger.i(
                '[AndroidBackgroundHandler] Using simplified decline logic with decline_push parameter.',
              );
              tempDeclineClient.handlePushNotification(
                pushMetaData,
                config is CredentialConfig ? config : null,
                config is TokenConfig ? config : null,
              );
            } else {
              _backgroundLogger.e(
                '[AndroidBackgroundHandler] Could not retrieve config from SharedPreferences. Cannot decline call.',
              );
            }
          } catch (e) {
            _backgroundLogger.e(
              '[AndroidBackgroundHandler] Error processing decline: $e',
            );
          }
        } else {
          _backgroundLogger.i(
            '[AndroidBackgroundHandler] No metadata for decline action.',
          );
        }
        break;
      case Event.actionCallAccept:
        _backgroundLogger.i(
          '[AndroidBackgroundHandler] Call accepted via CallKit from background.',
        );
        // Store the accept intent for when the main app processes the initial data
        TelnyxClient.setPushMetaData(
          message.data,
          isAnswer: true,
          isDecline: false,
        );
        break;
      default:
        break;
    }
  });
}

/// Android specific implementation of [PushNotificationHandler].
class AndroidPushNotificationHandler implements PushNotificationHandler {
  final _logger = Logger();

  @override
  Future<void> initialize() async {
    _logger.i('[PushNotificationHandler-Android] Initialize');
    await _createNotificationChannel();
    _setupFCMListeners();
    await _configureFCMForegroundHandling();
    _setupCallKitListener();
    _logger.i('[PushNotificationHandler-Android] Initialize complete.');
  }

  Future<void> _createNotificationChannel() async {
    _logger.i(
      '[PushNotificationHandler-Android] Creating notification channel...',
    );
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'telnyx_call_channel', // id
      'Incoming Calls', // name
      description: 'Notifications for incoming Telnyx calls.',
      importance: Importance.max,
      playSound: true,
      audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    try {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
      _logger.i(
        '[PushNotificationHandler-Android] High importance notification channel created/updated.',
      );
    } catch (e) {
      _logger.e(
        '[PushNotificationHandler-Android] Failed to create notification channel: $e',
      );
    }
  }

  void _setupFCMListeners() {
    _logger.i(
      '[PushNotificationHandler-Android] Setting up FCM listeners (onMessage, onMessageOpenedApp)...',
    );
    // Setup foreground message listener
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _logger.i(
        '[PushNotificationHandler-Android] onMessage: Received foreground message: ${message.data}',
      );
      if (message.data['message'] != null &&
          message.data['message'].toString().toLowerCase() == 'missed call!') {
        _logger.i(
          '[PushNotificationHandler-Android] onMessage: Missed call notification',
        );
        NotificationService.showMissedCallNotification(message);
        return;
      }
      // Show foreground notification using the service (which uses CallKitIncoming)
      NotificationService.showNotification(message);
      // Store metadata in case the app goes to background before user interaction
      TelnyxClient.setPushMetaData(message.data);
    });

    // Setup message opened app listener
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _logger.i(
        '[PushNotificationHandler-Android] onMessageOpenedApp: Message data: ${message.data}',
      );
    });
  }

  Future<void> _configureFCMForegroundHandling() async {
    _logger.i(
      '[PushNotificationHandler-Android] Configuring FCM foreground presentation and requesting permissions...',
    );
    final FirebaseMessaging messaging = FirebaseMessaging.instance;

    // 1. Set presentation options for foreground
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    _logger.i(
      '[PushNotificationHandler-Android] Foreground presentation options set.',
    );

    // 2. Request user permission (Required for Android 13+)
    final NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      announcement: true,
      badge: true,
      carPlay: true,
      criticalAlert: true,
      provisional: true,
      sound: true,
    );
    _logger.i(
      '[PushNotificationHandler-Android] Notification permission requested. Status: ${settings.authorizationStatus}',
    );
  }

  void _setupCallKitListener() {
    _logger.i(
      '[PushNotificationHandler-Android] Setting up CallKit event listener...',
    );
    // Add CallKit listener for Android foreground/active state interactions
    // This catches events from notifications created by NotificationService
    FlutterCallkitIncoming.onEvent.listen((CallEvent? event) async {
      _logger.i(
        '[PushNotificationHandler-Android] onEvent: ${event?.event} :: ${event?.body}',
      );
      switch (event!.event) {
        case Event.actionCallAccept:
          _logger.i(
            '[PushNotificationHandler-Android] actionCallAccept: Received. Metadata: ${event.body?['extra']?['metadata']}',
          );
          if (txClientViewModel.incomingInvitation != null) {
            _logger.i(
              '[PushNotificationHandler-Android] actionCallAccept: ViewModel has existing incomingInvitation. Accepting directly.',
            );
            await txClientViewModel.accept();
          } else {
            final metadata = event.body['extra']?['metadata'];
            if (metadata == null) {
              _logger.i(
                '[PushNotificationHandler-Android] actionCallAccept: Metadata missing. Accepting without push context.',
              );
              await txClientViewModel.accept();
            } else {
              _logger.i(
                '[PushNotificationHandler-Android] actionCallAccept: Metadata present. Calling processIncomingCallAction. Metadata: $metadata',
              );
              var decodedMetadata = metadata;
              if (metadata is String) {
                try {
                  decodedMetadata = jsonDecode(metadata);
                } catch (e) {
                  _logger.e(
                    '[PushNotificationHandler-Android] actionCallAccept: Error decoding metadata JSON: $e. Attempting direct accept.',
                  );
                  await txClientViewModel.accept(); // Fallback
                  return;
                }
              }
              // Call the handler's method to process the action, which will augment and call handlePush
              await processIncomingCallAction(
                decodedMetadata as Map<dynamic, dynamic>,
                isAnswer: true,
              );
            }
          }
          break;

        case Event.actionCallDecline:
          _logger.i(
            '[PushNotificationHandler-Android] actionCallDecline: Received. Metadata: ${event.body?['extra']?['metadata']}',
          );
          final metadata = event.body['extra']?['metadata'];
          if (txClientViewModel.incomingInvitation != null ||
              txClientViewModel.currentCall != null) {
            _logger.i(
              '[PushNotificationHandler-Android] actionCallDecline: Main client has existing call/invite. Using txClientViewModel.endCall().',
            );
            txClientViewModel.endCall();
          } else if (metadata == null) {
            _logger.i(
              '[PushNotificationHandler-Android] actionCallDecline: No metadata and no active call/invite in ViewModel.',
            );
            // If an ID is reliably available in event.body['id'], use it to end the specific CallKit call.
            if (event.body?['id'] != null &&
                event.body['id'].toString().isNotEmpty) {
              await FlutterCallkitIncoming.endCall(event.body['id']);
            } else {
              _logger.w(
                '[PushNotificationHandler-Android] actionCallDecline: Could not end CallKit call without ID.',
              );
            }
          } else {
            _logger.i(
              '[PushNotificationHandler-Android] actionCallDecline: Metadata present. Using simplified decline logic with decline_push parameter. Metadata: $metadata',
            );
            var decodedMetadata = metadata;
            if (metadata is String) {
              try {
                decodedMetadata = jsonDecode(metadata);
              } catch (e) {
                _logger.e(
                  '[PushNotificationHandler-Android] actionCallDecline: Error decoding metadata JSON: $e. Unable to process decline.',
                );
                return;
              }
            }
            // Use the simplified processIncomingCallAction approach with isDecline=true
            // This will trigger the new decline_push logic in TelnyxClient
            await processIncomingCallAction(
              decodedMetadata as Map<dynamic, dynamic>,
              isDecline: true,
            );
          }
          break;

        // Handle other events like ended, timeout if needed from foreground CallKit interactions
        case Event.actionCallEnded:
          _logger.i(
            '[PushNotificationHandler-Android] actionCallEnded: Call ended event from CallKit.',
          );
          txClientViewModel.endCall();
          break;
        case Event.actionCallTimeout:
          _logger.i(
            '[PushNotificationHandler-Android] actionCallTimeout: Call timeout event from CallKit.',
          );
          txClientViewModel.endCall();
          break;

        default:
          _logger.i(
            '[PushNotificationHandler-Android] Unhandled CallKit event in foreground: ${event.event}',
          );
          break;
      }
    });
  }

  @override
  Future<void> processIncomingCallAction(
    Map<dynamic, dynamic> payload, {
    bool isAnswer = false,
    bool isDecline = false,
  }) async {
    _logger.i(
      '[PushNotificationHandler-Android] processIncomingCallAction. Payload: $payload, Answer: $isAnswer, Decline: $isDecline',
    );
    final Map<dynamic, dynamic> mutablePayload = Map.from(payload);
    if (isAnswer) mutablePayload['isAnswer'] = true;
    if (isDecline) mutablePayload['isDecline'] = true;

    await handlePush(mutablePayload);
  }

  @override
  Future<void> displayIncomingCallUi(Map<dynamic, dynamic> payload) async {
    _logger.i(
      '[PushNotificationHandler-Android] displayIncomingCallUi: Calling NotificationService.showNotification. Payload: $payload',
    );
    // For Android, NotificationService.showNotification creates the system notification which acts as the incoming call UI.
    try {
      final remoteMessage = RemoteMessage(
        data: Map<String, String>.from(
          payload.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ),
        ),
      );
      await NotificationService.showNotification(remoteMessage);
    } catch (e) {
      _logger.e(
        '[PushNotificationHandler-Android] displayIncomingCallUi: Error creating RemoteMessage or showing notification: $e',
      );
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
    final RemoteMessage? initialMessage = await FirebaseMessaging.instance
        .getInitialMessage();
    if (initialMessage != null) {
      _logger.i(
        '[PushNotificationHandler-Android] getInitialPushData: Found initial message: ${initialMessage.data}',
      );
      return initialMessage.data;
    }
    // Fallback to getPushData from TelnyxClient for consistency with old flow, though getInitialMessage is preferred for FCM.
    return TelnyxClient.getPushData();
  }

  @override
  Future<void> showMissedCallNotification(Map<dynamic, dynamic> payload) async {
    _logger.i(
      '[PushNotificationHandler-Android] showMissedCallNotification. Payload: $payload',
    );
    await NotificationService.showMissedCallNotification(
      RemoteMessage(
        data: Map<String, String>.from(
          payload.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ),
        ),
      ),
    );
  }

  @override
  void clearPushData() {
    _logger.i('[PushNotificationHandler-Android] clearPushData');
    TelnyxClient.clearPushMetaData();
  }

  @override
  bool isFirebaseInitialized() {
    final bool initialized = Firebase.apps.isNotEmpty;
    _logger.i(
      '[PushNotificationHandler-Android] isFirebaseInitialized: Returning $initialized',
    );
    return initialized;
  }
}
