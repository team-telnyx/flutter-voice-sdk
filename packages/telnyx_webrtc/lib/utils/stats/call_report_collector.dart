import 'dart:async';
import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'package:telnyx_webrtc/utils/logging/global_logger.dart';
import 'package:telnyx_webrtc/utils/version_utils.dart';

/// Configuration options for call report collection
class CallReportOptions {
  /// Whether call reporting is enabled
  final bool enabled;

  /// Stats collection interval in milliseconds (default: 5000)
  final int intervalMs;

  /// Maximum number of stats intervals to buffer (default: 360 = 30 mins at 5s intervals)
  final int maxBufferSize;

  const CallReportOptions({
    this.enabled = true,
    this.intervalMs = 5000,
    this.maxBufferSize = 360,
  });
}

/// Summary information about the call
class CallSummary {
  final String callId;
  final String? destinationNumber;
  final String? callerNumber;
  final String direction; // 'inbound' or 'outbound'
  final String? state;
  final double? durationSeconds;
  final String? telnyxSessionId;
  final String? telnyxLegId;
  final String? voiceSdkId;
  final String sdkVersion;
  final String? startTimestamp;
  final String? endTimestamp;

  CallSummary({
    required this.callId,
    this.destinationNumber,
    this.callerNumber,
    required this.direction,
    this.state,
    this.durationSeconds,
    this.telnyxSessionId,
    this.telnyxLegId,
    this.voiceSdkId,
    required this.sdkVersion,
    this.startTimestamp,
    this.endTimestamp,
  });

  Map<String, dynamic> toJson() => {
        'callId': callId,
        if (destinationNumber != null) 'destinationNumber': destinationNumber,
        if (callerNumber != null) 'callerNumber': callerNumber,
        'direction': direction,
        if (state != null) 'state': state,
        if (durationSeconds != null) 'durationSeconds': durationSeconds,
        if (telnyxSessionId != null) 'telnyxSessionId': telnyxSessionId,
        if (telnyxLegId != null) 'telnyxLegId': telnyxLegId,
        if (voiceSdkId != null) 'voiceSdkId': voiceSdkId,
        'sdkVersion': sdkVersion,
        if (startTimestamp != null) 'startTimestamp': startTimestamp,
        if (endTimestamp != null) 'endTimestamp': endTimestamp,
      };
}

/// Stats collected during a single interval
class StatsInterval {
  final String intervalStartUtc;
  final String intervalEndUtc;
  final AudioStats? audio;
  final ConnectionStats? connection;

  StatsInterval({
    required this.intervalStartUtc,
    required this.intervalEndUtc,
    this.audio,
    this.connection,
  });

  Map<String, dynamic> toJson() => {
        'intervalStartUtc': intervalStartUtc,
        'intervalEndUtc': intervalEndUtc,
        if (audio != null) 'audio': audio!.toJson(),
        if (connection != null) 'connection': connection!.toJson(),
      };
}

/// Audio statistics for inbound and outbound streams
class AudioStats {
  final OutboundAudioStats? outbound;
  final InboundAudioStats? inbound;

  AudioStats({this.outbound, this.inbound});

  Map<String, dynamic> toJson() => {
        if (outbound != null) 'outbound': outbound!.toJson(),
        if (inbound != null) 'inbound': inbound!.toJson(),
      };
}

/// Outbound audio statistics
class OutboundAudioStats {
  final int? packetsSent;
  final int? bytesSent;
  final double? audioLevelAvg;
  final double? bitrateAvg;

  OutboundAudioStats({
    this.packetsSent,
    this.bytesSent,
    this.audioLevelAvg,
    this.bitrateAvg,
  });

  Map<String, dynamic> toJson() => {
        if (packetsSent != null) 'packetsSent': packetsSent,
        if (bytesSent != null) 'bytesSent': bytesSent,
        if (audioLevelAvg != null) 'audioLevelAvg': audioLevelAvg,
        if (bitrateAvg != null) 'bitrateAvg': bitrateAvg,
      };
}

/// Inbound audio statistics
class InboundAudioStats {
  final int? packetsReceived;
  final int? bytesReceived;
  final int? packetsLost;
  final int? packetsDiscarded;
  final double? jitterBufferDelay;
  final int? jitterBufferEmittedCount;
  final int? totalSamplesReceived;
  final int? concealedSamples;
  final int? concealmentEvents;
  final double? audioLevelAvg;
  final double? jitterAvg;
  final double? bitrateAvg;

  InboundAudioStats({
    this.packetsReceived,
    this.bytesReceived,
    this.packetsLost,
    this.packetsDiscarded,
    this.jitterBufferDelay,
    this.jitterBufferEmittedCount,
    this.totalSamplesReceived,
    this.concealedSamples,
    this.concealmentEvents,
    this.audioLevelAvg,
    this.jitterAvg,
    this.bitrateAvg,
  });

  Map<String, dynamic> toJson() => {
        if (packetsReceived != null) 'packetsReceived': packetsReceived,
        if (bytesReceived != null) 'bytesReceived': bytesReceived,
        if (packetsLost != null) 'packetsLost': packetsLost,
        if (packetsDiscarded != null) 'packetsDiscarded': packetsDiscarded,
        if (jitterBufferDelay != null) 'jitterBufferDelay': jitterBufferDelay,
        if (jitterBufferEmittedCount != null)
          'jitterBufferEmittedCount': jitterBufferEmittedCount,
        if (totalSamplesReceived != null)
          'totalSamplesReceived': totalSamplesReceived,
        if (concealedSamples != null) 'concealedSamples': concealedSamples,
        if (concealmentEvents != null) 'concealmentEvents': concealmentEvents,
        if (audioLevelAvg != null) 'audioLevelAvg': audioLevelAvg,
        if (jitterAvg != null) 'jitterAvg': jitterAvg,
        if (bitrateAvg != null) 'bitrateAvg': bitrateAvg,
      };
}

/// Connection statistics
class ConnectionStats {
  final double? roundTripTimeAvg;
  final int? packetsSent;
  final int? packetsReceived;
  final int? bytesSent;
  final int? bytesReceived;

  ConnectionStats({
    this.roundTripTimeAvg,
    this.packetsSent,
    this.packetsReceived,
    this.bytesSent,
    this.bytesReceived,
  });

  Map<String, dynamic> toJson() => {
        if (roundTripTimeAvg != null) 'roundTripTimeAvg': roundTripTimeAvg,
        if (packetsSent != null) 'packetsSent': packetsSent,
        if (packetsReceived != null) 'packetsReceived': packetsReceived,
        if (bytesSent != null) 'bytesSent': bytesSent,
        if (bytesReceived != null) 'bytesReceived': bytesReceived,
      };
}

/// The full call report payload sent to voice-sdk-proxy
class CallReportPayload {
  final CallSummary summary;
  final List<StatsInterval> stats;

  CallReportPayload({
    required this.summary,
    required this.stats,
  });

  Map<String, dynamic> toJson() => {
        'summary': summary.toJson(),
        'stats': stats.map((s) => s.toJson()).toList(),
      };
}

/// CallReportCollector
///
/// Collects WebRTC statistics during a call and posts them to voice-sdk-proxy
/// at the end of the call for quality analysis and debugging.
///
/// Stats Collection Strategy (based on Twilio/Jitsi best practices):
/// - Collects stats at regular intervals (default 5 seconds)
/// - Stores cumulative values (packets, bytes) from WebRTC API
/// - Calculates averages for variable metrics (audio level, jitter, RTT)
/// - Uses in-memory buffer with size limits for long calls
/// - Posts aggregated stats to voice-sdk-proxy on call end
class CallReportCollector {
  final CallReportOptions options;
  RTCPeerConnection? _peerConnection;
  Timer? _collectionTimer;
  final List<StatsInterval> _statsBuffer = [];
  DateTime? _intervalStartTime;
  final DateTime _callStartTime;
  DateTime? _callEndTime;

  // Accumulated values for averaging within an interval
  final List<double> _intervalOutboundAudioLevels = [];
  final List<double> _intervalInboundAudioLevels = [];
  final List<double> _intervalJitters = [];
  final List<double> _intervalRTTs = [];
  final List<double> _intervalOutboundBitrates = [];
  final List<double> _intervalInboundBitrates = [];

  // Previous values for rate calculations
  int? _previousOutboundBytes;
  int? _previousInboundBytes;
  int? _previousTimestamp;

  // Last collected raw stats for interval creation
  Map<String, dynamic>? _lastOutboundAudio;
  Map<String, dynamic>? _lastInboundAudio;
  Map<String, dynamic>? _lastCandidatePair;

  CallReportCollector({
    this.options = const CallReportOptions(),
  }) : _callStartTime = DateTime.now();

  /// Start collecting stats from the peer connection
  void start(RTCPeerConnection peerConnection) {
    if (!options.enabled) {
      GlobalLogger().d('CallReportCollector: Disabled, not starting');
      return;
    }

    _peerConnection = peerConnection;
    _intervalStartTime = DateTime.now();

    GlobalLogger().i(
      'CallReportCollector: Starting stats collection (interval: ${options.intervalMs}ms)',
    );

    _collectionTimer = Timer.periodic(
      Duration(milliseconds: options.intervalMs),
      (_) => _collectStats(),
    );
  }

  /// Stop collecting stats and prepare for final report
  void stop() {
    _collectionTimer?.cancel();
    _collectionTimer = null;
    _callEndTime = DateTime.now();

    // Collect final stats before stopping
    if (_peerConnection != null && _intervalStartTime != null) {
      _collectStats();
    }

    GlobalLogger().i(
      'CallReportCollector: Stopped (${_statsBuffer.length} intervals collected)',
    );
  }

  /// Post the collected stats to voice-sdk-proxy
  Future<void> postReport({
    required CallSummary summary,
    required String callReportId,
    required String host,
    String? voiceSdkId,
  }) async {
    if (!options.enabled || _statsBuffer.isEmpty) {
      GlobalLogger().d(
        'CallReportCollector: Skipping post (enabled=${options.enabled}, buffer=${_statsBuffer.length})',
      );
      return;
    }

    // Calculate duration
    final durationSeconds = _callEndTime != null
        ? (_callEndTime!.difference(_callStartTime).inMilliseconds / 1000)
        : null;

    // Build the report payload
    final payload = CallReportPayload(
      summary: CallSummary(
        callId: summary.callId,
        destinationNumber: summary.destinationNumber,
        callerNumber: summary.callerNumber,
        direction: summary.direction,
        state: summary.state,
        durationSeconds: durationSeconds,
        telnyxSessionId: summary.telnyxSessionId,
        telnyxLegId: summary.telnyxLegId,
        voiceSdkId: voiceSdkId,
        sdkVersion: VersionUtils.getSDKVersion(),
        startTimestamp: _callStartTime.toUtc().toIso8601String(),
        endTimestamp: _callEndTime?.toUtc().toIso8601String(),
      ),
      stats: _statsBuffer,
    );

    try {
      // Convert WebSocket URL to HTTP endpoint
      // ws://host -> http://host, wss://host -> https://host
      final wsUri = Uri.parse(host);
      final httpScheme = wsUri.scheme.replaceFirst('ws', 'http');
      final endpoint = Uri(
        scheme: httpScheme,
        host: wsUri.host,
        port: wsUri.port,
        path: '/call_report',
      );

      GlobalLogger().i(
        'CallReportCollector: Posting report to $endpoint (${_statsBuffer.length} intervals)',
      );

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'x-call-report-id': callReportId,
        'x-call-id': summary.callId,
      };
      if (voiceSdkId != null) {
        headers['x-voice-sdk-id'] = voiceSdkId;
      }

      final response = await http.post(
        endpoint,
        headers: headers,
        body: jsonEncode(payload.toJson()),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        GlobalLogger().i('CallReportCollector: Successfully posted report');
      } else {
        GlobalLogger().e(
          'CallReportCollector: Failed to post report (${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      GlobalLogger().e('CallReportCollector: Error posting report: $e');
    }
  }

  /// Get the current stats buffer (for debugging)
  List<StatsInterval> getStatsBuffer() => List.unmodifiable(_statsBuffer);

  /// Collect stats from the peer connection
  Future<void> _collectStats() async {
    if (_peerConnection == null || _intervalStartTime == null) {
      return;
    }

    try {
      final stats = await _peerConnection!.getStats();
      final now = DateTime.now();

      // Process stats reports
      for (final report in stats) {
        final type = report.type;

        switch (type) {
          case 'outbound-rtp':
            if (report.values['kind'] == 'audio') {
              _lastOutboundAudio = report.values;
              _processOutboundAudio(report.values, now);
            }
            break;
          case 'inbound-rtp':
            if (report.values['kind'] == 'audio') {
              _lastInboundAudio = report.values;
              _processInboundAudio(report.values, now);
            }
            break;
          case 'candidate-pair':
            if (report.values['nominated'] == true ||
                report.values['state'] == 'succeeded') {
              _lastCandidatePair = report.values;
              _processCandidatePair(report.values);
            }
            break;
        }
      }

      _previousTimestamp = now.millisecondsSinceEpoch;

      // Check if interval is complete
      final intervalDuration =
          now.difference(_intervalStartTime!).inMilliseconds;
      if (intervalDuration >= options.intervalMs) {
        _createStatsEntry(now);
        _intervalStartTime = now;
        _resetIntervalAccumulators();
      }
    } catch (e) {
      GlobalLogger().e('CallReportCollector: Error collecting stats: $e');
    }
  }

  void _processOutboundAudio(Map<String, dynamic> stats, DateTime now) {
    // Audio level
    final audioLevel = stats['audioLevel'] as double?;
    if (audioLevel != null) {
      _intervalOutboundAudioLevels.add(audioLevel);
    }

    // Calculate bitrate
    final bytesSent = stats['bytesSent'] as int?;
    if (bytesSent != null &&
        _previousOutboundBytes != null &&
        _previousTimestamp != null) {
      final bytesDelta = bytesSent - _previousOutboundBytes!;
      final timeDelta = now.millisecondsSinceEpoch - _previousTimestamp!;
      if (timeDelta > 0) {
        final bitrate = (bytesDelta * 8 * 1000) / timeDelta; // bps
        _intervalOutboundBitrates.add(bitrate);
      }
    }
    _previousOutboundBytes = bytesSent;
  }

  void _processInboundAudio(Map<String, dynamic> stats, DateTime now) {
    // Audio level
    final audioLevel = stats['audioLevel'] as double?;
    if (audioLevel != null) {
      _intervalInboundAudioLevels.add(audioLevel);
    }

    // Jitter (convert to ms)
    final jitter = stats['jitter'] as double?;
    if (jitter != null) {
      _intervalJitters.add(jitter * 1000);
    }

    // Calculate bitrate
    final bytesReceived = stats['bytesReceived'] as int?;
    if (bytesReceived != null &&
        _previousInboundBytes != null &&
        _previousTimestamp != null) {
      final bytesDelta = bytesReceived - _previousInboundBytes!;
      final timeDelta = now.millisecondsSinceEpoch - _previousTimestamp!;
      if (timeDelta > 0) {
        final bitrate = (bytesDelta * 8 * 1000) / timeDelta; // bps
        _intervalInboundBitrates.add(bitrate);
      }
    }
    _previousInboundBytes = bytesReceived;
  }

  void _processCandidatePair(Map<String, dynamic> stats) {
    // RTT (already in seconds in WebRTC stats)
    final rtt = stats['currentRoundTripTime'] as double?;
    if (rtt != null) {
      _intervalRTTs.add(rtt);
    }
  }

  void _createStatsEntry(DateTime endTime) {
    final entry = StatsInterval(
      intervalStartUtc: _intervalStartTime!.toUtc().toIso8601String(),
      intervalEndUtc: endTime.toUtc().toIso8601String(),
      audio: _createAudioStats(),
      connection: _createConnectionStats(),
    );

    _statsBuffer.add(entry);

    // Enforce buffer size limit
    if (_statsBuffer.length > options.maxBufferSize) {
      _statsBuffer.removeAt(0);
      GlobalLogger().w(
        'CallReportCollector: Buffer limit reached, removed oldest entry',
      );
    }
  }

  AudioStats? _createAudioStats() {
    OutboundAudioStats? outbound;
    InboundAudioStats? inbound;

    if (_lastOutboundAudio != null) {
      outbound = OutboundAudioStats(
        packetsSent: _lastOutboundAudio!['packetsSent'] as int?,
        bytesSent: _lastOutboundAudio!['bytesSent'] as int?,
        audioLevelAvg: _average(_intervalOutboundAudioLevels),
        bitrateAvg: _average(_intervalOutboundBitrates),
      );
    }

    if (_lastInboundAudio != null) {
      inbound = InboundAudioStats(
        packetsReceived: _lastInboundAudio!['packetsReceived'] as int?,
        bytesReceived: _lastInboundAudio!['bytesReceived'] as int?,
        packetsLost: _lastInboundAudio!['packetsLost'] as int?,
        packetsDiscarded: _lastInboundAudio!['packetsDiscarded'] as int?,
        jitterBufferDelay: _lastInboundAudio!['jitterBufferDelay'] as double?,
        jitterBufferEmittedCount:
            _lastInboundAudio!['jitterBufferEmittedCount'] as int?,
        totalSamplesReceived:
            _lastInboundAudio!['totalSamplesReceived'] as int?,
        concealedSamples: _lastInboundAudio!['concealedSamples'] as int?,
        concealmentEvents: _lastInboundAudio!['concealmentEvents'] as int?,
        audioLevelAvg: _average(_intervalInboundAudioLevels),
        jitterAvg: _average(_intervalJitters),
        bitrateAvg: _average(_intervalInboundBitrates),
      );
    }

    if (outbound == null && inbound == null) {
      return null;
    }

    return AudioStats(outbound: outbound, inbound: inbound);
  }

  ConnectionStats? _createConnectionStats() {
    if (_lastCandidatePair == null) {
      return null;
    }

    return ConnectionStats(
      roundTripTimeAvg: _average(_intervalRTTs),
      packetsSent: _lastCandidatePair!['packetsSent'] as int?,
      packetsReceived: _lastCandidatePair!['packetsReceived'] as int?,
      bytesSent: _lastCandidatePair!['bytesSent'] as int?,
      bytesReceived: _lastCandidatePair!['bytesReceived'] as int?,
    );
  }

  double? _average(List<double> values) {
    if (values.isEmpty) return null;
    final sum = values.reduce((a, b) => a + b);
    return double.parse((sum / values.length).toStringAsFixed(4));
  }

  void _resetIntervalAccumulators() {
    _intervalOutboundAudioLevels.clear();
    _intervalInboundAudioLevels.clear();
    _intervalJitters.clear();
    _intervalRTTs.clear();
    _intervalOutboundBitrates.clear();
    _intervalInboundBitrates.clear();
  }
}
