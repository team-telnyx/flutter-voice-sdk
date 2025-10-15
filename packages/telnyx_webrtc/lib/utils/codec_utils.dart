import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:telnyx_webrtc/model/audio_codec.dart';
import 'package:telnyx_webrtc/utils/logging/global_logger.dart';

/// Utility class for audio codec operations in WebRTC.
/// Provides functionality for codec parsing from SDP strings and RTP capabilities.
class CodecUtils {
  static const int _defaultAudioChannels = 1;

  /// Returns a list of audio codecs supported by WebRTC for this device.
  ///
  /// This method queries the native WebRTC RTP sender capabilities API to retrieve
  /// the actual audio codecs supported by the WebRTC library. This is the most efficient
  /// way to discover available codecs as it uses the platform's built-in capabilities query
  /// without creating any peer connections or media streams.
  ///
  /// The method directly calls `getRtpSenderCapabilities('audio')` which queries:
  /// - **Native platforms (iOS/Android)**: WebRTC native library via platform channel
  /// - **Web platform**: Browser's `RTCRtpSender.getCapabilities('audio')` API
  ///
  /// **Common codecs** returned include: Opus, PCMU, PCMA, G722, RED, CN, and telephone-event.
  /// ```
  static Future<List<AudioCodec>> getSupportedAudioCodecs() async {
    try {
      GlobalLogger().d('Querying WebRTC audio codecs via RTP capabilities');

      // Query capabilities directly from WebRTC without creating a peer connection
      final capabilities = await getRtpSenderCapabilities('audio');

      // Convert to AudioCodec list
      final codecs = _convertCapabilitiesToAudioCodecs(capabilities);

      GlobalLogger().d(
        'Retrieved ${codecs.length} audio codecs: ${codecs.map((c) => c.mimeType).toList()}',
      );

      return codecs;
    } catch (e) {
      GlobalLogger().e('Error retrieving supported audio codecs: $e');
      return [];
    }
  }

  /// Converts RTCRtpCapabilities to a list of AudioCodec objects.
  /// This is the preferred method for querying available codecs as it uses
  /// the native WebRTC API instead of parsing SDP.
  ///
  /// [capabilities] The RTP capabilities obtained from getRtpSenderCapabilities
  /// Returns a List of [AudioCodec] objects
  static List<AudioCodec> _convertCapabilitiesToAudioCodecs(
    RTCRtpCapabilities capabilities,
  ) {
    final codecs = <AudioCodec>[];

    if (capabilities.codecs == null || capabilities.codecs!.isEmpty) {
      GlobalLogger().w('No codecs found in RTCRtpCapabilities');
      return codecs;
    }

    for (final codecCapability in capabilities.codecs!) {
      try {
        // Only process audio codecs
        if (!codecCapability.mimeType.toLowerCase().startsWith('audio/')) {
          continue;
        }

        codecs.add(
          AudioCodec(
            mimeType: codecCapability.mimeType,
            clockRate: codecCapability.clockRate.toInt(),
            channels:
                codecCapability.channels?.toInt() ?? _defaultAudioChannels,
            sdpFmtpLine: codecCapability.sdpFmtpLine,
          ),
        );
      } catch (e) {
        GlobalLogger().w(
          'Failed to convert codec capability: ${codecCapability.mimeType} - $e',
        );
      }
    }

    GlobalLogger()
        .d('Converted ${codecs.length} audio codecs from capabilities');
    return codecs;
  }
}
