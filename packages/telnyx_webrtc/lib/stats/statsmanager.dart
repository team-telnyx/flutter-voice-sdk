import 'dart:async';
import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:logger/logger.dart';
import 'package:telnyx_webrtc/stats/stats_params.dart';
import 'package:telnyx_webrtc/tx_socket.dart';
import 'package:uuid/uuid.dart';

class StatsManager {
  StatsManager(this.socket, this.peerConnection, this.callId);
  final _logger = Logger();

  Timer? _timer;
  bool debugReportStarted = false;
  final Uuid uuid = Uuid();
  final int STATS_INITIAL = 1000; // Replace with appropriate initial delay
  final int STATS_INTERVAL = 1000; // Replace with appropriate interval
  final int CANDIDATE_LIMIT = 10; // Adjust as needed

  Map<String, dynamic> mainObject = {};
  Map<String, dynamic> audio = {};
  Map<String, dynamic> statsData = {};
  List<dynamic> inBoundStats = [];
  List<dynamic> outBoundStats = [];
  List<dynamic> candidatePairs = [];

  String debugStatsId = const Uuid().v4();

  // Placeholder for `client` and `peerConnection`, replace with actual implementation.
  final TxSocket socket;
  final RTCPeerConnection? peerConnection;
  final String callId;

  void stopTimer() {
    stopStats(debugStatsId);
    mainObject = {};
    peerConnection?.close();
    peerConnection?.dispose();
    _timer?.cancel();
  }

  void startTimer() {
    if (!debugReportStarted) {
      debugStatsId = uuid.v4();
      _startStats(debugStatsId);
    }

    _timer = Timer.periodic(Duration(milliseconds: STATS_INTERVAL), (_) {
      mainObject = {
        "event": "stats",
        "tag": "stats",
        "peerId": "stats",
        "connectionId": callId,
      };

      peerConnection?.getStats(null).then((stats) {
        for (int i = 0; i < stats.length; i++) {
          final report = stats[i];
          if (report.type == "inbound-rtp") {
            _logger.d("Stats: ${report.type} => ${report.values}");
            inBoundStats.add(report.values);
          } else if (report.type == "outbound-rtp") {
            _logger.d("Stats: ${report.type} => ${report.values}");
            outBoundStats.add(report.values);
          } else if (report.type == "candidate-pair") {
            _logger.d("Stats: ${report.type} => ${report.values}");
            candidatePairs.add(report.values);
          }
        }

        audio = {
          "inbound": inBoundStats,
          "outbound": outBoundStats,
          "candidatePair": candidatePairs,
        };

        statsData = {
          "audio": audio,
        };

        mainObject["data"] = statsData;
        mainObject["connectionId"] = callId;
        mainObject["timestamp"] = DateTime.now().millisecondsSinceEpoch;

        if (inBoundStats.isNotEmpty &&
            outBoundStats.isNotEmpty &&
            candidatePairs.isNotEmpty) {
          // Reset for next interval
          inBoundStats = [];
          outBoundStats = [];
          candidatePairs = [];
          statsData = {};
          audio = {};

          print("Stats Inbound: ${jsonEncode(mainObject)}");

          sendStats(mainObject, debugStatsId);
        }
      });
    });
  }

  void _startStats(String sessionId) {
    debugReportStarted = true;
    var loginMessage = InitiateOrStopStatParams(
      type: "debug_report_start",
      debugReportId: sessionId,
    );
    socket.send(jsonEncode(loginMessage.toJson()));
  }

  void sendStats(Map<String, dynamic> data, String sessionId) {
    var statParams = StatParams(
      debugReportId: sessionId,
      reportData: data,
    );
    socket.send(jsonEncode(statParams.toJson()));
  }

  void stopStats(String sessionId) {
    debugReportStarted = false;
    var loginMessage = InitiateOrStopStatParams(
      type: "debug_report_stop",
      debugReportId: sessionId,
    );
    socket.send(jsonEncode(loginMessage.toJson()));
  }
}
