import 'package:telnyx_webrtc/model/network_reason.dart';

/// Represents the state of a call.
enum CallState {
  /// [newCall] The call has been created but not yet connected.
  newCall,

  /// [connecting] the call is being connected to the remote client
  connecting,

  /// [ringing] the call invitation has been extended, we are waiting for an answer.
  ringing,

  /// [active] the call is active and the two clients are fully connected.
  active,

  /// [held] the user has put the call on hold.
  held,

  /// [reconnecting] The call is reconnecting - for this state a [NetworkReason] is provided.
  ///A call will remain in this state for the time specified within the configuration used to log in. The default value is 60 seconds'
  /// transitioning to [dropped] if the reconnection is not successful.
  reconnecting,

  /// [dropped] The call has been dropped - for this state a [NetworkReason] is provided.
  dropped,

  /// [done] the call is finished - either party has ended the call.
  done,

  /// [error] there was an issue creating the call.
  error;

  static final Map<CallState, NetworkReason?> _reasons = {};

  /// Get the reason for the call state - only valid for [reconnecting] and [dropped] states.
  NetworkReason? get reason => _reasons[this];

  /// Set the reason for the call state - only valid for [reconnecting] and [dropped] states.
  CallState withReason(NetworkReason reason) {
    if (this != reconnecting && this != dropped) {
      throw StateError(
          'Reason can only be set for reconnecting or dropped states',);
    }
    _reasons[this] = reason;
    return this;
  }

  /// Returns true if the call is actively attempting to reconnect to the remote client.
  bool get isReconnecting => this == reconnecting;

  /// Returns true if the call has been dropped.
  bool get isDropped => this == dropped;
}
