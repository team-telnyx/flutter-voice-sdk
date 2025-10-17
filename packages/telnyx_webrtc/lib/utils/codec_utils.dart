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

  /// Filters SDP to include only preferred audio codecs.
  /// This method is used on Android where setCodecPreferences() doesn't work reliably.
  ///
  /// [sdp] The original SDP string
  /// [preferredCodecs] List of preferred audio codecs in order of preference
  /// Returns the modified SDP with only preferred codecs
  static String filterSdpCodecs(String sdp, List<AudioCodec> preferredCodecs) {
    if (preferredCodecs.isEmpty) {
      GlobalLogger()
          .d('CodecUtils :: No preferred codecs, returning original SDP');
      return sdp;
    }

    try {
      final lines = sdp.split('\r\n');
      final modifiedLines = <String>[];

      // Find the m=audio line
      int? mAudioIndex;
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].startsWith('m=audio ')) {
          mAudioIndex = i;
          break;
        }
      }

      if (mAudioIndex == null) {
        GlobalLogger().w('CodecUtils :: No m=audio line found in SDP');
        return sdp;
      }

      // Parse m=audio line: "m=audio 9 UDP/TLS/RTP/SAVPF 111 63 9 0 8 13 110 126"
      final mAudioLine = lines[mAudioIndex];
      final mAudioParts = mAudioLine.split(' ');
      if (mAudioParts.length < 4) {
        GlobalLogger().w('CodecUtils :: Invalid m=audio line format');
        return sdp;
      }

      // Extract payload types from m=audio line (everything after the transport protocol)
      final payloadTypes = mAudioParts.sublist(3);

      // Build map of payload type -> codec info from a=rtpmap lines
      final payloadToCodec = <String, String>{};
      for (final line in lines) {
        if (line.startsWith('a=rtpmap:')) {
          // Format: "a=rtpmap:111 opus/48000/2"
          final rtpmapMatch =
              RegExp(r'a=rtpmap:(\d+)\s+([^/]+)').firstMatch(line);
          if (rtpmapMatch != null) {
            final payloadType = rtpmapMatch.group(1)!;
            final codecName = rtpmapMatch.group(2)!.toLowerCase();
            payloadToCodec[payloadType] = codecName;
          }
        }
      }

      GlobalLogger().d(
        'CodecUtils :: Found ${payloadToCodec.length} codecs in SDP: $payloadToCodec',
      );

      // Filter payload types to keep only preferred codecs
      final preferredPayloadTypes = <String>[];
      final preferredCodecNames = preferredCodecs
          .map((c) => (c.mimeType ?? 'unknown').split('/').last.toLowerCase())
          .toSet();

      GlobalLogger().d(
        'CodecUtils :: Preferred codec names: $preferredCodecNames',
      );

      for (final payloadType in payloadTypes) {
        final codecName = payloadToCodec[payloadType];
        if (codecName != null) {
          // Keep codec if it matches preferred codecs
          if (preferredCodecNames.contains(codecName)) {
            preferredPayloadTypes.add(payloadType);
            GlobalLogger().d(
              'CodecUtils :: Keeping payload type $payloadType ($codecName)',
            );
          } else if (codecName == 'telephone-event') {
            // Always keep telephone-event for DTMF
            preferredPayloadTypes.add(payloadType);
            GlobalLogger().d(
              'CodecUtils :: Keeping telephone-event payload type $payloadType',
            );
          } else if (codecName == 'red') {
            // Keep RED if it references a preferred codec
            preferredPayloadTypes.add(payloadType);
            GlobalLogger().d(
              'CodecUtils :: Keeping RED payload type $payloadType',
            );
          }
        }
      }

      if (preferredPayloadTypes.isEmpty) {
        GlobalLogger().w(
          'CodecUtils :: No matching codecs found, returning original SDP',
        );
        return sdp;
      }

      // Rebuild m=audio line with filtered payload types
      final newMAudioLine = mAudioParts.sublist(0, 3).join(' ') +
          ' ' +
          preferredPayloadTypes.join(' ');

      GlobalLogger().d(
        'CodecUtils :: Original m=audio: $mAudioLine',
      );
      GlobalLogger().d(
        'CodecUtils :: Modified m=audio: $newMAudioLine',
      );

      // Build set of payload types to keep
      final keepPayloadTypes = preferredPayloadTypes.toSet();

      // Filter all lines, removing codec-related attributes for non-preferred codecs
      for (int i = 0; i < lines.length; i++) {
        if (i == mAudioIndex) {
          // Replace m=audio line with filtered version
          modifiedLines.add(newMAudioLine);
        } else if (lines[i].startsWith('a=rtpmap:') ||
            lines[i].startsWith('a=fmtp:') ||
            lines[i].startsWith('a=rtcp-fb:')) {
          // Extract payload type from attribute line
          final payloadMatch = RegExp(r':(\d+)').firstMatch(lines[i]);
          if (payloadMatch != null) {
            final payloadType = payloadMatch.group(1)!;
            if (keepPayloadTypes.contains(payloadType)) {
              modifiedLines.add(lines[i]);
            } else {
              GlobalLogger().d(
                'CodecUtils :: Removing line: ${lines[i]}',
              );
            }
          } else {
            modifiedLines.add(lines[i]);
          }
        } else {
          // Keep all other lines unchanged
          modifiedLines.add(lines[i]);
        }
      }

      final modifiedSdp = modifiedLines.join('\r\n');
      GlobalLogger().d(
        'CodecUtils :: Successfully filtered SDP, kept ${preferredPayloadTypes.length} codecs',
      );

      return modifiedSdp;
    } catch (e) {
      GlobalLogger().e('CodecUtils :: Error filtering SDP: $e');
      return sdp; // Return original SDP on error
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
