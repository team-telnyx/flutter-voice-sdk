/// Warning code constants for the Telnyx WebRTC SDK.
///
/// Each code is a unique integer that identifies a specific warning condition.
class SdkWarningCode {
  SdkWarningCode._();

  // Network quality (310xx)
  /// Warning emitted when the measured round-trip time exceeds the acceptable threshold.
  static const int highRtt = 31001;

  /// Warning emitted when audio jitter rises above the acceptable threshold.
  static const int highJitter = 31002;

  /// Warning emitted when the packet-loss rate exceeds the acceptable threshold.
  static const int highPacketLoss = 31003;

  /// Warning emitted when the estimated Mean Opinion Score (MOS) drops below the acceptable threshold.
  static const int lowMos = 31004;

  /// Warning emitted when the outbound (local) audio level is too low, suggesting a muted or faulty microphone.
  static const int lowLocalAudio = 31005;

  /// Warning emitted when the inbound (remote) audio level is too low, suggesting silence from the far end.
  static const int lowInboundAudio = 31006;

  // Connection / data-flow (320xx)
  /// Warning emitted when the number of bytes received falls below the expected rate.
  static const int lowBytesReceived = 32001;

  /// Warning emitted when the number of bytes sent falls below the expected rate.
  static const int lowBytesSent = 32002;

  /// Warning emitted when call recording cannot be started or is not available.
  static const int recordingUnavailable = 32003;

  /// Warning emitted when the recording buffer overflows and audio data is dropped.
  static const int recordingBufferOverflow = 32004;

  // Call connection (330xx)
  /// Warning emitted when ICE connectivity for an established call is lost.
  static const int iceConnectivityLost = 33001;

  /// Warning emitted when ICE candidate gathering does not complete within the allotted time.
  static const int iceGatheringTimeout = 33002;

  /// Warning emitted when ICE gathering completes without producing any candidates.
  static const int iceGatheringEmpty = 33003;

  /// Warning emitted when the WebRTC peer connection enters a failed state.
  static const int peerConnectionFailed = 33004;

  /// Warning emitted when only host ICE candidates are available, indicating STUN/TURN reachability problems.
  static const int onlyHostIceCandidates = 33005;

  /// Warning emitted when an answer is received while a peer connection is already active.
  static const int answerWhilePeerActive = 33006;

  /// Warning emitted when a duplicate answer is received for an inbound call.
  static const int duplicateInboundAnswer = 33007;

  /// Warning emitted when the selected ICE candidate pair changes during a call.
  static const int iceCandidatePairChanged = 33008;

  /// Warning emitted when an audio input device change is skipped because it could not be applied.
  static const int audioInputDeviceChangeSkipped = 33009;

  /// Warning emitted when more than one active call is detected simultaneously.
  static const int multipleActiveCallsDetected = 33010;

  /// Warning emitted when a shared remote media element is overwritten by another call.
  static const int sharedRemoteElementOverwrite = 33011;

  // Authentication (340xx)
  /// Warning emitted when the authentication token is nearing expiry and should be refreshed.
  static const int tokenExpiringSoon = 34001;

  // Session / reconnection (350xx)
  /// Warning emitted when the server reattaches an unknown or unexpected session.
  static const int unknownReattachedSession = 35002;

  // Signaling health (360xx)
  /// Warning emitted when the signaling channel requires recovery to remain healthy.
  static const int signalingRecoveryRequired = 36003;

  /// Warning emitted when the media connection requires recovery to remain healthy.
  static const int mediaRecoveryRequired = 36004;

  /// Warning emitted when reconnection fails while automatic reconnection is disabled.
  static const int reconnectionFailedWithNoAutoReconnect = 36005;
}
