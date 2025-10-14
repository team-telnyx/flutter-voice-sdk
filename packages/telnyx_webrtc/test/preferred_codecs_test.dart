import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/model/audio_codec.dart';
import 'package:telnyx_webrtc/telnyx_client.dart';

void main() {
  group('Preferred Codecs Implementation', () {
    late TelnyxClient client;

    setUp(() {
      client = TelnyxClient();
    });

    test('getSupportedAudioCodecs should return expected codecs', () {
      final supportedCodecs = client.getSupportedAudioCodecs();

      expect(supportedCodecs, isNotEmpty);
      expect(supportedCodecs.length, equals(7));

      // Check for Opus codec
      final opusCodec = supportedCodecs.firstWhere(
        (codec) => codec.mimeType == 'audio/opus',
      );
      expect(opusCodec.clockRate, equals(48000));
      expect(opusCodec.channels, equals(2));
      expect(opusCodec.sdpFmtpLine, equals('minptime=10;useinbandfec=1'));

      // Check for G722 codec
      final g722Codec = supportedCodecs.firstWhere(
        (codec) => codec.mimeType == 'audio/G722',
      );
      expect(g722Codec.clockRate, equals(8000));
      expect(g722Codec.channels, equals(1));

      // Check for PCMU codec
      final pcmuCodec = supportedCodecs.firstWhere(
        (codec) => codec.mimeType == 'audio/PCMU',
      );
      expect(pcmuCodec.clockRate, equals(8000));
      expect(pcmuCodec.channels, equals(1));

      // Check for PCMA codec
      final pcmaCodec = supportedCodecs.firstWhere(
        (codec) => codec.mimeType == 'audio/PCMA',
      );
      expect(pcmaCodec.clockRate, equals(8000));
      expect(pcmaCodec.channels, equals(1));

      // Check for G729 codec
      final g729Codec = supportedCodecs.firstWhere(
        (codec) => codec.mimeType == 'audio/G729',
      );
      expect(g729Codec.clockRate, equals(8000));
      expect(g729Codec.channels, equals(1));

      // Check for AMR-WB codec
      final amrWbCodec = supportedCodecs.firstWhere(
        (codec) => codec.mimeType == 'audio/AMR-WB',
      );
      expect(amrWbCodec.clockRate, equals(16000));
      expect(amrWbCodec.channels, equals(1));

      // Check for telephone-event codec
      final telephoneEventCodec = supportedCodecs.firstWhere(
        (codec) => codec.mimeType == 'audio/telephone-event',
      );
      expect(telephoneEventCodec.clockRate, equals(8000));
      expect(telephoneEventCodec.channels, equals(1));
    });

    test('AudioCodec should serialize and deserialize correctly', () {
      const originalCodec = AudioCodec(
        mimeType: 'audio/opus',
        clockRate: 48000,
        channels: 2,
        sdpFmtpLine: 'minptime=10;useinbandfec=1',
      );

      final json = originalCodec.toJson();
      final deserializedCodec = AudioCodec.fromJson(json);

      expect(deserializedCodec, equals(originalCodec));
      expect(deserializedCodec.mimeType, equals(originalCodec.mimeType));
      expect(deserializedCodec.clockRate, equals(originalCodec.clockRate));
      expect(deserializedCodec.channels, equals(originalCodec.channels));
      expect(deserializedCodec.sdpFmtpLine, equals(originalCodec.sdpFmtpLine));
    });

    test('AudioCodec should handle null values correctly', () {
      const codec = AudioCodec(
        mimeType: 'audio/PCMU',
        clockRate: 8000,
      );

      final json = codec.toJson();
      expect(json['mimeType'], equals('audio/PCMU'));
      expect(json['clockRate'], equals(8000));
      expect(json.containsKey('channels'), isFalse);
      expect(json.containsKey('sdpFmtpLine'), isFalse);

      final deserializedCodec = AudioCodec.fromJson(json);
      expect(deserializedCodec.mimeType, equals('audio/PCMU'));
      expect(deserializedCodec.clockRate, equals(8000));
      expect(deserializedCodec.channels, isNull);
      expect(deserializedCodec.sdpFmtpLine, isNull);
    });

    test('AudioCodec equality and hashCode should work correctly', () {
      const codec1 = AudioCodec(
        mimeType: 'audio/opus',
        clockRate: 48000,
        channels: 2,
      );

      const codec2 = AudioCodec(
        mimeType: 'audio/opus',
        clockRate: 48000,
        channels: 2,
      );

      const codec3 = AudioCodec(
        mimeType: 'audio/PCMU',
        clockRate: 8000,
        channels: 1,
      );

      expect(codec1, equals(codec2));
      expect(codec1.hashCode, equals(codec2.hashCode));
      expect(codec1, isNot(equals(codec3)));
      expect(codec1.hashCode, isNot(equals(codec3.hashCode)));
    });

    test('AudioCodec toString should contain all properties', () {
      const codec = AudioCodec(
        mimeType: 'audio/opus',
        clockRate: 48000,
        channels: 2,
        sdpFmtpLine: 'minptime=10;useinbandfec=1',
      );

      final string = codec.toString();
      expect(string, contains('audio/opus'));
      expect(string, contains('48000'));
      expect(string, contains('2'));
      expect(string, contains('minptime=10;useinbandfec=1'));
    });
  });
}