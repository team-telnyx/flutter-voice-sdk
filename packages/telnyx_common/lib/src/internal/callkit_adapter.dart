import 'dart:async';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import '../models/call.dart';
import '../models/call_state.dart';

/// Internal adapter for managing native call UI through flutter_callkit_incoming.
///
/// This component encapsulates all interactions with the flutter_callkit_incoming
/// package, providing a clean interface for the CallStateController to manage
/// native call UI without being directly coupled to the third-party package.
class CallKitAdapter {
  /// Callback for when a call is accepted from the native UI.
  late final Function(String callId) onCallAccepted;
  
  /// Callback for when a call is declined from the native UI.
  late final Function(String callId) onCallDeclined;
  
  /// Callback for when a call is ended from the native UI.
  late final Function(String callId) onCallEnded;
  
  /// Whether the adapter has been initialized.
  bool _initialized = false;
  
  /// Whether the adapter has been disposed.
  bool _disposed = false;
  
  /// Stream subscription for CallKit events.
  StreamSubscription? _callKitEventSubscription;
  
  CallKitAdapter({
    required Function(String callId) onCallAccepted,
    required Function(String callId) onCallDeclined,
    required Function(String callId) onCallEnded,
  }) {
    this.onCallAccepted = onCallAccepted;
    this.onCallDeclined = onCallDeclined;
    this.onCallEnded = onCallEnded;
  }
  
  /// Initializes the CallKit adapter.
  Future<void> initialize() async {
    if (_initialized || _disposed) return;
    
    try {
      // Listen for CallKit events
      _callKitEventSubscription = FlutterCallkitIncoming.onEvent.listen(_handleCallKitEvent);
      
      _initialized = true;
    } catch (error) {
      throw Exception('Failed to initialize CallKit adapter: $error');
    }
  }
  
  /// Shows an incoming call UI.
  Future<void> showIncomingCall({
    required String callId,
    required String callerName,
    required String callerNumber,
    String? avatar,
  }) async {
    if (!_initialized || _disposed) return;
    
    try {
      final callKitParams = CallKitParams(
        id: callId,
        nameCaller: callerName,
        appName: 'Telnyx',
        avatar: avatar,
        handle: callerNumber,
        type: 0, // Audio call
        textAccept: 'Accept',
        textDecline: 'Decline',
        missedCallNotification: const NotificationParams(
          showNotification: true,
          isShowCallback: true,
          subtitle: 'Missed call',
          callbackText: 'Call back',
        ),
        duration: 30000, // 30 seconds
        extra: <String, dynamic>{'callId': callId},
        headers: <String, dynamic>{'platform': 'flutter'},
        android: const AndroidParams(
          isCustomNotification: true,
          isShowLogo: false,
          ringtonePath: 'system_ringtone_default',
          backgroundColor: '#0955fa',
          backgroundUrl: '',
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
      
      await FlutterCallkitIncoming.showCallkitIncoming(callKitParams);
    } catch (error) {
      throw Exception('Failed to show incoming call: $error');
    }
  }
  
  /// Starts an outgoing call UI.
  Future<void> startOutgoingCall({
    required String callId,
    required String destination,
    String? callerName,
  }) async {
    if (!_initialized || _disposed) return;
    
    try {
      final callKitParams = CallKitParams(
        id: callId,
        nameCaller: callerName ?? destination,
        appName: 'Telnyx',
        handle: destination,
        type: 0, // Audio call
        extra: <String, dynamic>{'callId': callId},
        headers: <String, dynamic>{'platform': 'flutter'},
        android: const AndroidParams(
          isCustomNotification: true,
          isShowLogo: false,
          backgroundColor: '#0955fa',
          actionColor: '#4CAF50',
          textColor: '#ffffff',
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
        ),
      );
      
      await FlutterCallkitIncoming.startCall(callKitParams);
    } catch (error) {
      throw Exception('Failed to start outgoing call: $error');
    }
  }
  
  /// Ends a call in the native UI.
  Future<void> endCall(String callId) async {
    if (!_initialized || _disposed) return;
    
    try {
      await FlutterCallkitIncoming.endCall(callId);
    } catch (error) {
      // Log error but don't throw, as the call might already be ended
    }
  }
  
  /// Ends all calls in the native UI.
  Future<void> endAllCalls() async {
    if (!_initialized || _disposed) return;
    
    try {
      await FlutterCallkitIncoming.endAllCalls();
    } catch (error) {
      // Log error but don't throw
    }
  }
  
  /// Updates the call state in the native UI.
  Future<void> updateCallState(String callId, CallState state) async {
    if (!_initialized || _disposed) return;
    
    try {
      switch (state) {
        case CallState.active:
          // Call is now active, no specific action needed for CallKit
          break;
        case CallState.held:
          // Update hold state if supported
          break;
        case CallState.ended:
        case CallState.error:
          await endCall(callId);
          break;
        default:
          // No action needed for other states
          break;
      }
    } catch (error) {
      // Log error but don't throw
    }
  }
  
  /// Handles CallKit events.
  void _handleCallKitEvent(CallKitEvent event) {
    if (_disposed) return;
    
    final callId = event.body['id'] as String?;
    if (callId == null) return;
    
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
  
  /// Disposes of the adapter and cleans up resources.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    
    _callKitEventSubscription?.cancel();
    _callKitEventSubscription = null;
    
    // End all calls when disposing
    endAllCalls();
  }
}