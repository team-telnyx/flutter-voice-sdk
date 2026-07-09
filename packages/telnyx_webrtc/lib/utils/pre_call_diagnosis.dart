import 'dart:async';

import 'package:telnyx_webrtc/call.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';
import 'package:telnyx_webrtc/model/call_quality.dart';
import 'package:telnyx_webrtc/model/call_quality_metrics.dart';
import 'package:telnyx_webrtc/model/call_state.dart';
import 'package:telnyx_webrtc/model/connection_status.dart';
import 'package:telnyx_webrtc/model/socket_method.dart';
import 'package:telnyx_webrtc/model/telnyx_message.dart';
import 'package:telnyx_webrtc/telnyx_client.dart';
import 'package:telnyx_webrtc/utils/logging/global_logger.dart';
import 'package:telnyx_webrtc/utils/logging/log_level.dart';
import 'package:telnyx_webrtc/utils/stats/mos_calculator.dart';

/// Quality rating for a diagnostic report.
enum DiagnosticQuality {
  excellent,
  good,
  fair,
  poor,
  bad;

  /// Map a MOS value to a [DiagnosticQuality].
  static DiagnosticQuality fromMos(double mos) {
    if (mos > 4.0) return DiagnosticQuality.excellent;
    if (mos >= 4.0) return DiagnosticQuality.good;
    if (mos >= 3.5) return DiagnosticQuality.fair;
    if (mos > 2.0) return DiagnosticQuality.poor;
    return DiagnosticQuality.bad;
  }
}

/// Min / max / average for a series of values.
class MinMaxAverage {
  final double min;
  final double max;
  final double average;

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
  final int packetsReceived;
  final int packetsLost;
  final int packetsSent;
  final int bytesSent;
  final int bytesReceived;

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
  final String? address;
  final String? candidateType;
  final bool? deleted;
  final String? id;
  final int? port;
  final int? priority;
  final String? protocol;
  final String? relayProtocol;
  final String? timestamp;
  final String? transportId;
  final String? type;
  final String? url;

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
  final List<RTCIceCandidateStats> iceCandidateStats;
  final Map<String, dynamic>? iceCandidatePairStats;
  final MinMaxAverage jitter;
  final MinMaxAverage rtt;
  final double mos;
  final DiagnosticQuality quality;
  final DiagnosticSessionStats sessionStats;

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
  final String texMLApplicationNumber;
  final String? sipToken;
  final String? sipUser;
  final String? sipPassword;
  final String sipCallerIDName;
  final String sipCallerIDNumber;

  const PreCallDiagnosisOptions({
    required this.texMLApplicationNumber,
    this.sipToken,
    this.sipUser,
    this.sipPassword,
    required this.sipCallerIDName,
    required this.sipCallerIDNumber,
  });
}

/// Reason for a pre-call diagnostic failure.
enum PreCallDiagnosticFailureReason {
  timeout,
  connectionFailed,
  sipError,
}

/// Exception thrown when [PreCallDiagnostic.run] fails.
class PreCallDiagnosticException implements Exception {
  final int? sipCode;
  final String? sipReason;
  final PreCallDiagnosticFailureReason reason;
  final String message;

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

    // Run the actual diagnostic, linking the result to the completer.
    runDiagnostic(options).then((report) {
      if (!completer.isCompleted) {
        completer.complete(report);
      }
    }).catchError((error) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    });

    try {
      return await completer.future;
    } finally {
      timer.cancel();
    }
  }

  /// The core diagnostic logic — connects, makes a test call, collects stats,
  /// cleans up, and returns the report.
  static Future<DiagnosticReport> runDiagnostic(
    PreCallDiagnosisOptions options,
  ) async {
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
          logLevel: LogLevel.all,
          debug: true,
        );
        client.connectWithToken(tokenConfig);
      } else {
        final credentialConfig = CredentialConfig(
          sipUser: options.sipUser!,
          sipPassword: options.sipPassword!,
          sipCallerIDName: options.sipCallerIDName,
          sipCallerIDNumber: options.sipCallerIDNumber,
          logLevel: LogLevel.all,
          debug: true,
        );
        client.connectWithCredential(credentialConfig);
      }

      // Wait for the client to be ready (registered), with a 5s
      // connection timeout so tests don't hang indefinitely when
      // no server is reachable.
      await connectionCompleter.future.timeout(const Duration(seconds: 5),
          onTimeout: () {
        throw PreCallDiagnosticException(
          reason: PreCallDiagnosticFailureReason.connectionFailed,
          message: 'Could not connect within 5 seconds — no server reachable',
        );
      });

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
      );

      if (testCall == null) {
        throw PreCallDiagnosticException(
          reason: PreCallDiagnosticFailureReason.connectionFailed,
          message: 'Failed to create test call',
        );
      }

      // --- Step 5: Set up stats collection via onCallQualityChange ---
      testCall.onCallQualityChange = (CallQualityMetrics metrics) {
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
      };

      // Monitor call state for errors.
      testCall.callHandler.onCallStateChanged = (CallState state) {
        if (state == CallState.done || state == CallState.dropped) {
          if (!statsCompleter.isCompleted) {
            // If we have SIP error info, throw with it.
            if (sipErrorCode != null && sipErrorCode! >= 400) {
              statsCompleter.completeError(
                PreCallDiagnosticException(
                  sipCode: sipErrorCode,
                  sipReason: sipErrorReason,
                  reason: PreCallDiagnosticFailureReason.sipError,
                  message: 'SIP ${sipErrorCode} ${sipErrorReason ?? ""}',
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

      // Wait for stats to be collected.
      return await statsCompleter.future;
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
