import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:telnyx_webrtc/utils/constants.dart';
import 'package:telnyx_webrtc/utils/stats/stats_parsing_helpers.dart';
import 'package:telnyx_webrtc/utils/stats/stats_message.dart';
import 'package:telnyx_webrtc/tx_socket.dart';
import 'package:telnyx_webrtc/utils/stats/webrtc_stats_event.dart';
import 'package:telnyx_webrtc/utils/stats/webrtc_stats_tag.dart';
import 'package:uuid/uuid.dart';

class WebRTCStatsReporter {
  WebRTCStatsReporter(this.socket, this.peerConnection, this.callId);

  final Logger _logger = Logger();
  final Queue<String> _messageQueue = Queue<String>();
  File? _logFile;

  Timer? _timer;
  bool debugReportStarted = false;
  final Uuid uuid = const Uuid();
  String debugStatsId = const Uuid().v4();

  final TxSocket socket;
  final RTCPeerConnection peerConnection;
  final String callId;

  Future<void> _initializeLogFile() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      _logFile = File('${directory.path}/webrtc_stats_log.json');

      if (!_logFile!.existsSync()) {
        _logFile!.createSync();
      }
    } catch (e) {
      _logger.e('Error initializing log file: $e');
    }
  }

  void _enqueueMessage(String message) {
    _messageQueue.add(message);
    _processMessageQueue();
  }

  void _processMessageQueue() async {
    while (_messageQueue.isNotEmpty) {
      final message = _messageQueue.removeFirst();
      socket.send(message);

      // Append the message to the log file.
      try {
        _logFile?.writeAsStringSync('$message\n\n,', mode: FileMode.append);
      } catch (e) {
        _logger.e('Error writing message to log file: $e');
      }

      await Future.delayed(Duration(milliseconds: 50));
    }
  }

  Future<void> startStatsReporting() async {
    await _initializeLogFile();

    if (!debugReportStarted) {
      debugStatsId = uuid.v4();
      _sendStartDebugReport(debugStatsId);
    }

    _sendAddConnectionMessage();
    _setupPeerEventHandlers();

    _timer = Timer.periodic(Duration(milliseconds: Constants.statsInterval),
        (_) async {
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

  void _setupPeerEventHandlers() {
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
        final localSdp = await peerConnection.getLocalDescription();
        final remoteSdp = await peerConnection.getRemoteDescription();

        final description = {
          'signalingState':
              StatParsingHelpers().parseSignalingStateChange(signalingState),
          'remoteDescription': {
            'type': remoteSdp?.type,
            'sdp': remoteSdp?.sdp,
          },
          'localDescription': {
            'type': localSdp?.type,
            'sdp': localSdp?.sdp,
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
      final connectionStats = [];
      final statsObject = {};

      final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch.toDouble();

      final Map<String, dynamic> localCandidates = {};
      final Map<String, dynamic> remoteCandidates = {};
      final List<Map<String, dynamic>> unresolvedCandidatePairs = [];

      for (var report in stats) {
        print('ZZZ report: ${report.type}');
        switch (report.type) {
          case 'inbound-rtp':
            audioInboundStats.add({
              ...report.values,
              'timestamp': timestamp,
              'track': {},
            });
            break;

          case 'outbound-rtp':
            audioOutboundStats.add({
              ...report.values,
              'timestamp': timestamp,
              'track': _constructTrack(
                  report.values.cast<String, dynamic>(), timestamp),
            });
            break;

          case 'local-candidate':
            localCandidates[report.id] = {
              ...report.values,
              'id': report.id,
              'type': report.type,
              'timestamp': timestamp,
            };
            break;

          case 'remote-candidate':
            remoteCandidates[report.id] = {
              ...report.values,
              'id': report.id,
              'type': report.type,
              'timestamp': timestamp,
            };
            break;

          case 'candidate-pair':
            final localCandidateId = report.values['localCandidateId'];
            final remoteCandidateId = report.values['remoteCandidateId'];

            final localCandidate = localCandidates[localCandidateId];
            final remoteCandidate = remoteCandidates[remoteCandidateId];

            if (localCandidate != null && remoteCandidate != null) {
              final candidatePair = {
                'id': report.id,
                ...report.values,
                'timestamp': timestamp,
                'type': 'candidate-pair',
                'local': localCandidate,
                'remote': remoteCandidate,
              };

              connectionStats.add(candidatePair);
              statsObject[report.id] = candidatePair;
            } else {
              // Store unresolved candidate-pair for later processing
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
              'timestamp': timestamp,
            };
        }
      }

      // Process unresolved candidate-pairs
      for (final unresolved in unresolvedCandidatePairs) {
        final report = unresolved['report'];
        final localCandidateId = report.values['localCandidateId'];
        final remoteCandidateId = report.values['remoteCandidateId'];

        final localCandidate = localCandidates[localCandidateId];
        final remoteCandidate = remoteCandidates[remoteCandidateId];

        if (localCandidate != null && remoteCandidate != null) {
          final candidatePair = {
            'id': report.id,
            ...report.values,
            'timestamp': unresolved['timestamp'],
            'type': 'candidate-pair',
            'local': localCandidate,
            'remote': remoteCandidate,
          };

          connectionStats.add(candidatePair);
          statsObject[report.id] = candidatePair;
        } else {
          _logger.w(
            'Failed to resolve local or remote candidate for candidate-pair ${report.id}',
          );
        }
      }

      final formattedData = {
        'audio': {
          'inbound': audioInboundStats,
          'outbound': audioOutboundStats,
        },
        'connection': connectionStats,
        'statsObject': statsObject,
      };

      _sendDebugReportData(
        event: WebRTCStatsEvent.stats,
        tag: WebRTCStatsTag.stats,
        data: formattedData,
      );
    } catch (e) {
      _logger.e('Error collecting stats: $e');
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

  void _sendAddConnectionMessage() {
    final message = DebugReportDataMessage(
      reportId: debugStatsId,
      reportData: {
        'event': WebRTCStatsEvent.addConnection.value,
        'tag': WebRTCStatsTag.peer.value,
        'peerId': callId,
        'connectionId': callId,
        'data': {
          'peerConfiguration': StatParsingHelpers().getPeerConfiguration(
            peerConnection.getConfiguration,
          ),
          'options': {'peerId': callId, 'pc': {}},
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
      'peerId': callId,
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
