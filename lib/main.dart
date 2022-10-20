import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:telnyx_flutter_webrtc/main_view_model.dart';
import 'package:telnyx_flutter_webrtc/service/notification_service.dart';
import 'package:telnyx_flutter_webrtc/view/screen/call_screen.dart';
import 'package:telnyx_flutter_webrtc/view/screen/home_screen.dart';
import 'package:telnyx_flutter_webrtc/view/screen/login_screen.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

final logger = Logger();

// Android Only - Push Notifications
Future _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling a background message ${message.messageId}');
  print('Notification Message: ${message.data}');
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
        NotificationService.showNotification(message);
      });
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        NotificationService.showNotification(message);
      });
    }
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: MainViewModel()),
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
