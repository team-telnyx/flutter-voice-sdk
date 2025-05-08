import 'dart:async';
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
import 'package:telnyx_flutter_webrtc/service/android_push_notification_handler.dart'
    show androidBackgroundMessageHandler;

import 'package:telnyx_flutter_webrtc/firebase_options.dart';

final logger = Logger();
final txClientViewModel = TelnyxClientViewModel();
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
      try {
        await Firebase.initializeApp(
          options: kIsWeb ? DefaultFirebaseOptions.currentPlatform : null,
        );
        logger.i('[AppInitializer] Firebase Core Initialized successfully.');
      } catch (e) {
        logger.e('[AppInitializer] Firebase Core Initialization failed: $e');
      }

      // Delegate to platform-specific push handler for initialization
      // This will set up FCM listeners, CallKit listeners, etc.
      await PlatformPushService.handler.initialize();
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
  logger.i(
      '[Background Notification]. Received background message: ${message.data}');
  await androidBackgroundMessageHandler(message);
}

@pragma('vm:entry-point')
Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Catch Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      logger.e('Caught Flutter error: ${details.exception}',
          stackTrace: details.stack);
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

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    final config = await txClientViewModel.getConfig();
    runApp(
      BackgroundDetector(
        skipWeb: true,
        onLifecycleEvent: (AppLifecycleState state) {
          if (state == AppLifecycleState.resumed) {
            logger
                .i('[BackgroundDetector] We are in the foreground, CONNECTING');
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
              '[BackgroundDetector] We are in the background, DISCONNECTING',
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
  logger.i('[handlePush] Started. Raw data: $data');
  txClientViewModel.setPushCallStatus(true);
  PushMetaData? pushMetaData;
  if (defaultTargetPlatform == TargetPlatform.android) {
    pushMetaData = PushMetaData.fromJson(data);
  } else if (Platform.isIOS) {
    pushMetaData = PushMetaData.fromJson(data);
  }
  logger.i('[handlePush] Before txClientViewModel.getConfig()');
  final config = await txClientViewModel.getConfig();
  logger.i(
      '[handlePush] Created PushMetaData: ${pushMetaData?.toJson()}');
  txClientViewModel
    ..handlePushNotification(
      pushMetaData!,
      config is CredentialConfig ? config : null,
      config is TokenConfig ? config : null,
    )
    ..observeResponses();
  logger.i('[handlePush] Processing complete. Call state should update soon.');
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
    PlatformPushService.handler.getInitialPushData().then((data) {
      if (data != null) {
        final Map<dynamic, dynamic> mutablePayload = Map.from(data);
        final answer = mutablePayload['isAnswer'] = true;
        PlatformPushService.handler.processIncomingCallAction(data,
            isAnswer: answer, isDecline: !answer);
      } else {
        logger.i('[_MyAppState] Android: No initial push data found.');
      }
    }).catchError((e) {
      logger.e('[_MyAppState] Android: Error fetching initial push data: $e');
    });
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
