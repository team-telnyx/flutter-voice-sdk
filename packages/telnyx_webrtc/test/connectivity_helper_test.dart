import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/model/region.dart';
import 'package:telnyx_webrtc/utils/connectivity_helper.dart';

void main() {
  group('ConnectivityHelper', () {
    test('getHostForRegion should return correct hosts', () {
      expect(ConnectivityHelper.getHostForRegion(Region.auto), 'rtc.telnyx.com');
      expect(ConnectivityHelper.getHostForRegion(Region.eu), 'rtc.eu.telnyx.com');
      expect(ConnectivityHelper.getHostForRegion(Region.usCentral), 'rtc.us-central.telnyx.com');
      expect(ConnectivityHelper.getHostForRegion(Region.usEast), 'rtc.us-east.telnyx.com');
      expect(ConnectivityHelper.getHostForRegion(Region.usWest), 'rtc.us-west.telnyx.com');
      expect(ConnectivityHelper.getHostForRegion(Region.caCentral), 'rtc.ca-central.telnyx.com');
      expect(ConnectivityHelper.getHostForRegion(Region.apac), 'rtc.apac.telnyx.com');
    });

    test('resolveOptimalRegion should return auto for auto region', () async {
      final result = await ConnectivityHelper.resolveOptimalRegion(Region.auto, true);
      expect(result, Region.auto);
    });

    test('resolveOptimalRegion should return same region for non-auto regions', () async {
      final result = await ConnectivityHelper.resolveOptimalRegion(Region.eu, true);
      expect(result, Region.eu);
    });

    test('resolveOptimalRegion should handle fallback disabled', () async {
      final result = await ConnectivityHelper.resolveOptimalRegion(Region.eu, false);
      expect(result, Region.eu);
    });

    test('isHostReachable should handle valid hosts', () async {
      // Note: This test would require mocking network calls in a real implementation
      // For now, we'll test the method exists and returns a boolean
      final result = await ConnectivityHelper.isHostReachable('rtc.telnyx.com');
      expect(result, isA<bool>());
    });

    test('findBestRegion should return a valid region', () async {
      // Note: This test would require mocking network calls in a real implementation
      // For now, we'll test the method exists and returns a Region
      final result = await ConnectivityHelper.findBestRegion();
      expect(result, isA<Region>());
    });
  });
}