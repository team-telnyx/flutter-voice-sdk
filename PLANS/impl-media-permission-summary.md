# VSD-417: Media Permission Recovery — Implementation Summary

**Date:** 2026-07-09
**Ticket:** VSDK-417
**Status:** ✅ Implemented

## Overview

Implemented the media-permission recovery flow for the Flutter Voice SDK. When `getUserMedia` fails during an inbound call answer and recovery is enabled, the SDK emits a `TelnyxMediaRecoveryErrorEvent` with `resume()` and `reject()` callbacks so the app can prompt the user to fix permissions before the call fails.

## Files Created

### `lib/model/errors/media_permission_recovery.dart`
- `MediaPermissionRecovery` class — Completer-based resume/reject gate
- `MediaRecoveryResult` enum (`resumed`, `rejected`, `timedOut`, `retryFailed`)
- `start()` factory method that creates the recovery flow and starts the safety timer
- `toEvent()` method that builds `TelnyxMediaRecoveryErrorEvent`
- `resume()` / `reject()` async callbacks
- `result` future that resolves when the flow completes
- `dispose()` for cleanup

## Files Modified

### `lib/peer/peer.dart`
- Added imports for `media_error_classifier.dart`, `media_permission_recovery.dart`, `telnyx_error.dart`, `telnyx_error_event.dart`, `telnyx_error_factory.dart`
- Modified `createStream()` to accept `{bool isAnswer = false}` parameter
- Added try/catch around `getUserMedia` with recovery flow:
  - If recovery enabled AND `isAnswer == true`: classify error, create `TelnyxError` with `fatal: false`, start `MediaPermissionRecovery`, emit `TelnyxMediaRecoveryErrorEvent`, await result
  - On `resumed`: retry `getUserMedia`, call `onSuccess`
  - On `rejected`/`timedOut`/`retryFailed`: call `onError`, rethrow
  - Non-recovery path: classify error, emit `TelnyxErrorEvent`, rethrow
- Updated `_createSession` to pass `isAnswer: direction == 'inbound'` to `createStream`

### `lib/peer/session.dart`
- Added `callId` field to `Session` class (was missing)

### `lib/telnyx_client.dart`
- Added imports for `media_permissions_recovery_config.dart`, `telnyx_error.dart`, `telnyx_error_event.dart`
- Added `OnTelnyxError` typedef
- Added `onTelnyxError` callback field
- Added `_mediaPermissionsRecovery` field and `mediaPermissionsRecovery` getter
- Added `emitTelnyxError()` and `emitMediaRecoveryError()` public methods
- Wired `_mediaPermissionsRecovery` from config in `credentialLogin()` and `tokenLogin()`

### `lib/config/telnyx_config.dart`
- Added import for `media_permissions_recovery_config.dart`
- Added `mediaPermissionsRecovery` field to `Config`
- Added `super.mediaPermissionsRecovery` to `CredentialConfig` and `TokenConfig` constructors

## Test Results

All 9 tests in `media_permission_recovery_test.dart` pass. `dart analyze` is clean on all new/modified files (0 warnings, 0 errors):
1. ✅ createStream with recovery enabled and isAnswer=true emits TelnyxMediaRecoveryErrorEvent on getUserMedia failure
2. ✅ recovery disabled does not emit recoverable event — falls through to standard error handling
3. ✅ recovery enabled but isAnswer=false (outbound call) does not emit recoverable event
4. ✅ successful getUserMedia does not trigger recovery flow
5. ✅ recovery event error has fatal: false (overridden from registry default)
6. ✅ onSuccess callback called on successful resume
7. ✅ onError callback called on reject
8. ✅ onError callback called on timeout
9. ✅ onError callback called on retry failure

## Design Decisions

1. **Completer-based gate**: Used `Completer<MediaRecoveryResult>` instead of JS Promise pattern — idiomatic Dart
2. **Public emit methods**: `emitTelnyxError()` and `emitMediaRecoveryError()` on `TelnyxClient` (not private) so `Peer` can access them
3. **Session.callId**: Added `callId` to `Session` class (was missing) for recovery event construction
4. **isAnswer parameter**: Added optional `isAnswer` to `createStream()` (default `false`) — only inbound calls trigger recovery
5. **fatal: false override**: Media errors (42001-42003) default to `fatal: true` in the registry, but recovery overrides to `false`
6. **Safety timer**: `Timer` auto-completes with `timedOut` result after `config.timeout` ms

## Usage Example

```dart
final config = CredentialConfig(
  sipUser: 'user',
  sipPassword: 'pass',
  sipCallerIDName: 'Caller',
  sipCallerIDNumber: '+1234567890',
  logLevel: LogLevel.all,
  debug: true,
  mediaPermissionsRecovery: MediaPermissionsRecoveryConfig(
    enabled: true,
    timeout: 25000,
    onSuccess: () => print('Recovery succeeded!'),
    onError: (error) => print('Recovery failed: $error'),
  ),
);

client.onTelnyxError = (event) {
  if (event is TelnyxMediaRecoveryErrorEvent) {
    // Show permission dialog to user
    showPermissionDialog(
      onGrant: () => event.resume(),
      onDeny: () => event.reject(),
    );
  } else if (event is TelnyxErrorEvent) {
    // Handle standard error
    print('Error: ${event.error}');
  }
};
```
