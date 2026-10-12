# Error Handling in the Telnyx Flutter Voice SDK

## Overview

The SDK provides structured error and warning events through two mechanisms:

1. **Callback API**: `onTelnyxError` and `onTelnyxWarning` (VSDK-415)
2. **Stream API** (planned): `client.errors` and `client.warnings` — idiomatic Dart streams that compose with `StreamBuilder`, Riverpod, or Bloc (planned for a future release)

Both mechanisms emit the same structured event objects. The callback API is available now; the stream API wraps the same emission pipeline.

## Error Model

All errors are `TelnyxError` objects with:

| Field           | Type                     | Description                                      |
|-----------------|--------------------------|--------------------------------------------------|
| `code`          | `int`                    | Numeric error code (40001–49001)                 |
| `name`          | `String`                 | Machine-readable name in UPPER_SNAKE_CASE        |
| `message`       | `String`                 | Short human-readable message for UI alerts       |
| `description`   | `String`                 | Full explanation of the error                    |
| `causes`        | `List<String>`           | Possible root causes                             |
| `solutions`     | `List<String>`           | Suggested remediation steps                      |
| `fatal`         | `bool`                   | `true` = terminal, `false` = recoverable         |
| `originalError` | `Object?`                | Underlying error that triggered this, if any     |
| `callId`        | `String?`                | Call ID this error is associated with            |
| `sessionId`     | `String?`                | Session ID this error is associated with          |
| `timestamp`     | `String?`                | ISO-8601 timestamp when the error was emitted     |
| `context`       | `Map<String, dynamic>?`  | Optional context map with extra details           |

Warnings are `TelnyxWarning` objects with the same structure minus `fatal` and `originalError`.

### Error Events

Error events come in two flavours:

- **`TelnyxErrorEvent`** — standard (non-recoverable) error. The `error` field contains the `TelnyxError`.
- **`TelnyxMediaRecoveryErrorEvent`** — recoverable media error. Provides `resume()` and `reject()` methods so the app can retry media acquisition after fixing permissions.

Use `isMediaRecoveryErrorEvent(event)` or check `event.recoverable` to discriminate.

## Migration from Legacy API

### Before (legacy)

```dart
// Old API: TelnyxSocketError with int errorCode and String errorMessage
client.onSocketErrorReceived = (TelnyxSocketError error) {
  switch (error.errorCode) {
    case -32000: // token error
      handleTokenError();
    case -32001: // credential error
      handleCredentialError();
    case -32002: // codec error
      handleCodecError();
    case -32003: // gateway timeout
    case -32004: // gateway failed
      handleGatewayError();
  }
};
```

### After (new API)

```dart
// Option A: Callback (available now)
client.onTelnyxError = (Object event) {
  if (event is TelnyxMediaRecoveryErrorEvent) {
    // Recoverable: show permission dialog, then call resume() or reject()
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Microphone Permission Needed'),
        content: Text(event.error.message),
        actions: [
          TextButton(
            child: const Text('Retry'),
            onPressed: () => event.resume(),
          ),
          TextButton(
            child: const Text('Reject'),
            onPressed: () => event.reject(),
          ),
        ],
      ),
    );
  } else if (event is TelnyxErrorEvent) {
    final error = event.error;
    print('[${error.code}] ${error.name}: ${error.message}');
    if (error.fatal) {
      showTerminalError(error);
    }
  }
};

// Option B: Stream (planned for future release)
// client.errors.listen((event) { ... });
// client.warnings.listen((event) { ... });
```

### Warnings

```dart
client.onTelnyxWarning = (TelnyxWarningEvent event) {
  final warning = event.warning;
  print('[${warning.code}] ${warning.name}: ${warning.message}');
  // Show toast, update quality indicator, etc.
  showToast(warning.message);
};
```

## Code Mapping (Legacy → Structured)

| Legacy Code | Legacy Name              | New Code | New Name                  |
|-------------|--------------------------|----------|---------------------------|
| -32000      | tokenErrorCode           | 46001    | LOGIN_FAILED              |
| -32001      | credentialErrorCode      | 46002    | INVALID_CREDENTIALS        |
| -32002      | codecError               | 49001    | UNEXPECTED_ERROR          |
| -32003      | gatewayTimeoutErrorCode  | 45004    | GATEWAY_FAILED            |
| -32004      | gatewayFailedErrorCode   | 45004    | GATEWAY_FAILED            |

> **Note:** Legacy error codes are negative integers (`-32000` range). New error codes are positive integers in category ranges (`40001`–`49001`). The legacy `TelnyxSocketError.errorCode` field has no direct 1:1 mapping for all new codes — many new error categories (SDP, media, call-control, ICE, network, session) have no legacy equivalent.

## Error Code Reference

### SDP Errors (400xx)

| Code  | Name                            | Message                              | Fatal |
|-------|---------------------------------|--------------------------------------|-------|
| 40001 | SDP_CREATE_OFFER_FAILED         | Failed to create call offer          | Yes   |
| 40002 | SDP_CREATE_ANSWER_FAILED         | Failed to answer the call            | Yes   |
| 40003 | SDP_SET_LOCAL_DESCRIPTION_FAILED| Failed to apply local call settings | Yes   |
| 40004 | SDP_SET_REMOTE_DESCRIPTION_FAILED| Failed to apply remote call settings| Yes   |
| 40005 | SDP_SEND_FAILED                  | Failed to send call data to server   | Yes   |

### Media / Device Errors (420xx)

| Code  | Name                                  | Message                    | Fatal |
|-------|---------------------------------------|----------------------------|-------|
| 42001 | MEDIA_MICROPHONE_PERMISSION_DENIED    | Microphone access denied   | Yes   |
| 42002 | MEDIA_DEVICE_NOT_FOUND                | No microphone found        | Yes   |
| 42003 | MEDIA_GET_USER_MEDIA_FAILED           | Failed to access microphone | Yes   |

### Call-Control Errors (440xx)

| Code  | Name                       | Message                    | Fatal |
|-------|----------------------------|----------------------------|-------|
| 44001 | HOLD_FAILED                | Failed to hold the call    | No    |
| 44002 | INVALID_CALL_PARAMETERS    | Invalid call parameters    | Yes   |
| 44003 | BYE_SEND_FAILED            | Failed to hang up cleanly  | No    |
| 44004 | SUBSCRIBE_FAILED           | Failed to subscribe        | No    |
| 44005 | PEER_CLOSED_DURING_INIT    | Call was closed during setup | Yes |

### WebSocket / Transport Errors (450xx)

| Code  | Name                          | Message                       | Fatal |
|-------|-------------------------------|-------------------------------|-------|
| 45001 | WEBSOCKET_CONNECTION_FAILED   | Unable to connect to server   | Yes   |
| 45002 | WEBSOCKET_ERROR               | Connection to server lost     | No    |
| 45003 | RECONNECTION_EXHAUSTED        | Unable to reconnect to server | Yes   |
| 45004 | GATEWAY_FAILED                | Gateway connection failed     | No    |

### Authentication Errors (460xx)

| Code  | Name                    | Message                        | Fatal |
|-------|-------------------------|--------------------------------|-------|
| 46001 | LOGIN_FAILED            | Authentication failed          | Yes   |
| 46002 | INVALID_CREDENTIALS     | Invalid credential parameters  | Yes   |
| 46003 | AUTHENTICATION_REQUIRED | Authentication required        | No    |

### ICE Restart Errors (470xx)

| Code  | Name               | Message          | Fatal |
|-------|--------------------|------------------|-------|
| 47001 | ICE_RESTART_FAILED | ICE restart failed | No  |

### Network Errors (480xx)

| Code  | Name            | Message          | Fatal |
|-------|-----------------|------------------|-------|
| 48001 | NETWORK_OFFLINE  | Device is offline | No   |

### Session Errors (485xx)

| Code  | Name                    | Message                          | Fatal |
|-------|-------------------------|----------------------------------|-------|
| 48501 | SESSION_NOT_REATTACHED   | Active call lost after reconnect | Yes   |

### General Errors (490xx)

| Code  | Name            | Message                    | Fatal |
|-------|-----------------|----------------------------|-------|
| 49001 | UNEXPECTED_ERROR | An unexpected error occurred | Yes |

## Warning Code Reference

### Network Quality Warnings (310xx)

| Code  | Name              | Message                              |
|-------|-------------------|--------------------------------------|
| 31001 | HIGH_RTT          | High network latency detected        |
| 31002 | HIGH_JITTER       | High jitter detected                 |
| 31003 | HIGH_PACKET_LOSS  | High packet loss detected            |
| 31004 | LOW_MOS           | Low call quality score               |
| 31005 | LOW_LOCAL_AUDIO   | Low local microphone audio detected  |
| 31006 | LOW_INBOUND_AUDIO | Low inbound audio detected           |

### Connection / Data-Flow Warnings (320xx)

| Code  | Name                       | Message                              |
|-------|----------------------------|--------------------------------------|
| 32001 | LOW_BYTES_RECEIVED         | No audio data received               |
| 32002 | LOW_BYTES_SENT             | No audio data being sent             |
| 32003 | RECORDING_UNAVAILABLE     | Call recording is not available      |
| 32004 | RECORDING_BUFFER_OVERFLOW | Call recording buffer overflow       |

### Call Connection Warnings (330xx)

| Code  | Name                             | Message                                          |
|-------|----------------------------------|--------------------------------------------------|
| 33001 | ICE_CONNECTIVITY_LOST           | Connection interrupted                           |
| 33002 | ICE_GATHERING_TIMEOUT            | ICE gathering timed out                          |
| 33003 | ICE_GATHERING_EMPTY              | No ICE candidates gathered                       |
| 33004 | PEER_CONNECTION_FAILED            | Connection failed                                |
| 33005 | ONLY_HOST_ICE_CANDIDATES         | Only local network candidates available          |
| 33006 | ANSWER_WHILE_PEER_ACTIVE         | Call answer ignored — peer already active         |
| 33007 | DUPLICATE_INBOUND_ANSWER         | Call answer ignored — another call being answered|
| 33008 | ICE_CANDIDATE_PAIR_CHANGED       | ICE candidate pair changed mid-call              |
| 33009 | AUDIO_INPUT_DEVICE_CHANGE_SKIPPED| Audio input device change skipped                |
| 33010 | MULTIPLE_ACTIVE_CALLS_DETECTED   | Multiple active calls detected                   |
| 33011 | SHARED_REMOTE_ELEMENT_OVERWRITE  | Remote media element overwritten                |

### Authentication Warnings (340xx)

| Code  | Name                  | Message                              |
|-------|-----------------------|--------------------------------------|
| 34001 | TOKEN_EXPIRING_SOON   | Authentication token expiring soon   |

### Session / Reconnection Warnings (350xx)

| Code  | Name                       | Message                              |
|-------|----------------------------|--------------------------------------|
| 35002 | UNKNOWN_REATTACHED_SESSION | Unknown reattach session after reconnect |

### Signaling Health Warnings (360xx)

| Code  | Name                                   | Message                              |
|-------|----------------------------------------|--------------------------------------|
| 36003 | SIGNALING_RECOVERY_REQUIRED            | Signaling recovery required           |
| 36004 | MEDIA_RECOVERY_REQUIRED                | Media recovery required               |
| 36005 | RECONNECTION_FAILED_WITH_NO_AUTO_RECONNECT | Reconnection failed — auto-reconnect disabled |

## Using the Registry Directly

For advanced use cases, you can look up error/warning metadata directly:

```dart
import 'package:telnyx_webrtc/model/errors/telnyx_error_codes.dart';
import 'package:telnyx_webrtc/model/errors/telnyx_error_factory.dart';
import 'package:telnyx_webrtc/model/errors/sdk_errors.dart';

// Look up a definition
final def = sdkErrors[TelnyxErrorCodes.sdpCreateOfferFailed];
print(def?.name);    // SDP_CREATE_OFFER_FAILED
print(def?.fatal);   // true

// Create a TelnyxError from a code
final error = createTelnyxError(TelnyxErrorCodes.gatewayFailed);
print(error.code);    // 45004
print(error.name);    // GATEWAY_FAILED
print(error.fatal);   // false
```

## Feature Flags

Structured error emission is controlled by `Config.enableStructuredErrors` (default: `true`). When enabled, both `onTelnyxError` and `onTelnyxWarning` fire alongside the legacy `onSocketErrorReceived`. When disabled, only the legacy callback fires.

```dart
final config = Config()
  ..enableStructuredErrors = true  // default: true
  ..enableSignalingHealthMonitor = true;
```

## Timeline

- **Phase 1 (current)**: Both legacy and new APIs work in parallel. Legacy classes are annotated `@Deprecated`.
- **Phase 2 (next minor)**: Legacy API emits deprecation warnings at runtime. Stream API (`client.errors`, `client.warnings`) added.
- **Phase 3 (v3.0.0)**: Legacy API removed. Only `TelnyxError`/`TelnyxWarning` and the stream/callback APIs remain.
