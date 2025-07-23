import 'package:shared_preferences/shared_preferences.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';
import 'package:telnyx_webrtc/utils/logging/log_level.dart';

/// A helper class to manage loading and saving of Telnyx configuration
/// from the device's persistent storage.
class ConfigHelper {
  static const _sipUserKey = 'sipUser';
  static const _sipPasswordKey = 'sipPassword';
  static const _tokenKey = 'token';
  static const _sipNameKey = 'sipName';
  static const _sipNumberKey = 'sipNumber';
  static const _notificationTokenKey = 'notificationToken';
  static const _forceRelayCandidateKey = 'forceRelayCandidate';
  static const _reconnectionTimeoutKey = 'reconnectionTimeout';

  /// Saves the provided [config] to SharedPreferences.
  ///
  /// This method automatically handles whether the config is a
  /// [CredentialConfig] or a [TokenConfig].
  static Future<void> saveConfig(Config config) async {
    final prefs = await SharedPreferences.getInstance();
    await _clearConfig(); // Clear old config first

    if (config is TokenConfig) {
      await prefs.setString(_tokenKey, config.sipToken);
    } else if (config is CredentialConfig) {
      await prefs.setString(_sipUserKey, config.sipUser);
      await prefs.setString(_sipPasswordKey, config.sipPassword);
    }

    await prefs.setString(_sipNameKey, config.sipCallerIDName);
    await prefs.setString(_sipNumberKey, config.sipCallerIDNumber);
    await prefs.setBool(_forceRelayCandidateKey, config.forceRelayCandidate);
    if (config.reconnectionTimeout != null) {
      await prefs.setInt(_reconnectionTimeoutKey, config.reconnectionTimeout!);
    }
    if (config.notificationToken != null) {
      await prefs.setString(_notificationTokenKey, config.notificationToken!);
    }
    print('ConfigHelper: Configuration saved successfully.');
  }

  /// Retrieves a [Config] object from SharedPreferences.
  ///
  /// It automatically determines whether to create a [CredentialConfig] or a
  /// [TokenConfig] based on the stored data. If no configuration is found,
  /// it returns null.
  static Future<Config?> getConfig() async {
    final prefs = await SharedPreferences.getInstance();

    final sipUser = prefs.getString(_sipUserKey);
    final sipPassword = prefs.getString(_sipPasswordKey);
    final token = prefs.getString(_tokenKey);
    final sipName = prefs.getString(_sipNameKey);
    final sipNumber = prefs.getString(_sipNumberKey);
    final notificationToken = prefs.getString(_notificationTokenKey);
    final forceRelayCandidate = prefs.getBool(_forceRelayCandidateKey) ?? false;
    final reconnectionTimeout = prefs.getInt(_reconnectionTimeoutKey);

    if (sipName == null || sipNumber == null) {
      print('ConfigHelper: No stored configuration found.');
      return null;
    }

    if (token != null) {
      print('ConfigHelper: Found stored TokenConfig.');
      return TokenConfig(
        sipToken: token,
        sipCallerIDName: sipName,
        sipCallerIDNumber: sipNumber,
        notificationToken: notificationToken,
        logLevel: LogLevel.info, // Default value
        debug: false, // Default value
        forceRelayCandidate: forceRelayCandidate,
        reconnectionTimeout: reconnectionTimeout,
      );
    } else if (sipUser != null && sipPassword != null) {
      print('ConfigHelper: Found stored CredentialConfig.');
      return CredentialConfig(
        sipUser: sipUser,
        sipPassword: sipPassword,
        sipCallerIDName: sipName,
        sipCallerIDNumber: sipNumber,
        notificationToken: notificationToken,
        logLevel: LogLevel.info, // Default value
        debug: false, // Default value
        forceRelayCandidate: forceRelayCandidate,
        reconnectionTimeout: reconnectionTimeout,
      );
    }

    print('ConfigHelper: Stored configuration is incomplete.');
    return null;
  }

  /// Clears any stored Telnyx configuration from SharedPreferences.
  static Future<void> _clearConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sipUserKey);
    await prefs.remove(_sipPasswordKey);
    await prefs.remove(_tokenKey);
    await prefs.remove(_sipNameKey);
    await prefs.remove(_sipNumberKey);
    await prefs.remove(_notificationTokenKey);
    await prefs.remove(_forceRelayCandidateKey);
    await prefs.remove(_reconnectionTimeoutKey);
    print('ConfigHelper: Cleared stored configuration.');
  }
}
