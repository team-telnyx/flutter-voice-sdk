/// Represents an error that occurred during WebSocket communication with Telnyx.
class TelnyxSocketError {
  /// The error code for the socket error.
  int errorCode = 0;

  /// The error message for the socket error.
  String errorMessage = 'Generic error. Source unknown.';

  /// The constructor for the TelnyxSocketError.
  TelnyxSocketError({required this.errorCode, required this.errorMessage});

  /// The constructor for the TelnyxSocketError from a JSON object.
  TelnyxSocketError.fromJson(Map<String, dynamic> json) {
    errorCode = json['code'] ?? 0;
    errorMessage = json['message'] ?? '';
  }
}

/// Contains constant error messages and codes used in Telnyx WebRTC communication.
class TelnyxErrorConstants {
  /// The error message for token registration errors.
  static const tokenError = 'Token registration error';

  /// The error code for token registration errors.
  static const tokenErrorCode = -32000;

  /// The error message for credential registration errors.
  static const credentialError = 'Credential registration error';

  /// The error code for credential registration errors.
  static const credentialErrorCode = -32001;

  /// The error message for codec errors.
  static const codecError = 'Codec error';

  /// The error code for codec errors.
  static const codecErrorCode = -32002;

  /// The error message for gateway registration timeout errors.
  static const gatewayTimeoutError = 'Gateway registration timeout';

  /// The error code for gateway registration timeout errors.
  static const gatewayTimeoutErrorCode = -32003;

  /// The error message for gateway registration failed errors.
  static const gatewayFailedError = 'Gateway registration failed';

  /// The error code for gateway registration failed errors.
  static const gatewayFailedErrorCode = -32004;

  /// The error message for call not found errors.
  static const callNotFound = 'Call not found';
}
