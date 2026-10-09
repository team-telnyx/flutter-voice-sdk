import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/model/errors/telnyx_warning.dart';

void main() {
  group('VSDK-396: TelnyxWarning', () {
    group('construction', () {
      test('constructs with all required fields', () {
        const warning = TelnyxWarning(
          code: 31001,
          name: 'HIGH_RTT',
          message: 'High network latency detected',
          description:
              'Round-trip time exceeded the threshold for multiple consecutive samples.',
          causes: ['Poor network connection', 'Network congestion'],
          solutions: ['Check network connectivity', 'Use wired connection'],
        );

        expect(warning.code, equals(31001));
        expect(warning.name, equals('HIGH_RTT'));
        expect(warning.message, equals('High network latency detected'));
        expect(warning.description, isNotEmpty);
        expect(warning.causes, hasLength(2));
        expect(warning.solutions, hasLength(2));
      });

      test('is a const class — can be used in const contexts', () {
        const warning = TelnyxWarning(
          code: 33001,
          name: 'ICE_CONNECTIVITY_LOST',
          message: 'Connection interrupted',
          description: 'ICE connection transitioned to disconnected state.',
          causes: ['Temporary network interruption'],
          solutions: ['Wait for automatic recovery'],
        );

        expect(warning.code, equals(33001));
      });

      test('supports all warning code ranges', () {
        const networkWarning = TelnyxWarning(
          code: 31004,
          name: 'LOW_MOS',
          message: 'Low call quality score',
          description: 'MOS dropped below acceptable threshold.',
          causes: ['Poor network conditions'],
          solutions: ['Check network'],
        );

        const connWarning = TelnyxWarning(
          code: 32001,
          name: 'LOW_BYTES_RECEIVED',
          message: 'No audio data received',
          description: 'No bytes received from remote party.',
          causes: ['Network interruption'],
          solutions: ['Check network'],
        );

        const callWarning = TelnyxWarning(
          code: 33004,
          name: 'PEER_CONNECTION_FAILED',
          message: 'Connection failed',
          description: 'RTCPeerConnection entered failed state.',
          causes: ['ICE failure'],
          solutions: ['Wait for recovery'],
        );

        const authWarning = TelnyxWarning(
          code: 34001,
          name: 'TOKEN_EXPIRING_SOON',
          message: 'Authentication token expiring soon',
          description: 'Token is approaching expiration.',
          causes: ['Token was issued with limited lifetime'],
          solutions: ['Generate new token'],
        );

        const sessionWarning = TelnyxWarning(
          code: 35002,
          name: 'UNKNOWN_REATTACHED_SESSION',
          message: 'Unknown reattach session after reconnect',
          description: 'Server sent Attach for unknown session.',
          causes: ['Server sent Attach for non-existent call'],
          solutions: ['Check application logic'],
        );

        const healthWarning = TelnyxWarning(
          code: 36003,
          name: 'SIGNALING_RECOVERY_REQUIRED',
          message: 'Signaling recovery required',
          description: 'Signaling path detected as unhealthy.',
          causes: ['WebSocket probe timed out'],
          solutions: ['SDK will reconnect automatically'],
        );

        expect(networkWarning.code, equals(31004));
        expect(connWarning.code, equals(32001));
        expect(callWarning.code, equals(33004));
        expect(authWarning.code, equals(34001));
        expect(sessionWarning.code, equals(35002));
        expect(healthWarning.code, equals(36003));
      });
    });

    group('toJson', () {
      test('includes all fields in the JSON output', () {
        const warning = TelnyxWarning(
          code: 31002,
          name: 'HIGH_JITTER',
          message: 'High jitter detected',
          description: 'Jitter exceeded threshold.',
          causes: ['Network congestion', 'Unstable Wi-Fi'],
          solutions: ['Use wired connection', 'Close bandwidth-heavy apps'],
        );

        final json = warning.toJson();

        expect(json['code'], equals(31002));
        expect(json['name'], equals('HIGH_JITTER'));
        expect(json['message'], equals('High jitter detected'));
        expect(json['description'], isNotEmpty);
        expect(json['causes'], isA<List>());
        expect(json['causes'], hasLength(2));
        expect(json['solutions'], isA<List>());
        expect(json['solutions'], hasLength(2));
      });

      test('toJson does not include fatal field (warnings are never fatal)',
          () {
        const warning = TelnyxWarning(
          code: 33005,
          name: 'ONLY_HOST_ICE_CANDIDATES',
          message: 'Only local network candidates available',
          description: 'Only host candidates gathered.',
          causes: ['STUN/TURN unreachable'],
          solutions: ['Verify TURN config'],
        );

        final json = warning.toJson();

        expect(json, isNot(contains('fatal')));
      });
    });
  });
}
