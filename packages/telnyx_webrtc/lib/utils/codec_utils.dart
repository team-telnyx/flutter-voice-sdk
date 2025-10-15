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

  /// Finds the audio transceiver from a peer connection.
  /// This method attempts multiple strategies to identify the audio transceiver,
  /// similar to the Android SDK implementation.
  ///
  /// [peerConnection] The RTCPeerConnection to search for audio transceiver
  /// Returns the audio [RTCRtpTransceiver] if found, null otherwise
  static Future<RTCRtpTransceiver?> findAudioTransceiver(
    RTCPeerConnection peerConnection,
  ) async {
    try {
      final transceivers = await peerConnection.getTransceivers();

      GlobalLogger().d(
        'CodecUtils :: Searching for audio transceiver among ${transceivers.length} transceivers',
      );

      for (final transceiver in transceivers) {
        // Try sender track kind first
        final senderKind = transceiver.sender.track?.kind;
        if (senderKind == 'audio') {
          GlobalLogger().d(
            'CodecUtils :: Found audio transceiver via sender track kind',
          );
          return transceiver;
        }

        // Fallback to receiver track kind
        final receiverKind = transceiver.receiver.track?.kind;
        if (receiverKind == 'audio') {
          GlobalLogger().d(
            'CodecUtils :: Found audio transceiver via receiver track kind',
          );
          return transceiver;
        }
      }

      GlobalLogger().w(
        'CodecUtils :: No audio transceiver found among ${transceivers.length} transceivers',
      );
      return null;
    } catch (e) {
      GlobalLogger().e('CodecUtils :: Error finding audio transceiver: $e');
      return null;
    }
  }

  /// Converts audio codec maps to RTCRtpCodecCapability objects for use with transceiver codec preferences.
  /// This method transforms the Map format (from AudioCodec.toJson()) into the format required
  /// by RTCRtpTransceiver.setCodecPreferences().
  ///
  /// [codecMaps] List of codec maps in the format produced by AudioCodec.toJson()
  /// Returns a List of [RTCRtpCodecCapability] objects ready for setCodecPreferences()
  static List<RTCRtpCodecCapability> convertAudioCodecMapsToCapabilities(
    List<Map<String, dynamic>> codecMaps,
  ) {
    final capabilities = <RTCRtpCodecCapability>[];

    for (final codecMap in codecMaps) {
      try {
        // Extract values from the map with proper type handling
        final mimeType = codecMap['mimeType'] as String?;
        final clockRate = codecMap['clockRate'];
        final channels = codecMap['channels'];
        final sdpFmtpLine = codecMap['sdpFmtpLine'] as String?;

        if (mimeType == null || clockRate == null) {
          GlobalLogger().w(
            'Skipping codec with missing mimeType or clockRate: $codecMap',
          );
          continue;
        }

        capabilities.add(
          RTCRtpCodecCapability(
            mimeType: mimeType,
            clockRate:
                clockRate is int ? clockRate : (clockRate as num).toInt(),
            channels: channels is int
                ? channels
                : (channels != null ? (channels as num).toInt() : null),
            sdpFmtpLine: sdpFmtpLine,
          ),
        );
      } catch (e) {
        GlobalLogger().w(
          'Failed to convert codec map to capability: $codecMap - $e',
        );
      }
    }

    GlobalLogger().d(
      'Converted ${capabilities.length} codec maps to capabilities: ${capabilities.map((c) => c.mimeType).toList()}',
    );
    return capabilities;
  }
}
