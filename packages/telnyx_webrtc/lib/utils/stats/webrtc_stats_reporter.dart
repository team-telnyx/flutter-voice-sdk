import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:ffi';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:telnyx_webrtc/model/call_quality.dart';
import 'package:telnyx_webrtc/model/call_quality_metrics.dart';
import 'package:telnyx_webrtc/utils/logging/global_logger.dart';
import 'package:telnyx_webrtc/utils/stats/mos_calculator.dart';
import 'package:telnyx_webrtc/utils/stats/stats_parsing_helpers.dart';
import 'package:telnyx_webrtc/utils/stats/stats_message.dart';
import 'package:telnyx_webrtc/tx_socket.dart'
    if (dart.library.js) 'package:telnyx_webrtc/tx_socket_web.dart';
import 'package:telnyx_webrtc/utils/stats/webrtc_stats_event.dart';
import 'package:telnyx_webrtc/utils/stats/webrtc_stats_tag.dart';
import 'package:uuid/uuid.dart';

/// Callback for receiving call quality metrics updates
typedef CallQualityCallback = void Function(CallQualityMetrics metrics);

/// Class to handle the reporting of WebRTC stats to the server
/// via the provided [socket] and [peerConnection].
/// The [callId] and [peerId] are used to identify the call and peer respectively.
/// The stats are collected every 3 seconds and sent to the server.
/// The stats reporting can be started and stopped using the [startStatsReporting] and [stopStatsReporting] methods.
/// The collected stats are available in the Telnyx Portal for debugging purposes.
class WebRTCStatsReporter {
  /// Default constructor that initializes the WebRTCStatsReporter with the provided parameters
  WebRTCStatsReporter(
    this.socket,
    this.peerConnection,
    this.callId,
    this.peerId,
    this.sendStats, {
    this.onCallQualityChange,
  });

  final Queue<String> _messageQueue = Queue<String>();

  //File? _logFile;

  Timer? _timer;
  bool debugReportStarted = false;
  final Uuid uuid = const Uuid();
  String debugStatsId = const Uuid().v4();

  final TxSocket socket;
  final RTCPeerConnection peerConnection;
  final String callId;
  final String peerId;
  final bool sendStats;

  /// Callback for call quality metrics updates
  final CallQualityCallback? onCallQualityChange;

  /*Future<void> _initializeLogFile() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      _logFile = File('${directory.path}/webrtc_stats_log.json');
      if (!_logFile!.existsSync()) {
        _logFile!.createSync();
      }
    } catch (e) {
      _logger.e('Error initializing log file: $e');
    }
  }*/

  void _enqueueMessage(String message) {
    if (!sendStats) {
      GlobalLogger()
          .d('Stats reporting is disabled. Not sending message: $message');
      return;
    }
    _messageQueue.add(message);
    _processMessageQueue();
  }

  void _processMessageQueue() {
    while (_messageQueue.isNotEmpty) {
      final message = _messageQueue.removeFirst();
      socket.send(message);

      //ToDo(Oliver): leave this here to uncomment to test as needed
      // Append the message to the log file.
      /*try {
        _logFile?.writeAsStringSync('$message\n\n,', mode: FileMode.append);
      } catch (e) {
        _logger.e('Error writing message to log file: $e');
      }*/
    }
  }

  Future<void> startStatsReporting() async {
    //ToDo(Oliver): leave this here to uncomment to test as needed
    //await _initializeLogFile();

    if (!debugReportStarted) {
      debugStatsId = uuid.v4();
      _sendStartDebugReport(debugStatsId);
    }

    await _sendAddConnectionMessage();
    await _setupPeerEventHandlers();

    _timer = Timer.periodic(Duration(seconds: 3), (_) async {
      await _collectAndSendStats();
    });
  }

  void stopStatsReporting() {
    if (debugReportStarted) {
      debugReportStarted = false;
      _sendStopDebugReport(debugStatsId);
    }
    _timer?.cancel();
  }

  Future<void> _setupPeerEventHandlers() async {
    peerConnection
      ..onAddStream = (MediaStream stream) {
        final streamData = {
          'streamId': stream.id,
          'audioTracks': stream.getAudioTracks().map((track) {
            return {'trackId': track.id, 'kind': track.kind};
          }).toList(),
          'videoTracks': stream.getVideoTracks().map((track) {
            return {'trackId': track.id, 'kind': track.kind};
          }).toList(),
        };
        _sendDebugReportData(
          event: WebRTCStatsEvent.onTrack,
          tag: WebRTCStatsTag.track,
          data: streamData,
        );
      }
      ..onRenegotiationNeeded = () {
        _sendDebugReportData(
          event: WebRTCStatsEvent.onNegotiationNeeded,
          tag: WebRTCStatsTag.connection,
          data: {},
        );
      }
      ..onIceCandidate = (RTCIceCandidate candidate) {
        final candidateData = {
          'candidate': candidate.candidate,
          'sdpMLineIndex': candidate.sdpMLineIndex,
          'sdpMid': candidate.sdpMid,
          'usernameFragment':
              StatParsingHelpers().parseUsernameFragment(candidate),
        };
        _sendDebugReportData(
          event: WebRTCStatsEvent.onIceCandidate,
          tag: WebRTCStatsTag.connection,
          data: candidateData,
        );
      }
      ..onSignalingState = (RTCSignalingState signalingState) async {
        RTCSessionDescription? localSdp;
        RTCSessionDescription? remoteSdp;

        try {
          localSdp = await peerConnection.getLocalDescription();
          remoteSdp = await peerConnection.getRemoteDescription();
        } catch (e) {
          GlobalLogger()
              .e('Error retrieving descriptions for Signaling State Stats: $e');
        }

        // If both are null, just skip
        if (localSdp == null && remoteSdp == null) {
          return;
        }

        final description = {
          'signalingState':
              StatParsingHelpers().parseSignalingStateChange(signalingState),
          if (remoteSdp != null)
            'remoteDescription': {
              'type': remoteSdp.type,
              'sdp': remoteSdp.sdp,
            },
          if (localSdp != null)
            'localDescription': {
              'type': localSdp.type,
              'sdp': localSdp.sdp,
            },
        };

        _sendDebugReportData(
          event: WebRTCStatsEvent.onSignalingStateChange,
          tag: WebRTCStatsTag.connection,
          data: description,
        );
      }
      ..onIceConnectionState = (RTCIceConnectionState iceConnectionState) {
        _sendDebugReportData(
          event: WebRTCStatsEvent.onIceConnectionStateChange,
          tag: WebRTCStatsTag.connection,
          data: {
            'iceConnectionState': StatParsingHelpers()
                .parseIceConnectionStateChange(iceConnectionState),
          },
        );
      }
      ..onIceGatheringState = (RTCIceGatheringState iceGatheringState) {
        _sendDebugReportData(
          event: WebRTCStatsEvent.onIceGatheringStateChange,
          tag: WebRTCStatsTag.connection,
          data: {
            'iceGatheringState': StatParsingHelpers()
                .parseIceGatheringStateChange(iceGatheringState),
          },
        );
      };
  }

  Future<void> _collectAndSendStats() async {
    try {
      final stats = await peerConnection.getStats(null);

      final audioInboundStats = [];
      final audioOutboundStats = [];
      Map<String, dynamic>? succeededConnection;
      final statsObject = {};

      final timestamp =
          DateTime.now().toUtc().millisecondsSinceEpoch.toDouble();

      final Map<String, dynamic> localCandidates = {};
      final Map<String, dynamic> remoteCandidates = {};
      final List<Map<String, dynamic>> unresolvedCandidatePairs = [];

      // Variables for call quality metrics
      double jitter = 0;
      double rtt = 0;
      double packetLoss = 0;
      Map<String, dynamic>? inboundAudioStats;
      Map<String, dynamic>? outboundAudioStats;

      for (var report in stats) {
        switch (report.type) {
          case 'inbound-rtp':
            final inboundValues = report.values.cast<String, dynamic>();

            // Extract jitter from inbound-rtp
            if (inboundValues.containsKey('jitter') &&
                inboundValues['kind'] == 'audio') {
              jitter = (inboundValues['jitter'] as num?)?.toDouble() ?? 0;

              // Extract packet loss if available
              if (inboundValues.containsKey('packetsLost') &&
                  inboundValues.containsKey('totalPacketsReceived')) {
                final packetsLost =
                    (inboundValues['packetsLost'] as num?)?.toDouble() ?? 0;
                final totalPackets =
                    (inboundValues['totalPacketsReceived'] as num?)
                            ?.toDouble() ??
                        1;
                if (totalPackets > 0) {
                  packetLoss = packetsLost / (totalPackets + packetsLost);
                }
              }

              inboundAudioStats = Map<String, dynamic>.from(inboundValues);
            }

            audioInboundStats.add({
              ...inboundValues,
              'timestamp': timestamp,
              'track': {},
            });
            statsObject[report.id] = {
              ...inboundValues,
              'id': report.id,
              'type': report.type,
              'timestamp': timestamp,
            };
            break;
          case 'outbound-rtp':
            final outboundValues = report.values.cast<String, dynamic>();

            if (outboundValues['kind'] == 'audio') {
              outboundAudioStats = Map<String, dynamic>.from(outboundValues);
            }

            audioOutboundStats.add({
              ...outboundValues,
              'timestamp': timestamp,
              'track': _constructTrack(
                outboundValues,
                timestamp,
              ),
            });
            statsObject[report.id] = {
              ...outboundValues,
              'id': report.id,
              'type': report.type,
              'timestamp': timestamp,
            };
            break;
          case 'remote-inbound-rtp':
            // Extract RTT from remote-inbound-rtp
            final remoteInboundValues = report.values.cast<String, dynamic>();
            if (remoteInboundValues.containsKey('roundTripTime') &&
                remoteInboundValues['kind'] == 'audio') {
              rtt =
                  (remoteInboundValues['roundTripTime'] as num?)?.toDouble() ??
                      0;
            }

            statsObject[report.id] = {
              ...remoteInboundValues,
              'id': report.id,
              'type': report.type,
              'timestamp': timestamp,
            };
            break;
          case 'local-candidate':
            final localCandidate = {
              ...report.values,
              'id': report.id,
              'type': report.type,
              'timestamp': timestamp,
            };
            localCandidates[report.id] = localCandidate;
            statsObject[report.id] = localCandidate;
            break;
          case 'remote-candidate':
            final remoteCandidate = {
              ...report.values,
              'id': report.id,
              'type': report.type,
              'timestamp': timestamp,
            };
            remoteCandidates[report.id] = remoteCandidate;
            statsObject[report.id] = remoteCandidate;
            break;
          case 'candidate-pair':
            final candidatePairValues = report.values.cast<String, dynamic>();
            final localCandidateId = candidatePairValues['localCandidateId'];
            final remoteCandidateId = candidatePairValues['remoteCandidateId'];

            final localCandidate = localCandidates[localCandidateId];
            final remoteCandidate = remoteCandidates[remoteCandidateId];

            final candidatePair = {
              'id': report.id,
              ...candidatePairValues,
              'timestamp': timestamp,
              'type': 'candidate-pair',
            };

            if (localCandidate != null && remoteCandidate != null) {
              candidatePair['localCandidateId'] = localCandidateId;
              candidatePair['remoteCandidateId'] = remoteCandidateId;
              candidatePair['local'] = localCandidate;
              candidatePair['remote'] = remoteCandidate;

              // Always set the succeededConnection to the most recent candidatePair
              succeededConnection = candidatePair.cast<String, dynamic>();

              // Extract RTT from candidate pair if not found in remote-inbound-rtp
              if (rtt == 0 &&
                  candidatePairValues.containsKey('currentRoundTripTime')) {
                rtt = (candidatePairValues['currentRoundTripTime'] as num?)
                        ?.toDouble() ??
                    0;
              }

              statsObject[report.id] = candidatePair;
            } else {
              unresolvedCandidatePairs.add({
                'report': report,
                'timestamp': timestamp,
              });
            }
            break;
          default:
            statsObject[report.id] = {
              ...report.values,
              'id': report.id,
              'type': report.type,
              'timestamp': timestamp,
            };
        }
      }

      // Process unresolved candidate-pairs
      for (final unresolved in unresolvedCandidatePairs) {
        final report = unresolved['report'];
        final reportValues = report.values.cast<String, dynamic>();
        final localCandidateId = reportValues['localCandidateId'];
        final remoteCandidateId = reportValues['remoteCandidateId'];

        final localCandidate = localCandidates[localCandidateId];
        final remoteCandidate = remoteCandidates[remoteCandidateId];

        final candidatePair = {
          'id': report.id,
          ...reportValues,
          'timestamp': unresolved['timestamp'],
          'type': 'candidate-pair',
        };

        if (localCandidate != null && remoteCandidate != null) {
          candidatePair['localCandidateId'] = localCandidateId;
          candidatePair['remoteCandidateId'] = remoteCandidateId;
          candidatePair['local'] = localCandidate;
          candidatePair['remote'] = remoteCandidate;

          // Always set the succeededConnection to the most recent candidatePair
          succeededConnection = candidatePair.cast<String, dynamic>();

          statsObject[report.id] = candidatePair;
        } else {
          GlobalLogger().w(
            'Failed to resolve local or remote candidate for candidate-pair ${report.id}',
          );
        }
      }

      // Calculate MOS and call quality metrics if we have valid data
      if (onCallQualityChange != null && (jitter > 0 || rtt > 0)) {
        // Calculate MOS using the E-model
        final mos = MosCalculator.calculateMos(
          rtt: rtt,
          jitter: jitter,
          packetLoss: packetLoss,
        );

        // Determine call quality based on MOS
        final quality = CallQuality.fromMos(mos);

        // Create call quality metrics object
        final metrics = CallQualityMetrics(
          jitter: jitter,
          rtt: rtt,
          mos: mos,
          quality: quality,
          inboundAudio: inboundAudioStats,
          outboundAudio: outboundAudioStats,
        );

        // Notify via callback
        onCallQualityChange!(metrics);

        // Log metrics (debug level to avoid excessive logging)
        GlobalLogger().d('Call quality metrics: $metrics');
      }

      // Format the data
      final formattedData = {
        'audio': {
          'inbound': audioInboundStats,
          'outbound': audioOutboundStats,
        },
        'connection': succeededConnection ?? {},
      };

      final reportData = {
        'event': WebRTCStatsEvent.stats.value,
        'tag': WebRTCStatsTag.stats.value,
        'peerId': peerId,
        'connectionId': callId,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'data': _normalizeData(formattedData),
        'statsObject': statsObject,
      };

      final message = DebugReportDataMessage(
        reportId: debugStatsId,
        reportData: reportData,
      );

      _enqueueMessage(jsonEncode(message.toJson()));
    } catch (e) {
      GlobalLogger().e('Error collecting stats: $e');
    }
  }

  Map<String, dynamic>? _constructTrack(
    Map<String, dynamic> reportValues,
    double timestamp,
  ) {
    if (!reportValues.containsKey('mediaSourceId')) {
      // Return null if media source info is not available
      return null;
    }

    return {
      'id': reportValues['mediaSourceId'],
      'timestamp': timestamp,
      'type': 'media-source',
      'kind': reportValues['kind'],
      'trackIdentifier': reportValues['trackIdentifier'],
      'audioLevel': reportValues['audioLevel'] ?? 0,
      'echoReturnLoss': reportValues['echoReturnLoss'],
      'echoReturnLossEnhancement': reportValues['echoReturnLossEnhancement'],
      'totalAudioEnergy': reportValues['totalAudioEnergy'],
      'totalSamplesDuration': reportValues['totalSamplesDuration'],
    };
  }

  Future<void> _sendAddConnectionMessage() async {
    // add a 2 second delay here to allow stats reporting to start before adding connection
    await Future.delayed(Duration(seconds: 2));
    final message = DebugReportDataMessage(
      reportId: debugStatsId,
      reportData: {
        'event': WebRTCStatsEvent.addConnection.value,
        'tag': WebRTCStatsTag.peer.value,
        'peerId': peerId,
        'connectionId': callId,
        'data': {
          'peerConfiguration': StatParsingHelpers().getPeerConfiguration(
            peerConnection.getConfiguration,
          ),
          'options': {'peerId': peerId, 'pc': {}},
        },
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      },
    );

    _enqueueMessage(jsonEncode(message.toJson()));
  }

  void _sendStartDebugReport(String sessionId) {
    final message = DebugReportStartMessage(reportId: sessionId);
    debugReportStarted = true;
    _enqueueMessage(jsonEncode(message.toJson()));
  }

  void _sendStopDebugReport(String sessionId) {
    final message = DebugReportStopMessage(reportId: sessionId);
    _enqueueMessage(jsonEncode(message.toJson()));
  }

  void _sendDebugReportData({
    required WebRTCStatsEvent event,
    required WebRTCStatsTag tag,
    required dynamic data,
  }) {
    final reportData = {
      'event': event.value,
      'tag': tag.value,
      'peerId': peerId,
      'connectionId': callId,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'data': _normalizeData(data),
    };

    final message = DebugReportDataMessage(
      reportId: debugStatsId,
      reportData: reportData,
    );

    _enqueueMessage(jsonEncode(message.toJson()));
  }

  dynamic _normalizeData(dynamic data) {
    // Check if the `data` is a single key-value pair, return the value directly.
    if (data is Map<String, dynamic> && data.length == 1) {
      return data.values.first;
    }
    return data;
  }
}
