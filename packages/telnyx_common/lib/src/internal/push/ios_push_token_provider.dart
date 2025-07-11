import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'push_token_provider.dart';

/// iOS VoIP Push Token implementation of PushTokenProvider.
///
/// This provider handles Apple VoIP push token retrieval and refresh events
/// using PushKit, specifically for iOS platform push notifications.
/// It does NOT use Firebase - only Apple's native VoIP push system.
class IosPushTokenProvider implements PushTokenProvider {
  bool _disposed = false;
  Function(String)? _onTokenRefresh;

  @override
  Future<String?> getToken() async {
    if (_disposed) return null;

    try {
      if (Platform.isIOS) {
        final token = await FlutterCallkitIncoming.getDevicePushTokenVoIP();
        print(
            'IosPushTokenProvider: Retrieved VoIP token: ${token?.substring(0, 20)}...');
        return token;
      } else {
        print(
            'IosPushTokenProvider: VoIP tokens only supported on iOS platform');
        return null;
      }
    } catch (e) {
      print('IosPushTokenProvider: Error getting VoIP token: $e');
      return null;
    }
  }

  @override
  Future<void> setupTokenRefreshListener(
      Function(String) onTokenRefresh) async {
    if (_disposed) return;

    _onTokenRefresh = onTokenRefresh;

    try {
      if (Platform.isIOS) {
        // Note: VoIP token refresh is typically handled at the native level
        // in AppDelegate.swift via PKPushRegistryDelegate.didUpdate
        // The token refresh events would need to be bridged through platform channels
        // if real-time refresh detection is needed in Flutter.
        //
        // For now, we set up the callback but actual token refresh detection
        // would require additional native iOS implementation.
        print(
            'IosPushTokenProvider: VoIP token refresh listener setup complete');
        print(
            'IosPushTokenProvider: Note - VoIP token refresh primarily handled in AppDelegate.swift');
      } else {
        print(
            'IosPushTokenProvider: Token refresh not supported on this platform');
      }
    } catch (e) {
      print(
          'IosPushTokenProvider: Error setting up token refresh listener: $e');
    }
  }

  /// Manually trigger token refresh callback.
  ///
  /// This method can be called from native iOS code via platform channels
  /// when the VoIP token is updated in AppDelegate.swift
  void notifyTokenRefresh(String newToken) {
    if (_disposed) return;

    print(
        'IosPushTokenProvider: VoIP token refreshed: ${newToken.substring(0, 20)}...');
    _onTokenRefresh?.call(newToken);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    _onTokenRefresh = null;

    print('IosPushTokenProvider: Disposed');
  }
}
