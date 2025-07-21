import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:telnyx_flutter_webrtc/provider/profile_provider.dart';
import 'package:telnyx_flutter_webrtc/view/screen/home_screen.dart';
import 'package:telnyx_flutter_webrtc/view/telnyx_client_view_model.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:telnyx_flutter_webrtc/utils/theme.dart';
import 'package:telnyx_common/telnyx_common.dart' as telnyx;

import 'package:telnyx_flutter_webrtc/firebase_options.dart';

final logger = Logger();
final txClientViewModel = TelnyxClientViewModel();

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

      // Initialize Firebase first - telnyx_common will handle the rest
      try {
        await Firebase.initializeApp(
          options: kIsWeb ? DefaultFirebaseOptions.currentPlatform : null,
        );
        logger.i('[AppInitializer] Firebase Core Initialized successfully.');
      } catch (e) {
        logger.e('[AppInitializer] Firebase Core Initialization failed: $e');
      }

      // telnyx_common handles push notification setup automatically
      logger.i(
          '[AppInitializer] Push notification setup handled by telnyx_common');
    } else {
      logger.i('[AppInitializer] Already initialized.');
    }
  }
}

// Simplified background message handler using telnyx_common
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  logger.i(
    '[Background Notification]. Received background message: ${message.data}',
  );

  // Initialize Firebase for the background isolate
  try {
    await Firebase.initializeApp(
      options: kIsWeb ? DefaultFirebaseOptions.currentPlatform : null,
    );
  } catch (e) {
    logger.e('[Background Handler] Firebase initialization failed: $e');
    return;
  }

  // Use telnyx_common to handle push notifications automatically
  // The TelnyxVoipClient in the view model will handle the push notification processing
  await handlePush(message.data);
}

@pragma('vm:entry-point')
Future<void> main() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();


      if (!AppInitializer()._isInitialized) {
        await AppInitializer().initialize();
      }

      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
      runApp(
        telnyx.TelnyxVoiceApp(
          voipClient: txClientViewModel.telnyxVoipClient,
          onPushNotificationProcessingStarted: () {
            logger.i('[TelnyxVoiceApp] Push notification processing started');
          },
          onPushNotificationProcessingCompleted: () {
            logger.i('[TelnyxVoiceApp] Push notification processing completed');
          },
          child: ChangeNotifierProvider<TelnyxClientViewModel>.value(
            value: txClientViewModel,
            child: const MyApp(),
          ),
        ),
      );
    },
    (error, stack) {
      logger.e('Caught Zoned error: $error', stackTrace: stack);
    },
  );
}

Future<void> handlePush(Map<dynamic, dynamic> data) async {
  logger.i('[handlePush] Started. Raw data: $data');
  txClientViewModel.setPushCallStatus(true);

  // Simplified push handling using telnyx_common
  try {
    // Convert data to Map<String, dynamic> for telnyx_common
    final pushData = Map<String, dynamic>.from(data);

    // telnyx_common handles push notification processing automatically
    await txClientViewModel.handlePushNotification(pushData);

    logger.i('[handlePush] Processing complete using telnyx_common');
  } catch (e) {
    logger.e('[handlePush] Error processing push notification: $e');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
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
        routes: {'/': (context) => const HomeScreen()},
      ),
    );
  }
}
