### onSocketErrorReceived

The `onSocketErrorReceived` event handler is called when an error is received from the WebSocket connection.

```dart
typedef OnSocketErrorReceived = void Function(TelnyxSocketError message);
```

### TelnyxSocketError

This class is used to represent an error received from the Telnyx Socket. It contains an `errorCode`
which is an integer representing the error code and an `errorMessage` which is a string representing
the error message.

```dart
class TelnyxSocketError {
  int errorCode = 0;
  String errorMessage = '';

  TelnyxSocketError({required this.errorCode, required this.errorMessage});

  TelnyxSocketError.fromJson(Map<String, dynamic> json) {
    errorCode = json['code'] ?? 0;
    errorMessage = json['message'] ?? '';
  }
}
```

### Error Codes

The error code can be one of the following:

```dart
class TelnyxErrorConstants {
  static const tokenError = 'Token registration error';
  static const tokenErrorCode = -32000;
  static const credentialError = 'Credential registration error';
  static const credentialErrorCode = -32001;
  static const gatewayTimeoutError = 'Gateway registration timeout';
  static const gatewayTimeoutErrorCode = -32003;
  static const gatewayFailedError = 'Gateway registration failed';
  static const gatewayFailedErrorCode = -32004;
  static const callNotFound = 'Call not found';
}
```