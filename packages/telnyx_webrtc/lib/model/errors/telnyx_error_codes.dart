/// Static constants for all SDK error codes.
///
/// Code ranges:
/// - 400xx — SDP negotiation errors
/// - 420xx — Media / device errors
/// - 440xx — Call-control errors
/// - 450xx — WebSocket / transport errors
/// - 460xx — Authentication errors
/// - 470xx — ICE restart errors
/// - 480xx — Network errors
/// - 485xx — Session errors
/// - 490xx — General / catch-all errors
class TelnyxErrorCodes {
  TelnyxErrorCodes._();

  // ── SDP errors (400xx) ──────────────────────────────────────────────
  static const int sdpCreateOfferFailed = 40001;
  static const int sdpCreateAnswerFailed = 40002;
  static const int sdpSetLocalDescriptionFailed = 40003;
  static const int sdpSetRemoteDescriptionFailed = 40004;
  static const int sdpSendFailed = 40005;

  // ── Media errors (420xx) ────────────────────────────────────────────
  static const int mediaMicrophonePermissionDenied = 42001;
  static const int mediaDeviceNotFound = 42002;
  static const int mediaGetUserMediaFailed = 42003;

  // ── Call-control errors (440xx) ────────────────────────────────────
  static const int holdFailed = 44001;
  static const int invalidCallParameters = 44002;
  static const int byeSendFailed = 44003;
  static const int subscribeFailed = 44004;
  static const int peerClosedDuringInit = 44005;

  // ── WebSocket errors (450xx) ───────────────────────────────────────
  static const int webSocketConnectionFailed = 45001;
  static const int webSocketError = 45002;
  static const int reconnectionExhausted = 45003;
  static const int gatewayFailed = 45004;

  // ── Authentication errors (460xx) ───────────────────────────────────
  static const int loginFailed = 46001;
  static const int invalidCredentials = 46002;
  static const int authenticationRequired = 46003;

  // ── ICE restart errors (470xx) ─────────────────────────────────────
  static const int iceRestartFailed = 47001;

  // ── Network errors (480xx) ─────────────────────────────────────────
  static const int networkOffline = 48001;

  // ── Session errors (485xx) ──────────────────────────────────────────
  static const int sessionNotReattached = 48501;

  // ── General errors (490xx) ─────────────────────────────────────────
  static const int unexpectedError = 49001;
}
