import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/model/verto/send/invite_answer_message_body.dart';
import 'package:telnyx_webrtc/model/audio_codec.dart';

void main() {
  group('DialogParams', () {
    test('should create DialogParams without preferred codecs', () {
      final params = DialogParams(
        callID: 'test-call-id',
        remoteSdp: 'test-sdp',
        callerIdName: 'Test Caller',
        callerIdNumber: '+1234567890',
        destinationNumber: '+0987654321',
        customHeaders: {'X-Test': 'value'},
      );

      expect(params.callID, equals('test-call-id'));
      expect(params.remoteSdp, equals('test-sdp'));
      expect(params.callerIdName, equals('Test Caller'));
      expect(params.callerIdNumber, equals('+1234567890'));
      expect(params.destinationNumber, equals('+0987654321'));
      expect(params.customHeaders, equals({'X-Test': 'value'}));
      expect(params.preferredCodecs, isNull);
    });

    test('should create DialogParams with preferred codecs', () {
      const codecs = [
        AudioCodec(mimeType: 'audio/opus', clockRate: 48000, channels: 2),
        AudioCodec(mimeType: 'audio/PCMU', clockRate: 8000),
      ];

      final params = DialogParams(
        callID: 'test-call-id',
        remoteSdp: 'test-sdp',
        callerIdName: 'Test Caller',
        callerIdNumber: '+1234567890',
        destinationNumber: '+0987654321',
        preferredCodecs: codecs,
      );

      expect(params.preferredCodecs, isNotNull);
      expect(params.preferredCodecs!.length, equals(2));
    });

    test('should serialize to JSON without preferred codecs', () {
      final params = DialogParams(
        callID: 'test-call-id',
        remoteSdp: 'test-sdp',
        callerIdName: 'Test Caller',
        callerIdNumber: '+1234567890',
        destinationNumber: '+0987654321',
        customHeaders: {'X-Test': 'value'},
      );

      final json = params.toJson();

      expect(json['callID'], equals('test-call-id'));
      expect(json['remoteSdp'], equals('test-sdp'));
      expect(json['caller_id_name'], equals('Test Caller'));
      expect(json['caller_id_number'], equals('+1234567890'));
      expect(json['destination_number'], equals('+0987654321'));
      expect(json['custom_headers'], equals({'X-Test': 'value'}));
      expect(json.containsKey('preferred_codecs'), isFalse);
    });

    test('should serialize to JSON with preferred codecs', () {
      const codecs = [
        AudioCodec(mimeType: 'audio/opus', clockRate: 48000, channels: 2),
        AudioCodec(mimeType: 'audio/PCMU', clockRate: 8000),
      ];

      final params = DialogParams(
        callID: 'test-call-id',
        remoteSdp: 'test-sdp',
        callerIdName: 'Test Caller',
        callerIdNumber: '+1234567890',
        destinationNumber: '+0987654321',
        preferredCodecs: codecs,
      );

      final json = params.toJson();

      expect(json['callID'], equals('test-call-id'));
      expect(json['preferred_codecs'], isNotNull);
      expect(json['preferred_codecs'], isA<List>());
      
      final codecsJson = json['preferred_codecs'] as List;
      expect(codecsJson.length, equals(2));
      expect(codecsJson[0]['mimeType'], equals('audio/opus'));
      expect(codecsJson[0]['clockRate'], equals(48000));
      expect(codecsJson[0]['channels'], equals(2));
      expect(codecsJson[1]['mimeType'], equals('audio/PCMU'));
      expect(codecsJson[1]['clockRate'], equals(8000));
    });

    test('should deserialize from JSON without preferred codecs', () {
      final json = {
        'callID': 'test-call-id',
        'remoteSdp': 'test-sdp',
        'caller_id_name': 'Test Caller',
        'caller_id_number': '+1234567890',
        'destination_number': '+0987654321',
        'custom_headers': {'X-Test': 'value'},
      };

      final params = DialogParams.fromJson(json);

      expect(params.callID, equals('test-call-id'));
      expect(params.remoteSdp, equals('test-sdp'));
      expect(params.callerIdName, equals('Test Caller'));
      expect(params.callerIdNumber, equals('+1234567890'));
      expect(params.destinationNumber, equals('+0987654321'));
      expect(params.customHeaders, equals({'X-Test': 'value'}));
      expect(params.preferredCodecs, isNull);
    });

    test('should deserialize from JSON with preferred codecs', () {
      final json = {
        'callID': 'test-call-id',
        'remoteSdp': 'test-sdp',
        'caller_id_name': 'Test Caller',
        'caller_id_number': '+1234567890',
        'destination_number': '+0987654321',
        'preferred_codecs': [
          {'mimeType': 'audio/opus', 'clockRate': 48000, 'channels': 2},
          {'mimeType': 'audio/PCMU', 'clockRate': 8000},
        ],
      };

      final params = DialogParams.fromJson(json);

      expect(params.callID, equals('test-call-id'));
      expect(params.preferredCodecs, isNotNull);
      expect(params.preferredCodecs!.length, equals(2));
      expect(params.preferredCodecs![0].mimeType, equals('audio/opus'));
      expect(params.preferredCodecs![0].clockRate, equals(48000));
      expect(params.preferredCodecs![0].channels, equals(2));
      expect(params.preferredCodecs![1].mimeType, equals('audio/PCMU'));
      expect(params.preferredCodecs![1].clockRate, equals(8000));
    });

    test('should handle empty preferred codecs list', () {
      final params = DialogParams(
        callID: 'test-call-id',
        remoteSdp: 'test-sdp',
        callerIdName: 'Test Caller',
        callerIdNumber: '+1234567890',
        destinationNumber: '+0987654321',
        preferredCodecs: [],
      );

      final json = params.toJson();
      expect(json['preferred_codecs'], equals([]));

      final deserialized = DialogParams.fromJson(json);
      expect(deserialized.preferredCodecs, isNotNull);
      expect(deserialized.preferredCodecs!.isEmpty, isTrue);
    });
  });
}