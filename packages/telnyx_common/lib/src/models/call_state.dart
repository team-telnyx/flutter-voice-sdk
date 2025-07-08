/// Represents the state of a call.
///
/// This enum provides a comprehensive set of call states that cover the
/// entire lifecycle of a call, from initiation to termination.
enum CallState {
  /// Call is being initiated (outgoing calls).
  initiating,

  /// Call is ringing (incoming or outgoing).
  ringing,

  /// Call is connected and active.
  active,

  /// Call is on hold.
  held,

  /// Call has ended normally.
  ended,

  /// Call is in an error state.
  error,

  /// Call is attempting to reconnect due to network issues.
  reconnecting;

  /// Whether the call can be answered.
  bool get canAnswer => this == CallState.ringing;

  /// Whether the call can be hung up.
  bool get canHangup => [
        CallState.initiating,
        CallState.ringing,
        CallState.active,
        CallState.held,
        CallState.reconnecting,
      ].contains(this);

  /// Whether the call can be put on hold.
  bool get canHold => this == CallState.active;

  /// Whether the call can be taken off hold.
  bool get canUnhold => this == CallState.held;

  /// Whether the call can be muted.
  bool get canMute => [CallState.active, CallState.held].contains(this);

  /// Whether the call is currently active (connected).
  bool get isActive => this == CallState.active;

  /// Whether the call is terminated (ended or error).
  bool get isTerminated => [CallState.ended, CallState.error].contains(this);

  /// Whether the call is in a stable state (not transitioning).
  bool get isStable => [
        CallState.active,
        CallState.held,
        CallState.ended,
        CallState.error,
      ].contains(this);
}
