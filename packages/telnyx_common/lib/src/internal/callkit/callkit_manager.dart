import 'dart:async';
import 'callkit_adapter.dart';

/// Centralized manager for all CallKit operations.
///
/// This class provides a high-level interface for managing native call UI
/// throughout the application lifecycle. It handles both incoming and outgoing
/// calls, ensuring consistent CallKit behavior across all scenarios.
class CallKitManager {
  CallKitAdapter? _adapter;
  bool _initialized = false;
  bool _disposed = false;

  // Track active calls to prevent duplicate UI
  final Set<String> _activeCalls = {};

  /// Whether native UI is enabled
  final bool enableNativeUI;

  /// Creates a new CallKitManager instance.
  CallKitManager({required this.enableNativeUI});

  /// Initializes the CallKit manager with event callbacks.
  Future<void> initialize({
    required void Function(String callId) onCallAccepted,
    required void Function(String callId) onCallDeclined,
    required void Function(String callId) onCallEnded,
  }) async {
    if (!enableNativeUI || _initialized || _disposed) return;

    _adapter = CallKitAdapter(
      onCallAccepted: onCallAccepted,
      onCallDeclined: onCallDeclined,
      onCallEnded: onCallEnded,
    );

    await _adapter!.initialize();
    _initialized = true;
  }

  /// Shows the native incoming call UI.
  Future<void> showIncomingCall({
    required String callId,
    required String callerName,
    required String callerNumber,
    Map<String, dynamic> extra = const {},
  }) async {
    if (!_canShowCallUI(callId)) return;

    _activeCalls.add(callId);

    try {
      await _adapter?.showIncomingCall(
        callId: callId,
        callerName: callerName,
        callerNumber: callerNumber,
        extra: extra,
      );
    } catch (e) {
      print('CallKitManager: Error showing incoming call: $e');
      _activeCalls.remove(callId);
    }
  }

  /// Shows the native outgoing call UI.
  Future<void> showOutgoingCall({
    required String callId,
    required String callerName,
    required String destination,
    Map<String, dynamic> extra = const {},
  }) async {
    if (!_canShowCallUI(callId)) return;

    _activeCalls.add(callId);

    try {
      await _adapter?.startOutgoingCall(
        callId: callId,
        destination: destination,
        callerName: callerName,
        extra: extra,
      );
    } catch (e) {
      print('CallKitManager: Error showing outgoing call: $e');
      _activeCalls.remove(callId);
    }
  }

  /// Updates the call as connected in the native UI.
  Future<void> setCallConnected(String callId) async {
    if (!_isCallActive(callId)) return;

    try {
      await _adapter?.setCallConnected(callId);
    } catch (e) {
      print('CallKitManager: Error setting call connected: $e');
    }
  }

  /// Ends a call in the native UI.
  Future<void> endCall(String callId) async {
    if (!_isCallActive(callId)) return;

    try {
      await _adapter?.endCall(callId);
    } finally {
      _activeCalls.remove(callId);
    }
  }

  /// Hides the incoming call UI (Android only).
  Future<void> hideIncomingCall({
    required String callId,
    required String callerName,
    required String callerNumber,
  }) async {
    if (!_isCallActive(callId)) return;

    try {
      await _adapter?.hideIncomingCall(callId, callerName, callerNumber);
    } finally {
      _activeCalls.remove(callId);
    }
  }

  /// Gets the list of active calls from CallKit.
  Future<List<Map<String, dynamic>>> getActiveCalls() async {
    if (!enableNativeUI || !_initialized) return [];

    try {
      return await _adapter?.getActiveCalls() ?? [];
    } catch (e) {
      print('CallKitManager: Error getting active calls: $e');
      return [];
    }
  }

  /// Checks if we can show call UI for this call ID.
  bool _canShowCallUI(String callId) {
    if (!enableNativeUI || !_initialized || _disposed) return false;

    // Prevent duplicate UI for the same call
    if (_activeCalls.contains(callId)) {
      print('CallKitManager: Call UI already shown for $callId');
      return false;
    }

    return true;
  }

  /// Checks if a call is currently active.
  bool _isCallActive(String callId) {
    return enableNativeUI &&
        _initialized &&
        !_disposed &&
        _activeCalls.contains(callId);
  }

  /// Disposes of the CallKit manager and cleans up resources.
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    _adapter?.dispose();
    _adapter = null;
    _activeCalls.clear();
  }
}
