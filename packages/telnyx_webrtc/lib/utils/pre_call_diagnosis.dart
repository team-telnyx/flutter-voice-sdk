import 'dart:async';

import 'package:telnyx_webrtc/call.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';
import 'package:telnyx_webrtc/model/call_quality_metrics.dart';
import 'package:telnyx_webrtc/model/call_state.dart';
import 'package:telnyx_webrtc/model/connection_status.dart';
import 'package:telnyx_webrtc/model/telnyx_message.dart';
import 'package:telnyx_webrtc/telnyx_client.dart';
import 'package:telnyx_webrtc/utils/logging/log_level.dart';
import 'package:telnyx_webrtc/utils/stats/mos_calculator.dart';

/// Quality rating for a diagnostic report.
enum DiagnosticQuality {
  /// Top-tier call quality with a MOS above 4.0.
  excellent,

  /// Good call quality with a MOS around 4.0.
  good,

  /// Acceptable call quality with a MOS between 3.5 and 4.0.
  fair,

  /// Degraded call quality with a MOS between 2.0 and 3.5.
  poor,

  /// Unusable call quality with a MOS at or below 2.0.
  bad;

  /// Map a MOS value to a [DiagnosticQuality].
  ///
  /// Uses the same bands as the JS SDK `getQuality` (utils/mos.ts) and the
  /// Flutter [CallQuality.fromMos]: `> 4.2` excellent, `>= 4.1` good,
  /// `>= 3.7` fair, `>= 3.1` poor, otherwise bad.
  static DiagnosticQuality fromMos(double mos) {
    if (mos > 4.2) return DiagnosticQuality.excellent;
    if (mos >= 4.1) return DiagnosticQuality.good;
    if (mos >= 3.7) return DiagnosticQuality.fair;
    if (mos >= 3.1) return DiagnosticQuality.poor;
    return DiagnosticQuality.bad;
  }
}

/// Min / max / average for a series of values.
class MinMaxAverage {
  /// The smallest value observed in the series.
  final double min;

  /// The largest value observed in the series.
  final double max;

  /// The arithmetic mean of the values in the series.
  final double average;

  /// Creates a [MinMaxAverage] from explicit [min], [max] and [average].
  const MinMaxAverage({
    required this.min,
    required this.max,
    required this.average,
  });

  /// Construct from a list of values.  An empty list yields all zeros.
  factory MinMaxAverage.fromValues(List<double> values) {
    if (values.isEmpty) {
      return const MinMaxAverage(min: 0, max: 0, average: 0);
    }
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final avg = values.reduce((a, b) => a + b) / values.length;
    return MinMaxAverage(min: min, max: max, average: avg);
  }
}

/// Session-level stats extracted after a diagnostic call.
class DiagnosticSessionStats {
  /// Total number of RTP packets received during the diagnostic call.
  final int packetsReceived;

  /// Total number of RTP packets lost during the diagnostic call.
  final int packetsLost;

  /// Total number of RTP packets sent during the diagnostic call.
  final int packetsSent;

  /// Total number of bytes sent during the diagnostic call.
  final int bytesSent;

  /// Total number of bytes received during the diagnostic call.
  final int bytesReceived;

  /// Creates the session-level packet and byte counters for a diagnostic call.
  const DiagnosticSessionStats({
    required this.packetsReceived,
    required this.packetsLost,
    required this.packetsSent,
    required this.bytesSent,
    required this.bytesReceived,
  });
}

/// ICE candidate stats (mirrors the WebRTC RTCIceCandidateStats dictionary).
class RTCIceCandidateStats {
  /// The IP address of the ICE candidate.
  final String? address;

  /// The type of ICE candidate (for example 'host', 'srflx' or 'relay').
  final String? candidateType;

  /// Whether this ICE candidate has been deleted.
  final bool? deleted;

  /// The unique identifier of this ICE candidate stats object.
  final String? id;

  /// The network port associated with the ICE candidate.
  final int? port;

  /// The priority value used during ICE candidate pairing.
  final int? priority;

  /// The transport protocol of the candidate (for example 'udp' or 'tcp').
  final String? protocol;

  /// The protocol used to communicate with the TURN relay, if any.
  final String? relayProtocol;

  /// The ISO-8601 timestamp at which these stats were captured.
  final String? timestamp;

  /// The identifier of the transport this candidate belongs to.
  final String? transportId;

  /// The WebRTC stats type, mirroring [candidateType].
  final String? type;

  /// The URL of the ICE/TURN server that provided this candidate.
  final String? url;

  /// Creates an immutable snapshot of a single ICE candidate's stats.
  const RTCIceCandidateStats({
    this.address,
    this.candidateType,
    this.deleted,
    this.id,
    this.port,
    this.priority,
    this.protocol,
    this.relayProtocol,
    this.timestamp,
    this.transportId,
    this.type,
    this.url,
  });
}

/// The full diagnostic report returned by [PreCallDiagnostic.run].
class DiagnosticReport {
  /// The individual ICE candidate stats gathered during the diagnostic.
  final List<RTCIceCandidateStats> iceCandidateStats;

  /// The selected ICE candidate pair stats, if a connection was established.
  final Map<String, dynamic>? iceCandidatePairStats;

  /// The min/max/average jitter observed across the collected samples.
  final MinMaxAverage jitter;

  /// The min/max/average round-trip time observed across the samples.
  final MinMaxAverage rtt;

  /// The Mean Opinion Score computed from the collected metrics.
  final double mos;

  /// The overall quality rating derived from [mos].
  final DiagnosticQuality quality;

  /// The session-level packet and byte counters for the diagnostic call.
  final DiagnosticSessionStats sessionStats;

  /// Creates a diagnostic report from the collected metrics.
  const DiagnosticReport({
    required this.iceCandidateStats,
    required this.iceCandidatePairStats,
    required this.jitter,
    required this.rtt,
    required this.mos,
    required this.quality,
    required this.sessionStats,
  });
}

/// Options for [PreCallDiagnostic.run].
class PreCallDiagnosisOptions {
  /// The TeXML application number to dial for the diagnostic test call.
  final String texMLApplicationNumber;

  /// SIP token to authenticate with, when using token-based login.
  final String? sipToken;

  /// SIP username to authenticate with, when using credential-based login.
  final String? sipUser;

  /// SIP password to authenticate with, when using credential-based login.
  final String? sipPassword;

  /// Caller ID name to present on the diagnostic test call.
  final String sipCallerIDName;

  /// Caller ID number to present on the diagnostic test call.
  final String sipCallerIDNumber;

  /// Log level applied to the diagnostic's temporary [TelnyxClient].
  ///
  /// Defaults to [LogLevel.info] instead of [LogLevel.all] so the diagnostic
  /// does not force maximally verbose logging of credentials/SDP over whatever
  /// level the integrating app configured. Callers that need full logs can opt
  /// in explicitly.
  final LogLevel logLevel;

  /// Creates diagnostic options. Provide either [sipToken] or the
  /// [sipUser]/[sipPassword] pair for authentication.
  const PreCallDiagnosisOptions({
    required this.texMLApplicationNumber,
    this.sipToken,
    this.sipUser,
    this.sipPassword,
    required this.sipCallerIDName,
    required this.sipCallerIDNumber,
    this.logLevel = LogLevel.info,
  });
}

/// Reason for a pre-call diagnostic failure.
enum PreCallDiagnosticFailureReason {
  /// The diagnostic did not receive stats within the allotted time.
  timeout,

  /// The client could not connect to or register with the Telnyx server.
  connectionFailed,

  /// The test call returned a SIP error response.
  sipError,
}

/// Exception thrown when [PreCallDiagnostic.run] fails.
class PreCallDiagnosticException implements Exception {
  /// The SIP response code associated with the failure, if any.
  final int? sipCode;

  /// The SIP reason phrase associated with the failure, if any.
  final String? sipReason;

  /// The categorized reason the diagnostic failed.
  final PreCallDiagnosticFailureReason reason;

  /// A human-readable description of the failure.
  final String message;

  /// Creates an exception describing why a pre-call diagnostic failed.
  PreCallDiagnosticException({
    this.sipCode,
    this.sipReason,
    required this.reason,
    this.message = '',
  });

  @override
  String toString() =>
      'PreCallDiagnosticException(sipCode: $sipCode, sipReason: $sipReason, '
      'reason: $reason, message: $message)';
}

/// Runs a pre-call diagnostic that connects to the Telnyx server, makes a
/// short test call, collects WebRTC stats, and returns a [DiagnosticReport].
class PreCallDiagnostic {
  PreCallDiagnostic._();

  /// Timeout duration for the entire diagnostic run.
  static const Duration _timeout = Duration(seconds: 30);

  /// Run the diagnostic with the given [options].
  ///
  /// This method:
  ///  1. Creates a [TelnyxClient]
  ///  2. Connects using token or credential config
  ///  3. Makes a test call to the texML application number
  ///  4. Collects WebRTC stats via the [Call.onCallQualityChange] callback
  ///  5. Hangs up and disconnects (with try/finally cleanup)
  ///  6. Returns a [DiagnosticReport]
  ///
  /// Throws [PreCallDiagnosticException] on failure:
  /// - [PreCallDiagnosticFailureReason.connectionFailed] if the client
  ///   cannot connect or register.
  /// - [PreCallDiagnosticFailureReason.sipError] if the test call returns
  ///   a SIP 4xx response.
  /// - [PreCallDiagnosticFailureReason.timeout] if no stats are received
  ///   within 30 seconds.
  static Future<DiagnosticReport> run(
    PreCallDiagnosisOptions options,
  ) async {
    return runWithTimeout(options, _timeout);
  }

  /// Internal implementation wrapped with a timeout.
  static Future<DiagnosticReport> runWithTimeout(
    PreCallDiagnosisOptions options,
    Duration timeout,
  ) async {
    final completer = Completer<DiagnosticReport>();

    // Set up the timeout timer.
    final timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.completeError(
          PreCallDiagnosticException(
            reason: PreCallDiagnosticFailureReason.timeout,
            message: 'PreCallDiagnostic timed out after ${timeout.inSeconds}s '
                'without receiving stats',
          ),
        );
      }
    });

    // Run the actual diagnostic, linking the result to the completer. This is
    // deliberately not awaited here — the outer completer (bounded by [timer])
    // is what the caller awaits.
    unawaited(
      runDiagnostic(options, timeout: timeout).then((report) {
        if (!completer.isCompleted) {
          completer.complete(report);
        }
      }).catchError((error) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      }),
    );

    try {
      return await completer.future;
    } finally {
      timer.cancel();
    }
  }

  /// The core diagnostic logic — connects, makes a test call, collects stats,
  /// cleans up, and returns the report.
  static Future<DiagnosticReport> runDiagnostic(
    PreCallDiagnosisOptions options, {
    Duration? timeout,
  }) async {
    final effectiveTimeout = timeout ?? _timeout;
    // Validate options.
    if (options.sipToken == null &&
        (options.sipUser == null || options.sipPassword == null)) {
      throw PreCallDiagnosticException(
        reason: PreCallDiagnosticFailureReason.connectionFailed,
        message: 'Either sipToken or (sipUser + sipPassword) must be provided',
      );
    }

    final client = TelnyxClient();
    Call? testCall;

    // Collected stats samples.
    final jitterSamples = <double>[];
    final rttSamples = <double>[];
    final iceCandidateStats = <RTCIceCandidateStats>[];
    Map<String, dynamic>? iceCandidatePairStats;
    DiagnosticSessionStats? sessionStats;

    // Completer to signal when we have collected enough stats.
    final statsCompleter = Completer<DiagnosticReport>();

    // Track SIP error state.
    int? sipErrorCode;
    String? sipErrorReason;

    try {
      // --- Step 1: Set up connection state monitoring ---
      final connectionCompleter = Completer<void>();

      client.onConnectionStateChanged = (ConnectionStatus status) {
        if (status == ConnectionStatus.clientReady &&
            !connectionCompleter.isCompleted) {
          connectionCompleter.complete();
        }
        if (status == ConnectionStatus.disconnected &&
            !connectionCompleter.isCompleted) {
          connectionCompleter.completeError(
            PreCallDiagnosticException(
              reason: PreCallDiagnosticFailureReason.connectionFailed,
              message: 'Client disconnected before reaching clientReady state',
            ),
          );
        }
      };

      // --- Step 2: Connect with the appropriate config ---
      if (options.sipToken != null) {
        final tokenConfig = TokenConfig(
          sipToken: options.sipToken!,
          sipCallerIDName: options.sipCallerIDName,
          sipCallerIDNumber: options.sipCallerIDNumber,
          logLevel: options.logLevel,
          debug: true,
        );
        client.connectWithToken(tokenConfig);
      } else {
        final credentialConfig = CredentialConfig(
          sipUser: options.sipUser!,
          sipPassword: options.sipPassword!,
          sipCallerIDName: options.sipCallerIDName,
          sipCallerIDNumber: options.sipCallerIDNumber,
          logLevel: options.logLevel,
          debug: true,
        );
        client.connectWithCredential(credentialConfig);
      }

      // Wait for the client to be ready (registered), with a 5s
      // connection timeout so tests don't hang indefinitely when
      // no server is reachable.
      await connectionCompleter.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw PreCallDiagnosticException(
            reason: PreCallDiagnosticFailureReason.connectionFailed,
            message: 'Could not connect within 5 seconds — no server reachable',
          );
        },
      );

      // --- Step 3: Set up SIP error monitoring via socket messages ---
      client.onSocketMessageReceived = (TelnyxMessage message) {
        // Check for SIP 4xx errors in call notifications.
        final receivedMessage = message.message;
        if (receivedMessage.byeParams != null) {
          final byeParams = receivedMessage.byeParams!;
          final sipCode = byeParams.sipCode;
          final sipReason = byeParams.sipReason;
          if (sipCode != null && sipCode >= 400) {
            sipErrorCode = sipCode;
            sipErrorReason = sipReason;
            if (!statsCompleter.isCompleted) {
              statsCompleter.completeError(
                PreCallDiagnosticException(
                  sipCode: sipCode,
                  sipReason: sipReason,
                  reason: PreCallDiagnosticFailureReason.sipError,
                  message: 'SIP $sipCode ${sipReason ?? ""}',
                ),
              );
            }
          }
        }
      };

      // --- Step 4: Create a test call ---
      testCall = client.newInvite(
        options.sipCallerIDName,
        options.sipCallerIDNumber,
        options.texMLApplicationNumber,
        'diagnostic-test',
        debug: true,
      )
        // --- Step 5: Set up stats collection via onCallQualityChange ---
        ..onCallQualityChange = (CallQualityMetrics metrics) {
          // Collect jitter and RTT samples.
          jitterSamples.add(metrics.jitter);
          rttSamples.add(metrics.rtt);

          // Extract ICE candidate stats from the metrics' raw stats maps.
          _extractIceCandidateStats(metrics, iceCandidateStats);

          // Extract session stats from the metrics.
          sessionStats = _extractSessionStats(metrics);
          iceCandidatePairStats = _extractIceCandidatePairStats(metrics);

          // After collecting at least one sample, we can complete.
          if (!statsCompleter.isCompleted) {
            final jitterMma = MinMaxAverage.fromValues(jitterSamples);
            final rttMma = MinMaxAverage.fromValues(rttSamples);

            // Calculate MOS from the averaged stats.
            final packetLoss = _calculatePacketLoss(metrics);
            final mos = MosCalculator.calculateMos(
              rtt: rttMma.average,
              jitter: jitterMma.average,
              packetLoss: packetLoss,
            );

            final quality = DiagnosticQuality.fromMos(mos);
            final report = DiagnosticReport(
              iceCandidateStats: List.unmodifiable(iceCandidateStats),
              iceCandidatePairStats: iceCandidatePairStats,
              jitter: jitterMma,
              rtt: rttMma,
              mos: mos,
              quality: quality,
              sessionStats: sessionStats ??
                  const DiagnosticSessionStats(
                    packetsReceived: 0,
                    packetsLost: 0,
                    packetsSent: 0,
                    bytesSent: 0,
                    bytesReceived: 0,
                  ),
            );
            statsCompleter.complete(report);
          }
        }
        // Monitor call state for errors.
        ..callHandler.onCallStateChanged = (CallState state) {
          if (state == CallState.done || state == CallState.dropped) {
            if (!statsCompleter.isCompleted) {
              // If we have SIP error info, throw with it.
              if (sipErrorCode != null && sipErrorCode! >= 400) {
                statsCompleter.completeError(
                  PreCallDiagnosticException(
                    sipCode: sipErrorCode,
                    sipReason: sipErrorReason,
                    reason: PreCallDiagnosticFailureReason.sipError,
                    message: 'SIP $sipErrorCode ${sipErrorReason ?? ""}',
                  ),
                );
              } else {
                statsCompleter.completeError(
                  PreCallDiagnosticException(
                    reason: PreCallDiagnosticFailureReason.connectionFailed,
                    message: 'Call ended before stats were collected '
                        '(state: $state)',
                  ),
                );
              }
            }
          }
        };

      // Wait for stats to be collected, but bound the wait so the cleanup in
      // the finally block always runs. Without this inner timeout, if the test
      // call connects but the server never sends a quality sample, a BYE, or a
      // done/dropped state, statsCompleter would never complete: this await
      // would hang forever and endCall()/disconnect() would never execute,
      // permanently leaking the TelnyxClient socket and the live test call.
      return await statsCompleter.future.timeout(
        effectiveTimeout,
        onTimeout: () => throw PreCallDiagnosticException(
          reason: PreCallDiagnosticFailureReason.timeout,
          message: 'PreCallDiagnostic timed out after '
              '${effectiveTimeout.inSeconds}s without receiving stats',
        ),
      );
    } catch (e) {
      // If we already have a PreCallDiagnosticException, rethrow it.
      if (e is PreCallDiagnosticException) {
        rethrow;
      }
      // Wrap unexpected errors.
      throw PreCallDiagnosticException(
        reason: PreCallDiagnosticFailureReason.connectionFailed,
        message: 'Diagnostic failed: $e',
      );
    } finally {
      // --- Step 6: Cleanup (try/finally) ---
      try {
        testCall?.endCall();
      } catch (e) {
        GlobalLogger().w('PreCallDiagnostic: error hanging up call: $e');
      }
      try {
        client.disconnect();
      } catch (e) {
        GlobalLogger().w('PreCallDiagnostic: error disconnecting client: $e');
      }
    }
  }

  /// Extract [RTCIceCandidateStats] from the raw stats maps in
  /// [CallQualityMetrics].
  static void _extractIceCandidateStats(
    CallQualityMetrics metrics,
    List<RTCIceCandidateStats> iceCandidateStats,
  ) {
    // The inbound/outbound audio stats maps may contain ICE candidate info.
    // We extract from the raw stats maps attached to the metrics.
    final maps = [
      metrics.inboundAudio,
      metrics.outboundAudio,
      metrics.remoteInboundAudio,
      metrics.remoteOutboundAudio,
    ];

    for (final map in maps) {
      if (map == null) continue;
      final candidate = _parseIceCandidateStats(map);
      if (candidate != null &&
          !_containsCandidate(iceCandidateStats, candidate)) {
        iceCandidateStats.add(candidate);
      }
    }
  }

  /// Parse a [RTCIceCandidateStats] from a raw stats map, if possible.
  static RTCIceCandidateStats? _parseIceCandidateStats(
    Map<String, dynamic> map,
  ) {
    // Look for ICE candidate fields in the stats map.
    final address = map['address'] as String?;
    final candidateType =
        map['candidateType'] as String? ?? map['type'] as String?;
    final id = map['id'] as String?;
    final port = map['port'] as int?;
    final priority = map['priority'] as int?;
    final protocol = map['protocol'] as String?;
    final relayProtocol = map['relayProtocol'] as String?;
    final transportId = map['transportId'] as String?;
    final url = map['url'] as String?;
    final deleted = map['deleted'] as bool?;

    // Only create a candidate if we have at least an id or address.
    if (id == null && address == null) return null;

    return RTCIceCandidateStats(
      address: address,
      candidateType: candidateType,
      deleted: deleted,
      id: id,
      port: port,
      priority: priority,
      protocol: protocol,
      relayProtocol: relayProtocol,
      timestamp: DateTime.now().toUtc().toIso8601String(),
      transportId: transportId,
      type: candidateType,
      url: url ?? '',
    );
  }

  /// Check if the list already contains a candidate with the same id.
  static bool _containsCandidate(
    List<RTCIceCandidateStats> list,
    RTCIceCandidateStats candidate,
  ) {
    if (candidate.id == null) return false;
    return list.any((c) => c.id == candidate.id);
  }

  /// Extract [DiagnosticSessionStats] from [CallQualityMetrics].
  static DiagnosticSessionStats _extractSessionStats(
    CallQualityMetrics metrics,
  ) {
    int packetsReceived = 0;
    int packetsLost = 0;
    int packetsSent = 0;
    int bytesSent = 0;
    int bytesReceived = 0;

    // Extract from inbound audio stats.
    if (metrics.inboundAudio != null) {
      packetsReceived =
          (metrics.inboundAudio!['totalPacketsReceived'] as num?)?.toInt() ??
              (metrics.inboundAudio!['packetsReceived'] as num?)?.toInt() ??
              0;
      packetsLost =
          (metrics.inboundAudio!['packetsLost'] as num?)?.toInt() ?? 0;
      bytesReceived =
          (metrics.inboundAudio!['bytesReceived'] as num?)?.toInt() ?? 0;
    }

    // Extract from outbound audio stats.
    if (metrics.outboundAudio != null) {
      packetsSent = (metrics.outboundAudio!['packetsSent'] as num?)?.toInt() ??
          (metrics.outboundAudio!['totalPacketsSent'] as num?)?.toInt() ??
          0;
      bytesSent = (metrics.outboundAudio!['bytesSent'] as num?)?.toInt() ?? 0;
    }

    return DiagnosticSessionStats(
      packetsReceived: packetsReceived,
      packetsLost: packetsLost,
      packetsSent: packetsSent,
      bytesSent: bytesSent,
      bytesReceived: bytesReceived,
    );
  }

  /// Extract ICE candidate pair stats from the metrics' raw stats maps.
  static Map<String, dynamic>? _extractIceCandidatePairStats(
    CallQualityMetrics metrics,
  ) {
    // The connection-level stats may be in any of the audio stats maps.
    for (final map in [
      metrics.remoteInboundAudio,
      metrics.inboundAudio,
      metrics.outboundAudio,
      metrics.remoteOutboundAudio,
    ]) {
      if (map == null) continue;
      if (map.containsKey('localCandidateId') ||
          map.containsKey('remoteCandidateId') ||
          map.containsKey('nominated')) {
        return Map<String, dynamic>.from(map);
      }
    }
    return null;
  }

  /// Calculate packet loss ratio from [CallQualityMetrics].
  static double _calculatePacketLoss(CallQualityMetrics metrics) {
    if (metrics.inboundAudio != null) {
      final packetsLost =
          (metrics.inboundAudio!['packetsLost'] as num?)?.toDouble() ?? 0;
      final packetsReceived =
          (metrics.inboundAudio!['totalPacketsReceived'] as num?)?.toDouble() ??
              (metrics.inboundAudio!['packetsReceived'] as num?)?.toDouble() ??
              0;
      final total = packetsReceived + packetsLost;
      if (total > 0) {
        return packetsLost / total;
      }
    }
    return 0.0;
  }
}
