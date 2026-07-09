/// Error code constants for the Telnyx WebRTC SDK.
///
/// Each code is a unique integer that identifies a specific error condition.
class SdkErrorCode {
  SdkErrorCode._();

  // SDP errors (400xx)
  /// The SDK failed to create an SDP offer for the call.
  static const int sdpCreateOfferFailed = 40001;

  /// The SDK failed to create an SDP answer for the call.
  static const int sdpCreateAnswerFailed = 40002;

  /// The SDK failed to apply the local SDP description to the peer connection.
  static const int sdpSetLocalDescriptionFailed = 40003;

  /// The SDK failed to apply the remote SDP description to the peer connection.
  static const int sdpSetRemoteDescriptionFailed = 40004;

  /// The SDK failed to send the SDP offer/answer to the remote party.
  static const int sdpSendFailed = 40005;

  // Media / device errors (420xx)
  /// The user denied the microphone permission required for the call.
  static const int mediaMicrophonePermissionDenied = 42001;

  /// No audio input device could be found.
  static const int mediaDeviceNotFound = 42002;

  /// The 'getUserMedia()' call failed to acquire the audio stream.
  static const int mediaGetUserMediaFailed = 42003;

  // Call-control errors (440xx)
  /// The SDK failed to place the call on hold.
  static const int holdFailed = 44001;

  /// One or more supplied call parameters were invalid.
  static const int invalidCallParameters = 44002;

  /// The SDK failed to send the BYE message to hang up the call.
  static const int byeSendFailed = 44003;

  /// The SDK failed to subscribe to the SIP events.
  static const int subscribeFailed = 44004;

  /// The peer connection was closed before the call was fully established.
  static const int peerClosedDuringInit = 44005;

  // WebSocket / transport errors (450xx)
  /// The WebSocket connection to the Telnyx server could not be established.
  static const int websocketConnectionFailed = 45001;

  /// A WebSocket-level error occurred.
  static const int websocketError = 45002;

  /// All reconnection attempts to the server were exhausted.
  static const int reconnectionExhausted = 45003;

  /// The Telnyx gateway returned a failure.
  static const int gatewayFailed = 45004;

  // Authentication errors (460xx)
  /// The login attempt to the Telnyx server failed.
  static const int loginFailed = 46001;

  /// The provided SIP credentials are invalid.
  static const int invalidCredentials = 46002;

  /// Authentication is required but was not provided.
  static const int authenticationRequired = 46003;

  // ICE restart errors (470xx)
  /// An ICE restart attempt failed.
  static const int iceRestartFailed = 47001;

  // Network errors (480xx)
  /// The device has no network connectivity.
  static const int networkOffline = 48001;

  // Session errors (485xx)
  /// A session reattachment attempt failed.
  static const int sessionNotReattached = 48501;

  // General / catch-all (490xx)
  /// An unexpected, uncategorised error occurred.
  static const int unexpectedError = 49001;
}
