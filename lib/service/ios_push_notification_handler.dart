import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:logger/logger.dart';
import 'package:telnyx_flutter_webrtc/main.dart'; // For logger, txClientViewModel, handlePush
import 'package:telnyx_flutter_webrtc/service/push_notification_handler.dart';
import 'package:telnyx_webrtc/telnyx_client.dart';
import 'package:telnyx_webrtc/model/push_notification.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';
import 'package:telnyx_webrtc/model/telnyx_message.dart';
import 'package:telnyx_webrtc/model/socket_method.dart';
import 'package:telnyx_webrtc/model/telnyx_socket_error.dart';
import 'package:firebase_core/firebase_core.dart';

/// iOS specific implementation of [PushNotificationHandler].
class IOSPushNotificationHandler implements PushNotificationHandler {
  final _logger = Logger();

  @override
  Future<void> initialize() async {
    _logger.i('[PushNotificationHandler-iOS] Initialize');
    // Native AppDelegate.swift handles showing CallKit UI initially.
    // This listener handles events coming from CallKit interactions.
    FlutterCallkitIncoming.onEvent.listen((CallEvent? event) async {
      _logger.i('[PushNotificationHandler-iOS] onEvent: ${event?.event} :: ${event?.body}');
      switch (event!.event) {
        case Event.actionCallIncoming:
          // This event means CallKit UI is shown. Metadata is from AppDelegate.
          if (event.body['extra']?['metadata'] == null) {
            _logger.i('[PushNotificationHandler-iOS] actionCallIncoming: Push Data is null!');
            return;
          }
          _logger.i(
            "[PushNotificationHandler-iOS] actionCallIncoming: Received from CallKit. Metadata: ${event.body['extra']['metadata']}",
          );
          break;

        case Event.actionCallAccept:
          _logger.i('[PushNotificationHandler-iOS] actionCallAccept: Received. Metadata: ${event.body?['extra']?['metadata']}');
          if (txClientViewModel.incomingInvitation != null) {
            _logger.i('[PushNotificationHandler-iOS] actionCallAccept: ViewModel has existing incomingInvitation. Accepting directly.');
            await txClientViewModel.accept();
          } else {
            final metadata = event.body['extra']?['metadata'];
            if (metadata == null) {
              _logger.i('[PushNotificationHandler-iOS] actionCallAccept: Metadata missing. Accepting without push context.');
              await txClientViewModel.accept();
            } else {
              _logger.i('[PushNotificationHandler-iOS] actionCallAccept: Metadata present. Calling processIncomingCallAction. Metadata: $metadata');
              var decodedMetadata = metadata;
              if (metadata is String) {
                try {
                  decodedMetadata = jsonDecode(metadata);
                } catch (e) {
                  _logger.e('[PushNotificationHandler-iOS] actionCallAccept: Error decoding metadata JSON: $e. Attempting direct accept.');
                  await txClientViewModel.accept(); // Fallback
                  return;
                }
              }
              await processIncomingCallAction(decodedMetadata as Map<dynamic, dynamic>, isAnswer: true);
            }
          }
          break;

        case Event.actionCallDecline:
          _logger.i('[PushNotificationHandler-iOS] actionCallDecline: Received. Metadata: ${event.body?['extra']?['metadata']}');
          final metadata = event.body['extra']?['metadata'];
          if (txClientViewModel.incomingInvitation != null || txClientViewModel.currentCall != null) {
            _logger.i('[PushNotificationHandler-iOS] actionCallDecline: Main client has existing call/invite. Using txClientViewModel.endCall().');
            txClientViewModel.endCall();
          } else if (metadata == null) {
            _logger.i('[PushNotificationHandler-iOS] actionCallDecline: No metadata and no active call/invite in ViewModel.');
          } else {
            _logger.i('[PushNotificationHandler-iOS] actionCallDecline: Metadata present. Using temporary client for decline. Metadata: $metadata');
            var decodedMetadata = metadata;
            if (metadata is String) {
              try {
                decodedMetadata = jsonDecode(metadata);
              } catch (e) {
                _logger.e('[PushNotificationHandler-iOS] actionCallDecline: Error decoding metadata JSON: $e.');
                return;
              }
            }
            // Using temporary client logic as established
            final Map<dynamic, dynamic> eventData = Map<dynamic, dynamic>.from(decodedMetadata as Map);
            final PushMetaData pushMetaData = PushMetaData.fromJson(eventData)..isDecline = true;
            final tempDeclineClient = TelnyxClient();
            tempDeclineClient..onSocketMessageReceived = (TelnyxMessage msg) {
              if (msg.socketMethod == SocketMethod.bye) {
                _logger.i('[PushNotificationHandler-iOS] actionCallDecline: Temp client received BYE, disconnecting.');
                tempDeclineClient.disconnect();
              }
            }
            ..onSocketErrorReceived = (TelnyxSocketError error) {
                _logger.e('[PushNotificationHandler-iOS] actionCallDecline: Temp client error: ${error.errorMessage}');
                tempDeclineClient.disconnect();
            };
            final config = await txClientViewModel.getConfig();
            _logger.i('[PushNotificationHandler-iOS] actionCallDecline: Temp client attempting to handlePushNotification. Config :: $config');
            tempDeclineClient.handlePushNotification(
              pushMetaData,
              config is CredentialConfig ? config : null,
              config is TokenConfig ? config : null,
            );
          }
          break;

        case Event.actionCallEnded:
          _logger.i('[PushNotificationHandler-iOS] actionCallEnded: Call ended event from CallKit.');
          txClientViewModel.endCall();
          break;

        case Event.actionCallTimeout:
          _logger.i('[PushNotificationHandler-iOS] actionCallTimeout: Call timeout event from CallKit.');
          txClientViewModel.endCall();
          break;
        default:
          _logger.i('[PushNotificationHandler-iOS] Unhandled CallKit event: ${event.event}');
          break;
      }
    });
  }

  @override
  Future<void> processIncomingCallAction(Map<dynamic, dynamic> payload, {bool isAnswer = false, bool isDecline = false}) async {
    _logger.i('[PushNotificationHandler-iOS] processIncomingCallAction. Payload: $payload, Answer: $isAnswer, Decline: $isDecline');
    final Map<dynamic, dynamic> mutablePayload = Map.from(payload);
    if (isAnswer) mutablePayload['isAnswer'] = true;
    if (isDecline) mutablePayload['isDecline'] = true;
    // This will call the global handlePush which then calls txClientViewModel.handlePushNotification
    await handlePush(mutablePayload);
  }

  @override
  Future<void> displayIncomingCallUi(Map<dynamic, dynamic> payload) async {
    _logger.i('[PushNotificationHandler-iOS] displayIncomingCallUi: Primarily handled by native AppDelegate.swift. Payload: $payload');
  }

  @override
  Future<String?> getPushToken() async {
    _logger.i('[PushNotificationHandler-iOS] getPushToken');
    if (Platform.isIOS) {
      return await FlutterCallkitIncoming.getDevicePushTokenVoIP();
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>?> getInitialPushData() async {
    _logger.i('[PushNotificationHandler-iOS] getInitialPushData: Not typically used in the same way as Android. CallKit events drive the flow.');
    // iOS flow is primarily driven by CallKit events after app launch.
    // No direct equivalent to FCM's getInitialMessage for VoIP pushes in this context.
    return null;
  }

  @override
  Future<void> showMissedCallNotification(Map<dynamic, dynamic> payload) async {
    _logger.i('[PushNotificationHandler-iOS] showMissedCallNotification: Not implemented for iOS in this handler. Relies on CallKits native missed call handling. Payload: $payload');
    // iOS CallKit handles its own missed call notifications/badges typically.
  }

  @override
  void clearPushData() {
    _logger.i('[PushNotificationHandler-iOS] clearPushData');
    TelnyxClient.clearPushMetaData(); // Uses the static TelnyxClient method
  }

  @override
  bool isFirebaseInitialized() {
    // iOS part of this app does not directly use Firebase for VoIP push notifications (it uses CallKit/PushKit).
    // Firebase might be used for other purposes, but from this handler's perspective for push,
    // it doesn't manage Firebase initialization itself in the same way Android FCM flow does.
    // If Firebase is initialized globally (e.g. for Analytics), checking Firebase.apps.isNotEmpty could be valid.
    final bool initialized = Firebase.apps.isNotEmpty; // Check if any app is initialized
    _logger.i('[PushNotificationHandler-iOS] isFirebaseInitialized: Returning $initialized');
    return initialized;
  }
} 