import 'package:telnyx_webrtc/model/sdk_warning_codes.dart';
import 'package:telnyx_webrtc/model/telnyx_warning.dart';

/// Definition record for a single SDK warning code.
class SdkWarningDefinition {
  /// The numeric SDK warning code.
  final int code;

  /// The machine-readable name in UPPER_SNAKE_CASE.
  final String name;

  /// A short human-readable message for UI alerts.
  final String message;

  /// A fuller explanation of what the warning means.
  final String description;

  /// Possible root causes of the warning.
  final List<String> causes;

  /// Suggested remediation steps for the warning.
  final List<String> solutions;

  /// Creates a warning definition for [code].
  const SdkWarningDefinition({
    required this.code,
    required this.name,
    required this.message,
    required this.description,
    required this.causes,
    required this.solutions,
  });
}

/// Registry of all known SDK warning codes and their metadata.
class SdkWarningRegistry {
  SdkWarningRegistry._();

  static const Map<int, SdkWarningDefinition> _definitions = {
    // ── Network quality (310xx) ──────────────────────────────────────────
    SdkWarningCode.highRtt: SdkWarningDefinition(
      code: SdkWarningCode.highRtt,
      name: 'HIGH_RTT',
      message: 'High network latency detected',
      description:
          'Round-trip time has exceeded 400 ms for 3 consecutive intervals.',
      causes: [
        'Network congestion or high load on the routing path',
        'Long geographic distance to the media server',
        'VPN or proxy adding latency',
      ],
      solutions: [
        'Use a closer media server region',
        'Disable VPN if active',
        'Check network bandwidth and congestion',
      ],
    ),
    SdkWarningCode.highJitter: SdkWarningDefinition(
      code: SdkWarningCode.highJitter,
      name: 'HIGH_JITTER',
      message: 'High jitter detected',
      description: 'Jitter has exceeded 30 ms for 3 consecutive intervals.',
      causes: [
        'Network congestion causing variable packet arrival times',
        'Insufficient buffering on the receiving end',
        'Shared network with heavy traffic',
      ],
      solutions: [
        'Use a wired connection instead of Wi-Fi',
        'Reduce network load from other applications',
        'Contact your ISP about line quality',
      ],
    ),
    SdkWarningCode.highPacketLoss: SdkWarningDefinition(
      code: SdkWarningCode.highPacketLoss,
      name: 'HIGH_PACKET_LOSS',
      message: 'High packet loss detected',
      description: 'Packet loss has exceeded 1% for 3 consecutive intervals.',
      causes: [
        'Unstable network connection',
        'Wireless interference',
        'Network hardware issues',
      ],
      solutions: [
        'Switch to a wired connection',
        'Restart your router/modem',
        'Contact your ISP',
      ],
    ),
    SdkWarningCode.lowMos: SdkWarningDefinition(
      code: SdkWarningCode.lowMos,
      name: 'LOW_MOS',
      message: 'Low call quality (MOS) detected',
      description:
          'Mean Opinion Score has fallen below 3.5 for 3 consecutive intervals.',
      causes: [
        'High jitter, RTT, or packet loss',
        'Insufficient bandwidth',
        'Codec issues',
      ],
      solutions: [
        'Check network conditions',
        'Reduce bandwidth usage from other apps',
        'Try a different network',
      ],
    ),
    SdkWarningCode.lowLocalAudio: SdkWarningDefinition(
      code: SdkWarningCode.lowLocalAudio,
      name: 'LOW_LOCAL_AUDIO',
      message: 'Low local audio level detected',
      description:
          'Outbound audio level is below threshold, possibly indicating a muted or disconnected microphone.',
      causes: [
        'Microphone is muted or disconnected',
        'Microphone permissions not granted',
        'Audio input device changed',
      ],
      solutions: [
        'Check microphone connection',
        'Unmute the microphone',
        'Verify microphone permissions',
      ],
    ),
    SdkWarningCode.lowInboundAudio: SdkWarningDefinition(
      code: SdkWarningCode.lowInboundAudio,
      name: 'LOW_INBOUND_AUDIO',
      message: 'Low inbound audio level detected',
      description:
          'Inbound audio level is below threshold, possibly indicating the remote party is muted or silent.',
      causes: [
        'Remote party has muted their microphone',
        'Remote party is silent',
        'Media server issue',
      ],
      solutions: [
        'Ask the remote party to check their microphone',
        'Verify the call is still connected',
      ],
    ),

    // ── Connection / data-flow (320xx) ─────────────────────────────────
    SdkWarningCode.lowBytesReceived: SdkWarningDefinition(
      code: SdkWarningCode.lowBytesReceived,
      name: 'LOW_BYTES_RECEIVED',
      message: 'No inbound data received',
      description: 'No bytes have been received for 3 consecutive intervals.',
      causes: [
        'Remote party stopped sending media',
        'Network firewall blocking inbound traffic',
        'Media server issue',
      ],
      solutions: [
        'Verify the remote party is still sending audio',
        'Check firewall settings',
        'Try reconnecting',
      ],
    ),
    SdkWarningCode.lowBytesSent: SdkWarningDefinition(
      code: SdkWarningCode.lowBytesSent,
      name: 'LOW_BYTES_SENT',
      message: 'No outbound data being sent',
      description: 'No bytes have been sent for 3 consecutive intervals.',
      causes: [
        'Local audio track is disabled or disconnected',
        'Network issue preventing outbound traffic',
        'Media server issue',
      ],
      solutions: [
        'Verify microphone is connected and enabled',
        'Check network connectivity',
        'Try reconnecting',
      ],
    ),
    SdkWarningCode.recordingUnavailable: SdkWarningDefinition(
      code: SdkWarningCode.recordingUnavailable,
      name: 'RECORDING_UNAVAILABLE',
      message: 'Call recording is unavailable',
      description:
          'The recording service could not be started or is not supported.',
      causes: [
        'Recording not enabled on the account',
        'Server-side recording service unavailable',
      ],
      solutions: [
        'Enable recording in the Telnyx dashboard',
        'Contact support',
      ],
    ),
    SdkWarningCode.recordingBufferOverflow: SdkWarningDefinition(
      code: SdkWarningCode.recordingBufferOverflow,
      name: 'RECORDING_BUFFER_OVERFLOW',
      message: 'Recording buffer overflow',
      description: 'The recording buffer overflowed, audio may be lost.',
      causes: [
        'Slow storage device',
        'High CPU usage',
      ],
      solutions: [
        'Free up device resources',
        'Restart the call',
      ],
    ),

    // ── Call connection (330xx) ────────────────────────────────────────
    SdkWarningCode.iceConnectivityLost: SdkWarningDefinition(
      code: SdkWarningCode.iceConnectivityLost,
      name: 'ICE_CONNECTIVITY_LOST',
      message: 'ICE connectivity lost',
      description: 'ICE connection state transitioned to "disconnected".',
      causes: [
        'Network disruption',
        'NAT or firewall changes',
        'Wi-Fi handoff',
      ],
      solutions: [
        'Wait for ICE restart / reconnection',
        'Check network connectivity',
      ],
    ),
    SdkWarningCode.iceGatheringTimeout: SdkWarningDefinition(
      code: SdkWarningCode.iceGatheringTimeout,
      name: 'ICE_GATHERING_TIMEOUT',
      message: 'ICE gathering timed out',
      description:
          'ICE candidate gathering did not complete within the expected time.',
      causes: [
        'Network issues preventing STUN/TURN communication',
        'Firewall blocking UDP traffic',
      ],
      solutions: [
        'Check firewall settings',
        'Ensure STUN/TURN servers are reachable',
      ],
    ),
    SdkWarningCode.iceGatheringEmpty: SdkWarningDefinition(
      code: SdkWarningCode.iceGatheringEmpty,
      name: 'ICE_GATHERING_EMPTY',
      message: 'No ICE candidates gathered',
      description: 'ICE gathering completed but no candidates were collected.',
      causes: [
        'No network connectivity',
        'All interfaces are down',
      ],
      solutions: [
        'Check network connectivity',
        'Restart the call',
      ],
    ),
    SdkWarningCode.peerConnectionFailed: SdkWarningDefinition(
      code: SdkWarningCode.peerConnectionFailed,
      name: 'PEER_CONNECTION_FAILED',
      message: 'Peer connection failed',
      description: 'The RTCPeerConnection transitioned to "failed" state.',
      causes: [
        'ICE negotiation failure',
        'Network disconnection',
        'SDP negotiation failure',
      ],
      solutions: [
        'Check network connectivity',
        'Restart the call',
      ],
    ),
    SdkWarningCode.onlyHostIceCandidates: SdkWarningDefinition(
      code: SdkWarningCode.onlyHostIceCandidates,
      name: 'ONLY_HOST_ICE_CANDIDATES',
      message: 'Only host ICE candidates available',
      description:
          'Only host (local) ICE candidates were gathered, no STUN or TURN candidates.',
      causes: [
        'STUN/TURN servers unreachable',
        'Firewall blocking STUN/TURN traffic',
      ],
      solutions: [
        'Check firewall settings',
        'Verify STUN/TURN server configuration',
      ],
    ),
    SdkWarningCode.answerWhilePeerActive: SdkWarningDefinition(
      code: SdkWarningCode.answerWhilePeerActive,
      name: 'ANSWER_WHILE_PEER_ACTIVE',
      message: 'Answer received while peer connection is active',
      description:
          'An SDP answer was received while the peer connection was already active.',
      causes: [
        'Duplicate or late answer from the server',
      ],
      solutions: [
        'Ignore the duplicate answer',
      ],
    ),
    SdkWarningCode.duplicateInboundAnswer: SdkWarningDefinition(
      code: SdkWarningCode.duplicateInboundAnswer,
      name: 'DUPLICATE_INBOUND_ANSWER',
      message: 'Duplicate inbound answer received',
      description: 'A duplicate SDP answer was received for an active call.',
      causes: [
        'Server retransmission',
      ],
      solutions: [
        'Ignore the duplicate answer',
      ],
    ),
    SdkWarningCode.iceCandidatePairChanged: SdkWarningDefinition(
      code: SdkWarningCode.iceCandidatePairChanged,
      name: 'ICE_CANDIDATE_PAIR_CHANGED',
      message: 'ICE candidate pair changed',
      description: 'The selected ICE candidate pair changed mid-call.',
      causes: [
        'Network path changed',
        'ICE restart',
        'Better candidate pair found',
      ],
      solutions: [
        'Monitor call quality after the change',
      ],
    ),
    SdkWarningCode.audioInputDeviceChangeSkipped: SdkWarningDefinition(
      code: SdkWarningCode.audioInputDeviceChangeSkipped,
      name: 'AUDIO_INPUT_DEVICE_CHANGE_SKIPPED',
      message: 'Audio input device change skipped',
      description: 'An audio input device change was detected but skipped.',
      causes: [
        'Call already in progress',
        'Device hot-swap not supported',
      ],
      solutions: [
        'Restart the call to use the new device',
      ],
    ),
    SdkWarningCode.multipleActiveCallsDetected: SdkWarningDefinition(
      code: SdkWarningCode.multipleActiveCallsDetected,
      name: 'MULTIPLE_ACTIVE_CALLS_DETECTED',
      message: 'Multiple active calls detected',
      description: 'Multiple active calls were detected on the same session.',
      causes: [
        'Call state issue',
      ],
      solutions: [
        'Verify call lifecycle management',
      ],
    ),
    SdkWarningCode.sharedRemoteElementOverwrite: SdkWarningDefinition(
      code: SdkWarningCode.sharedRemoteElementOverwrite,
      name: 'SHARED_REMOTE_ELEMENT_OVERWRITE',
      message: 'Shared remote element overwrite',
      description: 'A shared remote media element was overwritten.',
      causes: [
        'Multiple calls using the same media element',
      ],
      solutions: [
        'Use separate media elements per call',
      ],
    ),

    // ── Authentication (340xx) ─────────────────────────────────────────
    SdkWarningCode.tokenExpiringSoon: SdkWarningDefinition(
      code: SdkWarningCode.tokenExpiringSoon,
      name: 'TOKEN_EXPIRING_SOON',
      message: 'Authentication token expiring soon',
      description: 'The SIP token will expire within the next 5 minutes.',
      causes: [
        'Token TTL approaching expiry',
      ],
      solutions: [
        'Refresh the token',
      ],
    ),

    // ── Session / reconnection (350xx) ─────────────────────────────────
    SdkWarningCode.unknownReattachedSession: SdkWarningDefinition(
      code: SdkWarningCode.unknownReattachedSession,
      name: 'UNKNOWN_REATTACHED_SESSION',
      message: 'Unknown reattached session',
      description:
          'A session reattachment was received for an unknown session.',
      causes: [
        'Session ID mismatch',
        'Stale session',
      ],
      solutions: [
        'Verify session management',
      ],
    ),

    // ── Signaling health (360xx) ───────────────────────────────────────
    SdkWarningCode.signalingRecoveryRequired: SdkWarningDefinition(
      code: SdkWarningCode.signalingRecoveryRequired,
      name: 'SIGNALING_RECOVERY_REQUIRED',
      message: 'Signaling recovery required',
      description: 'The signaling connection requires recovery.',
      causes: [
        'WebSocket disconnection',
        'Network interruption',
      ],
      solutions: [
        'Wait for automatic reconnection',
        'Check network connectivity',
      ],
    ),
    SdkWarningCode.mediaRecoveryRequired: SdkWarningDefinition(
      code: SdkWarningCode.mediaRecoveryRequired,
      name: 'MEDIA_RECOVERY_REQUIRED',
      message: 'Media recovery required',
      description: 'The media connection requires recovery.',
      causes: [
        'ICE connection failure',
        'Media server issue',
      ],
      solutions: [
        'Wait for ICE restart',
        'Check network connectivity',
      ],
    ),
    SdkWarningCode.reconnectionFailedWithNoAutoReconnect: SdkWarningDefinition(
      code: SdkWarningCode.reconnectionFailedWithNoAutoReconnect,
      name: 'RECONNECTION_FAILED_WITH_NO_AUTO_RECONNECT',
      message: 'Reconnection failed and auto-reconnect is disabled',
      description:
          'Reconnection attempts failed and automatic reconnect is not enabled.',
      causes: [
        'All reconnection attempts exhausted',
        'Auto-reconnect disabled in configuration',
      ],
      solutions: [
        'Manually reconnect',
        'Enable auto-reconnect',
      ],
    ),
  };

  /// Look up the definition for [code], or `null` if not found.
  static SdkWarningDefinition? get(int code) => _definitions[code];

  /// Create a [TelnyxWarning] from a code, optionally overriding the message.
  static TelnyxWarning createWarning(
    int code, {
    String? message,
    String? callId,
    String? sessionId,
    Map<String, dynamic>? context,
  }) {
    final def = _definitions[code];
    if (def == null) {
      throw ArgumentError('Unknown warning code: $code');
    }
    return TelnyxWarning(
      code: def.code,
      name: def.name,
      message: message ?? def.message,
      description: def.description,
      causes: def.causes,
      solutions: def.solutions,
      callId: callId,
      sessionId: sessionId,
      context: context,
    );
  }
}
