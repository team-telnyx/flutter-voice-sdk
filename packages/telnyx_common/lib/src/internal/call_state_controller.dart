import 'dart:async';
import 'package:telnyx_webrtc/telnyx_client.dart';
import 'package:telnyx_webrtc/model/telnyx_message.dart';
import 'package:telnyx_webrtc/model/socket_method.dart';
import 'package:telnyx_webrtc/call.dart' as webrtc;
import 'package:telnyx_webrtc/model/call_state.dart' as webrtc;
import '../models/call.dart';
import '../models/call_state.dart';
import '../models/connection_state.dart';

/// Internal component that serves as the central state machine for call management.
///
/// This class subscribes to TelnyxClient socket messages and maintains a map of
/// active calls, translating raw socket messages into structured Call objects
/// with clear CallState enums.
class CallStateController {
  /// The TelnyxClient instance to monitor.
  final TelnyxClient _telnyxClient;
  
  /// Stream controller for the list of all calls.
  final StreamController<List<Call>> _callsController = 
      StreamController<List<Call>>.broadcast();
  
  /// Stream controller for the active call.
  final StreamController<Call?> _activeCallController = 
      StreamController<Call?>.broadcast();
  
  /// Map of active calls by call ID.
  final Map<String, Call> _activeCalls = {};
  
  /// Map of underlying WebRTC calls by call ID.
  final Map<String, webrtc.Call> _webrtcCalls = {};
  
  /// Whether the controller has been disposed.
  bool _disposed = false;
  
  /// Subscription to connection state changes.
  StreamSubscription<ConnectionState>? _connectionStateSubscription;
  
  CallStateController(this._telnyxClient) {
    _setupSocketMessageListener();
  }
  
  /// Stream of all active calls.
  Stream<List<Call>> get calls => _callsController.stream;
  
  /// Stream of the currently active call (null if no active call).
  Stream<Call?> get activeCall => _activeCallController.stream;
  
  /// Current list of active calls (synchronous access).
  List<Call> get currentCalls => _activeCalls.values.toList();
  
  /// Current active call (synchronous access).
  Call? get currentActiveCall {
    final activeCalls = _activeCalls.values
        .where((call) => call.currentState.isActive)
        .toList();
    return activeCalls.isNotEmpty ? activeCalls.first : null;
  }
  
  /// Monitors connection state changes to handle call cleanup.
  void monitorConnectionState(Stream<ConnectionState> connectionState) {
    _connectionStateSubscription?.cancel();
    _connectionStateSubscription = connectionState.listen(_handleConnectionStateChange);
  }
  
  /// Sets up the socket message listener.
  void _setupSocketMessageListener() {
    _telnyxClient.onSocketMessageReceived = _handleSocketMessage;
  }
  
  /// Initiates a new outgoing call.
  Future<Call> newCall(String destination) async {
    if (_disposed) throw StateError('CallStateController has been disposed');
    
    try {
      // Create the call object first
      final call = Call(
        destination: destination,
        isIncoming: false,
        onAction: _handleCallAction,
      );
      
      // Add to active calls
      _activeCalls[call.callId] = call;
      _notifyCallsChanged();
      
      // Initiate the call through the WebRTC client
      final webrtcCall = await _telnyxClient.newCall(destination);
      _webrtcCalls[call.callId] = webrtcCall;
      
      // Set up call state monitoring
      _setupCallStateMonitoring(call, webrtcCall);
      
      return call;
    } catch (error) {
      // Remove the call if creation failed
      _activeCalls.remove(call.callId);
      _notifyCallsChanged();
      rethrow;
    }
  }
  
  /// Handles incoming calls from socket messages.
  void _handleIncomingCall(TelnyxMessage message) {
    // Extract call information from the INVITE message
    final callId = message.id ?? message.callId;
    if (callId == null) return;
    
    // Parse caller information from the message
    final callerName = _extractCallerName(message);
    final callerNumber = _extractCallerNumber(message);
    
    // Create the call object
    final call = Call(
      callId: callId,
      callerName: callerName,
      callerNumber: callerNumber,
      isIncoming: true,
      onAction: _handleCallAction,
    );
    
    // Set initial state to ringing
    call.updateState(CallState.ringing);
    
    // Add to active calls
    _activeCalls[callId] = call;
    _notifyCallsChanged();
  }
  
  /// Handles socket messages from the TelnyxClient.
  void _handleSocketMessage(TelnyxMessage message) {
    switch (message.socketMethod) {
      case SocketMethod.invite:
        _handleIncomingCall(message);
        break;
      case SocketMethod.answer:
        _handleCallAnswered(message);
        break;
      case SocketMethod.bye:
        _handleCallEnded(message);
        break;
      case SocketMethod.media:
        _handleMediaUpdate(message);
        break;
      default:
        // Handle other message types as needed
        break;
    }
  }
  
  /// Handles call answered messages.
  void _handleCallAnswered(TelnyxMessage message) {
    final callId = message.id ?? message.callId;
    final call = _activeCalls[callId];
    if (call != null) {
      call.updateState(CallState.active);
      _notifyActiveCallChanged();
    }
  }
  
  /// Handles call ended messages.
  void _handleCallEnded(TelnyxMessage message) {
    final callId = message.id ?? message.callId;
    final call = _activeCalls[callId];
    if (call != null) {
      call.updateState(CallState.ended);
      _removeCall(callId);
    }
  }
  
  /// Handles media update messages (for mute/hold state).
  void _handleMediaUpdate(TelnyxMessage message) {
    final callId = message.id ?? message.callId;
    final call = _activeCalls[callId];
    if (call != null) {
      // Parse media state from message and update call accordingly
      // This would need to be implemented based on the actual message format
    }
  }
  
  /// Handles connection state changes.
  void _handleConnectionStateChange(ConnectionState state) {
    if (state is Disconnected || state is ConnectionError) {
      // End all active calls when connection is lost
      for (final call in _activeCalls.values) {
        if (!call.currentState.isTerminated) {
          call.updateState(CallState.error);
        }
      }
      _clearAllCalls();
    }
  }
  
  /// Sets up call state monitoring for a WebRTC call.
  void _setupCallStateMonitoring(Call call, webrtc.Call webrtcCall) {
    webrtcCall.callHandler.onCallStateChanged = (webrtc.CallState state) {
      _handleWebRtcCallStateChange(call, state);
    };
  }
  
  /// Handles WebRTC call state changes.
  void _handleWebRtcCallStateChange(Call call, webrtc.CallState webrtcState) {
    final commonState = _mapWebRtcStateToCommonState(webrtcState);
    call.updateState(commonState);
    
    if (commonState.isTerminated) {
      _removeCall(call.callId);
    } else if (commonState.isActive) {
      _notifyActiveCallChanged();
    }
  }
  
  /// Maps WebRTC call states to common call states.
  CallState _mapWebRtcStateToCommonState(webrtc.CallState webrtcState) {
    switch (webrtcState) {
      case webrtc.CallState.newCall:
      case webrtc.CallState.connecting:
        return CallState.initiating;
      case webrtc.CallState.ringing:
        return CallState.ringing;
      case webrtc.CallState.active:
        return CallState.active;
      case webrtc.CallState.held:
        return CallState.held;
      case webrtc.CallState.done:
        return CallState.ended;
      case webrtc.CallState.reconnecting:
        return CallState.reconnecting;
      default:
        return CallState.error;
    }
  }
  
  /// Handles call actions (answer, hangup, etc.).
  void _handleCallAction(String callId, String action, [Map<String, dynamic>? params]) {
    final call = _activeCalls[callId];
    final webrtcCall = _webrtcCalls[callId];
    
    if (call == null || webrtcCall == null) return;
    
    switch (action) {
      case 'answer':
        _answerCall(call, webrtcCall);
        break;
      case 'hangup':
        _hangupCall(call, webrtcCall);
        break;
      case 'toggleMute':
        _toggleMute(call, webrtcCall);
        break;
      case 'toggleHold':
        _toggleHold(call, webrtcCall);
        break;
      case 'dtmf':
        _sendDtmf(call, webrtcCall, params?['tone'] as String?);
        break;
    }
  }
  
  /// Answers a call.
  void _answerCall(Call call, webrtc.Call webrtcCall) {
    try {
      webrtcCall.acceptCall();
      call.updateState(CallState.active);
    } catch (error) {
      call.updateState(CallState.error);
    }
  }
  
  /// Hangs up a call.
  void _hangupCall(Call call, webrtc.Call webrtcCall) {
    try {
      webrtcCall.endCall();
      call.updateState(CallState.ended);
      _removeCall(call.callId);
    } catch (error) {
      call.updateState(CallState.error);
    }
  }
  
  /// Toggles mute state.
  void _toggleMute(Call call, webrtc.Call webrtcCall) {
    try {
      webrtcCall.onMuteUnmutePressed();
      call.updateMuteState(!call.currentIsMuted);
    } catch (error) {
      // Handle error
    }
  }
  
  /// Toggles hold state.
  void _toggleHold(Call call, webrtc.Call webrtcCall) {
    try {
      webrtcCall.onHoldUnholdPressed();
      call.updateHoldState(!call.currentIsHeld);
    } catch (error) {
      // Handle error
    }
  }
  
  /// Sends DTMF tone.
  void _sendDtmf(Call call, webrtc.Call webrtcCall, String? tone) {
    if (tone == null) return;
    
    try {
      webrtcCall.dtmf(tone);
    } catch (error) {
      // Handle error
    }
  }
  
  /// Removes a call from active calls.
  void _removeCall(String callId) {
    final call = _activeCalls.remove(callId);
    _webrtcCalls.remove(callId);
    
    if (call != null) {
      call.dispose();
      _notifyCallsChanged();
      _notifyActiveCallChanged();
    }
  }
  
  /// Clears all active calls.
  void _clearAllCalls() {
    for (final call in _activeCalls.values) {
      call.dispose();
    }
    _activeCalls.clear();
    _webrtcCalls.clear();
    _notifyCallsChanged();
    _notifyActiveCallChanged();
  }
  
  /// Notifies listeners of calls list changes.
  void _notifyCallsChanged() {
    if (!_disposed) {
      _callsController.add(currentCalls);
    }
  }
  
  /// Notifies listeners of active call changes.
  void _notifyActiveCallChanged() {
    if (!_disposed) {
      _activeCallController.add(currentActiveCall);
    }
  }
  
  /// Extracts caller name from socket message.
  String? _extractCallerName(TelnyxMessage message) {
    // This would need to be implemented based on the actual message format
    return null;
  }
  
  /// Extracts caller number from socket message.
  String? _extractCallerNumber(TelnyxMessage message) {
    // This would need to be implemented based on the actual message format
    return null;
  }
  
  /// Disposes of the controller and cleans up resources.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    
    _connectionStateSubscription?.cancel();
    _clearAllCalls();
    _callsController.close();
    _activeCallController.close();
  }
}