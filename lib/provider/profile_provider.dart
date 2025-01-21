import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telnyx_flutter_webrtc/model/profile_model.dart';

class ProfileProvider with ChangeNotifier {
  static const String _profilesKey = 'profiles';
  static const String _selectedProfileKey = 'selected_profile';
  List<Profile> _profiles = [];
  Profile? _selectedProfile;

  List<Profile> get profiles => _profiles;
  Profile? get selectedProfile => _selectedProfile;

  ProfileProvider() {
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final profilesJson = prefs.getStringList(_profilesKey) ?? [];
    _profiles = profilesJson
        .map((json) => Profile.fromJson(jsonDecode(json)))
        .toList();

    final selectedProfileJson = prefs.getString(_selectedProfileKey);
    if (selectedProfileJson != null) {
      _selectedProfile = Profile.fromJson(jsonDecode(selectedProfileJson));
    }
    notifyListeners();
  }

  Future<void> _saveProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final profilesJson = _profiles
        .map((profile) => jsonEncode(profile.toJson()))
        .toList();
    await prefs.setStringList(_profilesKey, profilesJson);

    if (_selectedProfile != null) {
      await prefs.setString(
        _selectedProfileKey,
        jsonEncode(_selectedProfile!.toJson()),
      );
    } else {
      await prefs.remove(_selectedProfileKey);
    }
  }

  Future<void> addProfile(Profile profile) async {
    if (_profiles.any((p) => p.name == profile.name)) {
      throw Exception('A profile with this name already exists');
    }
    _profiles.add(profile);
    await _saveProfiles();
    notifyListeners();
  }

  Future<void> removeProfile(String name) async {
    _profiles.removeWhere((profile) => profile.name == name);
    if (_selectedProfile?.name == name) {
      _selectedProfile = null;
    }
    await _saveProfiles();
    notifyListeners();
  }

  Future<void> selectProfile(String name) async {
    _selectedProfile = _profiles.firstWhere((profile) => profile.name == name);
    await _saveProfiles();
    notifyListeners();
  }
}