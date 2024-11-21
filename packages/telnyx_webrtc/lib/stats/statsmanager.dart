import 'dart:async';
import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:telnyx_webrtc/stats/stats_params.dart';
import 'package:telnyx_webrtc/tx_socket.dart';
import 'package:uuid/uuid.dart';

class StatsManager {
  StatsManager(this.socket,this.peerConnection,this.callId) 

  final Timer? _timer = null;
  bool debugReportStarted = false;
  final String callId;
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

  String? debugStatsId;
  bool isDebugStats = false;

  // Placeholder for `client` and `peerConnection`, replace with actual implementation.
  final TxSocket socket;
  final RTCPeerConnection peerConnection;
  final String callId = 'sampleCallId'; // Replace with actual callId.

  void stopTimer() {
    socket?.stopStats(debugStatsId);
    debugStatsId = null;
    mainObject = {};
    _timer?.cancel();
  }

  void startTimer() {
    isDebugStats = true;

    if (socket != null && !(socket.debugReportStarted ?? false)) {
      debugStatsId = uuid.v4();
       startStats(debugStatsId!);
    }

    Timer.periodic(Duration(milliseconds: STATS_INTERVAL), (timer) {
      mainObject = {
        "event": "stats",
        "tag": "stats",
        "peerId": "stats",
        "connectionId": callId,
      };

      peerConnection.getStats(null).then((stats) {
        stats.forEach((report) {

          report.values.forEach((key, value) {
        
            if (value['type'] == 'inbound-rtp') {
              inBoundStats.add(value);
            }
            if (value['type'] == 'outbound-rtp') {
             outBoundStats.add(value);
            }
            if (value['type'] == 'candidate-pair' &&
               candidatePairs.length < CANDIDATE_LIMIT) {
               candidatePairs.add(value);
            }
          });
        });

        audio = {
          "inbound": inBoundStats,
          "outbound": outBoundStats,
          "candidatePair": candidatePairs,
        };

        statsData = {
          "audio": audio,
        };

        mainObject["data"] = statsData;
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

          if (debugStatsId != null) {
            socket?.sendStats(mainObject, debugStatsId);
          }
        }
      });
   
   
    });
  }


   void startStats(String sessionId) {
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
