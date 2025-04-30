import 'package:telnyx_webrtc/model/call_quality.dart';

/// Represents real-time call quality metrics derived from WebRTC statistics.
class CallQualityMetrics {
  /// Creates a new instance of CallQualityMetrics.
  ///
  /// @param jitter Jitter in seconds
  /// @param rtt Round-trip time in seconds
  /// @param mos Mean Opinion Score (1.0-5.0)
  /// @param quality Call quality rating based on MOS
  /// @param inboundAudio Optional inbound audio statistics
  /// @param outboundAudio Optional outbound audio statistics
  CallQualityMetrics({
    required this.jitter,
    required this.rtt,
    required this.mos,
    required this.quality,
    this.inboundAudio,
    this.outboundAudio,
  });

  /// Jitter in seconds (multiply by 1000 for milliseconds)
  final double jitter;

  /// Round-trip time in seconds (multiply by 1000 for milliseconds)
  final double rtt;

  /// Mean Opinion Score (1.0-5.0)
  final double mos;

  /// Call quality rating based on MOS
  final CallQuality quality;

  /// Inbound audio statistics (optional)
  final Map<String, dynamic>? inboundAudio;

  /// Outbound audio statistics (optional)
  final Map<String, dynamic>? outboundAudio;

  /// Creates a dictionary representation of the metrics.
  ///
  /// @return Dictionary containing the metrics
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'jitter': jitter,
      'rtt': rtt,
      'mos': mos,
      'quality': quality.toString(),
    };

    if (inboundAudio != null) {
      map['inboundAudio'] = inboundAudio;
    }

    if (outboundAudio != null) {
      map['outboundAudio'] = outboundAudio;
    }

    return map;
  }

  /// Creates a string representation of the metrics.
  @override
  String toString() {
    return 'CallQualityMetrics{jitter: ${jitter * 1000}ms, rtt: ${rtt * 1000}ms, mos: $mos, quality: $quality}';
  }
}