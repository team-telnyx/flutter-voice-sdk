import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:telnyx_webrtc/utils/constants.dart';

import 'package:telnyx_webrtc/utils/logging/global_logger.dart';

/// Class to handle the storage of preferences
/// such as metadata and notification settings
class PreferencesStorage {
  /// Key for the notification settings
  static final String notificationKey = Constants.notificationKey;

  static Future<Map<String, dynamic>?> getMetaData() async {
    final String metaData = await getString(notificationKey);
    if (metaData.isEmpty) {
      GlobalLogger.logger.d('No PushMetaData found with notification key $notificationKey');
      return null;
    }
    saveMetadata('');
    return jsonDecode(metaData);
  }

  /// Save the push metadata to the shared preferences
  static void saveMetadata(String metaData) {
    GlobalLogger.logger.i('Save PushMetaData $metaData');
    saveString(notificationKey, metaData);
  }

  /// Save a string instance to the shared preferences
  static Future<void> saveString(String key, String data) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, data);
  }

  /// Get a string instance from the shared preferences
  static Future<String> getString(String key) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? preferences = prefs.getString(key);
    if (preferences != null) {
      return preferences;
    } else {
      return '';
    }
  }

  /// Save a boolean instance to the shared preferences
  static Future<void> saveBool(bool data, String key) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, data);
  }

  /// Get a boolean instance from the shared preferences
  static Future<bool> getBool(String key) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool? value = prefs.getBool(key);
    if (value != null) {
      return value;
    } else {
      return false;
    }
  }
}
