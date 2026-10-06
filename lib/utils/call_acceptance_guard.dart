/// Serializes incoming-call acceptance by stable call identifier.
///
/// CallKit can emit the same answer action more than once. The first handler
/// must claim the call synchronously, before either handler reaches an async
/// gap, otherwise both can invoke the SDK answer path.
class CallAcceptanceGuard {
  String? _claimedCallId;

  String? get claimedCallId => _claimedCallId;

  bool tryClaim(String? callId) {
    final normalizedCallId = callId?.trim();
    if (normalizedCallId == null || normalizedCallId.isEmpty) {
      return false;
    }
    // A client may have only one call in the answering/active lifecycle.
    // Reject both duplicate callbacks for that call and attempts to claim a
    // different call until the current lifecycle releases the slot.
    if (_claimedCallId != null) {
      return false;
    }
    _claimedCallId = normalizedCallId;
    return true;
  }

  void release(String? callId) {
    if (_claimedCallId == callId?.trim()) {
      _claimedCallId = null;
    }
  }

  void reset() {
    _claimedCallId = null;
  }
}
