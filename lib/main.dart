import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_fgbg/flutter_fgbg.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telnyx_flutter_webrtc/main_view_model.dart';
import 'package:telnyx_flutter_webrtc/service/notification_service.dart';
import 'package:telnyx_flutter_webrtc/view/screen/call_screen.dart';
import 'package:telnyx_flutter_webrtc/view/screen/home_screen.dart';
import 'package:telnyx_flutter_webrtc/view/screen/login_screen.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:telnyx_webrtc/model/push_notification.dart';
import 'package:telnyx_webrtc/telnyx_client.dart';
import 'package:telnyx_webrtc/model/telnyx_message.dart';
import 'package:telnyx_webrtc/model/socket_method.dart';

import 'package:telnyx_flutter_webrtc/firebase_options.dart';

final logger = Logger();
final mainViewModel = MainViewModel();
const MOCK_USER = '<MOCK_USER>';
const MOCK_PASSWORD = '<MOCK_PASSWORD>';
const CALL_MISSED_TIMEOUT = 30;

class AppInitializer {
  static final AppInitializer _instance = AppInitializer._internal();
  bool _isInitialized = false;

  factory AppInitializer() {
    return _instance;
  }

  AppInitializer._internal();

  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (!_isInitialized) {
      _isInitialized = true;
      var incomingPushCall = false;
      if (!kIsWeb) {
        // generate random number as string
        logger.i('FlutterCallkitIncoming :: Initializing listening for events');
        FlutterCallkitIncoming.onEvent.listen((CallEvent? event) async {
          logger.i('onEvent :: ${event?.event} :: ${event?.body}');
          switch (event!.event) {
            case Event.actionCallIncoming:
              incomingPushCall = true;
              // retrieve the push metadata from extras
              if (event.body['extra']['metadata'] == null) {
                logger.i('actionCallIncoming :: Push Data is null!');
                return;
              }
              logger.i(
                "received push Call for iOS ${event.body['extra']['metadata']}",
              );
              var metadata = event.body['extra']['metadata'];
              if (metadata is String) {
                metadata = jsonDecode(metadata);
              }
              await handlePush(metadata);
              break;
            case Event.actionCallStart:
              logger.i('actionCallStart :: call start');
              break;
            case Event.actionCallAccept:
              final metadata = event.body['extra']['metadata'];
              if (metadata == null || (incomingPushCall && fromBackground)) {
                logger.i('Accepted Call Directly');
                await mainViewModel.accept();

                /// Reset the incomingPushCall flag and fromBackground flag
                incomingPushCall = false;
                fromBackground = false;
              } else {
                logger.i(
                  'Received push Call with metadata on Accept, handle push here $metadata',
                );
                final data = metadata as Map<dynamic, dynamic>;
                data['isAnswer'] = true;
                await handlePush(data);
              }
              break;
            case Event.actionCallDecline:
              final metadata = event.body['extra']['metadata'];
              if (metadata == null) {
                logger.i('Decline Call Directly');
                mainViewModel.endCall();
              } else {
                logger.i('Received push Call for iOS $metadata');
                final data = metadata as Map<dynamic, dynamic>;
                data['isDecline'] = true;
                await handlePush(data);
              }
              break;
            case Event.actionCallEnded:
              mainViewModel.endCall();
              logger.i('actionCallEnded :: call ended');
              break;
            case Event.actionCallTimeout:
              mainViewModel.endCall();
              logger.i('Decline Call');
              break;
            case Event.actionCallCallback:
              logger.i('actionCallCallback :: call callback');
              break;
            case Event.actionCallToggleHold:
              logger.i('actionCallToggleHold :: call hold');
              break;
            case Event.actionCallToggleMute:
              logger.i('actionCallToggleMute :: call mute');
              break;
            case Event.actionCallToggleDmtf:
              logger.i('actionCallToggleDmtf :: call dmtf');
              break;
            case Event.actionCallToggleGroup:
              logger.i('actionCallToggleGroup :: call group');
              break;
            case Event.actionCallToggleAudioSession:
              logger.i('actionCallToggleAudioSession :: call audio session');
              break;
            case Event.actionDidUpdateDevicePushTokenVoip:
              logger.i('actionDidUpdateDevicePushTokenVoip :: call push token');
              break;
            case Event.actionCallCustom:
              logger.i('actionCallCustom :: call custom');
              break;
          }
        });
      }

      /// Firebase
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      if (Platform.isAndroid) {
        FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler,
        );
      } else {
        logger.i('iOS - Skipping Firebase Messaging onBackgroundMessage');
      }

      if (defaultTargetPlatform == TargetPlatform.android) {
        await FirebaseMessaging.instance
            .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
    } else {
      logger.i('AppInitializer :: Already Initialized');
    }
  }
}

// Android Only - Push Notifications
@pragma('vm:entry-point')
Future _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Platform.isAndroid) {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    logger.i('Handling a background message ${message.toMap().toString()}');
    await NotificationService.showNotification(message);
    FirebaseMessaging.onMessageOpenedApp
        .listen(firebaseOnMessageOpenedAppHandler);
    FlutterCallkitIncoming.onEvent.listen((CallEvent? event) async {
      switch (event!.event) {
        case Event.actionCallIncoming:
          logger.i(
              'actionCallIncoming :: Received Incoming Call! from background');
          break;
        case Event.actionCallStart:
          break;
        case Event.actionCallAccept:
          logger.i('Accepted Call from Push Notification');
          TelnyxClient.setPushMetaData(message.data,
              isAnswer: true, isDecline: false);
          break;
        case Event.actionCallDecline:
          /*
        * When the user declines the call from the push notification, the app will no longer be visible, and we have to
        * handle the endCall user here.
        *
        * */
          logger.i('Decline Call from Push Notification');
          String? token;
          PushMetaData? pushMetaData;
          final telnyxClient = TelnyxClient();

          telnyxClient.onSocketMessageReceived = (TelnyxMessage message) {
            switch (message.socketMethod) {
              case SocketMethod.bye:
                {
                  logger.i('telnyxClient disconnected');
                  telnyxClient.disconnect();
                  break;
                }
              default:
                logger.i('TelnyxClient :: onSocketMessageReceived   $message');
            }
            logger.i('TelnyxClient :: onSocketMessageReceived : $message');
          };

          pushMetaData =
              PushMetaData.fromJson(jsonDecode(message.data['metadata']!));

          /// Set the pushMetaData to decline
          pushMetaData.isDecline = true;

          if (defaultTargetPlatform == TargetPlatform.android) {
            token = (await FirebaseMessaging.instance.getToken());

            logger.i('Android notification token :: $token');
          } else if (defaultTargetPlatform == TargetPlatform.iOS) {
            token = await FlutterCallkitIncoming.getDevicePushTokenVoIP();
            logger.i('iOS notification token :: $token');
          }
          final prefs = await SharedPreferences.getInstance();

          // save token to shared preferences
          await prefs.setString(
            'notificationToken',
            token ?? '',
          );
          logger.i('Push notification token :: $token');
          final credentialConfig = await mainViewModel.getCredentialConfig();

          telnyxClient.handlePushNotification(
              pushMetaData, credentialConfig, null);
          break;
        case Event.actionDidUpdateDevicePushTokenVoip:
          break;
        case Event.actionCallEnded:
          break;
        case Event.actionCallTimeout:
          break;
        case Event.actionCallCallback:
          break;
        case Event.actionCallToggleHold:
          break;
        case Event.actionCallToggleMute:
          break;
        case Event.actionCallToggleDmtf:
          break;
        case Event.actionCallToggleGroup:
          break;
        case Event.actionCallToggleAudioSession:
          break;
        case Event.actionCallCustom:
          break;
      }
    });
    mainViewModel.updateCallFromPush(true);
  } else {
    logger.i('ZZZ Handling a background message ${message.toMap().toString()}');
  }
}

Future<void> firebaseOnMessageOpenedAppHandler(RemoteMessage? message) async {
  WidgetsFlutterBinding.ensureInitialized();

  SchedulerBinding.instance.addPostFrameCallback((_) async {
    logger
      ..i('_onReceiveNotification Called')
      ..i('Push Data - $message');
    mainViewModel.observeResponses();
  });
}

var fromBackground = false;
var inForeground = true;

@pragma('vm:entry-point')
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!AppInitializer()._isInitialized) {
    await AppInitializer().initialize();
  }
  final credentialConfig = await mainViewModel.getCredentialConfig();
  runApp(
    FGBGNotifier(
      onEvent: (FGBGType type) => switch (type) {
        FGBGType.foreground => {
            logger.i('We are in the foreground, CONNECTING'),
            // Check if we are from push, if we are do nothing, reconnection will happen there in handlePush. Otherwise connect
            if (!mainViewModel.callFromPush)
              {
                mainViewModel.login(credentialConfig),
              },
            fromBackground = false,
            inForeground = true,
          },
        FGBGType.background => {
            logger.i(
              'We are in the background setting fromBackground == true, DISCONNECTING',
            ),
            fromBackground = true,
            inForeground = false,
            mainViewModel.disconnect(),
          }
      },
      child: const MyApp(),
    ),
  );
}

Future<void> handlePush(Map<dynamic, dynamic> data) async {
  mainViewModel.updateCallFromPush(true);

  logger.i('Handle Push Init');
  String? token;

  PushMetaData? pushMetaData;
  if (defaultTargetPlatform == TargetPlatform.android) {
    token = (await FirebaseMessaging.instance.getToken())!;
    pushMetaData = PushMetaData.fromJson(data);
    logger.i('Android notification token :: $token');
  } else if (Platform.isIOS) {
    token = await FlutterCallkitIncoming.getDevicePushTokenVoIP();
    pushMetaData = PushMetaData.fromJson(data);
    logger.i('iOS notification token :: $token');
  }
  final credentialConfig = await mainViewModel.getCredentialConfig();
  mainViewModel
    ..handlePushNotification(pushMetaData!, credentialConfig, null)
    ..observeResponses();
  logger.i('actionCallIncoming :: Received Incoming Call! Handle Push');
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

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
        final DateTime nowTime = DateTime.now();
        final Duration difference = nowTime.difference(message.sentTime!);

        logger
            .i('OnMessage :: Notification difference: ${difference.inSeconds}');
        if (difference.inSeconds > CALL_MISSED_TIMEOUT) {
          logger.i('OnMessage :: Notification Message: Missed Call');
          // You can simulate a missed call here
          NotificationService.showMissedCallNotification(message);
          return;
        }

        logger.i('OnMessage Time :: Notification Message: ${message.sentTime}');
        TelnyxClient.setPushMetaData(message.data);
        NotificationService.showNotification(message);
        mainViewModel.updateCallFromPush(true);
      });
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        logger.i('onMessageOpenedApp :: Notification Message: ${message.data}');
      });
    }

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        // Handle Push when app comes from background :: Only for Android
        TelnyxClient.getPushData().then((data) {
          // whenever you open the app from the terminate state by clicking on Notification message,
          if (data != null) {
            handlePush(data);
            logger.i(
              'getPushData : getInitialMessage :: Notification Message: $data',
            );
          } else {
            logger.e('getPushData : No data');
          }
        });
      } else if (Platform.isIOS && !mainViewModel.callFromPush) {
        logger.i('iOS :: connect');
      }
    } catch (e) {
      logger.e('Error: $e');
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
          '/': (context) => const LoginScreen(),
          '/home': (context) => const HomeScreen(),
          '/call': (context) => const CallScreen(),
        },
      ),
    );
  }
}
