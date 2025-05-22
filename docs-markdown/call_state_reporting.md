# Call State and Termination Reason Reporting

This document explains the enhanced call state reporting and termination reason handling in the Telnyx Flutter SDK.

## Call States

The SDK uses a class-based approach to represent call states, allowing states to carry associated data. The following states are available:

- `CallState.newCall()`: The call has been created but not yet connected.
- `CallState.connecting()`: The call is being connected to the remote client.
- `CallState.ringing()`: The call invitation has been extended, we are waiting for an answer.
- `CallState.active()`: The call is active and the two clients are fully connected.
- `CallState.held()`: The user has put the call on hold.
- `CallState.reconnecting(NetworkReason reason)`: The call is being reconnected after a network issue.
- `CallState.dropped(NetworkReason reason)`: The call was dropped as a result of network issues.
- `CallState.done([CallTerminationReason? reason])`: The call is finished - either party has ended the call.
- `CallState.error()`: There was an issue creating the call.

## Network Reasons

For `reconnecting` and `dropped` states, a `NetworkReason` is provided to give more context about the network event:

- `NetworkReason.networkSwitch`: The network has been switched.
- `NetworkReason.networkLost`: The network has been lost.
- `NetworkReason.airplaneMode`: The network has adjusted due to Airplane mode.
- `NetworkReason.serverError`: A server error occurred.

## Call Termination Reasons

For the `done` state, a `CallTerminationReason` may be provided with detailed information about why the call ended:

- `cause`: General cause description (e.g., "CALL_REJECTED").
- `causeCode`: Numerical code for the cause (e.g., 21).
- `sipCode`: SIP response code (e.g., 403).
- `sipReason`: SIP reason phrase (e.g., "Dialed number is not included in whitelisted countries").

## Usage Examples

### Observing Call States

```dart
call.callHandler.onCallStateChanged = (CallState state) {
  if (state.isDone) {
    // Call has ended
    final terminationReason = state.terminationReason;
    if (terminationReason != null) {
      print('Call ended with reason: $terminationReason');
      
      // Access specific fields
      if (terminationReason.sipCode == 403) {
        print('Call was rejected: ${terminationReason.sipReason}');
      }
    } else {
      print('Call ended normally');
    }
  } else if (state.isDropped) {
    // Call was dropped due to network issues
    final networkReason = state.networkReason;
    print('Call dropped: ${networkReason?.message}');
  } else if (state.isReconnecting) {
    // Call is trying to reconnect
    final networkReason = state.networkReason;
    print('Call reconnecting: ${networkReason?.message}');
  }
};
```

### Checking Call State Type

```dart
void handleCallState(CallState state) {
  if (state is ActiveState) {
    // Call is active
  } else if (state is DoneState) {
    // Call is done, check termination reason
    final reason = state.reason;
    if (reason != null) {
      print('SIP Code: ${reason.sipCode}');
      print('Cause: ${reason.cause}');
    }
  } else if (state is DroppedState) {
    // Call was dropped, check network reason
    print('Network reason: ${state.reason.message}');
  }
}
```

## Error Handling

The SDK now includes enhanced error handling with error codes. When an error occurs, the `onSocketErrorReceived` callback will be called with a `TelnyxSocketError` object that includes:

- `errorCode`: The error code for the socket error.
- `errorMessage`: The error message for the socket error.

Common error codes include:

- `-32000`: Token registration error
- `-32001`: Credential registration error
- `-32002`: Codec error
- `-32003`: Gateway registration timeout
- `-32004`: Gateway registration failed

Example:

```dart
telnyxClient.onSocketErrorReceived = (TelnyxSocketError error) {
  print('Error code: ${error.errorCode}');
  print('Error message: ${error.errorMessage}');
  
  switch (error.errorCode) {
    case TelnyxErrorConstants.tokenErrorCode:
      // Handle token error
      break;
    case TelnyxErrorConstants.gatewayTimeoutErrorCode:
      // Handle gateway timeout
      break;
    // Handle other error codes
  }
};
```