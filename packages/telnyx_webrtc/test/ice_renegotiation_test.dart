import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/model/verto/receive/received_message_body.dart';

void main() {
  group('ICE Renegotiation', () {
    test('should parse updateMedia response correctly', () {
      final responseData = {
        'action': 'updateMedia',
        'callID': 'test-call-id-123',
        'sdp': 'v=0\r\no=- 987654321 987654321 IN IP4 192.168.1.100\r\n'
            's=-\r\nt=0 0\r\na=group:BUNDLE 0\r\n'
            'm=audio 9 UDP/TLS/RTP/SAVPF 111\r\n'
            'c=IN IP4 192.168.1.100\r\n'
            'a=rtcp:9 IN IP4 192.168.1.100\r\n'
            'a=ice-ufrag:test123\r\n'
            'a=ice-pwd:testpassword123\r\n'
            'a=fingerprint:sha-256 AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99\r\n'
            'a=setup:active\r\n'
            'a=mid:0\r\n'
            'a=sendrecv\r\n'
            'a=rtcp-mux\r\n'
            'a=rtpmap:111 opus/48000/2\r\n',
      };

      final receivedMessage = ReceivedMessageBody(result: responseData);

      expect(receivedMessage.result, isNotNull);
      expect(receivedMessage.result!['action'], equals('updateMedia'));
      expect(receivedMessage.result!['callID'], equals('test-call-id-123'));
      expect(receivedMessage.result!['sdp'], isNotNull);
      expect(receivedMessage.result!['sdp'], contains('v=0'));
      expect(receivedMessage.result!['sdp'], contains('ice-ufrag'));
      expect(receivedMessage.result!['sdp'], contains('ice-pwd'));
    });

    test('should validate updateMedia response has required fields', () {
      final responseData = {
        'action': 'updateMedia',
        'callID': 'test-call-id-456',
        'sdp': 'v=0\r\no=- 111222333 111222333 IN IP4 10.0.0.1\r\n',
      };

      final receivedMessage = ReceivedMessageBody(result: responseData);
      final result = receivedMessage.result!;

      // Validate required fields for updateMedia response
      expect(result['action'], equals('updateMedia'));
      expect(result['callID'], isNotNull);
      expect(result['callID'], isA<String>());
      expect(result['sdp'], isNotNull);
      expect(result['sdp'], isA<String>());
    });

    test('should handle missing action in response', () {
      final responseData = {
        'callID': 'test-call-id-789',
        'sdp': 'v=0\r\no=- 444555666 444555666 IN IP4 172.16.0.1\r\n',
      };

      final receivedMessage = ReceivedMessageBody(result: responseData);
      final result = receivedMessage.result!;

      expect(result['action'], isNull);
      expect(result['callID'], isNotNull);
      expect(result['sdp'], isNotNull);
    });

    test('should handle missing callID in response', () {
      final responseData = {
        'action': 'updateMedia',
        'sdp': 'v=0\r\no=- 777888999 777888999 IN IP4 203.0.113.1\r\n',
      };

      final receivedMessage = ReceivedMessageBody(result: responseData);
      final result = receivedMessage.result!;

      expect(result['action'], equals('updateMedia'));
      expect(result['callID'], isNull);
      expect(result['sdp'], isNotNull);
    });

    test('should handle missing SDP in response', () {
      final responseData = {
        'action': 'updateMedia',
        'callID': 'test-call-id-101112',
      };

      final receivedMessage = ReceivedMessageBody(result: responseData);
      final result = receivedMessage.result!;

      expect(result['action'], equals('updateMedia'));
      expect(result['callID'], isNotNull);
      expect(result['sdp'], isNull);
    });

    test('should handle different action types', () {
      final responseData = {
        'action': 'hold',
        'callID': 'test-call-id-131415',
      };

      final receivedMessage = ReceivedMessageBody(result: responseData);
      final result = receivedMessage.result!;

      expect(result['action'], equals('hold'));
      expect(result['action'], isNot(equals('updateMedia')));
    });

    test('should validate SDP format basics', () {
      const validSdp = 'v=0\r\n'
          'o=- 123456789 123456789 IN IP4 127.0.0.1\r\n'
          's=-\r\n'
          't=0 0\r\n'
          'a=group:BUNDLE 0\r\n'
          'm=audio 9 UDP/TLS/RTP/SAVPF 111\r\n'
          'c=IN IP4 127.0.0.1\r\n'
          'a=ice-ufrag:abcd1234\r\n'
          'a=ice-pwd:password1234567890\r\n';

      final responseData = {
        'action': 'updateMedia',
        'callID': 'test-call-id-161718',
        'sdp': validSdp,
      };

      final receivedMessage = ReceivedMessageBody(result: responseData);
      final sdp = receivedMessage.result!['sdp'] as String;

      // Basic SDP validation
      expect(sdp, startsWith('v=0'));
      expect(sdp, contains('o=-'));
      expect(sdp, contains('ice-ufrag:'));
      expect(sdp, contains('ice-pwd:'));
    });

    test('should handle empty result', () {
      final receivedMessage = ReceivedMessageBody(result: null);

      expect(receivedMessage.result, isNull);
    });

    test('should handle empty result map', () {
      final responseData = <String, dynamic>{};
      final receivedMessage = ReceivedMessageBody(result: responseData);

      expect(receivedMessage.result, isNotNull);
      expect(receivedMessage.result!.isEmpty, isTrue);
    });
  });
}