# 📞 Call State and Termination Reason Reporting

This document explains the enhanced call state reporting and termination reason handling in the Telnyx Flutter SDK using the new `enum`-based `CallState` model.

## 🔄 Call States

The SDK defines an `enum` called `CallState`, representing the lifecycle of a call:

```dart
enum CallState {
  newCall,
  connecting,
  ringing,
  active,
  held,
  reconnecting,
  dropped,
  done,
  error
}
```

### State Overview

* `CallState.newCall`: Call created, not yet connected.
* `CallState.connecting`: Attempting to connect.
* `CallState.ringing`: Waiting for an answer.
* `CallState.active`: Call is live.
* `CallState.held`: Call on hold.
* `CallState.reconnecting`: Reconnecting due to network loss.
* `CallState.dropped`: Dropped due to network failure.
* `CallState.done`: Call ended (can include termination reason).
* `CallState.error`: Call setup or runtime error.

## 🌐 Network Reasons

`CallState.reconnecting` and `CallState.dropped` can carry a `NetworkReason` using `withReason()`:

```dart
CallState.reconnecting.withReason(NetworkReason.networkLost);
```

Available reasons:

* `NetworkReason.networkSwitch`: Switched networks.
* `NetworkReason.networkLost`: Lost connectivity.
* `NetworkReason.airplaneMode`: Airplane mode triggered.
* `NetworkReason.serverError`: Backend/server issue.

To access:

```dart
final reason = callState.reason;
print(reason?.message);
```

## 📴 Call Termination Reasons

`CallState.done` can be linked to a `CallTerminationReason` explaining why the call ended.

```dart
CallTerminationReason(
  cause: 'CALL_REJECTED',
  causeCode: 21,
  sipCode: 403,
  sipReason: 'Dialed number not whitelisted'
);
```

## ✅ Usage Example

### Observing Call States

```dart
call.callHandler.onCallStateChanged = (CallState state) {
  switch (state) {
    case CallState.done:
      final reason = state.terminationReason;
      if (reason != null) {
        print('Call ended with SIP code: \${reason.sipCode}');
        print('Cause: \${reason.cause}');
      } else {
        print('Call ended normally');
      }
      break;
    case CallState.dropped:
    case CallState.reconnecting:
      print('Network issue: \${state.reason?.message}');
      break;
    default:
      break;
  }
};
```

### Checking State Flags

```dart
if (callState == CallState.active) {
  // The call is currently active
} else if (callState == CallState.done) {
  final reason = callState.terminationReason;
  // Handle termination
}
```

## 🚨 Error Handling

Socket errors from the Telnyx client are captured via:

```dart
telnyxClient.onSocketErrorReceived = (TelnyxSocketError error) {
  print('Error code: \${error.errorCode}');
  print('Message: \${error.errorMessage}');
};
```

Common error codes:

* `-32000`: Token registration failed
* `-32001`: Credential error
* `-32002`: Codec failure
* `-32003`: Gateway timeout
* `-32004`: Gateway registration failure

Use a switch block to map and handle these accordingly.
