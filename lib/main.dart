import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:telnyx_flutter_webrtc/main_view_model.dart';
import 'package:telnyx_flutter_webrtc/service/notification_service.dart';
import 'package:telnyx_flutter_webrtc/view/screen/call_screen.dart';
import 'package:telnyx_flutter_webrtc/view/screen/home_screen.dart';
import 'package:telnyx_flutter_webrtc/view/screen/login_screen.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:telnyx_webrtc/model/push_notification.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';
import 'package:telnyx_webrtc/telnyx_client.dart';
import 'package:telnyx_webrtc/model/telnyx_message.dart';
import 'package:telnyx_webrtc/model/socket_method.dart';

final logger = Logger();
final mainViewModel = MainViewModel();
const MOCK_USER = "<UserName>";
const MOCK_PASSWORD = "<Password>";
// Android Only - Push Notifications
@pragma('vm:entry-point')
Future _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling a background message ${message.toMap().toString()}');
  print("priority ${message.data.toString()}");
  NotificationService.showNotification(message);
  FlutterCallkitIncoming.onEvent.listen((CallEvent? event) async {
    switch (event!.event) {
      case Event.actionCallIncoming:
        logger
            .i('actionCallIncoming :: Received Incoming Call! from background');
        break;
      case Event.actionCallStart:
        // TODO: Handle this case.
        break;
      case Event.actionCallAccept:
        print("Accepted Call from Push Notification");
        TelnyxClient.setPushMetaData(message.data,
            isAnswer: true, isDecline: false);
        break;
      case Event.actionCallDecline:
        /*
        * When the user declines the call from the push notification, the app will no longer be visible, and we have to
        * handle the endCall user here.
        *
        * */
        print("Decline Call from Push Notification");
        String? token;
        PushMetaData? pushMetaData;
        final telnyxClient = TelnyxClient();

        telnyxClient.onSocketMessageReceived = (TelnyxMessage message) {
          switch (message.socketMethod) {
            case SocketMethod.BYE:
              {
                //make sure to disconnect the telnyxclient on Bye for Decline
                // Only disconnect the socket when the call was ended from push notifications
                print("telnyxClient disconnected");
                telnyxClient.disconnect();
                break;
              }
            default:
              logger.i('TelnyxClient :: onSocketMessageReceived   $message');
          }
          logger.i('TelnyxClient :: onSocketMessageReceived : $message');
        };

        pushMetaData =
            PushMetaData.fromJson(jsonDecode(message.data["metadata"]!));
        //set the pushMetaData to decline
        pushMetaData.isDecline = true;

        if (defaultTargetPlatform == TargetPlatform.android) {
          token = (await FirebaseMessaging.instance.getToken())!;

          logger.i("Android notification token :: $token");
        } else if (defaultTargetPlatform == TargetPlatform.iOS) {
          token = await FlutterCallkitIncoming.getDevicePushTokenVoIP();

          logger.i("iOS notification token :: $token");
        }
        var credentialConfig = CredentialConfig(MOCK_USER, MOCK_PASSWORD,
            "<caller_id>", "<caller_number>", token, true, "", "");
        telnyxClient.handlePushNotification(
            pushMetaData, credentialConfig, null);
        break;
      case Event.actionDidUpdateDevicePushTokenVoip:
        // TODO: Handle this case.
        break;
      case Event.actionCallEnded:
        // TODO: Handle this case.
        break;
      case Event.actionCallTimeout:
        // TODO: Handle this case.
        break;
      case Event.actionCallCallback:
        // TODO: Handle this case.
        break;
      case Event.actionCallToggleHold:
        // TODO: Handle this case.
        break;
      case Event.actionCallToggleMute:
        // TODO: Handle this case.
        break;
      case Event.actionCallToggleDmtf:
        // TODO: Handle this case.
        break;
      case Event.actionCallToggleGroup:
        // TODO: Handle this case.
        break;
      case Event.actionCallToggleAudioSession:
        // TODO: Handle this case.
        break;
      case Event.actionCallCustom:
        // TODO: Handle this case.
        break;
    }
  });
  mainViewModel.callFromPush = true;
}

@pragma('vm:entry-point')
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (defaultTargetPlatform == TargetPlatform.android) {
    // Android Only - Push Notifications
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    askForNotificationPermission();

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  if (!kIsWeb) {
    FlutterCallkitIncoming.onEvent.listen((CallEvent? event) async {
      logger.i('onEvent :: ${event?.event}');
      switch (event!.event) {
        case Event.actionCallIncoming:
          // retrieve the push metadata from extras
          if (Platform.isAndroid) {
            final data = await TelnyxClient.getPushData();
            if (data != null) {
              handlePush(data);
            } else {
              logger.i('actionCallIncoming :: Push Data is null!');
            }
          } else if (Platform.isIOS) {
            if (event.body['extra']['metadata'] == null) {
              logger.i('actionCallIncoming :: Push Data is null!');
              return;
            }
            logger.i(
                "received push Call for iOS ${event.body['extra']['metadata']}");
            handlePush(
                event.body['extra']['metadata'] as Map<dynamic, dynamic>);
          }

          break;
        case Event.actionCallStart:
          // TODO: started an outgoing call
          // TODO: show screen calling in Flutter
          break;
        case Event.actionCallAccept:
          print("Accepted Call");
          mainViewModel.accept();
          break;
        case Event.actionCallDecline:
          logger.i("actionCallDecline :: call declined");
          mainViewModel.endCall();
          break;
        case Event.actionCallEnded:
          mainViewModel.endCall(endfromCallScreen: false);
          print("EndCall Call");
          logger.i("actionCallEnded :: call ended");
          break;
        case Event.actionCallTimeout:
          mainViewModel.endCall();
          print("Decline Call");
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

  runApp(const MyApp());
}

Future<void> askForNotificationPermission() async {
  FlutterCallkitIncoming.requestNotificationPermission("notification");
  var status = await Permission.notification.status;
  if (status.isDenied) {
    // We haven't asked for permission yet or the permission has been denied before, but not permanently
    Permission.notification.request();
  }

// You can also directly ask permission about its status.
  if (await Permission.location.isRestricted) {
    // The OS restricts access, for example, because of parental controls.
  }
}

Future<void> handlePush(Map<dynamic, dynamic> data) async {
  mainViewModel.callFromPush = true;

  logger.i("Handle Push Init");
  String? token;

  PushMetaData? pushMetaData;
  if (defaultTargetPlatform == TargetPlatform.android) {
    token = (await FirebaseMessaging.instance.getToken())!;
    pushMetaData = PushMetaData.fromJson(data);
    logger.i("Android notification token :: $token");
  } else if (Platform.isIOS) {
    token = await FlutterCallkitIncoming.getDevicePushTokenVoIP();
    pushMetaData = PushMetaData.fromJson(data);
    logger.i("iOS notification token :: $token");
  }
  var credentialConfig = CredentialConfig(MOCK_USER, MOCK_PASSWORD,
      "<caller_id>", "<caller_number>", token, true, "", "");
  mainViewModel.handlePushNotification(pushMetaData!, credentialConfig, null);
  mainViewModel.observeResponses();
  logger.i('actionCallIncoming :: Received Incoming Call! Handle Push');
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
        TelnyxClient.setPushMetaData(message.data);
        NotificationService.showNotification(message);
        mainViewModel.callFromPush = true;
      });
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('onMessageOpenedApp :: Notification Message: ${message.data}');
      });
    }

    if (Platform.isAndroid) {
      // Handle Push when app comes from background :: Only for Android
      TelnyxClient.getPushData().then((data) {
        // whenever you open the app from the terminate state by clicking on Notification message,
        if (data != null) {
          handlePush(data);
          print(
              "getPushData : getInitialMessage :: Notification Message: $data");
        } else {
          print("getPushData : No data");
        }
      });
    } else if (Platform.isIOS && !mainViewModel.callFromPush) {
      logger.i("iOS :: connect");
    }
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
