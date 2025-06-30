import 'package:flutter/services.dart';

/// Utility class for retrieving SDK version information
class VersionUtils {
  static String? _sdkVersion;

  /// Gets the SDK version from the telnyx_webrtc package pubspec.yaml
  /// Returns the version string or a fallback version if unable to read
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
      _sdkVersion = 'unknown';
    }
    return _sdkVersion!;
  }

  /// Constructs the user agent string in the format Flutter-{SDK-Version}
  static Future<String> getUserAgent() async {
    final sdkVersion = await getSDKVersion();
    return 'Flutter-$sdkVersion';
  }
}