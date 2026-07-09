# TDD Error & Warning Parity — Test Manifest

**Date:** 2026-07-09  
**Phase:** 3 (TDD — Failing Tests Before Implementation)  
**Tickets covered:** VSDK-396, VSDK-415, VSDK-416, VSDK-417, VSDK-418

---

## Test Files Created

All test files are under `packages/telnyx_webrtc/test/`.

### VSDK-396: Typed Error/Warning Contract

| File | Group/Tests | Description |
|------|-------------|-------------|
| `model/errors/telnyx_error_test.dart` | 4 groups, 10 tests | TelnyxError class: construction, toString, toJson, Exception implementation |
| `model/errors/telnyx_warning_test.dart` | 2 groups, 4 tests | TelnyxWarning class: construction (const), toJson (no fatal field) |
| `model/errors/telnyx_error_event_test.dart` | 3 groups, 9 tests | TelnyxErrorEvent (recoverable=false), TelnyxMediaRecoveryErrorEvent (recoverable=true, resume/reject), isMediaRecoveryErrorEvent type guard |
| `model/errors/telnyx_warning_event_test.dart` | 1 group, 7 tests | TelnyxWarningEvent: construction with warning, reason, source (probe/request/peer_failure/no_rtp), sessionId, callId |
| `model/errors/request_timeout_error_test.dart` | 2 groups, 7 tests | RequestTimeoutError (requestId, timeoutMs, method, toString), StaleRequestError (requestId, staleGeneration, currentGeneration, toString) |

### VSDK-415: Error/Warning Registries

| File | Group/Tests | Description |
|------|-------------|-------------|
| `model/errors/telnyx_error_codes_test.dart` | 10 groups, 27 tests | All 24 error code constants, registry completeness (every code in sdkErrors, uniqueness, count=24) |
| `model/errors/telnyx_warning_codes_test.dart` | 8 groups, 30 tests | All 26 warning code constants, registry completeness (every code in sdkWarnings, uniqueness, count=26) |
| `model/errors/sdk_errors_test.dart` | 3 groups, 19 tests | 24 entries, non-empty fields, fatal flag correctness per code, code range coverage (400xx-490xx) |
| `model/errors/sdk_warnings_test.dart` | 2 groups, 12 tests | 26 entries, non-empty fields, code range coverage (310xx-360xx) |
| `model/errors/telnyx_error_factory_test.dart` | 1 group, 12 tests | createTelnyxError: registry lookup, ArgumentError for unknown, message/fatal override, originalError wrapping |
| `model/errors/telnyx_warning_factory_test.dart` | 1 group, 7 tests | createTelnyxWarning: registry lookup, ArgumentError for unknown, message override |
| `model/errors/media_error_classifier_test.dart` | 3 groups, 9 tests | classifyMediaErrorCode: PlatformException (permission→42001, NotFound→42002, generic→42003), string matching, null/generic → 42003 |

### VSDK-416: SignalingHealthMonitor

| File | Group/Tests | Description |
|------|-------------|-------------|
| `services/signaling_health_monitor_test.dart` | 7 groups, 20+ tests | start/stop lifecycle (idempotent), isProbeInFlight, isCriticalMethod (Modify/Bye/Ping vs Info), onRequestTimeout (critical→recovery, non-critical→no-op), onPeerFailure (healthy→ICE restart, unknown→probe), onNoRtp (healthy→ICE restart, unknown→probe), onIceRestartFailed→socket reconnect, recovery decision authority (never mix paths) |

### VSDK-417: Media Permission Recovery

| File | Group/Tests | Description |
|------|-------------|-------------|
| `model/errors/media_permissions_recovery_config_test.dart` | 2 groups, 9 tests | MediaPermissionsRecoveryConfig construction, enabled/disabled, timeout, optional callbacks, recovery flow Completer/resume/reject/timeout behavior |
| `peer/media_permission_recovery_test.dart` | 1 group, 9 tests | Peer.createStream integration: recovery enabled+isAnswer→emit TelnyxMediaRecoveryErrorEvent, disabled→standard error, outbound→no recovery, successful getUserMedia→no recovery, fatal=false override, onSuccess/onError callbacks |

### VSDK-418: Reconnect Token / Session Persistence

| File | Group/Tests | Description |
|------|-------------|-------------|
| `services/reconnect_token_store_test.dart` | 5 groups, 28+ tests | ReconnectTokenStore: set/get token, session ID freshness (90s threshold, 89s fresh, 91s stale), isReconnectSessionIdFresh, clearAll, active calls marker (store, retrieve, stale >15min, empty list clears), StoredActiveCall/StoredActiveCalls toJson/fromJson roundtrip, session recovery integration contracts |

---

## Summary

| Metric | Count |
|--------|-------|
| **Total test files** | 14 |
| **Total test groups** | ~40 |
| **Total individual tests** | ~170 |
| **Tickets covered** | 5 (VSDK-396, 415, 416, 417, 418) |
| **All tests are FAILING** | ✅ (reference classes/methods that don't exist yet) |

## File Tree

```
test/
├── model/
│   └── errors/
│       ├── telnyx_error_test.dart                 (VSDK-396)
│       ├── telnyx_warning_test.dart               (VSDK-396)
│       ├── telnyx_error_event_test.dart           (VSDK-396)
│       ├── telnyx_warning_event_test.dart          (VSDK-396)
│       ├── request_timeout_error_test.dart        (VSDK-396)
│       ├── telnyx_error_codes_test.dart           (VSDK-415)
│       ├── telnyx_warning_codes_test.dart         (VSDK-415)
│       ├── sdk_errors_test.dart                   (VSDK-415)
│       ├── sdk_warnings_test.dart                 (VSDK-415)
│       ├── telnyx_error_factory_test.dart         (VSDK-415)
│       ├── telnyx_warning_factory_test.dart       (VSDK-415)
│       ├── media_error_classifier_test.dart       (VSDK-415)
│       └── media_permissions_recovery_config_test.dart  (VSDK-417)
├── services/
│   ├── signaling_health_monitor_test.dart         (VSDK-416)
│   └── reconnect_token_store_test.dart            (VSDK-418)
├── peer/
│   └── media_permission_recovery_test.dart        (VSDK-417)
```

## Dependencies Required (not yet in pubspec.yaml)

- `shared_preferences` — already in pubspec.yaml ✅
- `mockito` — already in dev_dependencies ✅
- No additional packages needed — tests use existing dependencies

## Implementation Order

Tests are designed to pass only when the implementation matches the plan:

1. **VSDK-396** — Create `lib/model/errors/` types (TelnyxError, TelnyxWarning, events, RequestTimeoutError)
2. **VSDK-415** — Create registries (`sdkErrors`, `sdkWarnings`, TelnyxErrorCodes, TelnyxWarningCodes, factories, classifier)
3. **VSDK-416** — Create `lib/services/signaling_health_monitor.dart` (SignalingHealthMonitor, ISignalingHealthSession)
4. **VSDK-417** — Create `lib/model/errors/media_permissions_recovery_config.dart`, modify `lib/peer/peer.dart`
5. **VSDK-418** — Create `lib/services/reconnect_token_store.dart`, modify `lib/telnyx_client.dart`

---

*Generated by Phase 3 TDD Agent on 2026-07-09*
