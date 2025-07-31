import 'dart:async';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import 'package:telnyx_common/src/utils.dart';

/// Callback function types for CallKit events.
typedef CallKitEventCallback = void Function(String callId);

/// Internal adapter component that encapsulates all interactions with flutter_callkit_incoming.
///
/// This class isolates the core logic from the third-party CallKit dependency,
/// making the system more resilient to external changes and easier to test.
/// It handles both incoming and outgoing call UI through the native call interface.
class CallKitAdapter {
  final CallKitEventCallback onCallAccepted;
  final CallKitEventCallback onCallDeclined;
  final CallKitEventCallback onCallEnded;

  StreamSubscription<CallEvent?>? _callEventSubscription;
  bool _disposed = false;

  /// Creates a new CallKitAdapter instance.
  CallKitAdapter({
    required this.onCallAccepted,
    required this.onCallDeclined,
    required this.onCallEnded,
  });

  /// Initializes the CallKit adapter and sets up event listeners.
  Future<void> initialize() async {
    if (_disposed) return;

    // Listen for CallKit events
    _callEventSubscription =
        FlutterCallkitIncoming.onEvent.listen(_handleCallEvent);
  }

  /// Shows the native incoming call UI.
  Future<void> showIncomingCall({
    required String callId,
    required String callerName,
    required String callerNumber,
    Map<String, dynamic> extra = const {},
  }) async {
    if (_disposed) return;

    try {
      final callKitParams = _createCallKitParams(
        id: callId,
        nameCaller: callerName,
        handle: callerNumber,
        extra: extra,
      );

      BackgroundDetector.ignore =
          true; // Ignore lifecycle events during call UI display
      await FlutterCallkitIncoming.showCallkitIncoming(callKitParams);
    } catch (error) {
      // Log error but don't throw to avoid breaking the call flow
      print('CallKitAdapter: Error showing incoming call: $error');
    }
  }

  /// Starts the native outgoing call UI.
  Future<void> startOutgoingCall({
    required String callId,
    required String destination,
    String? callerName,
    Map<String, dynamic> extra = const {},
  }) async {
    if (_disposed) return;

    try {
      final callKitParams = _createCallKitParams(
        id: callId,
        nameCaller: callerName ?? 'Outgoing Call',
        handle: destination,
        extra: extra,
      );

      await FlutterCallkitIncoming.startCall(callKitParams);
    } catch (error) {
      // Log error but don't throw to avoid breaking the call flow
      print('CallKitAdapter: Error starting outgoing call: $error');
    }
  }

  /// Ends a call in the native UI.
  Future<void> endCall(String callId) async {
    if (_disposed) return;

    try {
      await FlutterCallkitIncoming.endCall(callId);
    } catch (error) {
      // Log error but don't throw
      print('CallKitAdapter: Error ending call: $error');
    }
  }

  /// Sets a call as connected in the native UI (iOS only).
  Future<void> setCallConnected(String callId) async {
    if (_disposed) return;

    try {
      await FlutterCallkitIncoming.setCallConnected(callId);
    } catch (error) {
      // Log error but don't throw
      print('CallKitAdapter: Error setting call connected: $error');
    }
  }

  /// Hides the incoming call UI (Android only).
  Future<void> hideIncomingCall(
      String callId, String callerName, String callerNumber) async {
    if (_disposed) return;

    try {
      final callKitParams = _createCallKitParams(
        id: callId,
        nameCaller: callerName,
        handle: callerNumber,
      );

      await FlutterCallkitIncoming.hideCallkitIncoming(callKitParams);
    } catch (error) {
      // Log error but don't throw
      print('CallKitAdapter: Error hiding incoming call: $error');
    }
  }

  /// Gets the list of active calls from CallKit.
  Future<List<Map<String, dynamic>>> getActiveCalls() async {
    if (_disposed) return [];

    try {
      return await FlutterCallkitIncoming.activeCalls();
    } catch (error) {
      print('CallKitAdapter: Error getting active calls: $error');
      return [];
    }
  }

  /// Handles CallKit events and routes them to the appropriate callbacks.
  void _handleCallEvent(CallEvent? event) {
    if (_disposed || event == null) return;

    final callId = event.body['id'] as String?;
    if (callId == null) return;

    // [PUSH-DIAG] Log raw event data
    print('[PUSH-DIAG] CallKitAdapter: Event=${event.event}, callId=$callId');
    print('[PUSH-DIAG] CallKitAdapter: event.body=${event.body}');
    print(
        '[PUSH-DIAG] CallKitAdapter: event.body.runtimeType=${event.body.runtimeType}');

    // Check if event.body contains 'extra' field
    if (event.body.containsKey('extra')) {
      print(
          '[PUSH-DIAG] CallKitAdapter: event.body[extra]=${event.body['extra']}');
      print(
          '[PUSH-DIAG] CallKitAdapter: event.body[extra].runtimeType=${event.body['extra'].runtimeType}');
    } else {
      print('[PUSH-DIAG] CallKitAdapter: No "extra" field in event.body');
    }

    switch (event.event) {
      case Event.actionCallAccept:
        onCallAccepted(callId);
        break;
      case Event.actionCallDecline:
        onCallDeclined(callId);
        break;
      case Event.actionCallEnded:
        onCallEnded(callId);
        break;
      case Event.actionCallTimeout:
        onCallDeclined(callId); // Treat timeout as decline
        break;
      default:
        // Handle other events as needed
        break;
    }
  }

  /// Creates standard CallKitParams for consistent UI across the app.
  CallKitParams _createCallKitParams({
    required String id,
    required String nameCaller,
    required String handle,
    Map<String, dynamic> extra = const {},
    int duration = 30000,
    String textAccept = 'Accept',
    String textDecline = 'Decline',
    String appName = 'Telnyx Flutter Voice',
    int type = 0, // 0 for audio call
  }) {
    return CallKitParams(
      id: id,
      nameCaller: nameCaller,
      appName: appName,
      handle: handle,
      type: type,
      textAccept: textAccept,
      textDecline: textDecline,
      duration: duration,
      extra: extra,
      headers: <String, dynamic>{'platform': 'flutter'},
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#0955fa',
        actionColor: '#4CAF50',
        textColor: '#ffffff',
        incomingCallNotificationChannelName: 'Incoming Call',
        missedCallNotificationChannelName: 'Missed Call',
      ),
      ios: const IOSParams(
        iconName: 'CallKitLogo',
        handleType: 'generic',
        supportsVideo: false,
        maximumCallGroups: 2,
        maximumCallsPerCallGroup: 1,
        audioSessionMode: 'default',
        audioSessionActive: true,
        audioSessionPreferredSampleRate: 44100.0,
        audioSessionPreferredIOBufferDuration: 0.005,
        supportsDTMF: true,
        supportsHolding: true,
        supportsGrouping: false,
        supportsUngrouping: false,
        ringtonePath: 'system_ringtone_default',
      ),
    );
  }

  /// Disposes of the CallKit adapter and cleans up resources.
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    if (_callEventSubscription != null) {
      _callEventSubscription!.cancel();
    }
  }
}
