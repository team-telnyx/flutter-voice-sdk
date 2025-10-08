import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/utils/version_utils.dart';

void main() {
  group('VersionUtils', () {
    test('getSDKVersion returns constant version', () {
      final version = VersionUtils.getSDKVersion();
      expect(version, equals('3.0.1'));
      expect(version, isNotEmpty);
    });

    test('getUserAgent returns properly formatted user agent string', () {
      final userAgent = VersionUtils.getUserAgent();
      expect(userAgent, equals('Flutter-3.0.1'));
      expect(userAgent, startsWith('Flutter-'));
    });

    test('getSDKVersion returns consistent result on multiple calls', () {
      final version1 = VersionUtils.getSDKVersion();
      final version2 = VersionUtils.getSDKVersion();
      expect(version1, equals(version2));
      expect(version1, equals('3.0.1'));
    });
  });
}
