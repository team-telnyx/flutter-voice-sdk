import 'dart:async';
import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:logger/logger.dart';
import 'package:telnyx_webrtc/utils/stats/stats_params.dart';
import 'package:telnyx_webrtc/tx_socket.dart';
import 'package:uuid/uuid.dart';

class StatsManager {
  StatsManager(this.socket, this.peerConnection, this.callId);

  static const int STATS_INITIAL = 1000;
  static const int STATS_INTERVAL = 1000;
  static const int CANDIDATE_LIMIT = 10;

  final _logger = Logger();
  Timer? _timer;
  bool debugReportStarted = false;
  final Uuid uuid = const Uuid();

  Map<String, dynamic> mainObject = {};
  Map<String, dynamic> audio = {};
  Map<String, dynamic> statsData = {};
  List<dynamic> inBoundStats = [];
  List<dynamic> outBoundStats = [];
  List<dynamic> candidatePairs = [];
  String debugStatsId = const Uuid().v4();

  final TxSocket socket;
  final RTCPeerConnection? peerConnection;
  final String callId;

  void stopTimer() {
    stopStats(debugStatsId);
    _resetStats();
    _timer?.cancel();
  }

  void startTimer() {
    if (!debugReportStarted) {
      debugStatsId = uuid.v4();
      _startStats(debugStatsId);
    }

    _timer = Timer.periodic(Duration(milliseconds: STATS_INTERVAL), (_) async {
      mainObject = {
        'event': 'stats',
        'tag': 'stats',
        'peerId': 'stats',
        'connectionId': callId,
      };

      try {
        final stats = await peerConnection?.getStats(null);
        stats?.forEach((report) {
          switch (report.type) {
            case 'inbound-rtp':
              inBoundStats.add(report.values);
              break;
            case 'outbound-rtp':
              outBoundStats.add(report.values);
              break;
            case 'candidate-pair':
              candidatePairs.add(report.values);
              break;
          }
        });

        audio = {
          'inbound': inBoundStats,
          'outbound': outBoundStats,
          'candidatePair': candidatePairs,
        };

        statsData = {'audio': audio};
        mainObject['data'] = statsData;
        mainObject['timestamp'] = DateTime.now().millisecondsSinceEpoch;

        if (inBoundStats.isNotEmpty &&
            outBoundStats.isNotEmpty &&
            candidatePairs.isNotEmpty) {
          _resetStats();
          sendStats(mainObject, debugStatsId);
        }
      } catch (e, stackTrace) {
        _logger.e('Error collecting stats', e, stackTrace);
      }
    });
  }

  void _startStats(String sessionId) {
    debugReportStarted = true;
    socket.send(jsonEncode(InitiateOrStopStatParams(
      type: 'debug_report_start',
      debugReportId: sessionId,
    ).toJson()));
  }

  void sendStats(Map<String, dynamic> data, String sessionId) {
    socket.send(jsonEncode(StatParams(
      debugReportId: sessionId,
      reportData: data,
    ).toJson()));
  }

  void stopStats(String sessionId) {
    debugReportStarted = false;
    socket.send(jsonEncode(InitiateOrStopStatParams(
      type: 'debug_report_stop',
      debugReportId: sessionId,
    ).toJson()));
  }

  void _resetStats() {
    inBoundStats = [];
    outBoundStats = [];
    candidatePairs = [];
    statsData = {};
    audio = {};
  }
}
