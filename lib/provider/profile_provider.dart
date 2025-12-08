import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telnyx_flutter_webrtc/model/profile_model.dart';

class ProfileProvider with ChangeNotifier {
  static const String _profilesKey = 'profiles';
  static const String _selectedProfileKey = 'selected_profile';
  static const String _isDevEnvironmentKey = 'is_dev_environment';
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
    _profiles =
        profilesJson.map((json) => Profile.fromJson(jsonDecode(json))).toList();

    final selectedProfileJson = prefs.getString(_selectedProfileKey);
    if (selectedProfileJson != null) {
      _selectedProfile = Profile.fromJson(jsonDecode(selectedProfileJson));
    }

    // Restore environment setting
    _isDevEnvironment = prefs.getBool(_isDevEnvironmentKey) ?? false;

    notifyListeners();
  }

  Future<void> _saveProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final profilesJson =
        _profiles.map((profile) => jsonEncode(profile.toJson())).toList();
    await prefs.setStringList(_profilesKey, profilesJson);

    if (_selectedProfile != null) {
      await prefs.setString(
        _selectedProfileKey,
        jsonEncode(_selectedProfile!.toJson()),
      );
    } else {
      await prefs.remove(_selectedProfileKey);
    }

    // Save environment setting
    await prefs.setBool(_isDevEnvironmentKey, _isDevEnvironment);
  }

  Future<void> addProfile(Profile profile) async {
    if (_profiles.any((p) => p.sipCallerIDName == profile.sipCallerIDName)) {
      throw Exception('A profile with this name already exists');
    }
    _profiles.add(profile);
    await _saveProfiles();
    notifyListeners();
  }

  Future<void> updateProfile(
    String originalName,
    Profile updatedProfile,
  ) async {
    final index = _profiles.indexWhere(
      (p) => p.sipCallerIDName == originalName,
    );

    if (index == -1) {
      throw Exception('Profile not found');
    }

    // If the name is changing, check if the new name already exists
    if (originalName != updatedProfile.sipCallerIDName) {
      if (_profiles.any(
        (p) => p.sipCallerIDName == updatedProfile.sipCallerIDName,
      )) {
        throw Exception('A profile with this name already exists');
      }
    }

    _profiles[index] = updatedProfile;

    // Update selected profile if it's the one being updated
    if (_selectedProfile?.sipCallerIDName == originalName) {
      _selectedProfile = updatedProfile;
    }

    await _saveProfiles();
    notifyListeners();
  }

  Future<void> removeProfile(String name) async {
    _profiles.removeWhere((profile) => profile.sipCallerIDName == name);
    if (_selectedProfile?.sipCallerIDName == name) {
      _selectedProfile = null;
    }
    await _saveProfiles();
    notifyListeners();
  }

  Future<void> selectProfile(String name) async {
    _selectedProfile = _profiles.firstWhere(
      (profile) => profile.sipCallerIDName == name,
    );
    await _saveProfiles();
    notifyListeners();
  }

  Future<void> toggleDebugMode() async {
    if (_selectedProfile != null) {
      final updatedProfile = _selectedProfile!.copyWith(
        isDebug: !_selectedProfile!.isDebug,
      );

      // Update the profile in the list
      final index = _profiles.indexWhere(
        (p) => p.sipCallerIDName == _selectedProfile!.sipCallerIDName,
      );
      if (index != -1) {
        _profiles[index] = updatedProfile;
      }

      // Update the selected profile
      _selectedProfile = updatedProfile;

      await _saveProfiles();
      notifyListeners();
    }
  }

  /// Whether the app is currently using development environment
  bool _isDevEnvironment = false;

  /// Gets whether the app is using development environment
  bool get isDevEnvironment => _isDevEnvironment;

  /// Sets the development environment flag
  ///
  /// When [isDev] is true, the SDK will use development TURN/STUN servers.
  /// When [isDev] is false, the SDK will use production TURN/STUN servers.
  Future<void> setDevEnvironment(bool isDev) async {
    _isDevEnvironment = isDev;
    await _saveProfiles();
    notifyListeners();
  }
}
