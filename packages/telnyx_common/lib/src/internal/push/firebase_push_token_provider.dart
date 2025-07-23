import 'dart:async';
import 'dart:io' show Platform;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'push_token_provider.dart';

/// Firebase Cloud Messaging implementation of PushTokenProvider.
///
/// This provider handles FCM token retrieval and refresh events,
/// primarily used for Android push notifications.
class FirebasePushTokenProvider implements PushTokenProvider {
  bool _disposed = false;
  StreamSubscription<String>? _tokenRefreshSubscription;
  Function(String)? _onTokenRefresh;

  @override
  Future<String?> getToken() async {
    if (_disposed) return null;

    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final token = await FirebaseMessaging.instance.getToken();
        print(
            'FirebasePushTokenProvider: Retrieved FCM token: ${token?.substring(0, 20)}...');
        return token;
      } else {
        print('FirebasePushTokenProvider: FCM not supported on this platform');
        return null;
      }
    } catch (e) {
      print('FirebasePushTokenProvider: Error getting FCM token: $e');
      return null;
    }
  }

  @override
  Future<void> setupTokenRefreshListener(
      Function(String) onTokenRefresh) async {
    if (_disposed) return;

    _onTokenRefresh = onTokenRefresh;

    try {
      if (Platform.isAndroid || Platform.isIOS) {
        _tokenRefreshSubscription =
            FirebaseMessaging.instance.onTokenRefresh.listen(
          (String token) {
            print(
                'FirebasePushTokenProvider: FCM token refreshed: ${token.substring(0, 20)}...');
            _onTokenRefresh?.call(token);
          },
          onError: (error) {
            print(
                'FirebasePushTokenProvider: Error in token refresh listener: $error');
          },
        );
        print(
            'FirebasePushTokenProvider: Token refresh listener setup complete');
      } else {
        print(
            'FirebasePushTokenProvider: Token refresh not supported on this platform');
      }
    } catch (e) {
      print(
          'FirebasePushTokenProvider: Error setting up token refresh listener: $e');
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
    _onTokenRefresh = null;

    print('FirebasePushTokenProvider: Disposed');
  }
}
