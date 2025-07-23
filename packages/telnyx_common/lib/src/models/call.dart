import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:telnyx_webrtc/model/call_quality_metrics.dart';
import 'call_state.dart';

/// Callback function type for call actions.
typedef CallActionCallback = void Function(String callId, CallAction action,
    [Map<String, dynamic>? params]);

/// Enum representing different call actions.
enum CallAction {
  answer,
  hangup,
  mute,
  unmute,
  hold,
  unhold,
  dtmf,
  enableSpeakerPhone,
}

/// Represents an individual call with state management and control methods.
///
/// This class provides a reactive interface for managing call state and
/// performing call actions. It uses streams to notify listeners of state
/// changes, making it easy to integrate with any state management solution.
class Call {
  /// Unique identifier for the call.
  final String callId;

  /// Destination number or SIP URI (for outgoing calls).
  final String? destination;

  /// Caller name (for incoming calls).
  final String? callerName;

  /// Caller number (for incoming calls).
  final String? callerNumber;

  /// Whether this is an incoming call.
  final bool isIncoming;

  /// Callback function for performing call actions.
  final CallActionCallback onAction;

  // Stream controllers for reactive state management
  final StreamController<CallState> _callStateController =
      StreamController<CallState>.broadcast();
  final StreamController<bool> _isMutedController =
      StreamController<bool>.broadcast();
  final StreamController<bool> _isHeldController =
      StreamController<bool>.broadcast();
  final StreamController<CallQualityMetrics> _callQualityController =
      StreamController<CallQualityMetrics>.broadcast();

  // Current state values
  CallState _currentState = CallState.initiating;
  bool _isMuted = false;
  bool _isHeld = false;
  CallQualityMetrics? _currentCallQualityMetrics;

  /// Creates a new Call instance.
  ///
  /// For outgoing calls, provide [destination].
  /// For incoming calls, provide [callerName], [callerNumber], and set [isIncoming] to true.
  Call({
    String? callId,
    this.destination,
    this.callerName,
    this.callerNumber,
    this.isIncoming = false,
    required this.onAction,
  }) : callId = callId ?? const Uuid().v4() {
    // Initialize streams with current values
    _callStateController.add(_currentState);
    _isMutedController.add(_isMuted);
    _isHeldController.add(_isHeld);
  }

  /// Stream of call state changes.
  Stream<CallState> get callState => _callStateController.stream;

  /// Stream of mute state changes.
  Stream<bool> get isMuted => _isMutedController.stream;

  /// Stream of hold state changes.
  Stream<bool> get isHeld => _isHeldController.stream;

  /// Stream of call quality metrics updates.
  Stream<CallQualityMetrics> get callQualityMetrics =>
      _callQualityController.stream;

  /// Current call state (synchronous access).
  CallState get currentState => _currentState;

  /// Current mute state (synchronous access).
  bool get currentIsMuted => _isMuted;

  /// Current hold state (synchronous access).
  bool get currentIsHeld => _isHeld;

  /// Current call quality metrics (synchronous access).
  CallQualityMetrics? get currentCallQualityMetrics =>
      _currentCallQualityMetrics;

  /// Updates the call state and notifies listeners.
  void updateState(CallState newState) {
    if (_currentState != newState) {
      _currentState = newState;
      _callStateController.add(newState);
    }
  }

  /// Updates the mute state and notifies listeners.
  void updateMuteState(bool muted) {
    if (_isMuted != muted) {
      _isMuted = muted;
      _isMutedController.add(muted);
    }
  }

  /// Updates the hold state and notifies listeners.
  void updateHoldState(bool held) {
    if (_isHeld != held) {
      _isHeld = held;
      _isHeldController.add(held);
    }
  }

  /// Updates the call quality metrics and notifies listeners.
  void updateCallQualityMetrics(CallQualityMetrics metrics) {
    _currentCallQualityMetrics = metrics;
    _callQualityController.add(metrics);
  }

  /// Answers the incoming call.
  ///
  /// This method can only be called on incoming calls that are in the ringing state.
  Future<void> answer() async {
    if (!isIncoming || !_currentState.canAnswer) {
      throw StateError('Cannot answer call in current state: $_currentState');
    }
    onAction(callId, CallAction.answer);
  }

  /// Ends the call.
  ///
  /// This method can be called on any active call to terminate it.
  Future<void> hangup() async {
    if (!_currentState.canHangup) {
      throw StateError('Cannot hangup call in current state: $_currentState');
    }
    onAction(callId, CallAction.hangup);
  }

  /// Toggles the mute state of the call.
  ///
  /// This method can only be called on active or held calls.
  Future<void> toggleMute() async {
    if (!_currentState.canMute) {
      throw StateError('Cannot mute call in current state: $_currentState');
    }

    final action = _isMuted ? CallAction.unmute : CallAction.mute;
    onAction(callId, action);
  }

  /// Toggles the hold state of the call.
  ///
  /// This method switches between active and held states.
  Future<void> toggleHold() async {
    if (_currentState == CallState.active && _currentState.canHold) {
      onAction(callId, CallAction.hold);
    } else if (_currentState == CallState.held && _currentState.canUnhold) {
      onAction(callId, CallAction.unhold);
    } else {
      throw StateError('Cannot toggle hold in current state: $_currentState');
    }
  }

  /// Sends a DTMF tone.
  ///
  /// [tone] should be a single digit (0-9), *, or #.
  /// This method can only be called on active calls.
  Future<void> dtmf(String tone) async {
    if (!_currentState.canMute) {
      // Using canMute as proxy for "can send DTMF"
      throw StateError('Cannot send DTMF in current state: $_currentState');
    }

    if (!RegExp(r'^[0-9*#]$').hasMatch(tone)) {
      throw ArgumentError('Invalid DTMF tone: $tone. Must be 0-9, *, or #');
    }

    onAction(callId, CallAction.dtmf, {'tone': tone});
  }

  /// Enables or disables speaker phone.
  ///
  /// [enable] - true to enable speaker phone, false to disable.
  /// This method can only be called on active calls.
  Future<void> enableSpeakerPhone(bool enable) async {
    if (!_currentState.canMute) {
      // Using canMute as proxy for "can enable speaker phone"
      throw StateError(
          'Cannot toggle speaker phone in current state: $_currentState');
    }

    onAction(callId, CallAction.enableSpeakerPhone, {'enable': enable});
  }

  /// Disposes of the call and closes all streams.
  ///
  /// This method should be called when the call is no longer needed
  /// to prevent memory leaks.
  void dispose() {
    _callStateController.close();
    _isMutedController.close();
    _isHeldController.close();
    _callQualityController.close();
  }

  @override
  String toString() {
    return 'Call(callId: $callId, state: $_currentState, '
        'isIncoming: $isIncoming, destination: $destination, '
        'callerName: $callerName, callerNumber: $callerNumber)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Call && other.callId == callId);

  @override
  int get hashCode => callId.hashCode;
}
