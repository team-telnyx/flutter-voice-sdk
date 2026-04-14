import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'package:telnyx_webrtc/utils/logging/global_logger.dart';
import 'package:telnyx_webrtc/utils/stats/call_report_log_collector.dart';
import 'package:telnyx_webrtc/utils/version_utils.dart';

// Conditional import for file I/O (mobile only)
import 'package:telnyx_webrtc/utils/stats/call_report_file_helper_stub.dart'
    if (dart.library.io) 'package:telnyx_webrtc/utils/stats/call_report_file_helper.dart' as file_helper;

/// Configuration options for call report collection
class CallReportOptions {
  /// Stats collection interval in milliseconds (default: 5000)
  final int intervalMs;

  /// Maximum number of stats intervals to buffer (default: 360 = 30 mins at 5s intervals)
  final int maxBufferSize;

  const CallReportOptions({
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
  final IceStats? ice;

  StatsInterval({
    required this.intervalStartUtc,
    required this.intervalEndUtc,
    this.audio,
    this.connection,
    this.ice,
  });

  Map<String, dynamic> toJson() => {
        'intervalStartUtc': intervalStartUtc,
        'intervalEndUtc': intervalEndUtc,
        if (audio != null) 'audio': audio!.toJson(),
        if (connection != null) 'connection': connection!.toJson(),
        if (ice != null) 'ice': ice!.toJson(),
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

/// ICE candidate statistics (local or remote)
class IceCandidateStats {
  final String? address;
  final String? candidateType;
  final String? networkType;
  final int? port;
  final String? protocol;
  final int? priority;
  final String? relatedAddress;
  final int? relatedPort;

  IceCandidateStats({
    this.address,
    this.candidateType,
    this.networkType,
    this.port,
    this.protocol,
    this.priority,
    this.relatedAddress,
    this.relatedPort,
  });

  Map<String, dynamic> toJson() => {
        if (address != null) 'address': address,
        if (candidateType != null) 'candidateType': candidateType,
        if (networkType != null) 'networkType': networkType,
        if (port != null) 'port': port,
        if (priority != null) 'priority': priority,
        if (relatedAddress != null) 'relatedAddress': relatedAddress,
        if (relatedPort != null) 'relatedPort': relatedPort,
        if (protocol != null) 'protocol': protocol,
      };
}

/// ICE connection statistics including selected candidate pair
class IceStats {
  final String? id;
  final IceCandidateStats? local;
  final IceCandidateStats? remote;
  final bool? nominated;
  final int? requestsSent;
  final int? responsesReceived;
  final String? state;
  final bool? writable;

  IceStats({
    this.id,
    this.local,
    this.remote,
    this.nominated,
    this.requestsSent,
    this.responsesReceived,
    this.state,
    this.writable,
  });

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (local != null) 'local': local!.toJson(),
        if (remote != null) 'remote': remote!.toJson(),
        if (nominated != null) 'nominated': nominated,
        if (requestsSent != null) 'requestsSent': requestsSent,
        if (responsesReceived != null) 'responsesReceived': responsesReceived,
        if (state != null) 'state': state,
        if (writable != null) 'writable': writable,
      };
}

/// The full call report payload sent to voice-sdk-proxy
class CallReportPayload {
  final CallSummary summary;
  final List<StatsInterval> stats;
  final List<Map<String, dynamic>>? logs;
  final int? segment;

  CallReportPayload({
    required this.summary,
    required this.stats,
    this.logs,
    this.segment,
  });

  Map<String, dynamic> toJson() => {
        'summary': summary.toJson(),
        'stats': stats.map((s) => s.toJson()).toList(),
        if (logs != null && logs!.isNotEmpty) 'logs': logs,
        if (segment != null) 'segment': segment,
      };
}

/// CallReportCollector
///
/// Collects WebRTC statistics during a call and posts them to voice-sdk-proxy
/// at the end of the call for quality analysis and debugging.
///
/// Features:
/// - Stats collection at regular intervals (default 5 seconds)
/// - Retry logic with exponential backoff for failed uploads
/// - Payload chunking for large reports (>1.9MB)
/// - Local file backup on mobile before uploading
/// - Intermediate segment flushing for long calls (~25 min)
/// - Structured event log integration
class CallReportCollector {
  final CallReportOptions options;
  RTCPeerConnection? _peerConnection;
  Timer? _collectionTimer;
  final List<StatsInterval> _statsBuffer = [];
  DateTime? _intervalStartTime;
  final DateTime _callStartTime;
  DateTime? _callEndTime;

  /// Log collector for structured event logging
  CallReportLogCollector? logCollector;

  // Retry configuration
  static const int _maxRetryAttempts = 3;
  static const List<int> _retryDelaysMs = [1000, 2000, 4000];

  // Payload size limits
  static final int _safePayloadSize = (1.9 * 1024 * 1024).toInt(); // 1.9MB

  // Intermediate segment flushing threshold (~300 entries = ~25 min at 5s)
  static const int _segmentFlushThreshold = 300;

  // Segment counter for chunked uploads
  int _segmentCounter = 0;

  // Upload config stored at start for intermediate flushing
  String? _storedCallReportId;
  String? _storedHost;
  String? _storedVoiceSdkId;
  CallSummary? _storedSummary;

  // Last saved report file path (mobile only)
  String? _lastReportFilePath;

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

  // ICE candidate data
  Map<String, dynamic>? _lastLocalCandidate;
  Map<String, dynamic>? _lastRemoteCandidate;
  String? _selectedLocalCandidateId;
  String? _selectedRemoteCandidateId;

  // Cache of all candidates for lookup
  final Map<String, Map<String, dynamic>> _candidateCache = {};

  CallReportCollector({
    this.options = const CallReportOptions(),
    this.logCollector,
  }) : _callStartTime = DateTime.now();

  /// Start collecting stats from the peer connection
  void start(RTCPeerConnection peerConnection) {
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

  /// Store upload config at call start for intermediate segment flushing
  void storeUploadConfig({
    required String callReportId,
    required String host,
    String? voiceSdkId,
  }) {
    _storedCallReportId = callReportId;
    _storedHost = host;
    _storedVoiceSdkId = voiceSdkId;
  }

  /// Cache an ICE candidate from the onIceCandidate callback.
  /// This is needed because Flutter WebRTC doesn't return local-candidate/remote-candidate
  /// stats from getStats(), so we cache them during ICE gathering instead.
  ///
  /// [candidate] The ICE candidate string (e.g., "candidate:... typ srflx ...")
  /// [sdpMid] The SDP media ID
  /// [sdpMLineIndex] The SDP m-line index
  /// [isLocal] True for local candidates, false for remote
  void cacheIceCandidate({
    required String candidate,
    String? sdpMid,
    int? sdpMLineIndex,
    required bool isLocal,
  }) {
    // Parse the candidate string to extract details
    // Format: "candidate:foundation component protocol priority ip port typ type [raddr relatedAddr] [rport relatedPort] ..."
    final parsed = _parseIceCandidateString(candidate);
    if (parsed == null) return;

    // Generate a unique ID for this candidate (similar to WebRTC stats ID format)
    final candidateId = 'RTCIce${isLocal ? "Lc" : "Rc"}_${parsed['foundation']}_${parsed['port']}';
    
    _candidateCache[candidateId] = {
      'id': candidateId,
      'address': parsed['address'],
      'ip': parsed['address'], // Some platforms use 'ip' instead of 'address'
      'port': parsed['port'],
      'protocol': parsed['protocol'],
      'candidateType': parsed['candidateType'],
      'priority': parsed['priority'],
      'relatedAddress': parsed['relatedAddress'],
      'relatedPort': parsed['relatedPort'],
      'foundation': parsed['foundation'],
      'component': parsed['component'],
    };

    GlobalLogger().d(
      'CallReportCollector: Cached ${isLocal ? "local" : "remote"} candidate $candidateId (${parsed['candidateType']}) at ${parsed['address']}:${parsed['port']}',
    );
  }

  /// Parse an ICE candidate string into its components
  Map<String, dynamic>? _parseIceCandidateString(String candidateStr) {
    try {
      // Remove "candidate:" prefix if present
      String str = candidateStr;
      if (str.startsWith('candidate:')) {
        str = str.substring('candidate:'.length);
      } else if (str.startsWith('a=candidate:')) {
        str = str.substring('a=candidate:'.length);
      }

      final parts = str.split(' ');
      if (parts.length < 8) return null;

      // Standard format: foundation component protocol priority address port typ type [extensions]
      final foundation = parts[0];
      final component = int.tryParse(parts[1]);
      final protocol = parts[2].toLowerCase();
      final priority = int.tryParse(parts[3]);
      final address = parts[4];
      final port = int.tryParse(parts[5]);
      // parts[6] is "typ"
      final candidateType = parts[7]; // host, srflx, prflx, relay

      String? relatedAddress;
      int? relatedPort;

      // Parse optional extensions (raddr, rport, etc.)
      for (int i = 8; i < parts.length - 1; i++) {
        if (parts[i] == 'raddr' && i + 1 < parts.length) {
          relatedAddress = parts[i + 1];
        } else if (parts[i] == 'rport' && i + 1 < parts.length) {
          relatedPort = int.tryParse(parts[i + 1]);
        }
      }

      return {
        'foundation': foundation,
        'component': component,
        'protocol': protocol,
        'priority': priority,
        'address': address,
        'port': port,
        'candidateType': candidateType,
        'relatedAddress': relatedAddress,
        'relatedPort': relatedPort,
      };
    } catch (e) {
      GlobalLogger().w('CallReportCollector: Failed to parse ICE candidate: $e');
      return null;
    }
  }

  /// Extract and cache ICE candidates from an SDP string.
  /// This is needed because remote candidates are often embedded in the SDP
  /// rather than sent via trickle ICE.
  ///
  /// [sdp] The SDP string (offer or answer)
  /// [isLocal] True for local SDP, false for remote SDP
  void cacheIceCandidatesFromSdp(String sdp, {required bool isLocal}) {
    try {
      final lines = sdp.split('\n');
      int candidateCount = 0;
      
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('a=candidate:')) {
          // Extract the candidate string (remove 'a=' prefix)
          final candidateStr = trimmed.substring(2); // Remove 'a='
          cacheIceCandidate(
            candidate: candidateStr,
            isLocal: isLocal,
          );
          candidateCount++;
        }
      }
      
      if (candidateCount > 0) {
        GlobalLogger().d(
          'CallReportCollector: Extracted $candidateCount ${isLocal ? "local" : "remote"} candidates from SDP',
        );
      }
    } catch (e) {
      GlobalLogger().w('CallReportCollector: Failed to parse SDP for candidates: $e');
    }
  }

  /// Stop collecting stats and prepare for final report.
  /// Awaits final stats collection to ensure no data is lost.
  Future<void> stop() async {
    _collectionTimer?.cancel();
    _collectionTimer = null;
    _callEndTime = DateTime.now();

    // Collect final stats before stopping (await to ensure buffer is complete)
    if (_peerConnection != null && _intervalStartTime != null) {
      await _collectStats();
    }

    GlobalLogger().i(
      'CallReportCollector: Stopped (${_statsBuffer.length} intervals collected)',
    );
  }

  /// Get the file path of the last saved report (null on web)
  String? getLastReportFilePath() => _lastReportFilePath;

  /// Post the collected stats to voice-sdk-proxy
  Future<void> postReport({
    required CallSummary summary,
    required String callReportId,
    required String host,
    String? voiceSdkId,
  }) async {
    if (_statsBuffer.isEmpty) {
      GlobalLogger().d(
        'CallReportCollector: Skipping post (buffer empty)',
      );
      return;
    }

    // Calculate duration
    final durationSeconds = _callEndTime != null
        ? (_callEndTime!.difference(_callStartTime).inMilliseconds / 1000)
        : null;

    // Build the final summary
    final finalSummary = CallSummary(
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
    );

    // Get logs from log collector if available
    final logs = logCollector?.getLogsJson();

    // Build the full payload
    final payload = CallReportPayload(
      summary: finalSummary,
      stats: List.from(_statsBuffer),
      logs: logs,
      segment: _segmentCounter > 0 ? _segmentCounter : null,
    );

    final payloadJson = jsonEncode(payload.toJson());

    // Save local backup before uploading (mobile only)
    await _saveLocalBackup(summary.callId, payloadJson);

    // Convert WebSocket URL to HTTP endpoint
    final endpoint = _buildEndpoint(host);
    if (endpoint == null) return;

    final headers = _buildHeaders(callReportId, summary.callId, voiceSdkId);

    // Check payload size and chunk if needed
    if (payloadJson.length > _safePayloadSize) {
      await _postChunkedReport(
        summary: finalSummary,
        stats: List.from(_statsBuffer),
        logs: logs,
        endpoint: endpoint,
        headers: headers,
      );
    } else {
      await _postWithRetry(endpoint, headers, payloadJson);
    }
  }

  /// Post an intermediate segment during a long call
  Future<void> _flushIntermediateSegment() async {
    if (_storedCallReportId == null ||
        _storedHost == null ||
        _storedSummary == null) {
      GlobalLogger().d(
        'CallReportCollector: Cannot flush segment, upload config not stored',
      );
      return;
    }

    final logs = logCollector?.flushLogs();
    final segmentPayload = CallReportPayload(
      summary: _storedSummary!,
      stats: List.from(_statsBuffer),
      logs: logs,
      segment: _segmentCounter,
    );

    final payloadJson = jsonEncode(segmentPayload.toJson());
    final endpoint = _buildEndpoint(_storedHost!);
    if (endpoint == null) return;

    final headers = _buildHeaders(
      _storedCallReportId!,
      _storedSummary!.callId,
      _storedVoiceSdkId,
    );

    GlobalLogger().i(
      'CallReportCollector: Flushing intermediate segment $_segmentCounter (${_statsBuffer.length} intervals)',
    );

    await _postWithRetry(endpoint, headers, payloadJson);

    // Clear buffer and increment segment counter
    _statsBuffer.clear();
    _segmentCounter++;
  }

  /// Post payload with retry logic and exponential backoff
  Future<void> _postWithRetry(
    Uri endpoint,
    Map<String, String> headers,
    String body,
  ) async {
    for (int attempt = 0; attempt < _maxRetryAttempts; attempt++) {
      try {
        GlobalLogger().i(
          'CallReportCollector: Posting report to $endpoint (attempt ${attempt + 1}/$_maxRetryAttempts)',
        );

        final response = await http.post(
          endpoint,
          headers: headers,
          body: body,
        );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          GlobalLogger().i('CallReportCollector: Successfully posted report');
          return;
        } else if (response.statusCode >= 400 && response.statusCode < 500) {
          // Client error - don't retry
          GlobalLogger().e(
            'CallReportCollector: Client error (${response.statusCode}), not retrying: ${response.body}',
          );
          return;
        } else {
          // Server error (5xx) - retry
          GlobalLogger().e(
            'CallReportCollector: Server error (${response.statusCode}): ${response.body}',
          );
          if (attempt < _maxRetryAttempts - 1) {
            await Future.delayed(
              Duration(milliseconds: _retryDelaysMs[attempt]),
            );
          }
        }
      } catch (e) {
        // Network exception - retry
        GlobalLogger().e(
          'CallReportCollector: Network error posting report (attempt ${attempt + 1}): $e',
        );
        if (attempt < _maxRetryAttempts - 1) {
          await Future.delayed(
            Duration(milliseconds: _retryDelaysMs[attempt]),
          );
        }
      }
    }

    GlobalLogger().e(
      'CallReportCollector: Failed to post report after $_maxRetryAttempts attempts',
    );
  }

  /// Post a large report in chunks
  Future<void> _postChunkedReport({
    required CallSummary summary,
    required List<StatsInterval> stats,
    required List<Map<String, dynamic>>? logs,
    required Uri endpoint,
    required Map<String, String> headers,
  }) async {
    GlobalLogger().i(
      'CallReportCollector: Payload too large, splitting into chunks',
    );

    // Estimate per-stat entry size for chunking
    final summaryJson = jsonEncode({'summary': summary.toJson()});
    final overheadSize = summaryJson.length + 200; // JSON structure overhead
    final availableSize = _safePayloadSize - overheadSize;

    // Calculate chunk size based on average stat entry size
    final statsJson = jsonEncode(stats.map((s) => s.toJson()).toList());
    final avgEntrySize =
        stats.isNotEmpty ? statsJson.length ~/ stats.length : 500;
    final entriesPerChunk =
        availableSize ~/ avgEntrySize.clamp(1, availableSize);

    int chunkSegment = _segmentCounter;
    for (int i = 0; i < stats.length; i += entriesPerChunk) {
      final end =
          (i + entriesPerChunk > stats.length) ? stats.length : i + entriesPerChunk;
      final chunk = stats.sublist(i, end);

      // Only include logs in the first chunk
      final chunkLogs = (i == 0) ? logs : null;

      final chunkPayload = CallReportPayload(
        summary: summary,
        stats: chunk,
        logs: chunkLogs,
        segment: chunkSegment,
      );

      final chunkBody = jsonEncode(chunkPayload.toJson());

      GlobalLogger().i(
        'CallReportCollector: Posting chunk segment $chunkSegment (${chunk.length} stats, ${chunkBody.length} bytes)',
      );

      await _postWithRetry(endpoint, headers, chunkBody);
      chunkSegment++;
    }

    _segmentCounter = chunkSegment;
  }

  /// Save a local backup of the report JSON (mobile only)
  Future<void> _saveLocalBackup(String callId, String payloadJson) async {
    if (kIsWeb) return; // Skip on web — no filesystem

    try {
      final path = await file_helper.saveCallReportToFile(callId, payloadJson);
      if (path != null) {
        _lastReportFilePath = path;
        GlobalLogger().i(
          'CallReportCollector: Saved local backup to $path',
        );
      }
    } catch (e) {
      GlobalLogger().w(
        'CallReportCollector: Failed to save local backup: $e',
      );
    }
  }

  /// Build the HTTP endpoint from a WebSocket URL
  Uri? _buildEndpoint(String host) {
    try {
      final wsUri = Uri.parse(host);
      final httpScheme = wsUri.scheme.replaceFirst('ws', 'http');
      return Uri(
        scheme: httpScheme,
        host: wsUri.host,
        port: wsUri.port,
        path: '/call_report',
      );
    } catch (e) {
      GlobalLogger().e(
        'CallReportCollector: Failed to build endpoint from host $host: $e',
      );
      return null;
    }
  }

  /// Build request headers
  Map<String, String> _buildHeaders(
    String callReportId,
    String callId,
    String? voiceSdkId,
  ) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'x-call-report-id': callReportId,
      'x-call-id': callId,
    };
    if (voiceSdkId != null) {
      headers['x-voice-sdk-id'] = voiceSdkId;
    }
    return headers;
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
        // Cast values to Map<String, dynamic>
        final values = Map<String, dynamic>.from(report.values);

        switch (type) {
          case 'outbound-rtp':
            if (values['kind'] == 'audio') {
              _lastOutboundAudio = values;
              _processOutboundAudio(values, now);
            }
            break;
          case 'inbound-rtp':
            if (values['kind'] == 'audio') {
              _lastInboundAudio = values;
              _processInboundAudio(values, now);
            }
            break;
          case 'candidate-pair':
            if (values['nominated'] == true ||
                values['state'] == 'succeeded') {
              _lastCandidatePair = values;
              _processCandidatePair(values);
              // Store candidate IDs for lookup
              _selectedLocalCandidateId = values['localCandidateId'] as String?;
              _selectedRemoteCandidateId = values['remoteCandidateId'] as String?;
            }
            break;
          case 'local-candidate':
            // Cache local candidates
            final candidateId = values['id'] as String?;
            if (candidateId != null) {
              _candidateCache[candidateId] = values;
              GlobalLogger().d(
                'CallReportCollector: Cached local candidate $candidateId (${values['candidateType']})',
              );
            }
            break;
          case 'remote-candidate':
            // Cache remote candidates
            final candidateId = values['id'] as String?;
            if (candidateId != null) {
              _candidateCache[candidateId] = values;
              GlobalLogger().d(
                'CallReportCollector: Cached remote candidate $candidateId (${values['candidateType']})',
              );
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

        // Check if we need to flush an intermediate segment
        if (_statsBuffer.length >= _segmentFlushThreshold &&
            _storedCallReportId != null) {
          await _flushIntermediateSegment();
        }
      }
    } catch (e) {
      GlobalLogger().e('CallReportCollector: Error collecting stats: $e');
    }
  }

  void _processOutboundAudio(Map<String, dynamic> stats, DateTime now) {
    // Audio level (WebRTC may return int, double, or num)
    final audioLevel = (stats['audioLevel'] as num?)?.toDouble();
    if (audioLevel != null) {
      _intervalOutboundAudioLevels.add(audioLevel);
    }

    // Calculate bitrate
    final bytesSent = (stats['bytesSent'] as num?)?.toInt();
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
    // Audio level (WebRTC may return int, double, or num)
    final audioLevel = (stats['audioLevel'] as num?)?.toDouble();
    if (audioLevel != null) {
      _intervalInboundAudioLevels.add(audioLevel);
    }

    // Jitter (convert to ms)
    final jitter = (stats['jitter'] as num?)?.toDouble();
    if (jitter != null) {
      _intervalJitters.add(jitter * 1000);
    }

    // Calculate bitrate
    final bytesReceived = (stats['bytesReceived'] as num?)?.toInt();
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
    final rtt = (stats['currentRoundTripTime'] as num?)?.toDouble();
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
      ice: _createIceStats(),
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
        packetsSent: (_lastOutboundAudio!['packetsSent'] as num?)?.toInt(),
        bytesSent: (_lastOutboundAudio!['bytesSent'] as num?)?.toInt(),
        audioLevelAvg: _average(_intervalOutboundAudioLevels),
        bitrateAvg: _average(_intervalOutboundBitrates),
      );
    }

    if (_lastInboundAudio != null) {
      inbound = InboundAudioStats(
        packetsReceived: (_lastInboundAudio!['packetsReceived'] as num?)?.toInt(),
        bytesReceived: (_lastInboundAudio!['bytesReceived'] as num?)?.toInt(),
        packetsLost: (_lastInboundAudio!['packetsLost'] as num?)?.toInt(),
        packetsDiscarded: (_lastInboundAudio!['packetsDiscarded'] as num?)?.toInt(),
        jitterBufferDelay: (_lastInboundAudio!['jitterBufferDelay'] as num?)?.toDouble(),
        jitterBufferEmittedCount:
            (_lastInboundAudio!['jitterBufferEmittedCount'] as num?)?.toInt(),
        totalSamplesReceived:
            (_lastInboundAudio!['totalSamplesReceived'] as num?)?.toInt(),
        concealedSamples: (_lastInboundAudio!['concealedSamples'] as num?)?.toInt(),
        concealmentEvents: (_lastInboundAudio!['concealmentEvents'] as num?)?.toInt(),
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
      packetsSent: (_lastCandidatePair!['packetsSent'] as num?)?.toInt(),
      packetsReceived: (_lastCandidatePair!['packetsReceived'] as num?)?.toInt(),
      bytesSent: (_lastCandidatePair!['bytesSent'] as num?)?.toInt(),
      bytesReceived: (_lastCandidatePair!['bytesReceived'] as num?)?.toInt(),
    );
  }

  IceStats? _createIceStats() {
    if (_lastCandidatePair == null) {
      return null;
    }

    // Debug: log candidate cache state and candidate-pair details
    GlobalLogger().d(
      'CallReportCollector: Creating ICE stats - localId=$_selectedLocalCandidateId, remoteId=$_selectedRemoteCandidateId, cacheSize=${_candidateCache.length}',
    );

    // Try to find local candidate - first by ID, then by searching cache
    IceCandidateStats? localCandidate;
    Map<String, dynamic>? localData;
    
    // Method 1: Direct ID lookup (works on some platforms)
    if (_selectedLocalCandidateId != null &&
        _candidateCache.containsKey(_selectedLocalCandidateId)) {
      localData = _candidateCache[_selectedLocalCandidateId];
    }
    
    // Method 2: Search cache for a local candidate (any will do for basic info)
    // Since we mark local candidates with 'RTCIceLc_' prefix
    if (localData == null) {
      for (final entry in _candidateCache.entries) {
        if (entry.key.contains('Lc_')) {
          localData = entry.value;
          GlobalLogger().d(
            'CallReportCollector: Found local candidate by prefix: ${entry.key}',
          );
          break;
        }
      }
    }
    
    if (localData != null) {
      localCandidate = IceCandidateStats(
        address: localData['address'] as String? ?? localData['ip'] as String?,
        candidateType: localData['candidateType'] as String?,
        networkType: localData['networkType'] as String?,
        port: (localData['port'] as num?)?.toInt(),
        protocol: localData['protocol'] as String?,
        priority: (localData['priority'] as num?)?.toInt(),
        relatedAddress: localData['relatedAddress'] as String?,
        relatedPort: (localData['relatedPort'] as num?)?.toInt(),
      );
    } else {
      GlobalLogger().w(
        'CallReportCollector: No local candidate found in cache. Available: ${_candidateCache.keys.toList()}',
      );
    }

    // Try to find remote candidate - first by ID, then by searching cache
    IceCandidateStats? remoteCandidate;
    Map<String, dynamic>? remoteData;
    
    // Method 1: Direct ID lookup
    if (_selectedRemoteCandidateId != null &&
        _candidateCache.containsKey(_selectedRemoteCandidateId)) {
      remoteData = _candidateCache[_selectedRemoteCandidateId];
    }
    
    // Method 2: Search cache for a remote candidate
    if (remoteData == null) {
      for (final entry in _candidateCache.entries) {
        if (entry.key.contains('Rc_')) {
          remoteData = entry.value;
          GlobalLogger().d(
            'CallReportCollector: Found remote candidate by prefix: ${entry.key}',
          );
          break;
        }
      }
    }
    
    if (remoteData != null) {
      remoteCandidate = IceCandidateStats(
        address: remoteData['address'] as String? ?? remoteData['ip'] as String?,
        candidateType: remoteData['candidateType'] as String?,
        networkType: remoteData['networkType'] as String?,
        port: (remoteData['port'] as num?)?.toInt(),
        protocol: remoteData['protocol'] as String?,
        priority: (remoteData['priority'] as num?)?.toInt(),
        relatedAddress: remoteData['relatedAddress'] as String?,
        relatedPort: (remoteData['relatedPort'] as num?)?.toInt(),
      );
    } else {
      GlobalLogger().w(
        'CallReportCollector: No remote candidate found in cache. Available: ${_candidateCache.keys.toList()}',
      );
    }

    return IceStats(
      id: _lastCandidatePair!['id'] as String?,
      local: localCandidate,
      remote: remoteCandidate,
      nominated: _lastCandidatePair!['nominated'] as bool?,
      requestsSent: (_lastCandidatePair!['requestsSent'] as num?)?.toInt(),
      responsesReceived: (_lastCandidatePair!['responsesReceived'] as num?)?.toInt(),
      state: _lastCandidatePair!['state'] as String?,
      writable: _lastCandidatePair!['writable'] as bool?,
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
