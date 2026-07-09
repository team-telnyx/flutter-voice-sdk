/// Static constants for all SDK warning codes.
///
/// Code ranges:
/// - 310xx — Network quality warnings
/// - 320xx — Connection / data-flow warnings
/// - 330xx — Call connection warnings
/// - 340xx — Authentication warnings
/// - 350xx — Session / reconnection warnings
/// - 360xx — Signaling health warnings
class TelnyxWarningCodes {
  TelnyxWarningCodes._();

  // ── Network quality warnings (310xx) ──────────────────────────────
  static const int highRtt = 31001;
  static const int highJitter = 31002;
  static const int highPacketLoss = 31003;
  static const int lowMos = 31004;
  static const int lowLocalAudio = 31005;
  static const int lowInboundAudio = 31006;

  // ── Connection / data-flow warnings (320xx) ────────────────────────
  static const int lowBytesReceived = 32001;
  static const int lowBytesSent = 32002;
  static const int recordingUnavailable = 32003;
  static const int recordingBufferOverflow = 32004;

  // ── Call connection warnings (330xx) ───────────────────────────────
  static const int iceConnectivityLost = 33001;
  static const int iceGatheringTimeout = 33002;
  static const int iceGatheringEmpty = 33003;
  static const int peerConnectionFailed = 33004;
  static const int onlyHostIceCandidates = 33005;
  static const int answerWhilePeerActive = 33006;
  static const int duplicateInboundAnswer = 33007;
  static const int iceCandidatePairChanged = 33008;
  static const int audioInputDeviceChangeSkipped = 33009;
  static const int multipleActiveCallsDetected = 33010;
  static const int sharedRemoteElementOverwrite = 33011;

  // ── Authentication warnings (340xx) ────────────────────────────────
  static const int tokenExpiringSoon = 34001;

  // ── Session / reconnection warnings (350xx) ────────────────────────
  static const int unknownReattachedSession = 35002;

  // ── Signaling health warnings (360xx) ─────────────────────────────
  static const int signalingRecoveryRequired = 36003;
  static const int mediaRecoveryRequired = 36004;
  static const int reconnectionFailedWithNoAutoReconnect = 36005;
}
