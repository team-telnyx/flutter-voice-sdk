import 'dart:async';
import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:logger/logger.dart';
import 'package:telnyx_webrtc/utils/constants.dart';
import 'package:telnyx_webrtc/utils/stats/stats_message.dart';
import 'package:telnyx_webrtc/tx_socket.dart';
import 'package:telnyx_webrtc/utils/stats/webrtc_stats_event.dart';
import 'package:telnyx_webrtc/utils/stats/webrtc_stats_tag.dart';
import 'package:uuid/uuid.dart';

class WebRTCStatsReporter {
  WebRTCStatsReporter(this.socket, this.peerConnection, this.callId);

  final _logger = Logger();
  Timer? _timer;
  bool debugReportStarted = false;
  final Uuid uuid = const Uuid();

  String debugStatsId = const Uuid().v4();

  final TxSocket socket;
  final RTCPeerConnection peerConnection;
  final String callId;

  RTCSessionDescription? localSdp;
  RTCSessionDescription? remoteSdp;

  // Start stats reporting
  Future<void> startStatsReporting() async {
    localSdp = await peerConnection.getLocalDescription();
    remoteSdp = await peerConnection.getRemoteDescription();

    if (!debugReportStarted) {
      debugStatsId = uuid.v4();
      _sendStartDebugReport(debugStatsId);
    }

    // Set up peer event handlers
    _setupPeerEventHandlers();

    // Schedule periodic stats collection
    _timer = Timer.periodic(Duration(milliseconds: Constants.statsInterval),
        (_) async {
      await _collectAndSendStats();
    });
  }

  // Stop stats reporting
  void stopStatsReporting() {
    if (debugReportStarted) {
      debugReportStarted = false;
      _sendStopDebugReport(debugStatsId);
    }
    _timer?.cancel();
  }

  // Event Handlers for Peer Events
  void _setupPeerEventHandlers() {
    peerConnection
      ..onIceCandidate = (RTCIceCandidate candidate) {
        final candidateData = {
          'candidate': candidate.candidate,
          'sdpMLineIndex': candidate.sdpMLineIndex,
          'sdpMid': candidate.sdpMid,
        };
        _sendDebugReportData(
          event: WebRTCStatsEvent.onIceCandidate,
          tag: WebRTCStatsTag.connection,
          data: candidateData,
        );
      }
      ..onSignalingState = (RTCSignalingState signalingState) async {
        final description = {
          'signalingState': signalingState.toString(),
          'localDescription': localSdp?.sdp,
          'remoteDescription': remoteSdp?.sdp,
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
          data: {'iceConnectionState': iceConnectionState.toString()},
        );
      }
      ..onIceGatheringState = (RTCIceGatheringState iceGatheringState) {
        _sendDebugReportData(
          event: WebRTCStatsEvent.onIceGatheringStateChange,
          tag: WebRTCStatsTag.connection,
          data: {'iceGatheringState': iceGatheringState.toString()},
        );
      };
  }

  // Periodic Stats Collection
  Future<void> _collectAndSendStats() async {
    try {
      final stats = await peerConnection.getStats(null);

      final audioInboundStats = [];
      final audioOutboundStats = [];
      final videoInboundStats = [];
      final videoOutboundStats = [];
      final candidatePairs = [];
      final statsObject = {};

      for (var report in stats) {
        switch (report.type) {
          case 'inbound-rtp':
            if (report.values['kind'] == 'audio') {
              audioInboundStats.add(report.values);
            } else if (report.values['kind'] == 'video') {
              videoInboundStats.add(report.values);
            }
            break;
          case 'outbound-rtp':
            if (report.values['kind'] == 'audio') {
              audioOutboundStats.add(report.values);
            } else if (report.values['kind'] == 'video') {
              videoOutboundStats.add(report.values);
            }
            break;
          case 'candidate-pair':
            candidatePairs.add(
              _parseCandidatePair(report.values.cast<String, dynamic>()),
            );
            break;
          default:
            statsObject[report.id] = report.values;
        }
      }

      final messageData = {
        'event': WebRTCStatsEvent.stats.value,
        'tag': WebRTCStatsTag.stats.value,
        'peerId': callId,
        'connectionId': callId,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'data': {
          'audio': {
            'inbound': audioInboundStats,
            'outbound': audioOutboundStats,
          },
          'video': {
            'inbound': videoInboundStats,
            'outbound': videoOutboundStats,
          },
          'connection': {'candidatePair': candidatePairs},
        },
        'statsObject': statsObject,
      };

      _sendDebugReportData(
        event: WebRTCStatsEvent.stats,
        tag: WebRTCStatsTag.stats,
        data: messageData,
      );
    } catch (e) {
      _logger.e('Error collecting stats: $e');
    }
  }

  // Helper Methods for Debug Report
  void _sendStartDebugReport(String sessionId) {
    final message = DebugReportStartMessage(reportId: sessionId);
    debugReportStarted = true;
    socket.send(jsonEncode(message.toJson()));
  }

  void _sendStopDebugReport(String sessionId) {
    final message = DebugReportStopMessage(reportId: sessionId);
    socket.send(jsonEncode(message.toJson()));
  }

  void _sendDebugReportData({
    required WebRTCStatsEvent event,
    required WebRTCStatsTag tag,
    required Map<String, dynamic> data,
  }) {
    final message = DebugReportDataMessage(
      reportId: debugStatsId,
      reportData: {
        'event': event.value,
        'tag': tag.value,
        'peerId': callId,
        'connectionId': callId,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'data': data,
      },
    );

    socket.send(jsonEncode(message.toJson()));
  }

  // Helper method for candidate pair parsing
  Map<String, dynamic> _parseCandidatePair(Map<String, dynamic> candidate) {
    return {
      'id': candidate['id'],
      'state': candidate['state'],
      'bytesSent': candidate['bytesSent'],
      'bytesReceived': candidate['bytesReceived'],
      'currentRoundTripTime': candidate['currentRoundTripTime'],
      'priority': candidate['priority'],
      'nominated': candidate['nominated'],
    };
  }
}
