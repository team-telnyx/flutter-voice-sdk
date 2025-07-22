import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:telnyx_flutter_webrtc/provider/profile_provider.dart';
import 'package:telnyx_flutter_webrtc/view/screen/home_screen.dart';
import 'package:telnyx_flutter_webrtc/view/telnyx_client_view_model.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:telnyx_flutter_webrtc/utils/theme.dart';
import 'package:telnyx_common/telnyx_common.dart' as telnyx;

final logger = Logger();
final txClientViewModel = TelnyxClientViewModel();

// Simplified background message handler using TelnyxVoiceApp
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  logger.i(
    '[Background Notification]. Received background message: ${message.data}',
  );

  // TelnyxVoiceApp handles all Firebase initialization and push processing automatically
  await telnyx.TelnyxVoiceApp.handleBackgroundPush(message);
}

@pragma('vm:entry-point')
Future<void> main() async {
  await runZonedGuarded(
        () async {
      // Ensure Flutter binding is initialized
      WidgetsFlutterBinding.ensureInitialized();

      // Use TelnyxVoiceApp's factory method for automatic SDK setup
      // This handles Firebase initialization, background handlers, and all setup
      runApp(
        await telnyx.TelnyxVoiceApp.initializeAndCreate(
          voipClient: txClientViewModel.telnyxVoipClient,
          backgroundMessageHandler: _firebaseMessagingBackgroundHandler,
          onPushNotificationProcessingStarted: () {
            logger.i('[TelnyxVoiceApp] Push notification processing started');
          },
          onPushNotificationProcessingCompleted: () {
            logger.i('[TelnyxVoiceApp] Push notification processing completed');
            // The connecting state will be cleared by the activeCall stream listener
          },
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: txClientViewModel),
              ChangeNotifierProvider(create: (context) => ProfileProvider()),
            ],
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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Telnyx WebRTC',
      theme: AppTheme.lightTheme,
      initialRoute: '/',
      routes: {'/': (context) => const HomeScreen()},
    );
  }
}