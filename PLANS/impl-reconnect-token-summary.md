# VSDK-418: ReconnectTokenStore — Implementation Summary

**Date:** 2026-07-09
**Ticket:** VSDK-418
**Status:** ✅ Complete

## What was implemented

### File created

`packages/telnyx_webrtc/lib/services/reconnect_token_store.dart`

### Classes

| Class | Role |
|-------|------|
| `ReconnectTokenStore` | Static SharedPreferences-based store for reconnect token, session ID, and active-calls recovery marker |
| `StoredActiveCall` | Narrow call projection (id + customHeaders only) for persistence |
| `StoredActiveCalls` | Recovery marker containing sessionId, list of StoredActiveCall, and storedAt timestamp |

### Key APIs

- `getReconnectToken()` / `setReconnectToken()` — persist voice_sdk_id across app restarts
- `getReconnectSessionId()` / `setReconnectSessionId()` — session ID with 90s freshness window; stale entries auto-cleaned
- `isReconnectSessionIdFresh()` — boolean check for session ID freshness
- `getActiveCallsRecoveryMarker()` / `setActiveCallsRecoveryMarker()` — 15 min max age; empty calls list clears marker; malformed JSON auto-cleaned
- `clearActiveCallsRecoveryMarker()` — removes marker
- `clearAll()` — removes all stored data (token, session ID, timestamp, active calls)

### Constants

- `reconnectSessionIdMaxAgeMs` = 90,000 ms (90s) — session ID freshness
- `recoveryMarkerMaxAgeMs` = 900,000 ms (15 min) — active calls recovery marker freshness

### Storage keys

- `telnyx-voice-sdk-id` — reconnect token
- `telnyx-voice-sdk-session-id` — session ID
- `telnyx-voice-sdk-session-id-stored-at` — session ID storage timestamp
- `telnyx-voice-sdk-active-calls` — active calls recovery marker (JSON)

## Test results

```
cd ~/telnyx/flutter-voice-sdk && fvm flutter test packages/telnyx_webrtc/test/services/reconnect_token_store_test.dart
```

**35/35 tests passed** — 0 failures, 0 errors.

## Design decisions

1. **Static methods only** — matches test expectations (all calls are `ReconnectTokenStore.method()`)
2. **Stale cleanup on read** — `getReconnectSessionId()` and `getActiveCallsRecoveryMarker()` auto-remove stale/malformed entries
3. **Empty list = clear** — `setActiveCallsRecoveryMarker([], ...)` clears the marker (no point storing empty recovery data)
4. **Boundary inclusive at 90s** — `currentTime - storedAt > maxAge` means exactly 90s is still fresh
5. **No external dependencies beyond shared_preferences** — uses `dart:convert` for JSON serialization

## Not yet implemented (future tickets)

The following are stub tests in the test file marked as "Implementation test — requires TelnyxClient integration":
- Connect with stored session ID adds voice_sdk_id to URL
- Successful login stores voice_sdk_id and session ID
- Reconnect uses stored voice_sdk_id
- Disconnect clears all stored data
- App startup with recovery marker attempts reattach
- SESSION_NOT_REATTACHED error emission
- recoveredCallId on recovered calls
- Active calls marker update on call state changes
- Active calls marker cleared when all calls end

These require `TelnyxClient` integration which is outside the scope of this task.
