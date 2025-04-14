This document describes the error handling mechanisms in the Telnyx WebRTC Flutter SDK, specifically focusing on when and why error events are triggered and how they are processed through the SDK.

## Error Handling Architecture

The Flutter SDK implements a structured approach to error handling through several key components:

1. **OnSocketErrorReceived Callback**: Defines a callback function that is triggered when socket errors occur
2. **TelnyxSocketError Class**: Provides a data structure for encapsulating error states
3. **TelnyxErrorConstants Class**: Defines standard error codes and messages used throughout the SDK
4. **Network Connectivity Monitoring**: Detects and handles network changes and connectivity issues
5. **Gateway State Management**: Monitors the gateway registration status and triggers errors when appropriate

## Error Scenarios

### 1. Gateway Registration Status

The SDK monitors the gateway registration status and triggers errors in the following scenarios:

- When the gateway status is "FAILED" after registration attempts
- When the gateway registration times out
- Location: `telnyx_client.dart`
- This ensures that the client is properly connected to the Telnyx network

Example:

```dart
case GatewayState.failed:
  GlobalLogger().i('GATEWAY REGISTRATION FAILED :: ${stateMessage.toString()}');
  gatewayState = GatewayState.failed;
  final error = TelnyxSocketError(
    errorCode: TelnyxErrorConstants.gatewayFailedErrorCode,
    errorMessage: TelnyxErrorConstants.gatewayFailedError,
  );
  onSocketErrorReceived(error);
```

### 2. Gateway Registration Timeout

The SDK handles gateway registration timeout:

- When the gateway registration process takes too long to complete
- Location: `telnyx_client.dart`
- This helps applications handle situations where the gateway is unreachable

Example:

```dart
GlobalLogger().i('GATEWAY REGISTRATION TIMEOUT');
final error = TelnyxSocketError(
  errorCode: TelnyxErrorConstants.gatewayTimeoutErrorCode,
  errorMessage: TelnyxErrorConstants.gatewayTimeoutError,
);
onSocketErrorReceived(error);
```

### 3. WebSocket Error Messages

The SDK handles error messages received through the WebSocket connection:

- When the server sends an error message via WebSocket
- Location: `telnyx_client.dart` - `_onMessage` method
- These errors typically indicate issues with the connection or server-side problems

Example:

```dart
if (data.toString().trim().contains('error')) {
  final errorJson = jsonEncode(data.toString());
  _logger.log(
    LogLevel.info,
    'Received WebSocket message - Contains Error :: $errorJson',
  );
  try {
    final ReceivedResult errorResult =
        ReceivedResult.fromJson(jsonDecode(data.toString()));
    onSocketErrorReceived.call(errorResult.error!);
  } on Exception catch (e) {
    GlobalLogger().e('Error parsing JSON: $e');
  }
}
```

### 4. Network Connectivity Issues

The SDK detects network connectivity problems and reports them as errors:

- When network is lost during an active session
- When network type changes (e.g., from WiFi to mobile data)
- Location: `telnyx_client.dart` - `_handleNetworkLost` method
- These errors help applications handle offline scenarios gracefully

Example:

```dart
void _handleNetworkLost() {
  for (var call in activeCalls().values) {
    call.callHandler.onCallStateChanged
        .call(CallState.dropped.withReason(NetworkReason.networkLost));
  }
}
```

## TelnyxSocketError Implementation

The `TelnyxSocketError` class provides a standardized way to handle errors throughout the SDK:

```dart
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
```

This class encapsulates:
- An error code that identifies the type of error
- An error message describing what went wrong

## Error Constants

The SDK defines standard error constants in the `TelnyxErrorConstants` class:

```dart
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

```

These constants provide consistent error reporting across the SDK.

## Call State Error Handling

The SDK uses the `CallState` enum to track the state of calls, including error states:

```dart
enum CallState {
  // Other states...
  
  /// [reconnecting] The call is reconnecting - for this state a [NetworkReason] is provided.
  reconnecting,

  /// [dropped] The call has been dropped - for this state a [NetworkReason] is provided.
  dropped,
  
  /// [error] there was an issue creating the call.
  error;
  
  // Methods to handle reasons...
}
```

When network issues occur, calls can transition to the `dropped` or `reconnecting` states with an associated `NetworkReason`:

```dart
enum NetworkReason {
  /// The network has been switched.
  networkSwitch('Network switched'),

  /// The network has been lost.
  networkLost('Network lost'),

  /// The network has adjusted due to Airplane mode.
  airplaneMode('Airplane mode enabled');

  /// The message associated with the network reason.
  final String message;

  const NetworkReason(this.message);
}
```

## Consuming Errors in Your Application

To handle errors in your application, you should implement the `onSocketErrorReceived` callback:

```dart
telnyxClient.onSocketErrorReceived = (TelnyxSocketError error) {
  // Log the error
  print('Telnyx Socket Error: ${error.errorMessage} (${error.errorCode})');

  // Handle specific error types
  switch (error.errorCode) {
    case TelnyxErrorConstants.gatewayFailedErrorCode:
      // Handle gateway registration failure
      attemptReconnection();
      break;
    case TelnyxErrorConstants.gatewayTimeoutErrorCode:
      // Handle gateway timeout
      showTimeoutMessage();
      break;
    default:
      // Handle other types of errors
      showErrorToUser(error.errorMessage);
      break;
  }
};
```

## Error Handling Best Practices

When implementing error handling for the Telnyx WebRTC Flutter SDK:

1. **Always implement the onSocketErrorReceived callback**: This is the primary channel for receiving error notifications
2. **Log errors for debugging purposes**: Capture error messages for troubleshooting
3. **Implement appropriate error recovery mechanisms**: Different errors may require different recovery strategies
4. **Display user-friendly error messages**: Translate technical error messages into user-friendly notifications
5. **Implement reconnection logic when appropriate**: For network or gateway issues, automatic reconnection may be appropriate
6. **Monitor call state changes**: Watch for `dropped`, `reconnecting`, and `error` states to handle call-specific issues

## Common Error Scenarios and Solutions

### Gateway Registration Failure

- **Cause**: Network connectivity issues or invalid credentials
- **Solution**: Check network connection and credential validity, then attempt reconnection

### Gateway Registration Timeout

- **Cause**: Server unreachable or network latency issues
- **Solution**: Implement retry mechanism with exponential backoff

### WebSocket Connection Errors

- **Cause**: Network interruption or server issues
- **Solution**: Implement automatic reconnection with exponential backoff

### Network Connectivity Changes

- **Cause**: Device switching between WiFi and mobile data, or losing connectivity
- **Solution**: Monitor network state changes and implement appropriate UI feedback and reconnection logic

## Additional Resources

- [Telnyx WebRTC Flutter SDK GitHub Repository](https://github.com/team-telnyx/flutter-voice-sdk)
- [API Documentation](https://developers.telnyx.com/docs/v2/webrtc)
