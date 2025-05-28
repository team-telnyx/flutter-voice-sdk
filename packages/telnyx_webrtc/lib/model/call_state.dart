import 'package:telnyx_webrtc/model/network_reason.dart';
import 'package:telnyx_webrtc/model/call_termination_reason.dart';

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
  /// A call will remain in this state for the time specified within the configuration used to log in. The default value is 60 seconds,
  /// transitioning to [dropped] if the reconnection is not successful.
  reconnecting,

  /// [dropped] The call has been dropped - for this state a [NetworkReason] is provided.
  dropped,

  /// [done] the call is finished - for this state a [CallTerminationReason] may be provided.
  done,

  /// [error] there was an issue creating the call.
  error;

  static final Map<CallState, NetworkReason?> _networkReasons = {};
  static final Map<CallState, CallTerminationReason?> _terminationReasons = {};

  /// Set the network reason for the call state - only for [reconnecting] or [dropped].
  CallState withNetworkReason(NetworkReason reason) {
    if (this != reconnecting && this != dropped) {
      throw StateError(
          'Network reason can only be set for reconnecting or dropped states');
    }
    _networkReasons[this] = reason;
    return this;
  }

  /// Set the termination reason for the call state - only for [done].
  CallState withTerminationReason(CallTerminationReason? reason) {
    if (this != done) {
      throw StateError('Termination reason can only be set for done state');
    }
    _terminationReasons[this] = reason;
    return this;
  }

  /// Get the network reason for [reconnecting] or [dropped] states.
  NetworkReason? get networkReason => _networkReasons[this];

  /// Get the termination reason for [done] state.
  CallTerminationReason? get terminationReason => _terminationReasons[this];

  /// Returns true if the call is actively attempting to reconnect to the remote client.
  bool get isReconnecting => this == reconnecting;

  /// Returns true if the call is actively attempting to reconnect to the remote client.
  bool get isActive => this == active;

  /// Returns true if the call has been dropped.
  bool get isDropped => this == dropped;

  /// Returns true if the call is completed.
  bool get isDone => this == done;
}
