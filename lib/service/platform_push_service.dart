import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:logger/logger.dart';
import 'package:telnyx_flutter_webrtc/service/push_notification_handler.dart';
import 'package:telnyx_flutter_webrtc/service/android_push_notification_handler.dart';
import 'package:telnyx_flutter_webrtc/service/ios_push_notification_handler.dart';

/// Service locator for providing the appropriate [PushNotificationHandler]
/// based on the current platform.
class PlatformPushService {
  static PushNotificationHandler? _handler;

  /// Gets the singleton instance of the platform-specific [PushNotificationHandler].
  ///
  /// This factory method determines the platform (Android, iOS, Web)
  /// and returns the corresponding handler implementation.
  static PushNotificationHandler get handler {
    _handler ??= _createHandler();
    return _handler!;
  }

  static PushNotificationHandler _createHandler() {
    if (kIsWeb) {
      return WebPushNotificationHandler();
    } else if (Platform.isAndroid) {
      return AndroidPushNotificationHandler();
    } else if (Platform.isIOS) {
      return IOSPushNotificationHandler();
    } else {
      // Fallback for unsupported platforms, defaults to Web/No-op behavior.
      // Consider logging a warning for unsupported platforms.
      Logger().w(
        'Warning: Unsupported platform for push notifications. Using WebPushNotificationHandler.',
      );
      return WebPushNotificationHandler();
    }
  }
}
