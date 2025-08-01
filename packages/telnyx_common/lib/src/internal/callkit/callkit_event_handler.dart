import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart'; // For debugPrint
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
      debugPrint(
          'CallKitEventHandler: Initialized with CallKit event listener');
    } catch (e) {
      debugPrint('CallKitEventHandler: Error during initialization: $e');
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
      final extra = _safeConvertToStringDynamicMap(event.body?['extra']);

      // [PUSH-DIAG] Log raw event data
      debugPrint('[PUSH-DIAG] CallKitEventHandler: Raw event received');
      debugPrint('[PUSH-DIAG] CallKitEventHandler: event.event=${event.event}');
      debugPrint('[PUSH-DIAG] CallKitEventHandler: event.body=${event.body}');
      debugPrint(
          '[PUSH-DIAG] CallKitEventHandler: event.body.runtimeType=${event.body?.runtimeType}');
      debugPrint('[PUSH-DIAG] CallKitEventHandler: callId=$callId');
      debugPrint(
          '[PUSH-DIAG] CallKitEventHandler: extra after conversion=$extra');

      debugPrint(
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
          debugPrint('CallKitEventHandler: Unhandled event: ${event.event}');
      }
    });
  }

  /// Safely converts any object to Map<String, dynamic>.
  ///
  /// This handles cases where the object might be _Map<Object?, Object?>
  /// or other map types that need to be converted safely.
  Map<String, dynamic> _safeConvertToStringDynamicMap(dynamic value) {
    if (value == null) {
      return <String, dynamic>{};
    }

    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      try {
        // Convert any Map type to Map<String, dynamic>
        final result = <String, dynamic>{};
        value.forEach((key, val) {
          if (key != null) {
            result[key.toString()] = val;
          }
        });
        return result;
      } catch (e) {
        debugPrint('CallKitEventHandler: Error converting map: $e');
        return <String, dynamic>{};
      }
    }

    // If it's not a map at all, return empty map
    debugPrint(
        'CallKitEventHandler: Expected Map but got ${value.runtimeType}');
    return <String, dynamic>{};
  }

  /// Handles call accept events.
  Future<void> _handleCallAccept(
      String callId, Map<String, dynamic> extra) async {
    if (_disposed) return;

    try {
      // [PUSH-DIAG] Log accept event details
      debugPrint('[PUSH-DIAG] CallKitEventHandler: Accept event for $callId');
      debugPrint(
          '[PUSH-DIAG] CallKitEventHandler: extra.keys=${extra.keys.toList()}');
      debugPrint('[PUSH-DIAG] CallKitEventHandler: extra=$extra');

      // Try to extract metadata
      final metadata = extractMetadata(extra);
      debugPrint(
          '[PUSH-DIAG] CallKitEventHandler: Metadata extraction result=$metadata');
      debugPrint(
          '[PUSH-DIAG] CallKitEventHandler: Metadata extraction result is null=${metadata == null}');
      debugPrint(
          '[PUSH-DIAG] CallKitEventHandler: Decision=${metadata != null ? "PUSH" : "FOREGROUND"}');

      debugPrint('CallKitEventHandler: Processing call accept for $callId');
      _onCallAccept?.call(callId, extra);
    } catch (e) {
      debugPrint('CallKitEventHandler: Error handling call accept: $e');
    }
  }

  /// Handles call decline events.
  Future<void> _handleCallDecline(
      String callId, Map<String, dynamic> extra) async {
    if (_disposed) return;

    try {
      debugPrint('CallKitEventHandler: Processing call decline for $callId');
      _onCallDecline?.call(callId, extra);
    } catch (e) {
      debugPrint('CallKitEventHandler: Error handling call decline: $e');
    }
  }

  /// Handles call end events.
  Future<void> _handleCallEnd(String callId, Map<String, dynamic> extra) async {
    if (_disposed) return;

    try {
      debugPrint('CallKitEventHandler: Processing call end for $callId');
      _onCallEnd?.call(callId, extra);
    } catch (e) {
      debugPrint('CallKitEventHandler: Error handling call end: $e');
    }
  }

  /// Handles call timeout events.
  Future<void> _handleCallTimeout(
      String callId, Map<String, dynamic> extra) async {
    if (_disposed) return;

    try {
      debugPrint('CallKitEventHandler: Processing call timeout for $callId');
      _onCallTimeout?.call(callId, extra);
    } catch (e) {
      debugPrint('CallKitEventHandler: Error handling call timeout: $e');
    }
  }

  /// Handles incoming call events.
  Future<void> _handleCallIncoming(
      String callId, Map<String, dynamic> extra) async {
    if (_disposed) return;

    try {
      debugPrint('CallKitEventHandler: Processing incoming call for $callId');
      _onCallIncoming?.call(callId, extra);
    } catch (e) {
      debugPrint('CallKitEventHandler: Error handling incoming call: $e');
    }
  }

  /// Extracts and decodes metadata from CallKit event extra data.
  Map<String, dynamic>? extractMetadata(Map<String, dynamic> extra) {
    try {
      // First, try to get metadata from the standard location
      var metadata = extra['metadata'];

      // On iOS, the push notification payload includes an 'aps' wrapper
      // So if metadata is not found at extra['metadata'], check if it exists
      // at the root level alongside 'aps'
      if (metadata == null && extra.containsKey('aps')) {
        // This is likely an iOS push notification with aps wrapper
        // Look for metadata at the root level
        final extraKeys = extra.keys.where((key) => key != 'aps').toList();
        if (extraKeys.contains('metadata')) {
          metadata = extra['metadata'];
        }
      }

      if (metadata == null) return null;

      if (metadata is String) {
        return jsonDecode(metadata) as Map<String, dynamic>;
      } else if (metadata is Map<String, dynamic>) {
        return metadata;
      } else if (metadata is Map) {
        // Handle case where metadata is Map but not the exact type (common on iOS)
        return Map<String, dynamic>.from(metadata);
      }
      return null;
    } catch (e) {
      debugPrint('CallKitEventHandler: Error extracting metadata: $e');
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

    debugPrint('CallKitEventHandler: Disposed');
  }
}
