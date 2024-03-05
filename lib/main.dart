import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:telnyx_flutter_webrtc/main_view_model.dart';
import 'package:telnyx_flutter_webrtc/service/notification_service.dart';
import 'package:telnyx_flutter_webrtc/view/screen/call_screen.dart';
import 'package:telnyx_flutter_webrtc/view/screen/home_screen.dart';
import 'package:telnyx_flutter_webrtc/view/screen/login_screen.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:telnyx_webrtc/model/push_notification.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';

final logger = Logger();
final mainViewModel = MainViewModel();
// Android Only - Push Notifications
@pragma('vm:entry-point')
Future _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  logger.i('Handling a background message ${message.messageId}');
  NotificationService.showNotification(message);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (defaultTargetPlatform == TargetPlatform.android) {
    // Android Only - Push Notifications
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();


    if (defaultTargetPlatform == TargetPlatform.android) {
      // Android Only - Push Notifications
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        logger.i('OnMessage :: Notification Message: ${message.data}');
        NotificationService.showNotification(message);
      });
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        logger.i('onMessageOpenedApp :: Notification Message: ${message.data}');
        NotificationService.showNotification(message);
      });
    }

    FlutterCallkitIncoming.onEvent.listen((CallEvent? event) {
      switch (event!.event) {
        case Event.actionCallIncoming:
          // retrieve the push metadata from extras
          Logger()
              .i('actionCallIncoming :: ${event?.body['extra']['metadata']}');
          handlePush(event);
          break;
        case Event.actionCallStart:
          // TODO: started an outgoing call
          // TODO: show screen calling in Flutter
          break;
        case Event.actionCallAccept:
          // TODO: accepted an incoming call
          // TODO: show screen calling in Flutter
          logger.i('Call Accepted Attach Call');
          break;
        case Event.actionCallDecline:
          // TODO: declined an incoming call
          break;
        case Event.actionCallEnded:
          // TODO: ended an incoming/outgoing call
          break;
        case Event.actionCallTimeout:
          // TODO: missed an incoming call
          break;
        case Event.actionCallCallback:
          // TODO: only Android - click action `Call back` from missed call notification
          break;
        case Event.actionCallToggleHold:
          // TODO: only iOS
          break;
        case Event.actionCallToggleMute:
          // TODO: only iOS
          break;
        case Event.actionCallToggleDmtf:
          // TODO: only iOS
          break;
        case Event.actionCallToggleGroup:
          // TODO: only iOS
          break;
        case Event.actionCallToggleAudioSession:
          // TODO: only iOS
          break;
        case Event.actionDidUpdateDevicePushTokenVoip:
          // TODO: only iOS
          break;
        case Event.actionCallCustom:
          // TODO: for custom action
          break;
      }
    });
  }

  Future<void> handlePush(CallEvent event) async {
    String? token;
    PushMetaData? pushMetaData = PushMetaData.fromJson(
        jsonDecode(event.body['extra']['metadata']));
    if (defaultTargetPlatform == TargetPlatform.android) {
      token = (await FirebaseMessaging.instance.getToken())!;
      logger.i("Android notification token :: $token");
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      token = await FlutterCallkitIncoming.getDevicePushTokenVoIP();
      logger.i("iOS notification token :: $token");
    }
    var credentialConfig = CredentialConfig("<username>", "<password>",
        "Isaac", "1234567890", token, true, "", "");
    mainViewModel.handlePushNotification(pushMetaData,credentialConfig, null);
    mainViewModel.observeResponses();
    logger.i('actionCallIncoming :: Received Incoming Call!');

  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: mainViewModel),
      ],
      child: MaterialApp(
        title: 'Telnyx WebRTC',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const LoginScreen(title: 'Telnyx Login'),
          '/home': (context) => const HomeScreen(title: 'Home'),
          '/call': (context) => const CallScreen(title: 'Ongoing Call'),
        },
      ),
    );
  }
}
