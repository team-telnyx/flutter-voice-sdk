import 'package:flutter/services.dart';
import 'dart:convert';

class VersionUtils {
  static String? _appVersion;
  static String? _sdkVersion;

  static Future<String> getAppVersion() async {
    if (_appVersion != null) return _appVersion!;

    try {
      final String pubspecContent = await rootBundle.loadString('pubspec.yaml');
      final lines = pubspecContent.split('\n');
      for (final line in lines) {
        if (line.startsWith('version:')) {
          final version = line.split(':')[1].trim();
          // Extract just the version number before the +
          _appVersion = version.split('+')[0];
          return _appVersion!;
        }
      }
    } catch (e) {
      // Fallback version if we can't read pubspec.yaml
      _appVersion = '1.0.0';
    }
    return _appVersion!;
  }

  static Future<String> getSDKVersion() async {
    if (_sdkVersion != null) return _sdkVersion!;

    try {
      final String pubspecContent = await rootBundle.loadString(
        'packages/telnyx_webrtc/pubspec.yaml',
      );
      final lines = pubspecContent.split('\n');
      for (final line in lines) {
        if (line.startsWith('version:')) {
          final version = line.split(':')[1].trim();
          _sdkVersion = version;
          return _sdkVersion!;
        }
      }
    } catch (e) {
      // Fallback version if we can't read SDK pubspec.yaml
      _sdkVersion = '1.2.0';
    }
    return _sdkVersion!;
  }

  static Future<String> getVersionString() async {
    final appVersion = await getAppVersion();
    final sdkVersion = await getSDKVersion();
    return 'Production TelnyxSDK [v$sdkVersion] - App [v$appVersion]';
  }
}
