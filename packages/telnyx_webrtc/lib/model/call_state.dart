import 'package:telnyx_webrtc/model/call_termination_reason.dart';
import 'package:telnyx_webrtc/model/network_reason.dart';

/// Represents the state of a call.
/// 
/// This is a sealed class hierarchy that allows states to carry associated data.
abstract class CallState {
  /// The string representation of the call state.
  final String name;

  /// Creates a new [CallState] instance.
  const CallState(this.name);

  /// Returns true if the call is actively attempting to reconnect to the remote client.
  bool get isReconnecting => this is ReconnectingState;

  /// Returns true if the call has been dropped.
  bool get isDropped => this is DroppedState;

  /// Returns true if the call is done.
  bool get isDone => this is DoneState;

  /// Returns true if the call is active.
  bool get isActive => this is ActiveState;

  /// Returns true if the call is in error state.
  bool get isError => this is ErrorState;

  /// Returns true if the call is in ringing state.
  bool get isRinging => this is RingingState;

  /// Returns true if the call is in connecting state.
  bool get isConnecting => this is ConnectingState;

  /// Returns true if the call is in new state.
  bool get isNew => this is NewState;

  /// Returns true if the call is in held state.
  bool get isHeld => this is HeldState;

  /// Factory method to create a new call state.
  factory CallState.newCall() = NewState;

  /// Factory method to create a connecting call state.
  factory CallState.connecting() = ConnectingState;

  /// Factory method to create a ringing call state.
  factory CallState.ringing() = RingingState;

  /// Factory method to create an active call state.
  factory CallState.active() = ActiveState;

  /// Factory method to create a held call state.
  factory CallState.held() = HeldState;

  /// Factory method to create a reconnecting call state.
  factory CallState.reconnecting(NetworkReason reason) = ReconnectingState;

  /// Factory method to create a dropped call state.
  factory CallState.dropped(NetworkReason reason) = DroppedState;

  /// Factory method to create a done call state.
  factory CallState.done([CallTerminationReason? reason]) = DoneState;

  /// Factory method to create an error call state.
  factory CallState.error() = ErrorState;

  /// Helper method to convert from the old enum-based CallState to the new class-based CallState.
  /// This is for backward compatibility during the transition.
  @Deprecated('Use the factory constructors instead')
  static CallState fromLegacyEnum(
    dynamic legacyState, {
    NetworkReason? networkReason,
    CallTerminationReason? terminationReason,
  }) {
    // Handle both string names and the actual enum values
    final String stateName = legacyState is String ? legacyState : legacyState.toString().split('.').last;
    
    switch (stateName) {
      case 'newCall':
        return CallState.newCall();
      case 'connecting':
        return CallState.connecting();
      case 'ringing':
        return CallState.ringing();
      case 'active':
        return CallState.active();
      case 'held':
        return CallState.held();
      case 'reconnecting':
        return CallState.reconnecting(networkReason ?? NetworkReason.networkLost);
      case 'dropped':
        return CallState.dropped(networkReason ?? NetworkReason.networkLost);
      case 'done':
        return CallState.done(terminationReason);
      case 'error':
        return CallState.error();
      default:
        throw ArgumentError('Unknown call state: $stateName');
    }
  }

  @override
  String toString() => name;
}

/// The call has been created but not yet connected.
class NewState extends CallState {
  /// Creates a new [NewState] instance.
  const NewState() : super('newCall');
}

/// The call is being connected to the remote client.
class ConnectingState extends CallState {
  /// Creates a new [ConnectingState] instance.
  const ConnectingState() : super('connecting');
}

/// The call invitation has been extended, we are waiting for an answer.
class RingingState extends CallState {
  /// Creates a new [RingingState] instance.
  const RingingState() : super('ringing');
}

/// The call is active and the two clients are fully connected.
class ActiveState extends CallState {
  /// Creates a new [ActiveState] instance.
  const ActiveState() : super('active');
}

/// The user has put the call on hold.
class HeldState extends CallState {
  /// Creates a new [HeldState] instance.
  const HeldState() : super('held');
}

/// The call is being reconnected after a network issue.
class ReconnectingState extends CallState {
  /// The reason for the reconnection.
  final NetworkReason reason;

  /// Creates a new [ReconnectingState] instance.
  const ReconnectingState(this.reason) : super('reconnecting');

  @override
  String toString() => '$name: ${reason.message}';
}

/// The call was dropped as a result of network issues.
class DroppedState extends CallState {
  /// The reason for the drop.
  final NetworkReason reason;

  /// Creates a new [DroppedState] instance.
  const DroppedState(this.reason) : super('dropped');

  @override
  String toString() => '$name: ${reason.message}';
}

/// The call is finished - either party has ended the call.
class DoneState extends CallState {
  /// The reason for the termination, if available.
  final CallTerminationReason? reason;

  /// Creates a new [DoneState] instance.
  const DoneState([this.reason]) : super('done');

  @override
  String toString() {
    if (reason == null) {
      return name;
    }
    return '$name: $reason';
  }
}

/// There was an issue creating the call.
class ErrorState extends CallState {
  /// Creates a new [ErrorState] instance.
  const ErrorState() : super('error');
}

/// Extension methods to provide backward compatibility with the old enum-based API.
extension CallStateBackwardCompatibility on CallState {
  /// Get the network reason for reconnecting or dropped states.
  NetworkReason? get networkReason {
    if (this is ReconnectingState) {
      return (this as ReconnectingState).reason;
    } else if (this is DroppedState) {
      return (this as DroppedState).reason;
    }
    return null;
  }

  /// Get the termination reason for done state.
  CallTerminationReason? get terminationReason {
    if (this is DoneState) {
      return (this as DoneState).reason;
    }
    return null;
  }
}
