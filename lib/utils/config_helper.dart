import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';
import 'package:telnyx_webrtc/utils/logging/log_level.dart';
import 'package:telnyx_flutter_webrtc/utils/custom_sdk_logger.dart';

/// A utility class to help with retrieving stored configuration.
class ConfigHelper {
  /// Retrieves stored Credential configuration from SharedPreferences.
  /// Returns null if required fields are missing.
  static Future<CredentialConfig?> getCredentialConfigFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sipUser = prefs.getString('sipUser');
      final sipPassword = prefs.getString('sipPassword');
      final sipName = prefs.getString('sipName');
      final sipNumber = prefs.getString('sipNumber');
      final notificationToken = prefs.getString('notificationToken');
      final forceRelayCandidate = prefs.getBool('forceRelayCandidate') ?? false;

      if (sipUser != null &&
          sipPassword != null &&
          sipName != null &&
          sipNumber != null) {
        return CredentialConfig(
          sipCallerIDName: sipName,
          sipCallerIDNumber: sipNumber,
          sipUser: sipUser,
          sipPassword: sipPassword,
          notificationToken: notificationToken,
          logLevel: LogLevel.all,
          customLogger: CustomSDKLogger(),
          debug: true, // Enable debug to get call quality metrics
          reconnectionTimeout: 30000,
          forceRelayCandidate: forceRelayCandidate,
        );
      }
    } catch (e) {
      Logger().e(
        '[ConfigHelper] Error reading CredentialConfig from Prefs: $e',
      );
    }
    return null;
  }

  /// Retrieves stored Token configuration from SharedPreferences.
  /// Returns null if required fields are missing.
  static Future<TokenConfig?> getTokenConfigFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final sipName = prefs.getString('sipName');
      final sipNumber = prefs.getString('sipNumber');
      final notificationToken = prefs.getString('notificationToken');
      final forceRelayCandidate = prefs.getBool('forceRelayCandidate') ?? false;

      if (token != null && sipName != null && sipNumber != null) {
        return TokenConfig(
          sipCallerIDName: sipName,
          sipCallerIDNumber: sipNumber,
          sipToken: token,
          notificationToken: notificationToken,
          logLevel: LogLevel.all,
          customLogger: CustomSDKLogger(),
          debug: true, // Enable debug to get call quality metrics
          forceRelayCandidate: forceRelayCandidate,
        );
      }
    } catch (e) {
      Logger().e('[ConfigHelper] Error reading TokenConfig from Prefs: $e');
    }
    return null;
  }

  /// Retrieves either Credential or Token configuration from SharedPreferences.
  /// Prefers CredentialConfig if available.
  /// Returns null if neither configuration can be fully retrieved.
  static Future<Object?> getTelnyxConfigFromPrefs() async {
    try {
      Object? config = await getCredentialConfigFromPrefs();
      config ??= await getTokenConfigFromPrefs();
      return config;
    } catch (e) {
      Logger().e('[ConfigHelper] Error reading TelnyxConfig from Prefs: $e');
      return null;
    }
  }
}
