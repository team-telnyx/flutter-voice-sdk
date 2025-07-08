import 'dart:async';
import 'dart:convert';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

/// Callback function types for CallKit events.
typedef CallKitEventCallback = void Function(
    String callId, Map<String, dynamic> extra);

/// Enhanced CallKit event handler that provides a unified interface for handling
/// CallKit events across both iOS and Android platforms.
///
/// This handler manages CallKit event listeners and provides callbacks for
/// common call actions like accept, decline, end, and timeout.
class CallKitEventHandler {
  bool _disposed = false;
  StreamSubscription? _eventSubscription;

  // Event callbacks
  CallKitEventCallback? _onCallAccept;
  CallKitEventCallback? _onCallDecline;
  CallKitEventCallback? _onCallEnd;
  CallKitEventCallback? _onCallTimeout;
  CallKitEventCallback? _onCallIncoming;

  /// Creates a new CallKit event handler.
  CallKitEventHandler();

  /// Initializes the CallKit event listener.
  ///
  /// This method sets up the event stream listener for CallKit events.
  /// It should be called once during initialization.
  Future<void> initialize() async {
    if (_disposed) return;

    try {
      await _setupCallKitEventListener();
      print('CallKitEventHandler: Initialized with CallKit event listener');
    } catch (e) {
      print('CallKitEventHandler: Error during initialization: $e');
    }
  }

  /// Sets up event callbacks for various CallKit actions.
  void setEventCallbacks({
    CallKitEventCallback? onCallAccept,
    CallKitEventCallback? onCallDecline,
    CallKitEventCallback? onCallEnd,
    CallKitEventCallback? onCallTimeout,
    CallKitEventCallback? onCallIncoming,
  }) {
    _onCallAccept = onCallAccept;
    _onCallDecline = onCallDecline;
    _onCallEnd = onCallEnd;
    _onCallTimeout = onCallTimeout;
    _onCallIncoming = onCallIncoming;
  }

  /// Sets up the actual CallKit event listener.
  Future<void> _setupCallKitEventListener() async {
    _eventSubscription =
        FlutterCallkitIncoming.onEvent.listen((CallEvent? event) async {
      if (event == null || _disposed) return;

      final callId = event.body?['id']?.toString() ?? '';
      final extra = event.body?['extra'] as Map<String, dynamic>? ?? {};

      print(
          'CallKitEventHandler: Received event ${event.event} for call $callId');

      switch (event.event) {
        case Event.actionCallAccept:
          await _handleCallAccept(callId, extra);
          break;
        case Event.actionCallDecline:
          await _handleCallDecline(callId, extra);
          break;
        case Event.actionCallEnded:
          await _handleCallEnd(callId, extra);
          break;
        case Event.actionCallTimeout:
          await _handleCallTimeout(callId, extra);
          break;
        case Event.actionCallIncoming:
          await _handleCallIncoming(callId, extra);
          break;
        default:
          print('CallKitEventHandler: Unhandled event: ${event.event}');
      }
    });
  }

  /// Handles call accept events.
  Future<void> _handleCallAccept(
      String callId, Map<String, dynamic> extra) async {
    if (_disposed) return;

    try {
      print('CallKitEventHandler: Processing call accept for $callId');
      _onCallAccept?.call(callId, extra);
    } catch (e) {
      print('CallKitEventHandler: Error handling call accept: $e');
    }
  }

  /// Handles call decline events.
  Future<void> _handleCallDecline(
      String callId, Map<String, dynamic> extra) async {
    if (_disposed) return;

    try {
      print('CallKitEventHandler: Processing call decline for $callId');
      _onCallDecline?.call(callId, extra);
    } catch (e) {
      print('CallKitEventHandler: Error handling call decline: $e');
    }
  }

  /// Handles call end events.
  Future<void> _handleCallEnd(String callId, Map<String, dynamic> extra) async {
    if (_disposed) return;

    try {
      print('CallKitEventHandler: Processing call end for $callId');
      _onCallEnd?.call(callId, extra);
    } catch (e) {
      print('CallKitEventHandler: Error handling call end: $e');
    }
  }

  /// Handles call timeout events.
  Future<void> _handleCallTimeout(
      String callId, Map<String, dynamic> extra) async {
    if (_disposed) return;

    try {
      print('CallKitEventHandler: Processing call timeout for $callId');
      _onCallTimeout?.call(callId, extra);
    } catch (e) {
      print('CallKitEventHandler: Error handling call timeout: $e');
    }
  }

  /// Handles incoming call events.
  Future<void> _handleCallIncoming(
      String callId, Map<String, dynamic> extra) async {
    if (_disposed) return;

    try {
      print('CallKitEventHandler: Processing incoming call for $callId');
      _onCallIncoming?.call(callId, extra);
    } catch (e) {
      print('CallKitEventHandler: Error handling incoming call: $e');
    }
  }

  /// Extracts and decodes metadata from CallKit event extra data.
  Map<String, dynamic>? extractMetadata(Map<String, dynamic> extra) {
    try {
      final metadata = extra['metadata'];
      if (metadata == null) return null;

      if (metadata is String) {
        return jsonDecode(metadata) as Map<String, dynamic>;
      } else if (metadata is Map<String, dynamic>) {
        return metadata;
      }
      return null;
    } catch (e) {
      print('CallKitEventHandler: Error extracting metadata: $e');
      return null;
    }
  }

  /// Disposes of the event handler and cleans up resources.
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    _eventSubscription?.cancel();
    _eventSubscription = null;

    // Clear callbacks
    _onCallAccept = null;
    _onCallDecline = null;
    _onCallEnd = null;
    _onCallTimeout = null;
    _onCallIncoming = null;

    print('CallKitEventHandler: Disposed');
  }
}
