import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

final _logger = Logger();

/// Abstract class defining the contract for platform-specific push notification handling.
abstract class PushNotificationHandler {
  /// Initializes platform-specific push notification listeners and setup.
  /// This is typically called once during app initialization.
  Future<void> initialize();

  /// Processes an incoming call-related push notification payload.
  ///
  /// This method is intended to be called when a push notification's content
  /// indicates an incoming call that requires action (e.g., user accepts or declines
  /// from a notification or CallKit UI).
  ///
  /// [payload] The raw payload data from the push notification (e.g., FCM data, CallKit extras).
  /// [isAnswer] True if the user's action implies answering the call.
  /// [isDecline] True if the user's action implies declining the call.
  Future<void> processIncomingCallAction(Map<dynamic, dynamic> payload, {bool isAnswer = false, bool isDecline = false});

  /// (iOS specific) Displays the native incoming call UI (CallKit).
  /// For other platforms, this might be a no-op or log a message.
  ///
  /// [payload] The data needed to display the call, typically including caller name, number, call ID.
  Future<void> displayIncomingCallUi(Map<dynamic, dynamic> payload);

  /// Retrieves the platform-specific push token (FCM for Android, VoIP for iOS).
  Future<String?> getPushToken();

  /// (Android specific) Retrieves push data if the app was launched from a terminated state
  /// by a notification tap. Returns null if no such data exists.
  Future<Map<String, dynamic>?> getInitialPushData();

  /// (Android specific) Displays a missed call notification.
  Future<void> showMissedCallNotification(Map<dynamic, dynamic> payload);

  /// Clears any stored push metadata or state.
  /// This is often called on errors or when disconnecting to ensure a clean state.
  void clearPushData();

  /// Checks if Firebase has been initialized for the current platform context.
  /// This is useful to avoid re-initializing Firebase unnecessarily.
  bool isFirebaseInitialized();
}

/// Web implementation of [PushNotificationHandler].
/// Push notifications are typically not handled in the same way on web,
/// so most methods are no-ops or log informational messages.
class WebPushNotificationHandler implements PushNotificationHandler {
  @override
  Future<void> initialize() async {
    if (kDebugMode) {
      _logger.i('[PushNotificationHandler-Web] Initialize: No push notification setup for web.');
    }
  }

  @override
  Future<void> processIncomingCallAction(Map<dynamic, dynamic> payload, {bool isAnswer = false, bool isDecline = false}) async {
    if (kDebugMode) {
      _logger.i('[PushNotificationHandler-Web] processIncomingCallAction: Not applicable for web. Payload: $payload, Answer: $isAnswer, Decline: $isDecline');
    }
  }

  @override
  Future<void> displayIncomingCallUi(Map<dynamic, dynamic> payload) async {
    if (kDebugMode) {
      _logger.i('[PushNotificationHandler-Web] displayIncomingCallUi: Not applicable for web. Payload: $payload');
    }
  }

  @override
  Future<String?> getPushToken() async {
    if (kDebugMode) {
      _logger.i('[PushNotificationHandler-Web] getPushToken: Not applicable for web.');
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>?> getInitialPushData() async {
    if (kDebugMode) {
      _logger.i('[PushNotificationHandler-Web] getInitialPushData: Not applicable for web.');
    }
    return null;
  }

  @override
  Future<void> showMissedCallNotification(Map<dynamic, dynamic> payload) async {
     if (kDebugMode) {
      _logger.i('[PushNotificationHandler-Web] showMissedCallNotification: Not applicable for web. Payload $payload');
    }
  }

  @override
  void clearPushData() {
    if (kDebugMode) {
      _logger.i('[PushNotificationHandler-Web] clearPushData: Not applicable for web.');
    }
  }

  @override
  bool isFirebaseInitialized() {
    // Firebase is typically initialized separately for web if needed.
    // Or, if initialized by a central spot, this could check Firebase.apps.isNotEmpty.
    // For this refactor, assuming web might initialize it via options in main AppInitializer if needed.
    if (kDebugMode) {
      _logger.i('[PushNotificationHandler-Web] isFirebaseInitialized: Returning false (web has specific init if used).');
    }
    return false;
  }
} 