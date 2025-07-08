import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:telnyx_flutter_webrtc/provider/profile_provider.dart';
import 'package:telnyx_flutter_webrtc/utils/background_detector.dart';
import 'package:telnyx_flutter_webrtc/view/screen/home_screen.dart';
import 'package:telnyx_flutter_webrtc/view/telnyx_client_view_model.dart';
import 'package:telnyx_flutter_webrtc/service/simplified_push_service.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:telnyx_flutter_webrtc/utils/theme.dart';
import 'package:telnyx_common/telnyx_common.dart';

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

      // Initialize Firebase first
      try {
        await Firebase.initializeApp(
          options: kIsWeb ? DefaultFirebaseOptions.currentPlatform : null,
        );
        logger.i('[AppInitializer] Firebase Core Initialized successfully.');
      } catch (e) {
        logger.e('[AppInitializer] Firebase Core Initialization failed: $e');
      }

      // Initialize simplified push service
      SimplifiedPushService.initialize(txClientViewModel);
      
      // Request notification permissions
      await SimplifiedPushService.requestPermissions();
      
      logger.i('[AppInitializer] Initialization complete.');
    } else {
      logger.i('[AppInitializer] Already initialized.');
    }
  }
}

// Background message handler for Firebase
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  logger.i('[Background Notification] Received: ${message.data}');
  // The telnyx_common module will handle background processing
  // when the app is brought to foreground
}

@pragma('vm:entry-point')
Future<void> main() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Catch Flutter framework errors
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        logger.e(
          'Caught Flutter error: ${details.exception}',
          stackTrace: details.stack,
        );
      };

      // Catch other platform errors
      PlatformDispatcher.instance.onError = (error, stack) {
        logger.e('Caught Platform error: $error', stackTrace: stack);
        return true;
      };

      // Initialize app
      if (!AppInitializer()._isInitialized) {
        await AppInitializer().initialize();
      }

      // Set background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Get saved config for auto-login
      final config = await _getSavedConfig();

      runApp(
        BackgroundDetector(
          skipWeb: true,
          onLifecycleEvent: (AppLifecycleState state) {
            if (state == AppLifecycleState.resumed) {
              logger.i('[BackgroundDetector] App resumed - attempting auto-login');
              
              // Auto-login if we have saved credentials and not in a push call context
              if (!txClientViewModel.callFromPush && config != null) {
                if (config is CredentialConfig) {
                  txClientViewModel.connectWithCredentials(
                    sipUser: config.sipUser,
                    sipPassword: config.sipPassword,
                    sipCallerIDName: config.sipCallerIDName,
                    sipCallerIDNumber: config.sipCallerIDNumber,
                    notificationToken: config.notificationToken,
                  );
                } else if (config is TokenConfig) {
                  txClientViewModel.connectWithToken(
                    sipToken: config.sipToken,
                    sipCallerIDName: config.sipCallerIDName,
                    sipCallerIDNumber: config.sipCallerIDNumber,
                    notificationToken: config.notificationToken,
                  );
                }
              }
            } else if (state == AppLifecycleState.paused) {
              logger.i('[BackgroundDetector] App paused - disconnecting');
              txClientViewModel.disconnect();
            }
          },
          child: const MyApp(),
        ),
      );
    },
    (error, stack) {
      logger.e('Caught Zoned error: $error', stackTrace: stack);
    },
  );
}

/// Get saved configuration for auto-login
Future<Config?> _getSavedConfig() async {
  try {
    // This is a simplified version - you might want to implement
    // a proper config service similar to the original
    return null; // For now, return null to disable auto-login
  } catch (error) {
    logger.e('Failed to get saved config: $error');
    return null;
  }
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

    // Check for initial message (app opened from terminated state)
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        logger.i('[_MyAppState] App opened from terminated state with message: ${message.data}');
        txClientViewModel.handlePushNotification(message.data);
      }
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
        routes: {'/': (context) => const HomeScreen()},
      ),
    );
  }
}