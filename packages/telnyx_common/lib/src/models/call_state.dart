/// Represents the state of a call in the telnyx_common module.
///
/// This enum provides a simplified, high-level view of call states that
/// abstracts away the complexity of the underlying WebRTC state machine.
enum CallState {
  /// The call is being initiated (outgoing call).
  initiating,
  
  /// The call is ringing (incoming or outgoing).
  ringing,
  
  /// The call is currently active and connected.
  active,
  
  /// The call is on hold.
  held,
  
  /// The call has ended.
  ended,
  
  /// The call is in an error state.
  error,
  
  /// The call is attempting to reconnect due to network issues.
  reconnecting,
}

extension CallStateExtension on CallState {
  /// Returns true if the call is in a state where it can be answered.
  bool get canAnswer => this == CallState.ringing;
  
  /// Returns true if the call is in a state where it can be hung up.
  bool get canHangup => [
    CallState.initiating,
    CallState.ringing,
    CallState.active,
    CallState.held,
    CallState.reconnecting,
  ].contains(this);
  
  /// Returns true if the call is in a state where it can be put on hold.
  bool get canHold => this == CallState.active;
  
  /// Returns true if the call is in a state where it can be taken off hold.
  bool get canUnhold => this == CallState.held;
  
  /// Returns true if the call is in a state where it can be muted.
  bool get canMute => [CallState.active, CallState.held].contains(this);
  
  /// Returns true if the call is currently active and connected.
  bool get isActive => this == CallState.active;
  
  /// Returns true if the call has ended or is in an error state.
  bool get isTerminated => [CallState.ended, CallState.error].contains(this);
}