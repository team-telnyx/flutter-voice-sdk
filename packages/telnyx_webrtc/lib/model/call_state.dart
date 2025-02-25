import 'network_reason.dart';

enum CallState {
  newCall,
  connecting,
  ringing,
  active,
  held,
  reconnecting,
  dropped,
  done,
  error;

  NetworkReason? _reason;

  NetworkReason? get reason => _reason;

  CallState withReason(NetworkReason reason) {
    if (this != reconnecting && this != dropped) {
      throw StateError('Reason can only be set for reconnecting or dropped states');
    }
    _reason = reason;
    return this;
  }

  bool get isReconnecting => this == reconnecting;
  bool get isDropped => this == dropped;
}
