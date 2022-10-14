import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:telnyx_flutter_webrtc/model/push_notification.dart';

class AndroidNotificationService {
  static final FlutterLocalNotificationsPlugin
      _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel', // id
    'High Importance Notifications', // title
    importance: Importance.max,
  );

  static Future initialize() async {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    AndroidInitializationSettings androidInitializationSettings =
        const AndroidInitializationSettings('@mipmap/ic_launcher');

    InitializationSettings initializationSettings =
        InitializationSettings(android: androidInitializationSettings);

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      // onSelectNotification: doSomething(),
    );
  }

  static Future showNotification(RemoteMessage message) async {
    AndroidNotificationDetails androidDetails =
        const AndroidNotificationDetails(
      "default_notification_channel_id",
      "channel",
      enableLights: true,
      enableVibration: true,
      priority: Priority.high,
      importance: Importance.max,
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: MediaStyleInformation(
        htmlFormatContent: true,
        htmlFormatTitle: true,
      ),
      playSound: true,
    );

    var metadata = Metadata.fromJson(jsonDecode(message.data["metadata"]));
    var received = message.data["message"];

    await _flutterLocalNotificationsPlugin.show(
        message.data.hashCode,
        received,
        metadata.caller_name,
        NotificationDetails(
          android: androidDetails,
        ));
  }
}
