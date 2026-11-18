import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:telnyx_webrtc/src/recovery/call_recovery_monitor.dart';

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

/// Selected ICE candidate pair from live `getStats()` [reports], captured
/// when recovery falls back to reattach. Prefers the transport's
/// `selectedCandidatePairId`, then a selected / nominated succeeded pair.
/// Returns `null` when no selected pair or local candidate is reported.
CandidateEvidence? selectedCandidateEvidenceFromReports(
  Iterable<StatsReport> reports, {
  String? callId,
}) {
  final byId = <String, StatsReport>{
    for (final report in reports) report.id: report,
  };

  StatsReport? pair;
  for (final report in reports) {
    if (report.type != 'transport') continue;
    final id = report.values['selectedCandidatePairId'];
    if (id is String && byId.containsKey(id)) {
      pair = byId[id];
      break;
    }
  }
  if (pair == null) {
    for (final report in reports) {
      if (report.type != 'candidate-pair') continue;
      final values = report.values;
      final selected = values['selected'] == true ||
          (values['nominated'] == true && values['state'] == 'succeeded');
      if (selected) {
        pair = report;
        break;
      }
    }
  }
  if (pair == null) return null;

  final local = byId[pair.values['localCandidateId']];
  if (local == null) return null;
  final remote = byId[pair.values['remoteCandidateId']];

  String? text(StatsReport? report, String key) {
    final value = report?.values[key];
    return value is String ? value : null;
  }

  return CandidateEvidence(
    callId: callId,
    localCandidateType: text(local, 'candidateType'),
    remoteCandidateType: text(remote, 'candidateType'),
    localNetworkType: text(local, 'networkType'),
    localAddress: text(local, 'address') ?? text(local, 'ip'),
    localProtocol: text(local, 'protocol'),
  );
}

/// Whether [evidence] shows media on a direct (non-relay) VPN path, which
/// justifies a one-shot relay-only replacement call. Fails closed: without
/// an explicit `vpn` network type no override is applied. Same rule as the
/// call-report heuristic (`CallReportCollector`).
bool shouldForceRelayForEvidence(CandidateEvidence evidence) {
  final candidateType = evidence.localCandidateType?.toLowerCase();
  return evidence.localNetworkType?.toLowerCase() == 'vpn' &&
      candidateType != null &&
      candidateType != 'relay';
}
