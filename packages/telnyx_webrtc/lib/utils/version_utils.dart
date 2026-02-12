/// Utility class for retrieving SDK version information
class VersionUtils {
  /// SDK version constant
  static const String _sdkVersion = '4.0.1';

  /// Gets the SDK version
  /// Returns the current SDK version as a constant
  static String getSDKVersion() {
    return _sdkVersion;
  }

  /// Constructs the user agent string in the format Flutter-{SDK-Version}
  static String getUserAgent() {
    return 'Flutter-$_sdkVersion';
  }
}
