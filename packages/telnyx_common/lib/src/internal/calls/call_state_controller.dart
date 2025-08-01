import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, VoidCallback;
import 'package:telnyx_webrtc/telnyx_client.dart';
import 'package:telnyx_webrtc/call.dart' as telnyx_call;
import 'package:telnyx_webrtc/model/telnyx_message.dart';
import 'package:telnyx_webrtc/model/socket_method.dart';
import 'package:telnyx_webrtc/model/call_state.dart' as telnyx_call_state;
import 'package:telnyx_webrtc/model/call_quality_metrics.dart';
import 'package:telnyx_webrtc/model/verto/receive/received_message_body.dart';
import 'package:telnyx_webrtc/utils/logging/global_logger.dart';
import '../../models/call.dart';
import '../../models/call_state.dart';
import '../../models/connection_state.dart';
import '../../../utils/iterable_extensions.dart';
import '../session/session_manager.dart';
import '../callkit/callkit_manager.dart';
import '../../utils/background_detector.dart';

/// Internal component that serves as the central state machine for call management.
///
/// This class subscribes to TelnyxClient socket messages and maintains the
/// authoritative state of all calls. It translates raw socket messages into
/// structured Call objects with reactive state streams.
class CallStateController {
  final TelnyxClient _telnyxClient;
  final SessionManager _sessionManager;
  final CallKitManager? _callKitManager;

  // Callback to check if we're waiting for an invite after accepting from terminated state
  bool Function()? _isWaitingForInvite;
  VoidCallback? _onInviteAutoAccepted;

  final StreamController<List<Call>> _callsController =
      StreamController<List<Call>>.broadcast();
  final StreamController<Call?> _activeCallController =
      StreamController<Call?>.broadcast();

  final Map<String, Call> _calls = {};
  final Map<String, telnyx_call.Call> _telnyxCalls = {};
  final Map<String, StreamSubscription> _callSubscriptions = {};
  final Map<String, IncomingInviteParams> _originalInviteParams = {};

  // Track socket-driven state changes to prioritize them over TelnyxCall state changes
  final Map<String, DateTime> _lastSocketStateChange = {};

  bool _disposed = false;

  /// Creates a new CallStateController instance.
  CallStateController(
    this._telnyxClient,
    this._sessionManager, {
    CallKitManager? callKitManager,
  }) : _callKitManager = callKitManager {
    _setupSocketObservers();
    _setupConnectionStateObserver();
  }

  /// Stream of all current calls.
  Stream<List<Call>> get calls => _callsController.stream;

  /// Stream of the currently active call.
  Stream<Call?> get activeCall => _activeCallController.stream;

  /// Current list of calls (synchronous access).
  List<Call> get currentCalls => _calls.values.toList();

  /// Current active call (synchronous access).
  /// Returns the call that needs user attention (ringing, active, held, etc.)
  Call? get currentActiveCall {
    return _calls.values
        .where(
          (call) =>
              call.currentState == CallState.ringing ||
              call.currentState == CallState.active ||
              call.currentState == CallState.held ||
              call.currentState == CallState.initiating ||
              call.currentState == CallState.reconnecting,
        )
        .firstOrNull;
  }

  /// Sets callbacks for handling waiting for invite logic.
  void setWaitingForInviteCallbacks({
    bool Function()? isWaitingForInvite,
    VoidCallback? onInviteAutoAccepted,
  }) {
    _isWaitingForInvite = isWaitingForInvite;
    _onInviteAutoAccepted = onInviteAutoAccepted;
  }

  /// Initiates a new outgoing call.
  Future<Call> newCall(String destination, bool debug) async {
    if (_disposed) throw StateError('CallStateController has been disposed');

    // Create the call object first
    final call = Call(
      destination: destination,
      isIncoming: false,
      onAction: _handleCallAction,
    );

    // Add to our tracking
    _calls[call.callId] = call;

    try {
      // Set background detector to ignore so app doesn't disconnect during call
      BackgroundDetector.ignore = true;

      // Show CallKit UI for outgoing call
      await _callKitManager?.showOutgoingCall(
        callId: call.callId,
        callerName: _sessionManager.sipCallerIDName ?? 'User',
        destination: destination,
      );

      // Initiate the call through the TelnyxClient
      final telnyxCall = _telnyxClient.newInvite(
        _sessionManager.sipCallerIDName ?? 'User',
        _sessionManager.sipCallerIDNumber ?? 'Unknown',
        destination,
        'State', // Default state
        customHeaders: {'X-RTC-CALLID': call.callId},
        debug: debug,
      );

      _telnyxCalls[call.callId] = telnyxCall;
      _observeTelnyxCall(call.callId, telnyxCall);
      call.updateState(CallState.initiating);
    } catch (error) {
      // Remove the call if initiation failed
      _calls.remove(call.callId);
      call.updateState(CallState.error);
      // End CallKit UI if call failed
      await _callKitManager?.endCall(call.callId);

      // Reset background detector if no calls remain
      if (_calls.isEmpty) {
        BackgroundDetector.ignore = false;
      }

      rethrow;
    }

    _notifyCallsChanged();
    return call;
  }

  /// Monitors connection state for call cleanup.
  void monitorConnectionState(Stream<ConnectionState> connectionState) {
    connectionState.listen((state) {
      if (state is ConnectionError || state is Disconnected) {
        _endAllCalls();
      }
    });
  }

  /// Sets up observers for socket messages from the TelnyxClient.
  void _setupSocketObservers() {
    // Store the original callback so we can call it first
    final originalCallback = _telnyxClient.onSocketMessageReceived;

    _telnyxClient.onSocketMessageReceived = (TelnyxMessage message) {
      // First, let the TelnyxClient handle the message internally
      // This is crucial for WebRTC setup, especially for incoming invites
      originalCallback(message);

      // Then handle our additional processing
      _handleSocketMessage(message);
    };
  }

  /// Sets up observer for connection state changes.
  void _setupConnectionStateObserver() {
    _sessionManager.connectionState.listen((state) {
      if (state is ConnectionError || state is Disconnected) {
        _endAllCalls();
      }
    });
  }

  /// Handles incoming socket messages and updates call states accordingly.
  void _handleSocketMessage(TelnyxMessage message) {
    switch (message.socketMethod) {
      case SocketMethod.clientReady:
        // Notify session manager that we're connected
        _sessionManager.setConnected();
        break;

      case SocketMethod.invite:
        debugPrint(
            '[PUSH-DIAG] CallStateController: ==================== INCOMING INVITE ====================');
        debugPrint('[PUSH-DIAG] CallStateController: Invite received on socket');
        debugPrint(
            '[PUSH-DIAG] CallStateController: Current waiting for invite flag: ${_isWaitingForInvite?.call() ?? false}');
        _handleIncomingInvite(message.message.inviteParams);
        break;

      case SocketMethod.answer:
        _handleAnswerMessage(message);
        break;

      case SocketMethod.ringing:
        _handleRingingMessage(message);
        break;

      case SocketMethod.bye:
        _handleByeMessage(message);
        break;

      default:
        // Handle other socket methods as needed
        break;
    }
  }

  /// Handles incoming call invitations.
  void _handleIncomingInvite(IncomingInviteParams? inviteParams) async {
    if (inviteParams?.callID == null) return;

    final callId = inviteParams!.callID!;

    // [PUSH-DIAG] Log invite details
    debugPrint(
        '[PUSH-DIAG] CallStateController: Processing invite for callId=$callId');
    debugPrint(
        '[PUSH-DIAG] CallStateController: Caller=${inviteParams.callerIdName} / ${inviteParams.callerIdNumber}');

    // Check if we already have this call (avoid duplicates)
    if (_calls.containsKey(callId)) {
      debugPrint(
          '[PUSH-DIAG] CallStateController: Duplicate invite - call already exists, ignoring');
      return;
    }

    // Store the original invite parameters with SDP data
    _originalInviteParams[callId] = inviteParams;

    // Get the TelnyxCall that was created during internal processing
    final telnyxCall = _telnyxClient.getCallOrNull(callId);

    if (telnyxCall != null) {
      // Store the TelnyxCall for later use
      _telnyxCalls[callId] = telnyxCall;

      // Set up observation of the TelnyxCall
      _observeTelnyxCall(callId, telnyxCall);
    }

    // Create our wrapper Call object
    final call = Call(
      callId: callId,
      callerName: inviteParams.callerIdName ?? 'Unknown Caller',
      callerNumber: inviteParams.callerIdNumber ?? 'Unknown Number',
      isIncoming: true,
      onAction: _handleCallAction,
    );

    // Check if we're waiting for an invite after accepting from terminated state
    final isWaitingForInvite = _isWaitingForInvite?.call() ?? false;

    // [PUSH-DIAG] Log decision flow
    debugPrint(
        '[PUSH-DIAG] CallStateController: isHandlingPushNotification=${_sessionManager.isHandlingPushNotification}');
    debugPrint(
        '[PUSH-DIAG] CallStateController: isWaitingForInvite=$isWaitingForInvite');

    if (_sessionManager.isHandlingPushNotification) {
      // This is from a push notification that was already accepted
      debugPrint(
          '[PUSH-DIAG] CallStateController: Decision=PUSH_ALREADY_ACCEPTED - Setting call to active');
      call.updateState(CallState.active);
      _sessionManager.isHandlingPushNotification = false;
    } else if (isWaitingForInvite) {
      // We're waiting for this invite after accepting from terminated state - auto-accept
      debugPrint(
          '[PUSH-DIAG] CallStateController: Decision=WAITING_FOR_INVITE - Auto-accepting call');
      debugPrint(
          'CallStateController: Invite received while waiting for terminated state acceptance. Auto-accepting call $callId');
      call.updateState(CallState.ringing); // Set to ringing first

      // Set background detector to ignore so app doesn't disconnect during call
      BackgroundDetector.ignore = true;

      // Notify the VoipClient that we're auto-accepting and reset the waiting flag
      _onInviteAutoAccepted?.call();

      // Auto-accept the call immediately
      try {
        await call.answer();
        debugPrint(
            '[PUSH-DIAG] CallStateController: Successfully auto-accepted call $callId from terminated state');
      } catch (e) {
        debugPrint('CallStateController: Error auto-accepting call $callId: $e');
        call.updateState(CallState.error);
      }
    } else {
      // This is a new incoming call in foreground - show CallKit UI
      debugPrint(
          '[PUSH-DIAG] CallStateController: Decision=FOREGROUND - Showing CallKit UI');
      call.updateState(CallState.ringing);

      // Set background detector to ignore so app doesn't disconnect during call
      BackgroundDetector.ignore = true;

      // Show CallKit UI for incoming call
      await _callKitManager?.showIncomingCall(
        callId: callId,
        callerName: inviteParams.callerIdName ?? 'Unknown Caller',
        callerNumber: inviteParams.callerIdNumber ?? 'Unknown Number',
        extra: {},
      );
    }
    _calls[callId] = call;
    _notifyCallsChanged();

    debugPrint(
        '[PUSH-DIAG] CallStateController: Incoming invite handling complete for call $callId');
    debugPrint(
        '[PUSH-DIAG] CallStateController: Final call state: ${call.currentState}');
    debugPrint(
        '[PUSH-DIAG] CallStateController: ==================== INVITE HANDLING COMPLETE ====================');
  }

  /// Handles answer messages from the socket.
  /// This provides IMMEDIATE state transition to active when remote party answers.
  void _handleAnswerMessage(TelnyxMessage message) async {
    final timestamp = DateTime.now();

    // Find the call that was answered and update its state IMMEDIATELY
    final activeCall = _calls.values
        .where((call) =>
            call.currentState == CallState.initiating ||
            call.currentState == CallState.ringing)
        .firstOrNull;

    if (activeCall != null) {
      // Mark this as a socket-driven state change (priority update)
      _lastSocketStateChange[activeCall.callId] = timestamp;
      activeCall.updateState(CallState.active);
      activeCall.updateHoldState(false); // Ensure not held when active

      // Set CallKit as connected when call is answered
      await _callKitManager?.setCallConnected(activeCall.callId);

      // On Android, show ongoing call notification for foreground calls
      if (!kIsWeb && Platform.isAndroid && activeCall.isIncoming) {
        // For incoming calls answered in foreground, we need to show ongoing notification
        await _callKitManager?.showOutgoingCall(
          callId: activeCall.callId,
          callerName: 'Ongoing Call',
          destination: activeCall.callerNumber ?? 'Unknown Number',
          extra: {'isOngoing': true},
        );
      }

      _notifyCallsChanged();
    }
  }

  /// Handles ringing messages from the socket.
  /// This provides IMMEDIATE state transition to ringing for outgoing calls.
  void _handleRingingMessage(TelnyxMessage message) {
    final timestamp = DateTime.now();

    // Update outgoing calls to ringing state IMMEDIATELY
    final ringingCall = _calls.values
        .where((call) =>
            !call.isIncoming && call.currentState == CallState.initiating)
        .firstOrNull;

    if (ringingCall != null) {
      // Mark this as a socket-driven state change (priority update)
      _lastSocketStateChange[ringingCall.callId] = timestamp;
      ringingCall.updateState(CallState.ringing);

      _notifyCallsChanged();
    }
  }

  /// Handles bye messages from the socket.
  /// This provides IMMEDIATE state transition to ended when call terminates.
  void _handleByeMessage(TelnyxMessage message) async {
    final timestamp = DateTime.now();

    // End all active calls when receiving a bye message IMMEDIATELY
    for (final call in _calls.values) {
      if (!call.currentState.isTerminated) {
        // Mark this as a socket-driven state change (priority update)
        _lastSocketStateChange[call.callId] = timestamp;
        call.updateState(CallState.ended);

        // End CallKit call
        await _callKitManager?.endCall(call.callId);
      }
    }

    _cleanupTerminatedCalls();

    // Reset background detector if no calls remain
    if (_calls.isEmpty) {
      BackgroundDetector.ignore = false;
    }

    _notifyCallsChanged();
  }

  /// Handles call actions from the Call objects.
  void _handleCallAction(String callId, CallAction action,
      [Map<String, dynamic>? params]) {
    final call = _calls[callId];
    final telnyxCall = _telnyxCalls[callId];

    if (call == null) return;

    switch (action) {
      case CallAction.answer:
        _answerCall(call, telnyxCall);
        break;
      case CallAction.hangup:
        _hangupCall(call, telnyxCall);
        break;
      case CallAction.mute:
        _muteCall(call, telnyxCall, true);
        break;
      case CallAction.unmute:
        _muteCall(call, telnyxCall, false);
        break;
      case CallAction.hold:
        _holdCall(call, telnyxCall, true);
        break;
      case CallAction.unhold:
        _holdCall(call, telnyxCall, false);
        break;
      case CallAction.dtmf:
        _sendDtmf(call, telnyxCall, params?['tone'] as String?);
        break;
      case CallAction.enableSpeakerPhone:
        _enableSpeakerPhone(call, telnyxCall, params?['enable'] as bool?);
        break;
    }
  }

  /// Answers an incoming call.
  void _answerCall(Call call, telnyx_call.Call? telnyxCall) async {
    if (!call.isIncoming || !call.currentState.canAnswer) return;

    try {
      // Get the original invite parameters with SDP data
      final originalInviteParams = _originalInviteParams[call.callId];

      if (telnyxCall != null && originalInviteParams != null) {
        // Use existing TelnyxCall with original invite parameters containing SDP data
        // Note: The acceptCall method returns a new Call instance with updated parameters
        final updatedTelnyxCall = telnyxCall.acceptCall(
          originalInviteParams,
          _sessionManager.sipCallerIDName ?? 'User',
          _sessionManager.sipCallerIDNumber ?? 'Unknown',
          'State', // Default state
          customHeaders: {},
          debug: true, // Enable debug to get call quality metrics
        );

        // Update our reference and re-observe the updated call
        _telnyxCalls[call.callId] = updatedTelnyxCall;
        _observeTelnyxCall(call.callId, updatedTelnyxCall);
      } else {
        // Fallback: Try to get the call from TelnyxClient or create new one
        final inviteParams = originalInviteParams ??
            IncomingInviteParams(
              callID: call.callId,
              callerIdName: call.callerName,
              callerIdNumber: call.callerNumber,
            );

        // Always enable debug for call quality metrics
        final newTelnyxCall = _telnyxClient.acceptCall(
          inviteParams,
          _sessionManager.sipCallerIDName ?? 'User',
          _sessionManager.sipCallerIDNumber ?? 'Unknown',
          'State', // Default state
          customHeaders: {},
          debug: true, // Enable debug to get call quality metrics
        );

        _telnyxCalls[call.callId] = newTelnyxCall;
        _observeTelnyxCall(call.callId, newTelnyxCall);
      }

      // Handle platform-specific call UI updates when answered
      if (call.isIncoming) {
        // On Android, we need to hide the incoming call UI and show an ongoing call notification
        if (!kIsWeb && Platform.isAndroid) {
          await _callKitManager?.hideIncomingCall(
            callId: call.callId,
            callerName: call.callerName ?? 'Unknown Caller',
            callerNumber: call.callerNumber ?? 'Unknown Number',
          );

          // Show ongoing call notification on Android
          // We use showOutgoingCall which creates an ongoing call notification
          await _callKitManager?.showOutgoingCall(
            callId: call.callId,
            callerName: 'Ongoing Call',
            destination: call.callerNumber ?? 'Unknown Number',
            extra: {'isOngoing': true},
          );
        }
      }

      // Don't update state here - let the TelnyxCall state change handler do it
      // This ensures proper state synchronization
      _notifyCallsChanged();
    } catch (error) {
      call.updateState(CallState.error);
      _notifyCallsChanged();
    }
  }

  /// Ends a call.
  void _hangupCall(Call call, telnyx_call.Call? telnyxCall) async {
    if (!call.currentState.canHangup) return;

    try {
      telnyxCall?.endCall();
      call.updateState(CallState.ended);

      // End CallKit call
      await _callKitManager?.endCall(call.callId);

      _cleanupCall(call.callId);
      _notifyCallsChanged();
    } catch (error) {
      call.updateState(CallState.error);

      // End CallKit call even on error
      await _callKitManager?.endCall(call.callId);

      // Check if we should reset background detector
      _cleanupCall(call.callId);
      if (_calls.isEmpty) {
        BackgroundDetector.ignore = false;
      }

      _notifyCallsChanged();
    }
  }

  /// Mutes or unmutes a call.
  void _muteCall(Call call, telnyx_call.Call? telnyxCall, bool mute) {
    if (!call.currentState.canMute) return;

    try {
      telnyxCall?.onMuteUnmutePressed();
      call.updateMuteState(mute);
    } catch (error) {
      // Mute operation failed, but don't change call state
    }
  }

  /// Holds or unholds a call.
  void _holdCall(Call call, telnyx_call.Call? telnyxCall, bool hold) {
    if (hold && !call.currentState.canHold) return;
    if (!hold && !call.currentState.canUnhold) return;

    try {
      telnyxCall?.onHoldUnholdPressed();

      // Immediately update the state since TelnyxCall state handlers may not be working properly
      if (hold) {
        call.updateState(CallState.held);
        call.updateHoldState(true);
      } else {
        call.updateState(CallState.active);
        call.updateHoldState(false);
      }

      _notifyCallsChanged();
    } catch (error) {
      // Hold operation failed, but don't change call state
    }
  }

  /// Sends a DTMF tone.
  void _sendDtmf(Call call, telnyx_call.Call? telnyxCall, String? tone) {
    if (!call.currentState.canMute || tone == null) return;

    try {
      telnyxCall?.dtmf(tone);
    } catch (error) {
      // DTMF operation failed, but don't change call state
    }
  }

  /// Enables or disables speaker phone.
  void _enableSpeakerPhone(
      Call call, telnyx_call.Call? telnyxCall, bool? enable) {
    if (!call.currentState.canMute || enable == null) return;

    try {
      telnyxCall?.enableSpeakerPhone(enable);
    } catch (error) {
      // Speaker phone operation failed, but don't change call state
    }
  }

  /// Observes a TelnyxCall for state changes.
  void _observeTelnyxCall(String callId, telnyx_call.Call telnyxCall) {
    final call = _calls[callId];
    if (call == null) return;

    // Set up call state observer
    telnyxCall.callHandler.onCallStateChanged =
        (telnyx_call_state.CallState state) {
      _handleTelnyxCallStateChange(callId, state);
    };

    // Set up call quality monitoring
    telnyxCall.onCallQualityChange = (metrics) {
      call.updateCallQualityMetrics(metrics);
    };
  }

  /// Handles state changes from TelnyxCall objects.
  void _handleTelnyxCallStateChange(
      String callId, telnyx_call_state.CallState state) async {
    final call = _calls[callId];
    if (call == null) {
      return;
    }

    // Check if there was a recent socket-driven state change that should take priority
    final lastSocketChange = _lastSocketStateChange[callId];
    final now = DateTime.now();
    const socketPriorityWindow =
        Duration(milliseconds: 2000); // 2-second priority window

    if (lastSocketChange != null &&
        now.difference(lastSocketChange) < socketPriorityWindow) {
      return;
    }

    switch (state) {
      case telnyx_call_state.CallState.connecting:
        call.updateState(CallState.initiating);
        break;
      case telnyx_call_state.CallState.ringing:
        call.updateState(CallState.ringing);
        break;
      case telnyx_call_state.CallState.active:
        call.updateState(CallState.active);
        call.updateHoldState(false);
        // Set CallKit as connected when call becomes active
        await _callKitManager?.setCallConnected(callId);

        // On Android, ensure ongoing call notification is shown for incoming calls
        if (!kIsWeb && Platform.isAndroid && call.isIncoming) {
          await _callKitManager?.showOutgoingCall(
            callId: callId,
            callerName: 'Ongoing Call',
            destination: call.callerNumber ?? 'Unknown Number',
            extra: {'isOngoing': true},
          );
        }
        break;
      case telnyx_call_state.CallState.held:
        call.updateState(CallState.held);
        call.updateHoldState(true);
        break;
      case telnyx_call_state.CallState.done:
        call.updateState(CallState.ended);
        // End CallKit call when call is done
        await _callKitManager?.endCall(callId);
        _cleanupCall(callId);

        // Reset background detector if no calls remain
        if (_calls.isEmpty) {
          BackgroundDetector.ignore = false;
        }
        break;
      case telnyx_call_state.CallState.error:
        call.updateState(CallState.error);
        // End CallKit call on error
        await _callKitManager?.endCall(callId);
        _cleanupCall(callId);

        // Reset background detector if no calls remain
        if (_calls.isEmpty) {
          BackgroundDetector.ignore = false;
        }
        break;
      case telnyx_call_state.CallState.reconnecting:
        call.updateState(CallState.reconnecting);
        break;
      default:
        break;
    }

    _notifyCallsChanged();
  }

  /// Ends all active calls.
  void _endAllCalls() async {
    for (final call in _calls.values) {
      if (!call.currentState.isTerminated) {
        call.updateState(CallState.ended);

        // End CallKit call
        await _callKitManager?.endCall(call.callId);
      }
    }
    _cleanupTerminatedCalls();

    // Reset background detector if no calls remain
    if (_calls.isEmpty) {
      BackgroundDetector.ignore = false;
    }

    _notifyCallsChanged();
  }

  /// Cleans up a specific call.
  void _cleanupCall(String callId) {
    final call = _calls.remove(callId);
    final telnyxCall = _telnyxCalls.remove(callId);
    final subscription = _callSubscriptions.remove(callId);

    // Clean up stored invite parameters and socket state tracking
    _originalInviteParams.remove(callId);
    _lastSocketStateChange.remove(callId);

    call?.dispose();
    subscription?.cancel();
  }

  /// Cleans up all terminated calls.
  void _cleanupTerminatedCalls() {
    final terminatedCallIds = _calls.entries
        .where((entry) => entry.value.currentState.isTerminated)
        .map((entry) => entry.key)
        .toList();

    for (final callId in terminatedCallIds) {
      _cleanupCall(callId);
    }
  }

  /// Notifies listeners of call list changes.
  void _notifyCallsChanged() {
    if (_disposed) return;

    final callsList = currentCalls;
    _callsController.add(callsList);

    // Update active call stream
    final activeCall = currentActiveCall;
    _activeCallController.add(activeCall);
  }

  /// Disposes of the call state controller and cleans up resources.
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    // Clean up all calls
    for (final callId in _calls.keys.toList()) {
      _cleanupCall(callId);
    }

    _callsController.close();
    _activeCallController.close();
  }
}
