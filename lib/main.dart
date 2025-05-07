import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:telnyx_flutter_webrtc/provider/profile_provider.dart';
import 'package:telnyx_flutter_webrtc/utils/background_detector.dart';
import 'package:telnyx_flutter_webrtc/view/screen/home_screen.dart';
import 'package:telnyx_flutter_webrtc/view/telnyx_client_view_model.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:telnyx_webrtc/model/push_notification.dart';
import 'package:telnyx_flutter_webrtc/utils/theme.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';
import 'package:telnyx_flutter_webrtc/service/platform_push_service.dart';
import 'package:telnyx_flutter_webrtc/service/android_push_notification_handler.dart' show androidBackgroundMessageHandler;
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
      logger.i('[AppInitializer] Initializing...');

      // Initialize Firebase first, ensuring it's ready before platform handlers use it.
      logger.i('[AppInitializer] Initializing Firebase Core...');
      try {
        await Firebase.initializeApp(
          options: kIsWeb ? DefaultFirebaseOptions.currentPlatform : null,
        );
        logger.i('[AppInitializer] Firebase Core Initialized successfully.');
      } catch (e) {
        logger.e('[AppInitializer] Firebase Core Initialization failed: $e');
        // Decide how to handle failure - maybe rethrow or prevent handler init?
      }
      
      // Delegate to platform-specific push handler for initialization
      // This will set up FCM listeners, CallKit listeners, etc.
      logger.i('[AppInitializer] Initializing Platform Push Service Handler...');
      await PlatformPushService.handler.initialize();
      logger.i('[AppInitializer] Platform Push Service Handler Initialized.');

      logger.i('[AppInitializer] Initialization complete.');
    } else {
      logger.i('[AppInitializer] Already initialized.');
    }
  }
}


// Android Only - Push Notifications
// This global function remains as an entry point for Firebase background messages on Android.
// It will now delegate to the annotated top-level function in android_push_notification_handler.dart.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Delegate to the new top-level annotated function
  await androidBackgroundMessageHandler(message);
}

@pragma('vm:entry-point')
Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Catch Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      logger.e('Caught Flutter error: ${details.exception}', stackTrace: details.stack);
      PlatformPushService.handler.clearPushData();
    };

    // Catch other platform errors (e.g., Dart errors outside Flutter)
    PlatformDispatcher.instance.onError = (error, stack) {
      logger.e('Caught Platform error: $error', stackTrace: stack);
      PlatformPushService.handler.clearPushData();
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
             txClientViewModel.disconnect();
           }
         },
         child: const MyApp(),
      ),
    );
  }, (error, stack) {
    logger.e('Caught Zoned error: $error', stackTrace: stack);
    PlatformPushService.handler.clearPushData();
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
    logger.i('[_MyAppState] initState called.');

    // Platform-specific logic for handling initial push data when app starts.
    // For Android, this checks if the app was launched from a terminated state by a notification.
    // For iOS, this is less critical as CallKit events usually drive the flow after launch.
    if (!kIsWeb && Platform.isAndroid) {
      PlatformPushService.handler.getInitialPushData().then((data) {
        if (data != null) {
          logger.i('[_MyAppState] Android: Found initial push data: $data. Processing...');
          // Determine if this initial push should be treated as an "answer" implicitly.
          // This depends on how Android notifications are structured and if they imply an accept.
          // For now, let's assume it should be processed as an incoming call that might need answering.
          // The `isAnswer` flag would typically come from a user action on the notification if it has action buttons.
          // If just tapping the notification body, `isAnswer` is likely false initially.
          PlatformPushService.handler.processIncomingCallAction(data, isAnswer: false /* Or true if applicable */);
        } else {
          logger.i('[_MyAppState] Android: No initial push data found.');
        }
      }).catchError((e) {
        logger.e('[_MyAppState] Android: Error fetching initial push data: $e');
      });
    }

    // Foreground FCM message listening for Android is now handled by AndroidPushNotificationHandler.initialize().
    // iOS CallKit event listening is handled by IOSPushNotificationHandler.initialize().

    // Original connection logic if not from push (now part of BackgroundDetector or specific user actions)
    // This part needs careful review. The original code had: 
    // } else if (!kIsWeb && Platform.isIOS && !txClientViewModel.callFromPush) {
    //   logger.i('iOS :: connect');
    // } else {
    //   logger.i('Web :: connect');
    // }
    // This suggests a default connection attempt. This might now be better handled
    // by the BackgroundDetector's onAppResumed, or a manual login button if no auto-login is desired.
    // For now, removing this explicit connect from here as push/resume flows should cover it.
    logger.i('[_MyAppState] initState completed.');
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
