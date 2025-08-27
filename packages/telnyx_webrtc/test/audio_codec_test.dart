import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/model/audio_codec.dart';

void main() {
  group('AudioCodec', () {
    test('should create AudioCodec with all properties', () {
      const codec = AudioCodec(
        mimeType: 'audio/opus',
        clockRate: 48000,
        channels: 2,
        sdpFmtpLine: 'minptime=10;useinbandfec=1',
      );

      expect(codec.mimeType, equals('audio/opus'));
      expect(codec.clockRate, equals(48000));
      expect(codec.channels, equals(2));
      expect(codec.sdpFmtpLine, equals('minptime=10;useinbandfec=1'));
    });

    test('should create AudioCodec with minimal properties', () {
      const codec = AudioCodec(mimeType: 'audio/PCMU', clockRate: 8000);

      expect(codec.mimeType, equals('audio/PCMU'));
      expect(codec.clockRate, equals(8000));
      expect(codec.channels, isNull);
      expect(codec.sdpFmtpLine, isNull);
    });

    test('should serialize to JSON correctly', () {
      const codec = AudioCodec(
        mimeType: 'audio/opus',
        clockRate: 48000,
        channels: 2,
        sdpFmtpLine: 'minptime=10;useinbandfec=1',
      );

      final json = codec.toJson();

      expect(
        json,
        equals({
          'mimeType': 'audio/opus',
          'clockRate': 48000,
          'channels': 2,
          'sdpFmtpLine': 'minptime=10;useinbandfec=1',
        }),
      );
    });

    test('should serialize to JSON with null values omitted', () {
      const codec = AudioCodec(mimeType: 'audio/PCMU', clockRate: 8000);

      final json = codec.toJson();

      expect(json, equals({'mimeType': 'audio/PCMU', 'clockRate': 8000}));
      expect(json.containsKey('channels'), isFalse);
      expect(json.containsKey('sdpFmtpLine'), isFalse);
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'mimeType': 'audio/opus',
        'clockRate': 48000,
        'channels': 2,
        'sdpFmtpLine': 'minptime=10;useinbandfec=1',
      };

      final codec = AudioCodec.fromJson(json);

      expect(codec.mimeType, equals('audio/opus'));
      expect(codec.clockRate, equals(48000));
      expect(codec.channels, equals(2));
      expect(codec.sdpFmtpLine, equals('minptime=10;useinbandfec=1'));
    });

    test('should deserialize from JSON with missing optional fields', () {
      final json = {'mimeType': 'audio/PCMU', 'clockRate': 8000};

      final codec = AudioCodec.fromJson(json);

      expect(codec.mimeType, equals('audio/PCMU'));
      expect(codec.clockRate, equals(8000));
      expect(codec.channels, isNull);
      expect(codec.sdpFmtpLine, isNull);
    });

    test('should handle equality correctly', () {
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

      const codec3 = AudioCodec(mimeType: 'audio/PCMU', clockRate: 8000);

      expect(codec1, equals(codec2));
      expect(codec1, isNot(equals(codec3)));
    });

    test('should handle hashCode correctly', () {
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

      expect(codec1.hashCode, equals(codec2.hashCode));
    });

    test('should handle toString correctly', () {
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
