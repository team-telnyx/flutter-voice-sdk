import 'dart:convert';
import 'package:telnyx_webrtc/model/push_notification.dart';
import 'callkit_adapter.dart';

/// Internal component for processing push notification payloads.
///
/// This gateway provides a unified entry point for push notification handling,
/// parsing Telnyx call metadata and coordinating with the CallKitAdapter to
/// display native incoming call UI.
class PushNotificationGateway {
  /// The CallKit adapter for displaying native UI.
  final CallKitAdapter _callKitAdapter;
  
  /// Callback for when a push notification is processed.
  late final Function(PushMetaData pushMetaData) onPushNotificationProcessed;
  
  PushNotificationGateway(
    this._callKitAdapter, {
    required Function(PushMetaData pushMetaData) onPushNotificationProcessed,
  }) {
    this.onPushNotificationProcessed = onPushNotificationProcessed;
  }
  
  /// Processes a push notification payload.
  ///
  /// This method parses the raw push payload, extracts Telnyx call metadata,
  /// and triggers the appropriate actions (showing incoming call UI, etc.).
  Future<void> handlePushNotification(Map<String, dynamic> payload) async {
    try {
      // Parse the push notification payload
      final pushMetaData = _parsePushPayload(payload);
      if (pushMetaData == null) {
        throw Exception('Invalid push notification payload');
      }
      
      // Extract call information
      final callId = pushMetaData.callId;
      final callerName = pushMetaData.callerName ?? 'Unknown';
      final callerNumber = pushMetaData.callerNumber ?? 'Unknown';
      
      // Show incoming call UI
      await _callKitAdapter.showIncomingCall(
        callId: callId,
        callerName: callerName,
        callerNumber: callerNumber,
      );
      
      // Notify that push notification has been processed
      onPushNotificationProcessed(pushMetaData);
      
    } catch (error) {
      throw Exception('Failed to handle push notification: $error');
    }
  }
  
  /// Parses a push notification payload into PushMetaData.
  PushMetaData? _parsePushPayload(Map<String, dynamic> payload) {
    try {
      // Handle different payload structures based on platform
      Map<String, dynamic> data;
      
      if (payload.containsKey('data')) {
        // Android FCM format
        data = payload['data'] as Map<String, dynamic>;
      } else if (payload.containsKey('aps')) {
        // iOS APNS format
        final aps = payload['aps'] as Map<String, dynamic>;
        data = payload;
        
        // Extract custom data from APNS payload
        if (aps.containsKey('alert')) {
          final alert = aps['alert'];
          if (alert is Map<String, dynamic>) {
            data.addAll(alert);
          }
        }
      } else {
        // Direct data format
        data = payload;
      }
      
      // Extract Telnyx-specific fields
      final callId = data['call_id'] as String?;
      final callerName = data['caller_name'] as String?;
      final callerNumber = data['caller_number'] as String?;
      final callerIdName = data['caller_id_name'] as String?;
      final callerIdNumber = data['caller_id_number'] as String?;
      
      if (callId == null) {
        return null;
      }
      
      // Create PushMetaData object
      return PushMetaData(
        callId: callId,
        callerName: callerName ?? callerIdName,
        callerNumber: callerNumber ?? callerIdNumber,
        metadata: data,
      );
      
    } catch (error) {
      return null;
    }
  }
  
  /// Validates if a payload is a valid Telnyx push notification.
  bool isValidTelnyxPush(Map<String, dynamic> payload) {
    final pushMetaData = _parsePushPayload(payload);
    return pushMetaData != null;
  }
  
  /// Extracts call ID from a push payload without full parsing.
  String? extractCallId(Map<String, dynamic> payload) {
    try {
      // Try different payload structures
      if (payload.containsKey('data')) {
        final data = payload['data'] as Map<String, dynamic>;
        return data['call_id'] as String?;
      } else if (payload.containsKey('call_id')) {
        return payload['call_id'] as String?;
      }
      return null;
    } catch (error) {
      return null;
    }
  }
}