/// Data class representing latency measurements for WebRTC call establishment.
/// These metrics help developers understand the time taken for each step in the call flow.
///
/// All time values are in milliseconds.
class LatencyMetrics {
  /// The unique identifier for the call these metrics belong to (null for registration metrics)
  final String? callId;

  /// True if this is an outbound call, false for inbound
  final bool isOutbound;

  /// Time from login initiation to successful registration (CLIENT_READY)
  final int? registrationLatencyMs;

  /// Time from call initiation (newInvite/acceptCall) to ACTIVE state
  final int? callSetupLatencyMs;

  /// Time from call initiation to first RTP packet sent/received
  final int? timeToFirstRtpMs;

  /// Time spent gathering ICE candidates
  final int? iceGatheringLatencyMs;

  /// Time spent in SIP signaling (INVITE to answer)
  final int? signalingLatencyMs;

  /// Time from signaling complete to media flowing
  final int? mediaEstablishmentLatencyMs;

  /// Detailed breakdown of individual milestones with timestamps
  final Map<String, int> milestones;

  /// Timestamp when these metrics were collected
  final int timestamp;

  const LatencyMetrics({
    this.callId,
    this.isOutbound = false,
    this.registrationLatencyMs,
    this.callSetupLatencyMs,
    this.timeToFirstRtpMs,
    this.iceGatheringLatencyMs,
    this.signalingLatencyMs,
    this.mediaEstablishmentLatencyMs,
    this.milestones = const {},
    int? timestamp,
  }) : timestamp = timestamp ?? _nowMs();

  static int _nowMs() => DateTime.now().millisecondsSinceEpoch;

  /// Returns a formatted string representation of the latency metrics.
  @override
  String toString() {
    final isRegistration = callId == null && registrationLatencyMs != null;
    final header = isRegistration
        ? 'REGISTRATION LATENCY METRICS'
        : '${isOutbound ? "OUTBOUND" : "INBOUND"} CALL LATENCY METRICS';

    final sb = StringBuffer()
      ..writeln('═══════════════════════════════════════════════════')
      ..writeln('       $header')
      ..writeln('═══════════════════════════════════════════════════');

    if (callId != null) sb.writeln('Call ID: $callId');
    if (registrationLatencyMs != null) {
      sb.writeln('Registration Latency:      ${registrationLatencyMs}ms');
    }
    if (callSetupLatencyMs != null) {
      sb.writeln('Call Setup Latency:        ${callSetupLatencyMs}ms');
    }
    if (timeToFirstRtpMs != null) {
      sb.writeln('Time to First RTP:         ${timeToFirstRtpMs}ms');
    }
    if (iceGatheringLatencyMs != null) {
      sb.writeln('ICE Gathering Latency:     ${iceGatheringLatencyMs}ms');
    }
    if (signalingLatencyMs != null) {
      sb.writeln('Signaling Latency:         ${signalingLatencyMs}ms');
    }
    if (mediaEstablishmentLatencyMs != null) {
      sb.writeln('Media Establishment:       ${mediaEstablishmentLatencyMs}ms');
    }

    if (milestones.isNotEmpty) {
      sb.writeln('───────────────────────────────────────────────────');
      sb.writeln('Detailed Milestones:');
      final sorted = milestones.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      for (final entry in sorted) {
        sb.writeln('  ${entry.key.padRight(35)} ${entry.value}ms');
      }
    }
    sb.writeln('═══════════════════════════════════════════════════');

    return sb.toString();
  }
}

/// Callback for receiving latency metrics updates.
typedef LatencyMetricsCallback = void Function(LatencyMetrics metrics);
