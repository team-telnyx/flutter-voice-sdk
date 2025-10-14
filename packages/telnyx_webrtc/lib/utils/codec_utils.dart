import 'package:telnyx_webrtc/model/audio_codec.dart';
import 'package:telnyx_webrtc/utils/logging/global_logger.dart';

/// Utility class for audio codec operations in WebRTC.
/// Provides functionality for codec parsing from SDP strings.
class CodecUtils {
  static const int _rtpmapPrefixLength = 9; // Length of "a=rtpmap:" prefix
  static const int _defaultAudioChannels = 1;

  /// Parses audio codecs from an SDP string by extracting rtpmap lines.
  /// Example rtpmap line: a=rtpmap:111 opus/48000/2
  ///
  /// [sdp] The SDP string to parse
  /// Returns a List of [AudioCodec] objects parsed from the SDP
  static List<AudioCodec> parseAudioCodecsFromSdp(String sdp) {
    final lines = sdp.split(RegExp(r'\r\n|\n'));
    final audioSectionLines = _extractAudioSectionLines(lines);
    final codecMap = <String, AudioCodec>{};

    // Parse rtpmap lines
    for (final line in audioSectionLines) {
      if (line.startsWith('a=rtpmap:')) {
        final codec = _parseRtpmapLine(line);
        if (codec != null) {
          // Extract payload type from the line
          final payloadType = line.substring(_rtpmapPrefixLength).split(' ')[0];
          codecMap[payloadType] = codec;
        }
      }
    }

    // Parse fmtp lines and add them to corresponding codecs
    for (final line in audioSectionLines) {
      if (line.startsWith('a=fmtp:')) {
        _parseFmtpLine(line, codecMap);
      }
    }

    return codecMap.values.toList();
  }

  /// Extracts lines from the audio media section of SDP.
  ///
  /// [lines] All lines from the SDP
  /// Returns a List of relevant lines from the audio section
  static List<String> _extractAudioSectionLines(List<String> lines) {
    final audioLines = <String>[];
    var inAudioSection = false;

    for (final line in lines) {
      if (line.startsWith('m=audio')) {
        inAudioSection = true;
      } else if (line.startsWith('m=')) {
        inAudioSection = false;
      } else if (inAudioSection &&
          (line.startsWith('a=rtpmap:') || line.startsWith('a=fmtp:'))) {
        audioLines.add(line);
      }
    }

    return audioLines;
  }

  /// Parses a single rtpmap line into an AudioCodec object.
  /// Format: a=rtpmap:<payload_type> <codec_name>/<clock_rate>[/<channels>]
  ///
  /// [line] The rtpmap line to parse
  /// Returns an [AudioCodec] if parsing succeeds, null otherwise
  static AudioCodec? _parseRtpmapLine(String line) {
    try {
      final parts = line.substring(_rtpmapPrefixLength).split(' ');
      if (parts.length < 2) return null;

      final codecInfo = parts[1].split('/');
      if (codecInfo.isEmpty) return null;

      final codecName = codecInfo[0];
      final clockRate =
          codecInfo.length > 1 ? int.tryParse(codecInfo[1]) : null;
      final channels = codecInfo.length > 2
          ? int.tryParse(codecInfo[2]) ?? _defaultAudioChannels
          : _defaultAudioChannels;

      if (clockRate == null) {
        GlobalLogger().w('Failed to parse clock rate from rtpmap line: $line');
        return null;
      }

      return AudioCodec(
        mimeType: 'audio/$codecName',
        clockRate: clockRate,
        channels: channels,
      );
    } catch (e) {
      GlobalLogger().w('Failed to parse rtpmap line: $line - $e');
      return null;
    }
  }

  /// Parses an fmtp line and adds the format-specific parameters to the
  /// corresponding codec in the codecMap.
  /// Format: a=fmtp:<payload_type> <parameters>
  ///
  /// [line] The fmtp line to parse
  /// [codecMap] Map of payload types to AudioCodec objects
  static void _parseFmtpLine(String line, Map<String, AudioCodec> codecMap) {
    try {
      final content = line.substring(7); // Skip "a=fmtp:"
      final spaceIndex = content.indexOf(' ');
      if (spaceIndex == -1) return;

      final payloadType = content.substring(0, spaceIndex);
      final parameters = content.substring(spaceIndex + 1);

      final codec = codecMap[payloadType];
      if (codec != null) {
        // Create a new codec with the fmtp parameters
        codecMap[payloadType] = AudioCodec(
          mimeType: codec.mimeType,
          clockRate: codec.clockRate,
          channels: codec.channels,
          sdpFmtpLine: parameters,
        );
      }
    } catch (e) {
      GlobalLogger().w('Failed to parse fmtp line: $line - $e');
    }
  }
}
