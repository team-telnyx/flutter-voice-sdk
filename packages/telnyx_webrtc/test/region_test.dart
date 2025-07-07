import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/model/region.dart';

void main() {
  group('Region', () {
    test('should have correct values', () {
      expect(Region.auto.value, 'auto');
      expect(Region.eu.value, 'eu');
      expect(Region.usCentral.value, 'us-central');
      expect(Region.usEast.value, 'us-east');
      expect(Region.usWest.value, 'us-west');
      expect(Region.caCentral.value, 'ca-central');
      expect(Region.apac.value, 'apac');
    });

    test('should have correct display names', () {
      expect(Region.auto.displayName, 'AUTO');
      expect(Region.eu.displayName, 'EU');
      expect(Region.usCentral.displayName, 'US-CENTRAL');
      expect(Region.usEast.displayName, 'US-EAST');
      expect(Region.usWest.displayName, 'US-WEST');
      expect(Region.caCentral.displayName, 'CA-CENTRAL');
      expect(Region.apac.displayName, 'APAC');
    });

    test('fromValue should return correct region', () {
      expect(Region.fromValue('auto'), Region.auto);
      expect(Region.fromValue('eu'), Region.eu);
      expect(Region.fromValue('us-central'), Region.usCentral);
      expect(Region.fromValue('us-east'), Region.usEast);
      expect(Region.fromValue('us-west'), Region.usWest);
      expect(Region.fromValue('ca-central'), Region.caCentral);
      expect(Region.fromValue('apac'), Region.apac);
      expect(Region.fromValue('invalid'), null);
    });

    test('fromDisplayName should return correct region', () {
      expect(Region.fromDisplayName('AUTO'), Region.auto);
      expect(Region.fromDisplayName('EU'), Region.eu);
      expect(Region.fromDisplayName('US-CENTRAL'), Region.usCentral);
      expect(Region.fromDisplayName('US-EAST'), Region.usEast);
      expect(Region.fromDisplayName('US-WEST'), Region.usWest);
      expect(Region.fromDisplayName('CA-CENTRAL'), Region.caCentral);
      expect(Region.fromDisplayName('APAC'), Region.apac);
      expect(Region.fromDisplayName('INVALID'), null);
    });

    test('toString should return display name', () {
      expect(Region.auto.toString(), 'AUTO');
      expect(Region.eu.toString(), 'EU');
      expect(Region.usCentral.toString(), 'US-CENTRAL');
    });
  });
}
