import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:telnyx_flutter_webrtc/provider/profile_provider.dart';
import 'package:telnyx_flutter_webrtc/utils/background_detector.dart';
import 'package:telnyx_flutter_webrtc/view/screen/home_screen.dart';
import 'package:telnyx_flutter_webrtc/view/telnyx_client_view_model.dart';
import 'package:telnyx_flutter_webrtc/service/notification_service.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:telnyx_webrtc/model/push_notification.dart';
import 'package:telnyx_webrtc/telnyx_client.dart';
import 'package:telnyx_webrtc/model/telnyx_message.dart';
import 'package:telnyx_webrtc/model/socket_method.dart';
import 'package:telnyx_flutter_webrtc/utils/theme.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';
import 'package:telnyx_webrtc/model/telnyx_socket_error.dart';

import 'package:telnyx_flutter_webrtc/firebase_options.dart';

final logger = Logger();
final txClientViewModel = TelnyxClientViewModel();
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
      if (!kIsWeb) {
        logger.i('FlutterCallkitIncoming :: Initializing listening for events');
        FlutterCallkitIncoming.onEvent.listen((CallEvent? event) async {
          logger.i('onEvent :: ${event?.event} :: ${event?.body}');
          switch (event!.event) {
            case Event.actionCallIncoming:
              // retrieve the push metadata from extras
              if (event.body['extra']['metadata'] == null) {
                logger.i('actionCallIncoming :: Push Data is null!');
                return;
              }
              logger.i(
                "ZZZ received push Call for iOS (actionCallIncoming): ${event.body['extra']['metadata']}",
              );
              // No connection or handlePush call here.
              // CallKit's native UI is already shown by this point.
              // We wait for user action (Accept/Decline).
              break;
            case Event.actionCallStart:
              logger.i('actionCallStart :: call start');
              break;
            case Event.actionCallAccept:
              logger.i('[iOS_PUSH_DEBUG] Event.actionCallAccept received. Metadata: ${event.body?['extra']?['metadata']}');
              if (txClientViewModel.incomingInvitation != null) {
                logger.i('[iOS_PUSH_DEBUG] Event.actionCallAccept: ViewModel has existing incomingInvitation.');
                logger.i('Accepted Call Directly because of incomingInvitation');
                await txClientViewModel.accept();
              } else {
                final metadata = event.body['extra']['metadata'];
                if (metadata == null) {
                   // This case should ideally not happen if CallKit sends metadata on accept.
                  logger.i('Accepted Call Directly - Metadata missing in actionCallAccept event.');
                  await txClientViewModel.accept(); // Accept without push context
                } else {
                  logger.i(
                    '[iOS_PUSH_DEBUG] Event.actionCallAccept: Metadata present. Preparing to call global handlePush. Metadata: $metadata',
                  );
                  var decodedMetadata = metadata;
                  if (metadata is String) {
                    try {
                      decodedMetadata = jsonDecode(metadata);
                    } catch (e) {
                      logger.e('Error decoding metadata JSON in actionCallAccept: $e. Attempting direct accept.');
                      await txClientViewModel.accept(); // Fallback
                      return;
                    }
                  }
                  // Pass the acceptance intent and data to the global handlePush
                  final Map<dynamic, dynamic> data = Map<dynamic, dynamic>.from(decodedMetadata as Map);
                  data['isAnswer'] = true;
                  logger.i('[iOS_PUSH_DEBUG] Event.actionCallAccept: Calling global handlePush with augmented data: $data');
                  await handlePush(data);
                }
              }
              break;
            case Event.actionCallDecline:
              final metadata = event.body['extra']['metadata'];
              if (txClientViewModel.incomingInvitation != null || txClientViewModel.currentCall != null) {
                // If the main client already has an active call or invite, let it handle the decline.
                // This could happen if the app was already open and connected when CallKit decline comes.
                logger.i('Main client has existing call/invite. Using txClientViewModel.endCall() for decline.');
                txClientViewModel.endCall();
              } else if (metadata == null) {
                logger.i('Decline Call Directly (no metadata from CallKit event and no active call/invite in ViewModel).');
                // Potentially a no-op if there's nothing to decline, or CallKit might handle UI.
                // Consider if ending all CallKit calls is appropriate if no specific ID is known:
                // FlutterCallkitIncoming.endAllCalls(); 
              } else {
                // This is a decline from a CallKit push, and the main ViewModel doesn't have an active session for it.
                // Use a temporary client to handle this decline.
                logger.i(
                  'Received CallKit decline event with metadata: $metadata. Using temporary client for decline.',
                );
                var decodedMetadata = metadata;
                if (metadata is String) {
                  try {
                    decodedMetadata = jsonDecode(metadata);
                  } catch (e) {
                    logger.e('Error decoding metadata JSON in actionCallDecline: $e. Cannot proceed with temporary client decline.');
                    return;
                  }
                }

                final Map<dynamic, dynamic> eventData = Map<dynamic, dynamic>.from(decodedMetadata as Map);
                eventData['isDecline'] = true; // Ensure decline intent

                final PushMetaData pushMetaData;
                try {
                  pushMetaData = PushMetaData.fromJson(eventData);
                } catch (e) {
                    logger.e('Error creating PushMetaData from eventData for temporary client decline: $e');
                    return;
                }

                final tempDeclineClient = TelnyxClient();

                tempDeclineClient..onSocketMessageReceived = (TelnyxMessage message) {
                  switch (message.socketMethod) {
                    case SocketMethod.bye:
                      logger.i('Temporary client (iOS decline) received BYE, disconnecting.');
                      tempDeclineClient.disconnect();
                      break;
                    default:
                      logger.i('Temporary client (iOS decline) received message: ${message.socketMethod}');
                  }
                }

                ..onSocketErrorReceived = (TelnyxSocketError error) {
                    logger.e('Temporary client (iOS decline) received error: ${error.errorCode} :: ${error.errorMessage}');
                    tempDeclineClient.disconnect(); // Attempt to cleanup on error too
                };

                // getConfig() might rely on txClientViewModel, or it might be static/retrievable independently.
                // For this example, assuming it can be fetched.
                // If getConfig is problematic here, the credentials/token would need to be passed differently or stored accessibly.
                final config = await txClientViewModel.getConfig();

                logger.i('Temporary client (iOS decline) attempting to handlePushNotification. Config :: $config');
                tempDeclineClient.handlePushNotification(
                  pushMetaData,
                  config is CredentialConfig ? config : null,
                  config is TokenConfig ? config : null,
                );
              }
              break;
            case Event.actionCallEnded:
              txClientViewModel.endCall();
              logger.i('actionCallEnded :: call ended');
              break;
            case Event.actionCallTimeout:
              txClientViewModel.endCall();
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
        options: kIsWeb ? DefaultFirebaseOptions.currentPlatform : null,
      );
      if (!kIsWeb && Platform.isAndroid) {
        FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler,
        );
      } else {
        logger
            .i('Web or iOS - Skipping Firebase Messaging onBackgroundMessage');
      }

      if (defaultTargetPlatform == TargetPlatform.android) {
        ///await askForNotificationPermission();
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

var fromBackground = false;

// Android Only - Push Notifications
@pragma('vm:entry-point')
Future _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: kIsWeb ? DefaultFirebaseOptions.currentPlatform : null,
  );
  logger.i('Handling a background message ${message.toMap().toString()}');
  await NotificationService.showNotification(message);
  FlutterCallkitIncoming.onEvent.listen((CallEvent? event) async {
    switch (event!.event) {
      case Event.actionCallIncoming:
        logger
            .i('actionCallIncoming :: Received Incoming Call! from background');
        break;
      case Event.actionCallStart:
        break;
      case Event.actionCallAccept:
        logger.i(
          'actionCallAccept :: _firebaseMessagingBackgroundHandler call accepted',
        );
        TelnyxClient.setPushMetaData(
          message.data,
          isAnswer: true,
          isDecline: false,
        );
        break;
      case Event.actionCallDecline:
        /*
        * When the user declines the call from the push notification, the app will no longer be visible, and we have to
        * handle the endCall user here.
        *
        * */
        logger.i('actionCallDecline :: call declined');
        String? token;
        PushMetaData? pushMetaData;
        final telnyxClient = TelnyxClient();

        telnyxClient.onSocketMessageReceived = (TelnyxMessage message) {
          switch (message.socketMethod) {
            case SocketMethod.bye:
              {
                // make sure to disconnect the telnyxclient on Bye for Decline
                // Only disconnect the socket when the call was ended from push notifications
                logger.i('TelnyxClient :: onSocketMessageReceived :: BYE');
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
        // Set the pushMetaData to decline
        pushMetaData.isDecline = true;
        token = (await FirebaseMessaging.instance.getToken())!;
        final config = await txClientViewModel.getConfig();
        telnyxClient.handlePushNotification(
          pushMetaData,
          config is CredentialConfig ? config : null,
          config is TokenConfig ? config : null,
        );
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
  txClientViewModel.setPushCallStatus(true);
}

@pragma('vm:entry-point')
Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Catch Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      logger.e('Caught Flutter error: ${details.exception}', stackTrace: details.stack);
      TelnyxClient.clearPushMetaData();
    };

    // Catch other platform errors (e.g., Dart errors outside Flutter)
    PlatformDispatcher.instance.onError = (error, stack) {
      logger.e('Caught Platform error: $error', stackTrace: stack);
      TelnyxClient.clearPushMetaData();
      return true; 
    };

    if (!AppInitializer()._isInitialized) {
      await AppInitializer().initialize();
    }

    final config = await txClientViewModel.getConfig();
    runApp(
      BackgroundDetector(
         skipWeb: true,
         onLifecycleEvent: (AppLifecycleState state) {
           if (state == AppLifecycleState.resumed) {
             logger.i('We are in the foreground, CONNECTING');
             // Check if we are from push, if we are do nothing, reconnection will happen there in handlePush. Otherwise connect
             if (!txClientViewModel.callFromPush) {
               if (config != null && config is CredentialConfig) {
                 txClientViewModel.login(config);
               } else if (config != null && config is TokenConfig) {
                 txClientViewModel.loginWithToken(config);
               }
             }
           } else if (state == AppLifecycleState.paused) {
             logger.i(
               'We are in the background setting fromBackground == true, DISCONNECTING',
             );
             fromBackground = true;
             txClientViewModel.disconnect();
           }
         },
         child: const MyApp(),
      ),
    );
  }, (error, stack) {
    logger.e('Caught Zoned error: $error', stackTrace: stack);
    TelnyxClient.clearPushMetaData();
  });
}

Future<void> handlePush(Map<dynamic, dynamic> data) async {
  logger.i('[iOS_PUSH_DEBUG] handlePush: Started. Raw data: $data');
  txClientViewModel.setPushCallStatus(true);
  PushMetaData? pushMetaData;
  if (defaultTargetPlatform == TargetPlatform.android) {
    pushMetaData = PushMetaData.fromJson(data);
  } else if (Platform.isIOS) {
    pushMetaData = PushMetaData.fromJson(data);
  }
  logger.i('[iOS_PUSH_DEBUG] handlePush: Before txClientViewModel.getConfig()');
  final config = await txClientViewModel.getConfig();
  logger.i('[iOS_PUSH_DEBUG] handlePush: After txClientViewModel.getConfig(). Config: $config');
  logger.i('[iOS_PUSH_DEBUG] handlePush: Created PushMetaData: ${pushMetaData?.toJson()}');
  txClientViewModel
    ..handlePushNotification(
      pushMetaData!,
      config is CredentialConfig ? config : null,
      config is TokenConfig ? config : null,
    )
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
        txClientViewModel.setPushCallStatus(true);
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
            logger.d('getPushData : No data');
          }
        });
      } else if (!kIsWeb && Platform.isIOS && !txClientViewModel.callFromPush) {
        logger.i('iOS :: connect');
      } else {
        logger.i('Web :: connect');
      }
    } catch (e) {
      logger.e('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => txClientViewModel),
        ChangeNotifierProvider(create: (context) => ProfileProvider()),
      ],
      child: MaterialApp(
        title: 'Telnyx WebRTC',
        theme: AppTheme.lightTheme,
        initialRoute: '/',
        routes: {
          '/': (context) => const HomeScreen(),
        },
      ),
    );
  }
}
