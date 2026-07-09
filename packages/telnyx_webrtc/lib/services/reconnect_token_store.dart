import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Stores and retrieves the reconnect token (voice_sdk_id) and session ID
/// for session reattachment after app restart.
///
/// Ported from JS SDK `Modules/Verto/util/reconnect.ts` which uses
/// `sessionStorage`. Flutter uses `SharedPreferences` as the equivalent
/// persistent key-value store.
class ReconnectTokenStore {
  ReconnectTokenStore._();

  static const String _reconnectTokenKey = 'telnyx-voice-sdk-id';
  static const String _sessionIdKey = 'telnyx-voice-sdk-session-id';
  static const String _sessionIdStoredAtKey =
      'telnyx-voice-sdk-session-id-stored-at';
  static const String _activeCallsKey = 'telnyx-voice-sdk-active-calls';

  /// Max age (ms) for the reconnect session ID to be considered fresh.
  static const int reconnectSessionIdMaxAgeMs = 90 * 1000; // 90s

  /// Max age (ms) for the active-calls recovery marker.
  static const int recoveryMarkerMaxAgeMs = 15 * 60 * 1000; // 15 min

  // ── Reconnect token (voice_sdk_id) ────────────────────────────

  /// Get the stored reconnect token (voice_sdk_id).
  static Future<String?> getReconnectToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_reconnectTokenKey);
  }

  /// Store the reconnect token.
  static Future<void> setReconnectToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_reconnectTokenKey, token);
  }

  // ── Reconnect session ID ──────────────────────────────────────

  /// Get the stored session ID if it's still fresh, null otherwise.
  ///
  /// If the session ID is stale (> 90s), the stored entries are cleaned up.
  static Future<String?> getReconnectSessionId({int? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString(_sessionIdKey);
    if (sessionId == null) return null;

    final storedAt = prefs.getInt(_sessionIdStoredAtKey);
    if (storedAt == null) return null;

    final currentTime = now ?? DateTime.now().millisecondsSinceEpoch;
    if (currentTime - storedAt > reconnectSessionIdMaxAgeMs) {
      // Stale — clean up
      await prefs.remove(_sessionIdKey);
      await prefs.remove(_sessionIdStoredAtKey);
      return null;
    }

    return sessionId;
  }

  /// Store the session ID with a timestamp.
  static Future<void> setReconnectSessionId(
    String sessionId, {
    int? storedAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionIdKey, sessionId);
    await prefs.setInt(
      _sessionIdStoredAtKey,
      storedAt ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Check if the reconnect session ID is fresh (within max age).
  static Future<bool> isReconnectSessionIdFresh({int? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final storedAt = prefs.getInt(_sessionIdStoredAtKey);
    if (storedAt == null) return false;

    final currentTime = now ?? DateTime.now().millisecondsSinceEpoch;
    return currentTime - storedAt <= reconnectSessionIdMaxAgeMs;
  }

  // ── Active calls recovery marker ──────────────────────────────

  /// Get the stored active-calls recovery marker if still fresh.
  ///
  /// Returns null when:
  /// - Nothing is stored
  /// - The calls list is empty
  /// - The marker is stale (> 15 min)
  /// - The stored JSON is malformed
  ///
  /// Stale or malformed entries are cleaned up automatically.
  static Future<StoredActiveCalls?> getActiveCallsRecoveryMarker({
    int? now,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_activeCallsKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final parsed = jsonDecode(raw) as Map<String, dynamic>;
      final callsList = parsed['calls'] as List?;
      if (callsList == null || callsList.isEmpty) {
        await prefs.remove(_activeCallsKey);
        return null;
      }

      final storedAt = parsed['storedAt'] as int?;
      if (storedAt == null) {
        await prefs.remove(_activeCallsKey);
        return null;
      }

      final currentTime = now ?? DateTime.now().millisecondsSinceEpoch;
      if (currentTime - storedAt > recoveryMarkerMaxAgeMs) {
        await prefs.remove(_activeCallsKey);
        return null;
      }

      return StoredActiveCalls.fromJson(parsed);
    } catch (_) {
      await prefs.remove(_activeCallsKey);
      return null;
    }
  }

  /// Persist the active-calls recovery marker.
  ///
  /// If [calls] is empty, the existing marker is cleared (no point
  /// storing an empty recovery marker).
  static Future<void> setActiveCallsRecoveryMarker(
    List<StoredActiveCall> calls,
    String sessionId, {
    int? storedAt,
  }) async {
    if (calls.isEmpty) {
      await clearActiveCallsRecoveryMarker();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final payload = StoredActiveCalls(
      sessionId: sessionId,
      calls: calls,
      storedAt: storedAt ?? DateTime.now().millisecondsSinceEpoch,
    );
    await prefs.setString(_activeCallsKey, jsonEncode(payload.toJson()));
  }

  /// Remove the active-calls recovery marker.
  static Future<void> clearActiveCallsRecoveryMarker() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeCallsKey);
  }

  // ── Clear all ─────────────────────────────────────────────────

  /// Clear all reconnect-related storage.
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_reconnectTokenKey);
    await prefs.remove(_sessionIdKey);
    await prefs.remove(_sessionIdStoredAtKey);
    await prefs.remove(_activeCallsKey);
  }
}

/// Narrow projection of an active call for persistence.
///
/// Only [id] and [customHeaders] are stored — no SDP, credentials,
/// streams, or peer connection references.
class StoredActiveCall {
  /// The unique identifier of the stored call.
  final String id;

  /// Custom SIP headers associated with the call.
  final List<Map<String, String>> customHeaders;

  /// Creates a stored active-call projection.
  StoredActiveCall({required this.id, required this.customHeaders});

  /// Serializes this stored call to a JSON-encodable map.
  Map<String, dynamic> toJson() => {
        'id': id,
        'customHeaders': customHeaders,
      };

  /// Creates a stored active call from a decoded JSON map.
  factory StoredActiveCall.fromJson(Map<String, dynamic> json) {
    return StoredActiveCall(
      id: json['id'] as String,
      customHeaders: (json['customHeaders'] as List? ?? [])
          .map((e) => Map<String, String>.from(e as Map))
          .toList(),
    );
  }
}

/// Stored active-calls recovery marker persisted across app restarts.
class StoredActiveCalls {
  /// The SDK session identifier these calls belong to.
  final String sessionId;

  /// The active calls captured for recovery.
  final List<StoredActiveCall> calls;

  /// Epoch timestamp in ms when this marker was persisted.
  final int storedAt;

  /// Creates a stored active-calls recovery marker.
  StoredActiveCalls({
    required this.sessionId,
    required this.calls,
    required this.storedAt,
  });

  /// Serializes this recovery marker to a JSON-encodable map.
  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'calls': calls.map((c) => c.toJson()).toList(),
        'storedAt': storedAt,
      };

  /// Creates a stored active-calls marker from a decoded JSON map.
  factory StoredActiveCalls.fromJson(Map<String, dynamic> json) {
    return StoredActiveCalls(
      sessionId: json['sessionId'] as String,
      calls: (json['calls'] as List)
          .map((c) => StoredActiveCall.fromJson(c as Map<String, dynamic>))
          .toList(),
      storedAt: json['storedAt'] as int,
    );
  }
}
