class TelnyxSocketError {
  int errorCode = 0;
  String errorMessage = '';

  TelnyxSocketError({required this.errorCode, required this.errorMessage});

  TelnyxSocketError.fromJson(Map<String, dynamic> json) {
    errorCode = json['code'] ?? 0;
    errorMessage = json['message'] ?? '';
  }
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
  static const callNotFound = "Call not found";

}
