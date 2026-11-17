import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Waits for ICE gathering of a freshly set ICE-restart offer to finish, so
/// the `updateMedia` offer carries the new candidates.
///
/// Right after `setLocalDescription` the gathering state may still report
/// `complete` from the previous negotiation, so a `complete` state only
/// counts after `gathering` was observed or after [startGrace]. Never waits
/// longer than [timeout]; the recovery monitor bounds the whole restart.
Future<void> waitForIceRestartGathering(
  RTCIceGatheringState? Function() readState, {
  Duration timeout = const Duration(seconds: 5),
  Duration startGrace = const Duration(milliseconds: 500),
  Duration pollInterval = const Duration(milliseconds: 100),
}) async {
  final stopwatch = Stopwatch()..start();
  var sawGathering = false;
  while (stopwatch.elapsed < timeout) {
    final state = readState();
    if (state == RTCIceGatheringState.RTCIceGatheringStateGathering) {
      sawGathering = true;
    } else if (state == RTCIceGatheringState.RTCIceGatheringStateComplete &&
        (sawGathering || stopwatch.elapsed >= startGrace)) {
      return;
    }
    await Future<void>.delayed(pollInterval);
  }
}

/// Sums `packetsReceived` across inbound audio RTP streams in [reports].
/// Returns `null` when no inbound audio counter is available.
int? inboundAudioPacketsFromReports(Iterable<StatsReport> reports) {
  int? total;
  for (final report in reports) {
    if (report.type != 'inbound-rtp') continue;
    final values = report.values;
    final kind = values['kind'] ?? values['mediaType'];
    if (kind != 'audio') continue;
    final raw = values['packetsReceived'];
    final packets = raw is num ? raw.toInt() : int.tryParse('$raw');
    if (packets != null) total = (total ?? 0) + packets;
  }
  return total;
}
