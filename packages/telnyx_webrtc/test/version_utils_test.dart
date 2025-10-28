import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/utils/version_utils.dart';

void main() {
  group('VersionUtils', () {
    test('getSDKVersion returns valid semantic version', () {
      final version = VersionUtils.getSDKVersion();
      expect(
        version,
        matches(
          RegExp(r'^\d+\.\d+\.\d+$'),
        ),
      );
      expect(version, isNotEmpty);
    });

    test('getUserAgent returns properly formatted user agent string', () {
      final userAgent = VersionUtils.getUserAgent();
      expect(userAgent, startsWith('Flutter-'));
      expect(
        userAgent,
        matches(
          RegExp(r'^Flutter-\d+\.\d+\.\d+$'),
        ),
      );
    });

    test('getSDKVersion returns consistent result on multiple calls', () {
      final version1 = VersionUtils.getSDKVersion();
      final version2 = VersionUtils.getSDKVersion();
      expect(version1, equals(version2));
      expect(
        version1,
        matches(
          RegExp(r'^\d+\.\d+\.\d+$'),
        ),
      );
    });
  });
}
