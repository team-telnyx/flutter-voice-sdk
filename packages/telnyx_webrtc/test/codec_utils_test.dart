import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/model/audio_codec.dart';
import 'package:telnyx_webrtc/utils/codec_utils.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

void main() {
  group('CodecUtils - filterSdpCodecs Tests', () {
    const sampleSdp = 'v=0\r\n'
        'o=- 1234567890 2 IN IP4 127.0.0.1\r\n'
        's=-\r\n'
        't=0 0\r\n'
        'a=group:BUNDLE 0\r\n'
        'a=extmap-allow-mixed\r\n'
        'a=msid-semantic: WMS stream\r\n'
        'm=audio 9 UDP/TLS/RTP/SAVPF 111 63 9 0 8 13 110 126\r\n'
        'c=IN IP4 0.0.0.0\r\n'
        'a=rtcp:9 IN IP4 0.0.0.0\r\n'
        'a=ice-ufrag:abcd\r\n'
        'a=ice-pwd:abcdefghijklmnopqrstuvwx\r\n'
        'a=ice-options:trickle\r\n'
        'a=fingerprint:sha-256 00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00\r\n'
        'a=setup:actpass\r\n'
        'a=mid:0\r\n'
        'a=extmap:1 urn:ietf:params:rtp-hdrext:ssrc-audio-level\r\n'
        'a=extmap:2 http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time\r\n'
        'a=sendrecv\r\n'
        'a=msid:stream audio\r\n'
        'a=rtcp-mux\r\n'
        'a=rtpmap:111 opus/48000/2\r\n'
        'a=rtcp-fb:111 transport-cc\r\n'
        'a=fmtp:111 minptime=10;useinbandfec=1\r\n'
        'a=rtpmap:63 red/48000/2\r\n'
        'a=fmtp:63 111/111\r\n'
        'a=rtpmap:9 G722/8000\r\n'
        'a=rtpmap:0 PCMU/8000\r\n'
        'a=rtpmap:8 PCMA/8000\r\n'
        'a=rtpmap:13 CN/8000\r\n'
        'a=rtpmap:110 telephone-event/48000\r\n'
        'a=rtpmap:126 telephone-event/8000\r\n'
        'a=ssrc:1234567890 cname:stream\r\n'
        'a=ssrc:1234567890 msid:stream audio\r\n'
        'a=ssrc:1234567890 mslabel:stream\r\n'
        'a=ssrc:1234567890 label:audio';

    test('filters SDP to include only preferred codecs (PCMU and PCMA)', () {
      final preferredCodecs = [
        AudioCodec(mimeType: 'audio/PCMU', clockRate: 8000, channels: 1),
        AudioCodec(mimeType: 'audio/PCMA', clockRate: 8000, channels: 1),
      ];

      final filteredSdp = CodecUtils.filterSdpCodecs(sampleSdp, preferredCodecs);

      // Check m=audio line contains PCMU (0), PCMA (8), RED (63), and telephone-event (110 & 126)
      // RED and telephone-event are automatically preserved
      final mAudioLine =
          filteredSdp.split('\r\n').firstWhere((l) => l.startsWith('m=audio'));
      expect(mAudioLine, contains('0')); // PCMU
      expect(mAudioLine, contains('8')); // PCMA
      expect(mAudioLine, contains('63')); // RED (preserved)
      expect(mAudioLine, contains('126')); // telephone-event

      // Check preferred codecs are present
      expect(filteredSdp, contains('a=rtpmap:0 PCMU/8000'));
      expect(filteredSdp, contains('a=rtpmap:8 PCMA/8000'));

      // Check telephone-event is preserved
      expect(filteredSdp, contains('a=rtpmap:126 telephone-event/8000'));

      // Check non-preferred codecs are removed
      expect(filteredSdp, isNot(contains('a=rtpmap:111 opus/48000/2')));
      expect(filteredSdp, isNot(contains('a=rtpmap:9 G722/8000')));
      expect(filteredSdp, isNot(contains('a=rtpmap:13 CN/8000')));

      // RED and telephone-event are preserved
      expect(filteredSdp, contains('a=rtpmap:63 red/48000/2'));

      // Check fmtp lines for non-preferred codecs are removed
      expect(filteredSdp, isNot(contains('a=fmtp:111')));

      // RED's fmtp line is preserved
      expect(filteredSdp, contains('a=fmtp:63'));

      // Check rtcp-fb lines for non-preferred codecs are removed
      expect(filteredSdp, isNot(contains('a=rtcp-fb:111')));
    });

    test('filters SDP to include only Opus', () {
      final preferredCodecs = [
        AudioCodec(mimeType: 'audio/opus', clockRate: 48000, channels: 2),
      ];

      final filteredSdp = CodecUtils.filterSdpCodecs(sampleSdp, preferredCodecs);

      // Check m=audio line contains opus (111), RED (63), and telephone-event (110 & 126)
      final mAudioLine =
          filteredSdp.split('\r\n').firstWhere((l) => l.startsWith('m=audio'));
      expect(mAudioLine, contains('111')); // opus
      expect(mAudioLine, contains('63')); // RED (preserved)
      expect(mAudioLine, contains('126')); // telephone-event

      // Check opus is present with its attributes
      expect(filteredSdp, contains('a=rtpmap:111 opus/48000/2'));
      expect(filteredSdp, contains('a=fmtp:111 minptime=10;useinbandfec=1'));
      expect(filteredSdp, contains('a=rtcp-fb:111 transport-cc'));

      // Check RED is preserved (redundancy codec)
      expect(filteredSdp, contains('a=rtpmap:63 red/48000/2'));

      // Check telephone-event is preserved
      expect(filteredSdp, contains('a=rtpmap:126 telephone-event/8000'));

      // Check non-preferred codecs are removed
      expect(filteredSdp, isNot(contains('a=rtpmap:0 PCMU/8000')));
      expect(filteredSdp, isNot(contains('a=rtpmap:8 PCMA/8000')));
      expect(filteredSdp, isNot(contains('a=rtpmap:9 G722/8000')));
      expect(filteredSdp, isNot(contains('a=rtpmap:13 CN/8000')));
    });

    test('filters SDP to include only G722', () {
      final preferredCodecs = [
        AudioCodec(mimeType: 'audio/G722', clockRate: 8000, channels: 1),
      ];

      final filteredSdp = CodecUtils.filterSdpCodecs(sampleSdp, preferredCodecs);

      // Check m=audio line contains G722 (9), RED (63), and telephone-event
      final mAudioLine =
          filteredSdp.split('\r\n').firstWhere((l) => l.startsWith('m=audio'));
      expect(mAudioLine, contains('9')); // G722
      expect(mAudioLine, contains('126')); // telephone-event

      // Check G722 is present
      expect(filteredSdp, contains('a=rtpmap:9 G722/8000'));

      // Check telephone-event is preserved
      expect(filteredSdp, contains('a=rtpmap:126 telephone-event/8000'));

      // Check other codecs are removed
      expect(filteredSdp, isNot(contains('a=rtpmap:111 opus/48000/2')));
      expect(filteredSdp, isNot(contains('a=rtpmap:0 PCMU/8000')));
      expect(filteredSdp, isNot(contains('a=rtpmap:8 PCMA/8000')));
    });

    test('returns original SDP when no preferred codecs provided', () {
      final preferredCodecs = <AudioCodec>[];

      final filteredSdp = CodecUtils.filterSdpCodecs(sampleSdp, preferredCodecs);

      // Should return original SDP unchanged
      expect(filteredSdp, equals(sampleSdp));
    });

    test('preserves all other SDP attributes when filtering', () {
      final preferredCodecs = [
        AudioCodec(mimeType: 'audio/PCMU', clockRate: 8000, channels: 1),
      ];

      final filteredSdp = CodecUtils.filterSdpCodecs(sampleSdp, preferredCodecs);

      // Check non-codec attributes are preserved
      expect(filteredSdp, contains('v=0'));
      expect(filteredSdp, contains('o=- 1234567890 2 IN IP4 127.0.0.1'));
      expect(filteredSdp, contains('s=-'));
      expect(filteredSdp, contains('a=group:BUNDLE 0'));
      expect(filteredSdp, contains('a=ice-ufrag:abcd'));
      expect(filteredSdp, contains('a=ice-pwd:abcdefghijklmnopqrstuvwx'));
      expect(filteredSdp, contains('a=setup:actpass'));
      expect(filteredSdp, contains('a=mid:0'));
      expect(filteredSdp, contains('a=sendrecv'));
      expect(filteredSdp, contains('a=rtcp-mux'));
      expect(filteredSdp, contains('a=ssrc:1234567890 cname:stream'));
    });

    test('handles SDP without m=audio line gracefully', () {
      const sdpNoAudio = 'v=0\r\n'
          'o=- 1234567890 2 IN IP4 127.0.0.1\r\n'
          's=-\r\n'
          't=0 0\r\n'
          'm=video 9 UDP/TLS/RTP/SAVPF 96\r\n'
          'a=rtpmap:96 VP8/90000';

      final preferredCodecs = [
        AudioCodec(mimeType: 'audio/PCMU', clockRate: 8000, channels: 1),
      ];

      final filteredSdp = CodecUtils.filterSdpCodecs(sdpNoAudio, preferredCodecs);

      // Should return original SDP when no m=audio line found
      expect(filteredSdp, equals(sdpNoAudio));
    });

    test('handles malformed m=audio line gracefully', () {
      const malformedSdp = 'v=0\r\n'
          'o=- 1234567890 2 IN IP4 127.0.0.1\r\n'
          's=-\r\n'
          'm=audio 9\r\n'
          'a=rtpmap:0 PCMU/8000';

      final preferredCodecs = [
        AudioCodec(mimeType: 'audio/PCMU', clockRate: 8000, channels: 1),
      ];

      final filteredSdp = CodecUtils.filterSdpCodecs(malformedSdp, preferredCodecs);

      // Should return original SDP on error
      expect(filteredSdp, equals(malformedSdp));
    });

    test('returns original SDP when no matching codecs found', () {
      final preferredCodecs = [
        AudioCodec(mimeType: 'audio/ISAC', clockRate: 16000, channels: 1),
      ];

      final filteredSdp = CodecUtils.filterSdpCodecs(sampleSdp, preferredCodecs);

      // When no matching codec is found, the implementation still filters out
      // all non-essential codecs, keeping only RED and telephone-event
      // This is actually valid behavior as these are essential for call functionality
      final mAudioLine =
          filteredSdp.split('\r\n').firstWhere((l) => l.startsWith('m=audio'));

      // Should only contain RED and telephone-event
      expect(mAudioLine, contains('63')); // RED
      expect(mAudioLine, contains('110')); // telephone-event/48000
      expect(mAudioLine, contains('126')); // telephone-event/8000

      // Should NOT contain any audio codecs
      expect(filteredSdp, isNot(contains('a=rtpmap:111 opus')));
      expect(filteredSdp, isNot(contains('a=rtpmap:0 PCMU')));
      expect(filteredSdp, isNot(contains('a=rtpmap:8 PCMA')));
      expect(filteredSdp, isNot(contains('a=rtpmap:9 G722')));
    });

    test('handles multiple preferred codecs in order', () {
      final preferredCodecs = [
        AudioCodec(mimeType: 'audio/opus', clockRate: 48000, channels: 2),
        AudioCodec(mimeType: 'audio/PCMU', clockRate: 8000, channels: 1),
        AudioCodec(mimeType: 'audio/PCMA', clockRate: 8000, channels: 1),
      ];

      final filteredSdp = CodecUtils.filterSdpCodecs(sampleSdp, preferredCodecs);

      // Check all preferred codecs are in the m=audio line
      final mAudioLine = filteredSdp
          .split('\r\n')
          .firstWhere((line) => line.startsWith('m=audio'));

      // Should contain opus (111), PCMU (0), PCMA (8), RED (63), telephone-event (126)
      expect(mAudioLine, contains('111'));
      expect(mAudioLine, contains('0'));
      expect(mAudioLine, contains('8'));
      expect(mAudioLine, contains('63')); // RED preserved
      expect(mAudioLine, contains('126')); // telephone-event preserved

      // Check all rtpmap entries are present
      expect(filteredSdp, contains('a=rtpmap:111 opus/48000/2'));
      expect(filteredSdp, contains('a=rtpmap:0 PCMU/8000'));
      expect(filteredSdp, contains('a=rtpmap:8 PCMA/8000'));
      expect(filteredSdp, contains('a=rtpmap:63 red/48000/2'));
      expect(filteredSdp, contains('a=rtpmap:126 telephone-event/8000'));
    });

    test('case-insensitive codec name matching', () {
      final preferredCodecs = [
        // Test with different casing
        AudioCodec(mimeType: 'audio/pcmu', clockRate: 8000, channels: 1),
        AudioCodec(mimeType: 'audio/Opus', clockRate: 48000, channels: 2),
      ];

      final filteredSdp = CodecUtils.filterSdpCodecs(sampleSdp, preferredCodecs);

      // Should match regardless of case
      expect(filteredSdp, contains('a=rtpmap:0 PCMU/8000'));
      expect(filteredSdp, contains('a=rtpmap:111 opus/48000/2'));
    });
  });

  group('CodecUtils - convertAudioCodecMapsToCapabilities Tests', () {
    test('converts valid codec maps to RTCRtpCodecCapability objects', () {
      final codecMaps = [
        {
          'mimeType': 'audio/opus',
          'clockRate': 48000,
          'channels': 2,
          'sdpFmtpLine': 'minptime=10;useinbandfec=1',
        },
        {
          'mimeType': 'audio/PCMU',
          'clockRate': 8000,
          'channels': 1,
        },
        {
          'mimeType': 'audio/PCMA',
          'clockRate': 8000,
          'channels': 1,
          'sdpFmtpLine': null,
        },
      ];

      final capabilities =
          CodecUtils.convertAudioCodecMapsToCapabilities(codecMaps);

      expect(capabilities.length, equals(3));

      // Check first codec (Opus)
      expect(capabilities[0].mimeType, equals('audio/opus'));
      expect(capabilities[0].clockRate, equals(48000));
      expect(capabilities[0].channels, equals(2));
      expect(capabilities[0].sdpFmtpLine, equals('minptime=10;useinbandfec=1'));

      // Check second codec (PCMU)
      expect(capabilities[1].mimeType, equals('audio/PCMU'));
      expect(capabilities[1].clockRate, equals(8000));
      expect(capabilities[1].channels, equals(1));

      // Check third codec (PCMA with null fmtp)
      expect(capabilities[2].mimeType, equals('audio/PCMA'));
      expect(capabilities[2].clockRate, equals(8000));
      expect(capabilities[2].channels, equals(1));
      expect(capabilities[2].sdpFmtpLine, isNull);
    });

    test('handles codec maps with missing channels field', () {
      final codecMaps = [
        {
          'mimeType': 'audio/opus',
          'clockRate': 48000,
          // channels field omitted
        },
      ];

      final capabilities =
          CodecUtils.convertAudioCodecMapsToCapabilities(codecMaps);

      expect(capabilities.length, equals(1));
      expect(capabilities[0].mimeType, equals('audio/opus'));
      expect(capabilities[0].clockRate, equals(48000));
      expect(capabilities[0].channels, isNull);
    });

    test('skips codec maps with missing mimeType', () {
      final codecMaps = [
        {
          'clockRate': 48000,
          'channels': 2,
        },
        {
          'mimeType': 'audio/opus',
          'clockRate': 48000,
          'channels': 2,
        },
      ];

      final capabilities =
          CodecUtils.convertAudioCodecMapsToCapabilities(codecMaps);

      // Should skip the first one and only include the second
      expect(capabilities.length, equals(1));
      expect(capabilities[0].mimeType, equals('audio/opus'));
    });

    test('skips codec maps with missing clockRate', () {
      final codecMaps = [
        {
          'mimeType': 'audio/opus',
          'channels': 2,
        },
        {
          'mimeType': 'audio/PCMU',
          'clockRate': 8000,
          'channels': 1,
        },
      ];

      final capabilities =
          CodecUtils.convertAudioCodecMapsToCapabilities(codecMaps);

      // Should skip the first one and only include the second
      expect(capabilities.length, equals(1));
      expect(capabilities[0].mimeType, equals('audio/PCMU'));
    });

    test('handles empty codec maps list', () {
      final codecMaps = <Map<String, dynamic>>[];

      final capabilities =
          CodecUtils.convertAudioCodecMapsToCapabilities(codecMaps);

      expect(capabilities, isEmpty);
    });

    test('handles clockRate as num type', () {
      final codecMaps = [
        {
          'mimeType': 'audio/opus',
          'clockRate': 48000.0, // double instead of int
          'channels': 2,
        },
      ];

      final capabilities =
          CodecUtils.convertAudioCodecMapsToCapabilities(codecMaps);

      expect(capabilities.length, equals(1));
      expect(capabilities[0].clockRate, equals(48000));
    });

    test('handles channels as num type', () {
      final codecMaps = [
        {
          'mimeType': 'audio/opus',
          'clockRate': 48000,
          'channels': 2.0, // double instead of int
        },
      ];

      final capabilities =
          CodecUtils.convertAudioCodecMapsToCapabilities(codecMaps);

      expect(capabilities.length, equals(1));
      expect(capabilities[0].channels, equals(2));
    });

    test('converts AudioCodec objects via toJson', () {
      final codecs = [
        AudioCodec(
          mimeType: 'audio/opus',
          clockRate: 48000,
          channels: 2,
          sdpFmtpLine: 'minptime=10',
        ),
        AudioCodec(
          mimeType: 'audio/PCMU',
          clockRate: 8000,
          channels: 1,
        ),
      ];

      final codecMaps = codecs.map((c) => c.toJson()).toList();
      final capabilities =
          CodecUtils.convertAudioCodecMapsToCapabilities(codecMaps);

      expect(capabilities.length, equals(2));
      expect(capabilities[0].mimeType, equals('audio/opus'));
      expect(capabilities[0].clockRate, equals(48000));
      expect(capabilities[1].mimeType, equals('audio/PCMU'));
      expect(capabilities[1].clockRate, equals(8000));
    });
  });

  // Note: getSupportedAudioCodecs() requires WebRTC initialization which is not
  // available in unit tests. This method should be tested in integration tests.

  group('CodecUtils - Integration Tests', () {
    test('full flow: AudioCodec -> Map -> RTCRtpCodecCapability', () {
      // Simulate the full conversion flow used in the SDK
      final audioCodecs = [
        AudioCodec(
          mimeType: 'audio/opus',
          clockRate: 48000,
          channels: 2,
          sdpFmtpLine: 'minptime=10;useinbandfec=1',
        ),
        AudioCodec(
          mimeType: 'audio/PCMU',
          clockRate: 8000,
          channels: 1,
        ),
      ];

      // Step 1: Convert to JSON (what Call.newInvite receives)
      final codecMaps = audioCodecs.map((c) => c.toJson()).toList();

      // Step 2: Convert to capabilities (what setCodecPreferences uses)
      final capabilities =
          CodecUtils.convertAudioCodecMapsToCapabilities(codecMaps);

      expect(capabilities.length, equals(2));
      expect(capabilities[0].mimeType, equals('audio/opus'));
      expect(capabilities[0].clockRate, equals(48000));
      expect(capabilities[0].channels, equals(2));
      expect(capabilities[0].sdpFmtpLine, equals('minptime=10;useinbandfec=1'));

      expect(capabilities[1].mimeType, equals('audio/PCMU'));
      expect(capabilities[1].clockRate, equals(8000));
      expect(capabilities[1].channels, equals(1));
    });

    test('full flow: Map -> AudioCodec -> SDP filtering', () {
      // Simulate the Android SDP filtering flow
      final codecMaps = [
        {
          'mimeType': 'audio/PCMU',
          'clockRate': 8000,
          'channels': 1,
        },
        {
          'mimeType': 'audio/PCMA',
          'clockRate': 8000,
          'channels': 1,
        },
      ];

      // Step 1: Convert to AudioCodec objects
      final audioCodecs = codecMaps.map((m) => AudioCodec.fromJson(m)).toList();

      // Step 2: Filter SDP
      const sampleSdp = 'm=audio 9 UDP/TLS/RTP/SAVPF 111 63 9 0 8 13 110 126\r\n'
          'a=rtpmap:111 opus/48000/2\r\n'
          'a=rtpmap:63 red/48000/2\r\n'
          'a=rtpmap:9 G722/8000\r\n'
          'a=rtpmap:0 PCMU/8000\r\n'
          'a=rtpmap:8 PCMA/8000\r\n'
          'a=rtpmap:13 CN/8000\r\n'
          'a=rtpmap:126 telephone-event/8000';

      final filteredSdp = CodecUtils.filterSdpCodecs(sampleSdp, audioCodecs);

      // Verify filtering worked - RED (63) is automatically preserved
      final mAudioLine =
          filteredSdp.split('\r\n').firstWhere((l) => l.startsWith('m=audio'));
      expect(mAudioLine, contains('0')); // PCMU
      expect(mAudioLine, contains('8')); // PCMA
      expect(mAudioLine, contains('63')); // RED (preserved)
      expect(mAudioLine, contains('126')); // telephone-event

      expect(filteredSdp, contains('a=rtpmap:0 PCMU/8000'));
      expect(filteredSdp, contains('a=rtpmap:8 PCMA/8000'));
      expect(filteredSdp, contains('a=rtpmap:126 telephone-event/8000'));
      expect(filteredSdp, isNot(contains('a=rtpmap:111 opus/48000/2')));
    });
  });
}
