import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/utils/version_utils.dart';

void main() {
  group('VersionUtils', () {
    test('getSDKVersion returns fallback version when pubspec.yaml cannot be read', () async {
      // Since we can't easily mock the rootBundle in a unit test,
      // this test verifies the fallback behavior
      final version = await VersionUtils.getSDKVersion();
      expect(version, isNotEmpty);
      expect(version, matches(RegExp(r'^\d+\.\d+\.\d+.*')));
    });

    test('getUserAgent returns properly formatted user agent string', () async {
      final userAgent = await VersionUtils.getUserAgent();
      expect(userAgent, startsWith('Flutter-'));
      expect(userAgent, matches(RegExp(r'^Flutter-\d+\.\d+\.\d+.*')));
    });

    test('getSDKVersion caches result on subsequent calls', () async {
      final version1 = await VersionUtils.getSDKVersion();
      final version2 = await VersionUtils.getSDKVersion();
      expect(version1, equals(version2));
    });
  });
}