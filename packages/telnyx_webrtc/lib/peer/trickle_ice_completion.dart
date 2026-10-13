/// Tracks trickle ICE completion for the active call.
///
/// WebRTC can report completion either through a null candidate or through the
/// ICE gathering state. This guard makes both paths safe to handle while
/// ensuring the signaling layer emits `end-of-candidates` exactly once.
final class TrickleIceCompletion {
  String? _callId;
  bool _completed = false;

  /// Starts tracking ICE gathering for [callId].
  void begin(String callId) {
    _callId = callId;
    _completed = false;
  }

  /// Marks completion as signaled for [callId] and returns whether the caller
  /// should signal it: true once per gathering, false for another call or a
  /// repeat.
  bool trySignal(String callId) {
    if (_callId != callId || _completed) {
      return false;
    }
    _completed = true;
    return true;
  }

  /// Clears the active gathering state.
  void reset() {
    _callId = null;
    _completed = false;
  }
}
