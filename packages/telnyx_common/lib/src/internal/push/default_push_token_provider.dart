import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

import 'push_token_provider.dart';
import 'firebase_push_token_provider.dart';
import 'ios_push_token_provider.dart';

/// Default PushTokenProvider that automatically selects the appropriate
/// platform-specific implementation.
///
/// This provider chooses:
/// - iOS: VoIP Push tokens via PushKit (IosPushTokenProvider)
/// - Android: Firebase Cloud Messaging tokens (FirebasePushTokenProvider)
/// - Other platforms: No-op implementation
class DefaultPushTokenProvider implements PushTokenProvider {
  late final PushTokenProvider _delegate;
  bool _initialized = false;

  /// Creates a default push token provider with automatic platform detection.
  DefaultPushTokenProvider() {
    _initializeDelegate();
  }

  void _initializeDelegate() {
    if (kIsWeb) {
      // Web does not support push tokens in this implementation
      _delegate = _NoOpPushTokenProvider();
      return;
    }
    if (Platform.isIOS) {
      _delegate = IosPushTokenProvider();
    } else if (Platform.isAndroid) {
      _delegate = FirebasePushTokenProvider();
    } else {
      _delegate = _NoOpPushTokenProvider();
    }
    _initialized = true;
  }

  @override
  Future<String?> getToken() async {
    if (!_initialized) return null;
    return await _delegate.getToken();
  }

  @override
  Future<void> setupTokenRefreshListener(
      Function(String) onTokenRefresh) async {
    if (!_initialized) return;
    await _delegate.setupTokenRefreshListener(onTokenRefresh);
  }

  @override
  void dispose() {
    if (!_initialized) return;
    _delegate.dispose();
  }
}

/// No-operation implementation for unsupported platforms.
class _NoOpPushTokenProvider implements PushTokenProvider {
  @override
  Future<String?> getToken() async {
    print('NoOpPushTokenProvider: Push tokens not supported on this platform');
    return null;
  }

  @override
  Future<void> setupTokenRefreshListener(
      Function(String) onTokenRefresh) async {
    print(
        'NoOpPushTokenProvider: Token refresh not supported on this platform');
  }

  @override
  void dispose() {
    print('NoOpPushTokenProvider: Disposed');
  }
}
