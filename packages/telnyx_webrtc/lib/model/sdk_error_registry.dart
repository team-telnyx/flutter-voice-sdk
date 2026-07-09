import 'package:telnyx_webrtc/model/sdk_error_codes.dart';
import 'package:telnyx_webrtc/model/telnyx_error.dart';

/// Definition record for a single SDK error code.
class SdkErrorDefinition {
  /// The unique integer code identifying this error.
  final int code;

  /// The stable, machine-readable name of the error (e.g. 'SDP_SEND_FAILED').
  final String name;

  /// A short, human-readable summary of the error.
  final String message;

  /// A longer explanation of what the error represents.
  final String description;

  /// The likely causes that can trigger this error.
  final List<String> causes;

  /// Suggested steps to resolve or recover from the error.
  final List<String> solutions;

  /// Whether this error is fatal to the call or session.
  final bool fatal;

  /// Creates a definition describing a single SDK error code.
  const SdkErrorDefinition({
    required this.code,
    required this.name,
    required this.message,
    required this.description,
    required this.causes,
    required this.solutions,
    required this.fatal,
  });
}

/// Registry of all known SDK error codes and their metadata.
class SdkErrorRegistry {
  SdkErrorRegistry._();

  static const Map<int, SdkErrorDefinition> _definitions = {
    // ── SDP errors (400xx) ──────────────────────────────────────────────
    SdkErrorCode.sdpCreateOfferFailed: SdkErrorDefinition(
      code: SdkErrorCode.sdpCreateOfferFailed,
      name: 'SDP_CREATE_OFFER_FAILED',
      message: 'Failed to create SDP offer',
      description: 'The SDK could not create an SDP offer for the call.',
      causes: [
        'Peer connection not initialised',
        'Codec negotiation failure',
        'Internal WebRTC error',
      ],
      solutions: [
        'Restart the call',
        'Check peer connection state',
      ],
      fatal: true,
    ),
    SdkErrorCode.sdpCreateAnswerFailed: SdkErrorDefinition(
      code: SdkErrorCode.sdpCreateAnswerFailed,
      name: 'SDP_CREATE_ANSWER_FAILED',
      message: 'Failed to create SDP answer',
      description: 'The SDK could not create an SDP answer for the call.',
      causes: [
        'Peer connection not initialised',
        'Codec negotiation failure',
        'Invalid remote SDP',
      ],
      solutions: [
        'Restart the call',
        'Verify the remote SDP is valid',
      ],
      fatal: true,
    ),
    SdkErrorCode.sdpSetLocalDescriptionFailed: SdkErrorDefinition(
      code: SdkErrorCode.sdpSetLocalDescriptionFailed,
      name: 'SDP_SET_LOCAL_DESCRIPTION_FAILED',
      message: 'Failed to set local SDP description',
      description:
          'The SDK could not apply the local SDP description to the peer connection.',
      causes: [
        'Invalid SDP',
        'Peer connection in wrong state',
      ],
      solutions: [
        'Restart the call',
        'Check peer connection state',
      ],
      fatal: true,
    ),
    SdkErrorCode.sdpSetRemoteDescriptionFailed: SdkErrorDefinition(
      code: SdkErrorCode.sdpSetRemoteDescriptionFailed,
      name: 'SDP_SET_REMOTE_DESCRIPTION_FAILED',
      message: 'Failed to set remote SDP description',
      description:
          'The SDK could not apply the remote SDP description to the peer connection.',
      causes: [
        'Invalid remote SDP',
        'Peer connection in wrong state',
      ],
      solutions: [
        'Restart the call',
        'Verify the remote SDP is valid',
      ],
      fatal: true,
    ),
    SdkErrorCode.sdpSendFailed: SdkErrorDefinition(
      code: SdkErrorCode.sdpSendFailed,
      name: 'SDP_SEND_FAILED',
      message: 'Failed to send SDP',
      description:
          'The SDK could not send the SDP offer/answer to the remote party.',
      causes: [
        'WebSocket not connected',
        'Message serialisation failure',
      ],
      solutions: [
        'Check WebSocket connection',
        'Retry the call',
      ],
      fatal: true,
    ),

    // ── Media / device errors (420xx) ───────────────────────────────────
    SdkErrorCode.mediaMicrophonePermissionDenied: SdkErrorDefinition(
      code: SdkErrorCode.mediaMicrophonePermissionDenied,
      name: 'MEDIA_MICROPHONE_PERMISSION_DENIED',
      message: 'Microphone permission denied',
      description: 'The user denied microphone access required for the call.',
      causes: [
        'OS permission not granted',
        'User denied the permission prompt',
      ],
      solutions: [
        'Grant microphone permission in OS settings',
        'Retry the call',
      ],
      fatal: true,
    ),
    SdkErrorCode.mediaDeviceNotFound: SdkErrorDefinition(
      code: SdkErrorCode.mediaDeviceNotFound,
      name: 'MEDIA_DEVICE_NOT_FOUND',
      message: 'Media device not found',
      description: 'No audio input device was found.',
      causes: [
        'No microphone connected',
        'Device disconnected during call',
      ],
      solutions: [
        'Connect a microphone',
        'Restart the call',
      ],
      fatal: true,
    ),
    SdkErrorCode.mediaGetUserMediaFailed: SdkErrorDefinition(
      code: SdkErrorCode.mediaGetUserMediaFailed,
      name: 'MEDIA_GET_USER_MEDIA_FAILED',
      message: 'Failed to access media devices',
      description: 'getUserMedia() failed to acquire audio.',
      causes: [
        'Hardware error',
        'Permission issue',
        'Device in use by another app',
      ],
      solutions: [
        'Close other apps using the microphone',
        'Restart the device',
      ],
      fatal: true,
    ),

    // ── Call-control errors (440xx) ────────────────────────────────────
    SdkErrorCode.holdFailed: SdkErrorDefinition(
      code: SdkErrorCode.holdFailed,
      name: 'HOLD_FAILED',
      message: 'Failed to hold call',
      description: 'The SDK could not place the call on hold.',
      causes: [
        'Peer connection issue',
        'SDP renegotiation failure',
      ],
      solutions: [
        'Retry the hold operation',
      ],
      fatal: false,
    ),
    SdkErrorCode.invalidCallParameters: SdkErrorDefinition(
      code: SdkErrorCode.invalidCallParameters,
      name: 'INVALID_CALL_PARAMETERS',
      message: 'Invalid call parameters',
      description: 'One or more call parameters were invalid.',
      causes: [
        'Missing required parameter',
        'Invalid value',
      ],
      solutions: [
        'Verify call parameters',
      ],
      fatal: false,
    ),
    SdkErrorCode.byeSendFailed: SdkErrorDefinition(
      code: SdkErrorCode.byeSendFailed,
      name: 'BYE_SEND_FAILED',
      message: 'Failed to send BYE',
      description:
          'The SDK could not send the BYE message to hang up the call.',
      causes: [
        'WebSocket not connected',
        'Message serialisation failure',
      ],
      solutions: [
        'Check WebSocket connection',
      ],
      fatal: false,
    ),
    SdkErrorCode.subscribeFailed: SdkErrorDefinition(
      code: SdkErrorCode.subscribeFailed,
      name: 'SUBSCRIBE_FAILED',
      message: 'Failed to subscribe',
      description: 'The SDK could not subscribe to the SIP events.',
      causes: [
        'WebSocket not connected',
        'Authentication issue',
      ],
      solutions: [
        'Check credentials and connection',
      ],
      fatal: false,
    ),
    SdkErrorCode.peerClosedDuringInit: SdkErrorDefinition(
      code: SdkErrorCode.peerClosedDuringInit,
      name: 'PEER_CLOSED_DURING_INIT',
      message: 'Peer closed during initialization',
      description:
          'The peer connection was closed before the call was fully established.',
      causes: [
        'Remote party hung up early',
        'Network issue',
      ],
      solutions: [
        'Retry the call',
      ],
      fatal: true,
    ),

    // ── WebSocket / transport errors (450xx) ────────────────────────────
    SdkErrorCode.websocketConnectionFailed: SdkErrorDefinition(
      code: SdkErrorCode.websocketConnectionFailed,
      name: 'WEBSOCKET_CONNECTION_FAILED',
      message: 'Unable to connect to server',
      description:
          'The WebSocket connection to the Telnyx server could not be established.',
      causes: [
        'Network offline',
        'Server unreachable',
        'Invalid server URL',
      ],
      solutions: [
        'Check network connectivity',
        'Verify server URL',
        'Retry',
      ],
      fatal: true,
    ),
    SdkErrorCode.websocketError: SdkErrorDefinition(
      code: SdkErrorCode.websocketError,
      name: 'WEBSOCKET_ERROR',
      message: 'WebSocket error',
      description: 'A WebSocket-level error occurred.',
      causes: [
        'Network disruption',
        'Server-side error',
      ],
      solutions: [
        'Check network connectivity',
        'Retry',
      ],
      fatal: true,
    ),
    SdkErrorCode.reconnectionExhausted: SdkErrorDefinition(
      code: SdkErrorCode.reconnectionExhausted,
      name: 'RECONNECTION_EXHAUSTED',
      message: 'Unable to reconnect to server',
      description: 'All reconnection attempts have been exhausted.',
      causes: [
        'Persistent network issue',
        'Server unavailable',
      ],
      solutions: [
        'Check network connectivity',
        'Retry later',
      ],
      fatal: true,
    ),
    SdkErrorCode.gatewayFailed: SdkErrorDefinition(
      code: SdkErrorCode.gatewayFailed,
      name: 'GATEWAY_FAILED',
      message: 'Gateway failure',
      description: 'The Telnyx gateway returned a failure.',
      causes: [
        'Server-side issue',
        'Configuration error',
      ],
      solutions: [
        'Retry',
        'Contact support',
      ],
      fatal: true,
    ),

    // ── Authentication errors (460xx) ───────────────────────────────────
    SdkErrorCode.loginFailed: SdkErrorDefinition(
      code: SdkErrorCode.loginFailed,
      name: 'LOGIN_FAILED',
      message: 'Login failed',
      description: 'The login attempt to the Telnyx server failed.',
      causes: [
        'Invalid credentials',
        'Server issue',
      ],
      solutions: [
        'Verify credentials',
        'Retry',
      ],
      fatal: true,
    ),
    SdkErrorCode.invalidCredentials: SdkErrorDefinition(
      code: SdkErrorCode.invalidCredentials,
      name: 'INVALID_CREDENTIALS',
      message: 'Invalid credentials',
      description: 'The provided SIP credentials are invalid.',
      causes: [
        'Wrong SIP user or password',
        'Expired token',
      ],
      solutions: [
        'Verify SIP credentials',
        'Refresh token',
      ],
      fatal: true,
    ),
    SdkErrorCode.authenticationRequired: SdkErrorDefinition(
      code: SdkErrorCode.authenticationRequired,
      name: 'AUTHENTICATION_REQUIRED',
      message: 'Authentication required',
      description: 'Authentication is required but was not provided.',
      causes: [
        'No token or credentials set',
        'Token expired',
      ],
      solutions: [
        'Provide valid credentials or token',
      ],
      fatal: true,
    ),

    // ── ICE restart errors (470xx) ─────────────────────────────────────
    SdkErrorCode.iceRestartFailed: SdkErrorDefinition(
      code: SdkErrorCode.iceRestartFailed,
      name: 'ICE_RESTART_FAILED',
      message: 'ICE restart failed',
      description: 'An ICE restart attempt failed.',
      causes: [
        'Peer connection issue',
        'Network issue',
      ],
      solutions: [
        'Restart the call',
      ],
      fatal: true,
    ),

    // ── Network errors (480xx) ─────────────────────────────────────────
    SdkErrorCode.networkOffline: SdkErrorDefinition(
      code: SdkErrorCode.networkOffline,
      name: 'NETWORK_OFFLINE',
      message: 'Network offline',
      description: 'The device has no network connectivity.',
      causes: [
        'No Wi-Fi or cellular connection',
        'Airplane mode',
      ],
      solutions: [
        'Check network connectivity',
      ],
      fatal: true,
    ),

    // ── Session errors (485xx) ─────────────────────────────────────────
    SdkErrorCode.sessionNotReattached: SdkErrorDefinition(
      code: SdkErrorCode.sessionNotReattached,
      name: 'SESSION_NOT_REATTACHED',
      message: 'Session was not reattached',
      description: 'A session reattachment attempt failed.',
      causes: [
        'Session ID invalid',
        'Server issue',
      ],
      solutions: [
        'Start a new session',
      ],
      fatal: true,
    ),

    // ── General / catch-all (490xx) ────────────────────────────────────
    SdkErrorCode.unexpectedError: SdkErrorDefinition(
      code: SdkErrorCode.unexpectedError,
      name: 'UNEXPECTED_ERROR',
      message: 'Unexpected error',
      description: 'An unexpected error occurred.',
      causes: [
        'Internal SDK error',
      ],
      solutions: [
        'Restart the call',
        'Contact support',
      ],
      fatal: true,
    ),
  };

  /// Look up the definition for [code], or `null` if not found.
  static SdkErrorDefinition? get(int code) => _definitions[code];

  /// Create a [TelnyxError] from a code, optionally overriding the fatal flag.
  static TelnyxError createError(
    int code, {
    bool? fatalOverride,
    String? callId,
    String? sessionId,
    Map<String, dynamic>? context,
  }) {
    final def = _definitions[code];
    if (def == null) {
      throw ArgumentError('Unknown error code: $code');
    }
    return TelnyxError(
      code: def.code,
      name: def.name,
      message: def.message,
      description: def.description,
      causes: def.causes,
      solutions: def.solutions,
      fatal: fatalOverride ?? def.fatal,
      callId: callId,
      sessionId: sessionId,
      context: context,
    );
  }
}
