import 'dart:async';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'callkit_adapter.dart';
import 'callkit_event_handler.dart';

/// Centralized manager for all CallKit operations.
///
/// This class provides a high-level interface for managing native call UI
/// throughout the application lifecycle. It handles both incoming and outgoing
/// calls, ensuring consistent CallKit behavior across all scenarios.
/// 
/// Now uses CallKitEventHandler for unified event processing with metadata extraction.
class CallKitManager {
  CallKitAdapter? _adapter;
  CallKitEventHandler? _eventHandler;
  bool _initialized = false;
  bool _disposed = false;

  // Track active calls to prevent duplicate UI
  final Set<String> _activeCalls = {};

  /// Whether native UI is enabled
  final bool enableNativeUI;

  // Store callbacks for routing
  void Function(String callId)? _onCallAccepted;
  void Function(String callId)? _onCallDeclined;
  void Function(String callId)? _onCallEnded;
  
  // Callback for when push notification is accepted (with metadata)
  void Function(String callId, Map<String, dynamic> extra)? _onPushNotificationAccepted;

  /// Creates a new CallKitManager instance.
  CallKitManager({required this.enableNativeUI});

  /// Initializes the CallKit manager with event callbacks.
  /// 
  /// [onPushNotificationAccepted] - Optional callback for push notification acceptance with metadata
  Future<void> initialize({
    required void Function(String callId) onCallAccepted,
    required void Function(String callId) onCallDeclined,
    required void Function(String callId) onCallEnded,
    void Function(String callId, Map<String, dynamic> extra)? onPushNotificationAccepted,
  }) async {
    if (!enableNativeUI || _initialized || _disposed) return;

    // Store callbacks
    _onCallAccepted = onCallAccepted;
    _onCallDeclined = onCallDeclined;
    _onCallEnded = onCallEnded;
    _onPushNotificationAccepted = onPushNotificationAccepted;

    // Create the adapter for UI operations (without event listening)
    _adapter = CallKitAdapter(
      onCallAccepted: (callId) {}, // Dummy callback - events handled by _eventHandler
      onCallDeclined: (callId) {}, // Dummy callback - events handled by _eventHandler
      onCallEnded: (callId) {}, // Dummy callback - events handled by _eventHandler
    );
    
    // Initialize the adapter but DO NOT call initialize() to avoid duplicate event listeners
    // The _eventHandler will handle all events
    
    // Create and initialize the event handler for unified event processing
    _eventHandler = CallKitEventHandler();
    await _eventHandler!.initialize();
    
    // Set up event callbacks with smart routing based on metadata
    _eventHandler!.setEventCallbacks(
      onCallAccept: _handleCallAcceptWithMetadata,
      onCallDecline: _handleCallDeclineWithMetadata,
      onCallEnd: _handleCallEndWithMetadata,
      onCallTimeout: _handleCallTimeoutWithMetadata,
      onCallIncoming: (callId, extra) {
        debugPrint('CallKitManager: Incoming call event for $callId');
      },
    );

    _initialized = true;
    debugPrint('CallKitManager: Initialized with unified event handling');
  }

  /// Handles call accept events with smart routing based on metadata presence.
  void _handleCallAcceptWithMetadata(String callId, Map<String, dynamic> extra) {
    debugPrint('[PUSH-DIAG] CallKitManager: Accept event received for $callId');
    debugPrint('[PUSH-DIAG] CallKitManager: extra.keys=${extra.keys.toList()}');
    
    // Extract metadata to determine routing
    final metadata = _eventHandler?.extractMetadata(extra);
    debugPrint('[PUSH-DIAG] CallKitManager: Metadata extracted=${metadata != null}');
    
    if (metadata != null && _onPushNotificationAccepted != null) {
      // Route to push notification handling (terminated state)
      debugPrint('[PUSH-DIAG] CallKitManager: Routing to push notification handler');
      _onPushNotificationAccepted!(callId, extra);
    } else {
      // Route to standard foreground handling
      debugPrint('[PUSH-DIAG] CallKitManager: Routing to foreground call handler');
      _onCallAccepted?.call(callId);
    }
  }

  /// Handles call decline events with smart routing.
  void _handleCallDeclineWithMetadata(String callId, Map<String, dynamic> extra) {
    debugPrint('CallKitManager: Decline event received for $callId');
    
    // For decline, we can route to both paths if needed
    // but typically foreground decline is sufficient
    _onCallDeclined?.call(callId);
  }

  /// Handles call end events with smart routing.
  void _handleCallEndWithMetadata(String callId, Map<String, dynamic> extra) {
    debugPrint('CallKitManager: End event received for $callId');
    _onCallEnded?.call(callId);
  }

  /// Handles call timeout events.
  void _handleCallTimeoutWithMetadata(String callId, Map<String, dynamic> extra) {
    debugPrint('CallKitManager: Timeout event received for $callId - treating as decline');
    _onCallDeclined?.call(callId);
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
      debugPrint('CallKitManager: Error showing incoming call: $e');
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
      debugPrint('CallKitManager: Error showing outgoing call: $e');
      _activeCalls.remove(callId);
    }
  }

  /// Updates the call as connected in the native UI.
  Future<void> setCallConnected(String callId) async {
    if (!_isCallActive(callId)) return;

    try {
      await _adapter?.setCallConnected(callId);
    } catch (e) {
      debugPrint('CallKitManager: Error setting call connected: $e');
    }
  }

  /// Ends a call in the native UI.
  Future<void> endCall(String callId) async {
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
      debugPrint('CallKitManager: Error getting active calls: $e');
      return [];
    }
  }

  /// Checks if we can show call UI for this call ID.
  bool _canShowCallUI(String callId) {
    if (!enableNativeUI || !_initialized || _disposed) return false;

    // Prevent duplicate UI for the same call
    if (_activeCalls.contains(callId)) {
      debugPrint('CallKitManager: Call UI already shown for $callId');
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

    _eventHandler?.dispose();
    _eventHandler = null;
    _adapter?.dispose();
    _adapter = null;
    _activeCalls.clear();
    
    // Clear callbacks
    _onCallAccepted = null;
    _onCallDeclined = null;
    _onCallEnded = null;
    _onPushNotificationAccepted = null;
  }
}
