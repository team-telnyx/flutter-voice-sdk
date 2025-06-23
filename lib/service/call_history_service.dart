import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telnyx_flutter_webrtc/model/call_history_entry.dart';

class CallHistoryService {
  static const int _maxHistoryEntries = 20;
  static const String _keyPrefix = 'call_history_';

  static String _getKeyForProfile(String profileId) {
    return '$_keyPrefix$profileId';
  }

  /// Add a new call history entry for a specific profile
  static Future<void> addCallHistoryEntry({
    required String profileId,
    required CallHistoryEntry entry,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getKeyForProfile(profileId);
      
      // Get existing history
      final existingHistory = await getCallHistory(profileId);
      
      // Add new entry at the beginning
      existingHistory.insert(0, entry);
      
      // Limit to max entries (remove oldest if necessary)
      if (existingHistory.length > _maxHistoryEntries) {
        existingHistory.removeRange(_maxHistoryEntries, existingHistory.length);
      }
      
      // Save back to preferences
      final jsonList = existingHistory.map((e) => e.toJson()).toList();
      await prefs.setString(key, jsonEncode(jsonList));
    } catch (e) {
      // Non-blocking operation - log error but don't throw
      Logger().e('Error adding call history entry: $e');
    }
  }

  /// Get call history for a specific profile
  static Future<List<CallHistoryEntry>> getCallHistory(String profileId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getKeyForProfile(profileId);
      final jsonString = prefs.getString(key);
      
      if (jsonString == null) {
        return [];
      }
      
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map((json) => CallHistoryEntry.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Non-blocking operation - log error and return empty list
      Logger().e('Error getting call history: $e');
      return [];
    }
  }

  /// Clear call history for a specific profile
  static Future<void> clearCallHistory(String profileId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getKeyForProfile(profileId);
      await prefs.remove(key);
    } catch (e) {
      // Non-blocking operation - log error but don't throw
      Logger().e('Error clearing call history: $e');

    }
  }

  /// Remove a specific call history entry
  static Future<void> removeCallHistoryEntry({
    required String profileId,
    required String entryId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getKeyForProfile(profileId);
      
      // Get existing history
      final existingHistory = await getCallHistory(profileId);
      
      // Remove the entry with matching ID
      existingHistory.removeWhere((entry) => entry.id == entryId);
      
      // Save back to preferences
      final jsonList = existingHistory.map((e) => e.toJson()).toList();
      await prefs.setString(key, jsonEncode(jsonList));
    } catch (e) {
      // Non-blocking operation - log error but don't throw
      Logger().e('Error removing call history entry: $e');
    }
  }
}