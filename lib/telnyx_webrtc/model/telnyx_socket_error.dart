class TelnyxSocketError {
  int errorCode;
  String errorMessage;

  TelnyxSocketError({required this.errorCode, required this.errorMessage});
}

class TelnyxErrorConstants {
  static const tokenError = "Token registration error";
  static const tokenErrorCode = -32000;
  static const credentialError = "Credential registration error";
  static const credentialErrorCode = -32001;
  static const gatewayTimeoutError = "Gateway registration timeout";
  static const gatewayTimeoutErrorCode = -32003;
  static const gatewayFailedError = "Gateway registration failed";
  static const gatewayFailedErrorCode = -32004;
}
