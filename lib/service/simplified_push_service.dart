import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:logger/logger.dart';
import 'package:telnyx_flutter_webrtc/view/telnyx_client_view_model_new.dart';

/// Simplified push notification service that integrates with telnyx_common.
/// 
/// This replaces the complex platform-specific push notification handlers
/// with a simple service that delegates to the TelnyxVoipClient's built-in
/// push notification handling.
class SimplifiedPushService {
  static final Logger _logger = Logger();
  static TelnyxClientViewModel? _viewModel;

  /// Initialize the push service with the view model
  static void initialize(TelnyxClientViewModel viewModel) {
    _viewModel = viewModel;
    _setupFirebaseMessaging();
  }

  /// Set up Firebase messaging listeners
  static void _setupFirebaseMessaging() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _logger.i('Received foreground push notification: ${message.data}');
      _handlePushNotification(message.data);
    });

    // Handle background messages (when app is in background but not terminated)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _logger.i('App opened from background push notification: ${message.data}');
      _handlePushNotification(message.data);
    });

    // Check for initial message (when app is opened from terminated state)
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        _logger.i('App opened from terminated state push notification: ${message.data}');
        _handlePushNotification(message.data);
      }
    });
  }

  /// Handle push notification by delegating to TelnyxVoipClient
  static void _handlePushNotification(Map<String, dynamic> data) {
    if (_viewModel != null) {
      _viewModel!.handlePushNotification(data);
    } else {
      _logger.w('Push notification received but view model not initialized');
    }
  }

  /// Get the current FCM token
  static Future<String?> getToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (error) {
      _logger.e('Failed to get FCM token: $error');
      return null;
    }
  }

  /// Request notification permissions
  static Future<bool> requestPermissions() async {
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

      return settings.authorizationStatus == AuthorizationStatus.authorized;
    } catch (error) {
      _logger.e('Failed to request notification permissions: $error');
      return false;
    }
  }
}

/// Background message handler for Firebase
/// This must be a top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  Logger().i('Handling background message: ${message.data}');
  
  // The telnyx_common module will handle the background processing
  // when the app is brought to foreground or started
}