/// Utility class for retrieving SDK version information
class VersionUtils {
  /// SDK version constant
  static const String _sdkVersion = '4.4.0';

  /// Gets the SDK version
  /// Returns the current SDK version as a constant
  static String getSDKVersion() {
    return _sdkVersion;
  }

  /// Constructs the user agent string in the format Flutter-{SDK-Version}
  /// or Flutter-mpn-{SDK-Version} when missed call notifications are enabled.
  static String getUserAgent({bool enableMissedCallNotifications = false}) {
    final prefix = enableMissedCallNotifications ? 'Flutter-mpn' : 'Flutter';
    return '$prefix-$_sdkVersion';
  }
}
