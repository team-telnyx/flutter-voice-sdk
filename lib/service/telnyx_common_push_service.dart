import 'dart:async';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:telnyx_flutter_webrtc/provider/telnyx_common_provider.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';

/// Push notification service that uses telnyx_common for handling push notifications.
/// 
/// This service replaces the legacy push notification handling with a simplified
/// approach using the telnyx_common module.
class TelnyxCommonPushService {
  static final TelnyxCommonPushService _instance = TelnyxCommonPushService._internal();
  static TelnyxCommonPushService get instance => _instance;
  
  final Logger logger = Logger();
  TelnyxCommonProvider? _provider;
  bool _initialized = false;
  
  TelnyxCommonPushService._internal();
  
  /// Initialize the push service with the provider instance
  void initialize(TelnyxCommonProvider provider) {
    if (_initialized) return;
    
    _provider = provider;
    _setupFirebaseListeners();
    _initialized = true;
    logger.i('TelnyxCommonPushService initialized');
  }
  
  void _setupFirebaseListeners() {
    if (kIsWeb) return; // No push notifications on web
    
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      logger.i('Received foreground push notification: ${message.data}');
      _handlePushNotification(message.data, isBackground: false);
    });
    
    // Handle notification taps when app is in background but not terminated
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      logger.i('App opened from background notification: ${message.data}');
      _handlePushNotification(message.data, isBackground: true);
    });
    
    // Check for initial message when app was terminated and opened via notification
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        logger.i('App opened from terminated state via notification: ${message.data}');
        _handlePushNotification(message.data, isBackground: true);
      }
    });
  }
  
  /// Handle push notification using telnyx_common
  Future<void> _handlePushNotification(Map<String, dynamic> data, {bool isBackground = false}) async {
    if (_provider == null) {
      logger.e('TelnyxCommonPushService not initialized with provider');
      return;
    }
    
    try {
      // Set push call status
      _provider!.setPushCallStatus(true);
      
      // Let telnyx_common handle the push notification
      await _provider!.handlePushNotification(data);
      
      logger.i('Push notification handled successfully via telnyx_common');
    } catch (e) {
      logger.e('Failed to handle push notification: $e');
    }
  }
  
  /// Handle background push notification (called from background handler)
  static Future<void> handleBackgroundMessage(RemoteMessage message) async {
    final logger = Logger();
    logger.i('Handling background push notification: ${message.data}');
    
    // For background messages, we need to handle them differently since
    // the provider might not be available. We'll store the data and
    // process it when the app becomes active.
    
    // TODO: Implement background message storage and processing
    // This could involve storing the push data locally and processing
    // it when the app becomes active and the provider is available.
  }
  
  /// Get the current FCM token
  Future<String?> getFCMToken() async {
    if (kIsWeb) return null;
    
    try {
      final token = await FirebaseMessaging.instance.getToken();
      logger.i('FCM Token: $token');
      return token;
    } catch (e) {
      logger.e('Failed to get FCM token: $e');
      return null;
    }
  }
  
  /// Request notification permissions
  Future<bool> requestPermissions() async {
    if (kIsWeb) return true;
    
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      
      final granted = settings.authorizationStatus == AuthorizationStatus.authorized;
      logger.i('Notification permissions granted: $granted');
      return granted;
    } catch (e) {
      logger.e('Failed to request notification permissions: $e');
      return false;
    }
  }
  
  /// Subscribe to FCM topic
  Future<void> subscribeToTopic(String topic) async {
    if (kIsWeb) return;
    
    try {
      await FirebaseMessaging.instance.subscribeToTopic(topic);
      logger.i('Subscribed to topic: $topic');
    } catch (e) {
      logger.e('Failed to subscribe to topic $topic: $e');
    }
  }
  
  /// Unsubscribe from FCM topic
  Future<void> unsubscribeFromTopic(String topic) async {
    if (kIsWeb) return;
    
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
      logger.i('Unsubscribed from topic: $topic');
    } catch (e) {
      logger.e('Failed to unsubscribe from topic $topic: $e');
    }
  }
}