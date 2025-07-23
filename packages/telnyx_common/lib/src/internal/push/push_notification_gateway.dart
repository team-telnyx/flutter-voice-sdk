import 'dart:convert';
import 'package:telnyx_webrtc/model/push_notification.dart';
import '../callkit/callkit_adapter.dart';

/// Callback function type for processed push notifications.
typedef PushNotificationCallback = void Function(PushMetaData pushMetaData);

/// Internal component that provides a unified entry point for push notification payloads.
///
/// This class parses push notification payloads, extracts Telnyx call metadata,
/// and coordinates with the CallKitAdapter to display the native incoming call UI.
/// It handles both foreground and background push notification scenarios.
class PushNotificationGateway {
  final CallKitAdapter _callKitAdapter;
  final PushNotificationCallback onPushNotificationProcessed;

  bool _disposed = false;

  /// Creates a new PushNotificationGateway instance.
  PushNotificationGateway(
    this._callKitAdapter, {
    required this.onPushNotificationProcessed,
  });

  /// Processes a push notification payload and initiates the incoming call flow.
  ///
  /// This method should be called from the application's push notification handlers
  /// (both foreground and background) to handle incoming call notifications.
  ///
  /// [payload] - The raw push notification payload from FCM/APNS.
  Future<void> handlePushNotification(Map<String, dynamic> payload) async {
    if (_disposed) return;

    try {
      // Parse the push notification metadata
      final pushMetaData = _parsePushMetaData(payload);
      if (pushMetaData == null) {
        print('PushNotificationGateway: Failed to parse push metadata');
        return;
      }

      // Extract call information
      final callId = _extractCallId(payload, pushMetaData);
      if (callId == null || callId.isEmpty) {
        print('PushNotificationGateway: Missing or empty call ID');
        return;
      }

      // Check if this is a missed call notification
      if (_isMissedCallNotification(payload)) {
        print(
            'PushNotificationGateway: Received missed call notification, ignoring');
        await _showMissedCallNotification(callId, pushMetaData, payload);
        return;
      }

      // Check if the notification is stale
      if (_isStaleNotification(payload)) {
        print(
            'PushNotificationGateway: Notification is stale, showing missed call instead');
        await _showMissedCallNotification(callId, pushMetaData, payload);
        return;
      }

      // Show the incoming call UI
      await _callKitAdapter.showIncomingCall(
        callId: callId,
        callerName: pushMetaData.callerName ?? 'Unknown Caller',
        callerNumber: pushMetaData.callerNumber ?? 'Unknown Number',
        extra: payload,
      );

      // Notify that the push notification has been processed
      onPushNotificationProcessed(pushMetaData);

      print(
          'PushNotificationGateway: Successfully processed push notification for call $callId');
    } catch (error) {
      print(
          'PushNotificationGateway: Error processing push notification: $error');
    }
  }

  /// Parses push notification metadata from the payload.
  PushMetaData? _parsePushMetaData(Map<String, dynamic> payload) {
    try {
      final metadataJson = payload['metadata'];
      if (metadataJson == null) return null;

      final Map<String, dynamic> metadataMap;
      if (metadataJson is String) {
        metadataMap = jsonDecode(metadataJson);
      } else if (metadataJson is Map<String, dynamic>) {
        metadataMap = metadataJson;
      } else {
        return null;
      }

      return PushMetaData.fromJson(metadataMap);
    } catch (error) {
      print('PushNotificationGateway: Error parsing push metadata: $error');
      return null;
    }
  }

  /// Extracts the call ID from the push payload and metadata.
  String? _extractCallId(Map<String, dynamic> payload, PushMetaData metadata) {
    print('ZZ metadata: ${metadata.toJson()}');
    // First try to get the call ID from metadata
    String? callId = metadata.callId;

    // If not found, check for X-RTC-CALLID in custom headers
    if (callId == null || callId.isEmpty) {
      try {
        final metadataMap = payload['metadata'];
        final Map<String, dynamic> parsedMetadata;

        if (metadataMap is String) {
          parsedMetadata = jsonDecode(metadataMap);
        } else if (metadataMap is Map<String, dynamic>) {
          parsedMetadata = metadataMap;
        } else {
          return null;
        }

        final dialogParams = parsedMetadata['dialogParams'];
        if (dialogParams != null && dialogParams['custom_headers'] != null) {
          final customHeaders = dialogParams['custom_headers'] as List<dynamic>;
          for (final header in customHeaders) {
            if (header['name'] == 'X-RTC-CALLID') {
              callId = header['value'];
              break;
            }
          }
        }
      } catch (error) {
        print(
            'PushNotificationGateway: Error extracting call ID from headers: $error');
      }
    }

    return callId;
  }

  /// Checks if the push notification is for a missed call.
  bool _isMissedCallNotification(Map<String, dynamic> payload) {
    final message = payload['message'];
    return message != null && message == 'Missed call!';
  }

  /// Checks if the push notification is stale (older than 30 seconds).
  bool _isStaleNotification(Map<String, dynamic> payload) {
    try {
      final sentTimeString = payload['sentTime'];
      if (sentTimeString == null) return false;

      final sentTime = DateTime.parse(sentTimeString);
      final now = DateTime.now();
      final difference = now.difference(sentTime);

      return difference.inSeconds > 30; // 30 seconds timeout
    } catch (error) {
      print(
          'PushNotificationGateway: Error checking notification staleness: $error');
      return false;
    }
  }

  /// Shows a missed call notification instead of an incoming call.
  Future<void> _showMissedCallNotification(
    String callId,
    PushMetaData metadata,
    Map<String, dynamic> payload,
  ) async {
    try {
      // First end any potentially active incoming call UI
      await _callKitAdapter.endCall(callId);

      // Note: Showing missed call notification would require additional
      // CallKit functionality that's not implemented in this basic version.
      // This is a placeholder for the full implementation.
      print(
          'PushNotificationGateway: Would show missed call notification for $callId');
    } catch (error) {
      print(
          'PushNotificationGateway: Error showing missed call notification: $error');
    }
  }

  /// Disposes of the push notification gateway.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
  }
}
