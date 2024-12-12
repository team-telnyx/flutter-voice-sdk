import 'dart:convert';

import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telnyx_webrtc/utils/constants.dart';

class PreferencesStorage {
  static final String notificationKey = Constants.notificationKey;

  static Future<Map<String, dynamic>?> getMetaData() async {
    final String metaData = await getString(notificationKey);
    if (metaData.isEmpty) {
      print('No Metadata found');
      return null;
    }
    saveMetadata('');
    return jsonDecode(metaData);
  }

  static void saveMetadata(String metaData) {
    Logger().i('Save meta data $metaData');
    saveString(notificationKey, metaData);
  }

  static Future<void> saveString(String key, String data) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, data);
  }

  static Future<String> getString(String key) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? preferences = prefs.getString(key);
    if (preferences != null) {
      return preferences;
    } else {
      return '';
    }
  }

  static Future<void> saveBool(bool data, String key) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, data);
  }

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
