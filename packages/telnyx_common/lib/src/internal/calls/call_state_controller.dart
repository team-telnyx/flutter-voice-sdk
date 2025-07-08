import 'dart:async';
import 'package:telnyx_webrtc/telnyx_client.dart';
import 'package:telnyx_webrtc/call.dart' as telnyx_call;
import 'package:telnyx_webrtc/model/telnyx_message.dart';
import 'package:telnyx_webrtc/model/socket_method.dart';
import 'package:telnyx_webrtc/model/call_state.dart' as telnyx_call_state;
import 'package:telnyx_webrtc/model/verto/receive/received_message_body.dart';
import '../../models/call.dart';
import '../../models/call_state.dart';
import '../../models/connection_state.dart';
import '../../../utils/iterable_extensions.dart';
import '../session/session_manager.dart';

/// Internal component that serves as the central state machine for call management.
///
/// This class subscribes to TelnyxClient socket messages and maintains the
/// authoritative state of all calls. It translates raw socket messages into
/// structured Call objects with reactive state streams.
class CallStateController {
  final TelnyxClient _telnyxClient;
  final SessionManager _sessionManager;

  final StreamController<List<Call>> _callsController =
      StreamController<List<Call>>.broadcast();
  final StreamController<Call?> _activeCallController =
      StreamController<Call?>.broadcast();

  final Map<String, Call> _calls = {};
  final Map<String, telnyx_call.Call> _telnyxCalls = {};
  final Map<String, StreamSubscription> _callSubscriptions = {};

  bool _disposed = false;

  /// Creates a new CallStateController instance.
  CallStateController(this._telnyxClient, this._sessionManager) {
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
  Call? get currentActiveCall {
    return _calls.values
        .where((call) => call.currentState.isActive)
        .firstOrNull;
  }

  /// Initiates a new outgoing call.
  Future<Call> newCall(String destination) async {
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
      // Initiate the call through the TelnyxClient
      final telnyxCall = _telnyxClient.newInvite(
        _sessionManager.sipCallerIDName ?? 'User',
        _sessionManager.sipCallerIDNumber ?? 'Unknown',
        destination,
        'State', // Default state
        customHeaders: {'X-RTC-CALLID': call.callId},
        debug: true,
      );

      if (telnyxCall != null) {
        _telnyxCalls[call.callId] = telnyxCall;
        _observeTelnyxCall(call.callId, telnyxCall);
        call.updateState(CallState.initiating);
      }
    } catch (error) {
      // Remove the call if initiation failed
      _calls.remove(call.callId);
      call.updateState(CallState.error);
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
    _telnyxClient.onSocketMessageReceived = (TelnyxMessage message) {
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
  void _handleIncomingInvite(IncomingInviteParams? inviteParams) {
    if (inviteParams?.callID == null) return;

    final callId = inviteParams!.callID!;

    // Check if we already have this call (avoid duplicates)
    if (_calls.containsKey(callId)) return;

    final call = Call(
      callId: callId,
      callerName: inviteParams.callerIdName ?? 'Unknown Caller',
      callerNumber: inviteParams.callerIdNumber ?? 'Unknown Number',
      isIncoming: true,
      onAction: _handleCallAction,
    );

    call.updateState(CallState.ringing);
    _calls[callId] = call;
    _notifyCallsChanged();
  }

  /// Handles answer messages from the socket.
  void _handleAnswerMessage(TelnyxMessage message) {
    // Find the call that was answered and update its state
    final activeCall = _calls.values
        .where((call) =>
            call.currentState == CallState.initiating ||
            call.currentState == CallState.ringing)
        .firstOrNull;

    if (activeCall != null) {
      activeCall.updateState(CallState.active);
      _notifyCallsChanged();
    }
  }

  /// Handles ringing messages from the socket.
  void _handleRingingMessage(TelnyxMessage message) {
    // Update outgoing calls to ringing state
    final ringingCall = _calls.values
        .where((call) =>
            !call.isIncoming && call.currentState == CallState.initiating)
        .firstOrNull;

    if (ringingCall != null) {
      ringingCall.updateState(CallState.ringing);
      _notifyCallsChanged();
    }
  }

  /// Handles bye messages from the socket.
  void _handleByeMessage(TelnyxMessage message) {
    // End all active calls when receiving a bye message
    for (final call in _calls.values) {
      if (!call.currentState.isTerminated) {
        call.updateState(CallState.ended);
      }
    }
    _cleanupTerminatedCalls();
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
    }
  }

  /// Answers an incoming call.
  void _answerCall(Call call, telnyx_call.Call? telnyxCall) {
    if (!call.isIncoming || !call.currentState.canAnswer) return;

    try {
      if (telnyxCall != null) {
        // Use existing TelnyxCall if available
        telnyxCall.acceptCall(
          IncomingInviteParams(
            callID: call.callId,
            callerIdName: call.callerName,
            callerIdNumber: call.callerNumber,
          ),
          _sessionManager.sipCallerIDName ?? 'User',
          _sessionManager.sipCallerIDNumber ?? 'Unknown',
          'State', // Default state
        );
      } else {
        // Create new TelnyxCall for incoming call
        final inviteParams = IncomingInviteParams(
          callID: call.callId,
          callerIdName: call.callerName,
          callerIdNumber: call.callerNumber,
        );

        final newTelnyxCall = _telnyxClient.acceptCall(
          inviteParams,
          _sessionManager.sipCallerIDName ?? 'User',
          _sessionManager.sipCallerIDNumber ?? 'Unknown',
          'State', // Default state
          customHeaders: {},
          debug: true,
        );

        _telnyxCalls[call.callId] = newTelnyxCall;
        _observeTelnyxCall(call.callId, newTelnyxCall);
      }

      call.updateState(CallState.active);
      _notifyCallsChanged();
    } catch (error) {
      call.updateState(CallState.error);
      _notifyCallsChanged();
    }
  }

  /// Ends a call.
  void _hangupCall(Call call, telnyx_call.Call? telnyxCall) {
    if (!call.currentState.canHangup) return;

    try {
      telnyxCall?.endCall();
      call.updateState(CallState.ended);
      _cleanupCall(call.callId);
      _notifyCallsChanged();
    } catch (error) {
      call.updateState(CallState.error);
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
      if (hold) {
        call
          ..updateState(CallState.held)
          ..updateHoldState(true);
      } else {
        call
          ..updateState(CallState.active)
          ..updateHoldState(false);
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

  /// Observes a TelnyxCall for state changes.
  void _observeTelnyxCall(String callId, telnyx_call.Call telnyxCall) {
    final call = _calls[callId];
    if (call == null) return;

    // Set up call state observer
    telnyxCall.callHandler.onCallStateChanged =
        (telnyx_call_state.CallState state) {
      _handleTelnyxCallStateChange(callId, state);
    };
  }

  /// Handles state changes from TelnyxCall objects.
  void _handleTelnyxCallStateChange(
      String callId, telnyx_call_state.CallState state) {
    final call = _calls[callId];
    if (call == null) return;

    switch (state) {
      case telnyx_call_state.CallState.connecting:
        call.updateState(CallState.initiating);
        break;
      case telnyx_call_state.CallState.ringing:
        call.updateState(CallState.ringing);
        break;
      case telnyx_call_state.CallState.active:
        call.updateState(CallState.active);
        break;
      case telnyx_call_state.CallState.held:
        call.updateState(CallState.held);
        call.updateHoldState(true);
        break;
      case telnyx_call_state.CallState.done:
        call.updateState(CallState.ended);
        _cleanupCall(callId);
        break;
      case telnyx_call_state.CallState.error:
        call.updateState(CallState.error);
        _cleanupCall(callId);
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
  void _endAllCalls() {
    for (final call in _calls.values) {
      if (!call.currentState.isTerminated) {
        call.updateState(CallState.ended);
      }
    }
    _cleanupTerminatedCalls();
    _notifyCallsChanged();
  }

  /// Cleans up a specific call.
  void _cleanupCall(String callId) {
    final call = _calls.remove(callId);
    final telnyxCall = _telnyxCalls.remove(callId);
    final subscription = _callSubscriptions.remove(callId);

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
    final activeCall =
        callsList.where((call) => call.currentState.isActive).firstOrNull;
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
