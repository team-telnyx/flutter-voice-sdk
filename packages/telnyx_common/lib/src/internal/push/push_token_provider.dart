/// Abstract interface for platform-specific push token management.
///
/// Applications should implement this interface to provide platform-specific
/// token management functionality. The telnyx_common module provides this
/// interface but does not implement it to avoid external dependencies.
///
/// Example implementation:
/// ```dart
/// class MyAndroidTokenProvider implements PushTokenProvider {
///   @override
///   Future<String?> getToken() async {
///     return await FirebaseMessaging.instance.getToken();
///   }
///
///   @override
///   Future<void> setupTokenRefreshListener(Function(String) onTokenRefresh) async {
///     FirebaseMessaging.instance.onTokenRefresh.listen(onTokenRefresh);
///   }
///
///   @override
///   void dispose() {
///     // Clean up listeners
///   }
/// }
/// ```
abstract class PushTokenProvider {
  /// Retrieves the current push token for the platform.
  Future<String?> getToken();

  /// Sets up token refresh listeners if supported by the platform.
  Future<void> setupTokenRefreshListener(Function(String) onTokenRefresh);

  /// Disposes of any resources or listeners.
  void dispose();
}

/// No-op implementation used when no custom token provider is supplied.
class NoOpPushTokenProvider implements PushTokenProvider {
  @override
  Future<String?> getToken() async {
    print('NoOpPushTokenProvider: No token provider configured');
    return null;
  }

  @override
  Future<void> setupTokenRefreshListener(
      Function(String) onTokenRefresh) async {
    print('NoOpPushTokenProvider: No token provider configured');
  }

  @override
  void dispose() {
    // No-op
  }
}
