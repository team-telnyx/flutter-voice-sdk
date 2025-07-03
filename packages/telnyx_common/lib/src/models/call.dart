import 'dart:async';
import 'package:uuid/uuid.dart';
import 'call_state.dart';

/// Represents a call in the telnyx_common module.
///
/// This class provides a high-level interface for managing individual calls,
/// including state management, call control actions, and reactive streams
/// for UI integration.
class Call {
  /// Unique identifier for this call.
  final String callId;
  
  /// The destination number or SIP URI for outgoing calls.
  final String? destination;
  
  /// The caller's name (for incoming calls).
  final String? callerName;
  
  /// The caller's number (for incoming calls).
  final String? callerNumber;
  
  /// Whether this is an incoming call.
  final bool isIncoming;
  
  /// Stream controller for call state changes.
  final StreamController<CallState> _stateController = StreamController<CallState>.broadcast();
  
  /// Stream controller for mute state changes.
  final StreamController<bool> _muteController = StreamController<bool>.broadcast();
  
  /// Stream controller for hold state changes.
  final StreamController<bool> _holdController = StreamController<bool>.broadcast();
  
  /// Current call state.
  CallState _currentState = CallState.initiating;
  
  /// Current mute state.
  bool _isMuted = false;
  
  /// Current hold state.
  bool _isHeld = false;
  
  /// Callback for call actions (answer, hangup, etc.).
  late final Function(String callId, String action, [Map<String, dynamic>? params]) _onAction;
  
  Call({
    String? callId,
    this.destination,
    this.callerName,
    this.callerNumber,
    this.isIncoming = false,
    required Function(String callId, String action, [Map<String, dynamic>? params]) onAction,
  }) : callId = callId ?? const Uuid().v4(),
       _onAction = onAction;
  
  /// Stream of call state changes.
  Stream<CallState> get callState => _stateController.stream;
  
  /// Stream of mute state changes.
  Stream<bool> get isMuted => _muteController.stream;
  
  /// Stream of hold state changes.
  Stream<bool> get isHeld => _holdController.stream;
  
  /// Current call state (synchronous access).
  CallState get currentState => _currentState;
  
  /// Current mute state (synchronous access).
  bool get currentIsMuted => _isMuted;
  
  /// Current hold state (synchronous access).
  bool get currentIsHeld => _isHeld;
  
  /// Updates the call state and notifies listeners.
  void updateState(CallState newState) {
    if (_currentState != newState) {
      _currentState = newState;
      _stateController.add(newState);
    }
  }
  
  /// Updates the mute state and notifies listeners.
  void updateMuteState(bool muted) {
    if (_isMuted != muted) {
      _isMuted = muted;
      _muteController.add(muted);
    }
  }
  
  /// Updates the hold state and notifies listeners.
  void updateHoldState(bool held) {
    if (_isHeld != held) {
      _isHeld = held;
      _holdController.add(held);
    }
  }
  
  /// Answers the call (only valid for incoming calls in ringing state).
  Future<void> answer() async {
    if (!isIncoming || !_currentState.canAnswer) {
      throw StateError('Cannot answer call in current state: $_currentState');
    }
    _onAction(callId, 'answer');
  }
  
  /// Hangs up the call.
  Future<void> hangup() async {
    if (!_currentState.canHangup) {
      throw StateError('Cannot hangup call in current state: $_currentState');
    }
    _onAction(callId, 'hangup');
  }
  
  /// Toggles the mute state of the call.
  Future<void> toggleMute() async {
    if (!_currentState.canMute) {
      throw StateError('Cannot mute call in current state: $_currentState');
    }
    _onAction(callId, 'toggleMute');
  }
  
  /// Toggles the hold state of the call.
  Future<void> toggleHold() async {
    if (_currentState.canHold || _currentState.canUnhold) {
      _onAction(callId, 'toggleHold');
    } else {
      throw StateError('Cannot toggle hold in current state: $_currentState');
    }
  }
  
  /// Sends a DTMF tone.
  Future<void> dtmf(String tone) async {
    if (!_currentState.isActive) {
      throw StateError('Cannot send DTMF in current state: $_currentState');
    }
    _onAction(callId, 'dtmf', {'tone': tone});
  }
  
  /// Disposes of the call and closes all streams.
  void dispose() {
    _stateController.close();
    _muteController.close();
    _holdController.close();
  }
  
  @override
  String toString() {
    return 'Call(id: $callId, state: $_currentState, destination: $destination, '
           'callerName: $callerName, callerNumber: $callerNumber, isIncoming: $isIncoming)';
  }
}