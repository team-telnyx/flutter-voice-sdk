# Flutter Structured Error & Warning Parity — Implementation Plan

**Date:** 2026-07-09
**Author:** Phase 2 Planning Agent
**Tickets:** VSDK-395, VSDK-396, VSDK-397, VSDK-415, VSDK-416, VSDK-417, VSDK-418
**Reference:** JS SDK at `~/telnyx/webrtc/packages/js/src/`
**Target:** Flutter SDK at `~/telnyx/flutter-voice-sdk/packages/telnyx_webrtc/lib/`

---

## Guru API Note

Guru API token (`GURU_API_TOKEN`) returned HTTP 401 on all search queries (flutter+sdk+error, webrtc+sdk, telnyx+error+handling, signaling+health+reconnect). The token appears expired. No Guru reference docs were retrievable. This plan is based entirely on source code analysis of the JS and Flutter SDKs.

---

## Dependency Graph

```
VSDK-395 (Audit) ──────────────────────────────────────────┐
                                                           │
VSDK-396 (Typed Error/Warning Contract) ──────────────────►│
                                                           │
VSDK-397 (Native Mapping & Rollout) ───────────────────────►│
                                                           ▼
VSDK-415 (Error/Warning Registry) ◄── depends on 396 ──►  Foundation
                                                           │
VSDK-416 (SignalingHealthMonitor) ◄── depends on 415 ──►  Recovery Authority
                                                           │
VSDK-417 (Media Permission Recovery) ◄── depends on 415 ──►  Call Recovery
                                                           │
VSDK-418 (Reconnect Token/Session Persistence) ◄── depends on 415, 416 ──►  Session Recovery
```

**Execution order:**
1. VSDK-395 (audit — research/output is this plan + confirmation)
2. VSDK-396 (contract — Dart interfaces/abstract classes, no impl)
3. VSDK-397 (native mapping strategy — design doc + platform channel plan)
4. VSDK-415 (registry impl — concrete error/warning code maps, factory, event emission)
5. VSDK-416 (SignalingHealthMonitor impl — depends on 415 for warning codes)
6. VSDK-417 (media permission recovery — depends on 415 for error codes)
7. VSDK-418 (reconnect token — depends on 415 + 416 for recovery flow integration)

---

## VSDK-395: Audit Current Flutter Error Surface & Native Dependency Model

### What needs to be done

This is primarily a research/audit ticket. The output is a documented inventory of:

1. **All current error paths in the Flutter SDK** — every `throw`, every `catch`, every error callback, every `TelnyxSocketError` usage
2. **All native dependencies** — `flutter_webrtc`, `connectivity_plus`, `shared_preferences`, `web_socket_channel` — their error surfaces and how they propagate
3. **Gap mapping** — current Flutter error codes vs JS SDK error codes (already done in GAP_ANALYSIS.md, this ticket formalizes it)

### Specific deliverables

- **File:** `docs/error-audit.md` — comprehensive audit document
- Inventory table: every file that handles errors, what errors it handles, and what it emits
- Native dependency error surface table: each dependency, its error types, how they're currently mapped (or not)
- Confirmation that the GAP_ANALYSIS.md findings are accurate

### Current Flutter Error Surface (from source analysis)

**Current error handling files:**

| File | Role | Error Types | Status |
|------|------|-------------|--------|
| `model/telnyx_socket_error.dart` | `TelnyxSocketError` class + `TelnyxErrorConstants` (5 codes) | `int errorCode` + `String errorMessage` | Minimal — no structured metadata |
| `telnyx_client.dart` | Login errors, WebSocket errors, reconnection errors | `TelnyxSocketError` via `onSocketErrorReceived` | No structured codes, no `fatal` flag, no `causes`/`solutions` |
| `peer/peer.dart` | SDP errors, ICE errors, media errors | Bare `throw Exception(...)` | No error codes at all |
| `tx_socket.dart` | WebSocket connection errors | `onClose` callback with code + reason | No structured mapping |

**Current error codes (TelnyxErrorConstants):**

| Constant | Code | Description |
|----------|------|-------------|
| `tokenErrorCode` | -32000 | Token registration error |
| `credentialErrorCode` | -32001 | Credential registration error |
| `codecErrorCode` | -32002 | Codec error |
| `gatewayTimeoutErrorCode` | -32003 | Gateway registration timeout |
| `gatewayFailedErrorCode` | -32004 | Gateway registration failed |

These are JSON-RPC error codes from the server, not SDK-level error codes. They don't map to the JS SDK's structured error system (400xx–490xx).

**Native dependency error surfaces:**

| Dependency | Error Type | How Currently Handled |
|------------|------------|----------------------|
| `flutter_webrtc` | `PlatformException` in `getUserMedia` | Uncaught — propagates as generic `Exception` |
| `flutter_webrtc` | `RTCPeerConnection` state failures | Logged, no structured error emitted |
| `connectivity_plus` | `ConnectivityResult.none` | Triggers `_handleNetworkLost()` → reconnection |
| `shared_preferences` | `SharedPreferences.getInstance()` failure | Not handled (assumed always available) |
| `dart:io WebSocket` | `WebSocketException` | Caught in `TxSocket`, passed to `onClose` callback |

### How the JS SDK is organized (reference)

| Component | JS File | Flutter Equivalent |
|-----------|---------|-------------------|
| Error class | `Modules/Verto/util/errors.ts` → `TelnyxError` | `model/telnyx_socket_error.dart` → `TelnyxSocketError` (minimal) |
| Error code constants | `Modules/Verto/util/constants/errorCodes.ts` → `TELNYX_ERROR_CODES` | `model/telnyx_socket_error.dart` → `TelnyxErrorConstants` (5 JSON-RPC codes only) |
| Error definitions | `Modules/Verto/util/constants/errors.ts` → `SDK_ERRORS` (24 entries) | None |
| Warning constants | `Modules/Verto/util/constants/warnings.ts` → `TELNYX_WARNING_CODES`, `SDK_WARNINGS` (26 entries) | None |
| Error factory | `Modules/Verto/util/errors.ts` → `createTelnyxError()` | None |
| Warning factory | `Modules/Verto/util/constants/warnings.ts` → `createTelnyxWarning()` | None |
| Request timeout | `Modules/Verto/util/errors.ts` → `RequestTimeoutError` | None |
| Stale request | `Modules/Verto/util/errors.ts` → `StaleRequestError` | None |
| Media error classifier | `Modules/Verto/util/errors.ts` → `classifyMediaErrorCode()` | None |
| Health monitor | `Modules/Verto/services/SignalingHealthMonitor.ts` | None |
| Reconnect token | `Modules/Verto/util/reconnect.ts` | `utils/preference_storage.dart` (push metadata only, no session reattachment) |

### Flutter-specific considerations

- Flutter uses callback-based pattern (`onSocketErrorReceived`, `onConnectionStateChanged`) not event emitter (`trigger(SwEvent.Error, ...)`)
- No `Stream`-based event bus exists — **recommendation:** add typed error/warning callback API (`onTelnyxError`, `onTelnyxWarning`) alongside existing callbacks, rather than introducing an event bus (minimizes API surface change, matches existing pattern)
- `TelnyxSocketError` and `TelnyxErrorConstants` should remain for backward compat during transition

### Test plan (for Phase 3 TDD)

- No direct tests — this is an audit ticket
- The audit document should be reviewed and confirmed accurate

---

## VSDK-396: Define Flutter Typed Error/Warning Contract

### What needs to be built

Dart interfaces (classes/typedefs) that define the error and warning contract. **No implementation** — just the types. This is the API contract that VSDK-415 implements.

### Files to create

#### `lib/model/errors/telnyx_error.dart`

```dart
/// Structured error class matching JS SDK's `TelnyxError`.
class TelnyxError implements Exception {
  final int code;
  final String name;
  final String message;
  final String description;
  final List<String> causes;
  final List<String> solutions;
  final Object? originalError;
  final bool fatal;

  TelnyxError({
    required this.code,
    required this.name,
    required this.message,
    required this.description,
    required this.causes,
    required this.solutions,
    this.originalError,
    required this.fatal,
  });

  @override
  String toString() => '[$code] $name: $message';

  Map<String, dynamic> toJson() => {
    'code': code, 'name': name, 'message': message,
    'description': description, 'causes': causes, 'solutions': solutions,
    'fatal': fatal,
    if (originalError != null) 'originalError': originalError.toString(),
  };
}
```

#### `lib/model/errors/telnyx_warning.dart`

```dart
/// Structured warning matching JS SDK's `ITelnyxWarning`.
class TelnyxWarning {
  final int code;
  final String name;
  final String message;
  final String description;
  final List<String> causes;
  final List<String> solutions;

  const TelnyxWarning({
    required this.code, required this.name, required this.message,
    required this.description, required this.causes, required this.solutions,
  });

  Map<String, dynamic> toJson() => {
    'code': code, 'name': name, 'message': message,
    'description': description, 'causes': causes, 'solutions': solutions,
  };
}
```

#### `lib/model/errors/telnyx_error_event.dart`

```dart
/// Standard (non-recoverable) error event.
class TelnyxErrorEvent {
  final TelnyxError error;
  final String sessionId;
  final String? callId;
  final bool recoverable = false;

  const TelnyxErrorEvent({required this.error, required this.sessionId, this.callId});
}

/// Media recovery error event — emitted when getUserMedia fails during
/// inbound call answer and mediaPermissionsRecovery is enabled.
class TelnyxMediaRecoveryErrorEvent {
  final TelnyxError error;
  final String sessionId;
  final String callId;
  final bool recoverable = true;
  final int retryDeadline;
  final Future<void> Function() resume;
  final Future<void> Function() reject;

  const TelnyxMediaRecoveryErrorEvent({
    required this.error, required this.sessionId, required this.callId,
    required this.retryDeadline, required this.resume, required this.reject,
  });
}

/// Type guard for media recovery events.
bool isMediaRecoveryErrorEvent(Object event) => event is TelnyxMediaRecoveryErrorEvent;
```

#### `lib/model/errors/telnyx_warning_event.dart`

```dart
/// Warning event emitted via `onTelnyxWarning`.
class TelnyxWarningEvent {
  final TelnyxWarning warning;
  final String? reason;
  final String? source; // 'probe', 'request', 'peer_failure', 'no_rtp'
  final String sessionId;
  final String? callId;

  const TelnyxWarningEvent({
    required this.warning, this.reason, this.source,
    required this.sessionId, this.callId,
  });
}
```

#### `lib/model/errors/request_timeout_error.dart`

```dart
/// Indicates a signaling request timed out waiting for a server response.
class RequestTimeoutError implements Exception {
  final String requestId;
  final int timeoutMs;
  final String method;

  RequestTimeoutError(this.requestId, this.timeoutMs, [this.method = '']);

  @override
  String toString() =>
    'Signaling request timed out (id=$requestId, method=${method.isEmpty ? 'unknown' : method}, timeout=${timeoutMs}ms)';
}

/// Indicates a request's timeout fired after the WebSocket was replaced.
class StaleRequestError implements Exception {
  final String requestId;
  final int staleGeneration;
  final int currentGeneration;

  StaleRequestError(this.requestId, this.staleGeneration, this.currentGeneration);

  @override
  String toString() =>
    'Stale request cancelled (id=$requestId, gen=$staleGeneration, current=$currentGeneration)';
}
```

### Callbacks to add to `TelnyxClient`

```dart
typedef OnTelnyxError = void Function(Object event); // TelnyxErrorEvent | TelnyxMediaRecoveryErrorEvent
typedef OnTelnyxWarning = void Function(TelnyxWarningEvent event);
```

### How the JS SDK implements it

- `TelnyxError` class in `errors.ts` extends `Error`, implements `ITelnyxError`
- `ITelnyxWarning` interface in `warnings.ts`
- Event types: `ITelnyxStandardErrorEvent`, `ITelnyxMediaRecoveryErrorEvent`, union `ITelnyxErrorEvent`
- `RequestTimeoutError`, `StaleRequestError` custom error classes
- `classifyMediaErrorCode()` function maps `DOMException.name` to error codes
- Events emitted via `trigger(SwEvent.Error, ...)` and `trigger(SwEvent.Warning, ...)`

### Flutter-specific considerations

- Dart doesn't have TypeScript discriminated unions — use `Object` type for the union with `isMediaRecoveryErrorEvent()` type guard
- No `DOMException` on mobile — media errors come from `flutter_webrtc` as `PlatformException`
- Callbacks (not event emitter) — matches existing Flutter SDK pattern

### Dependencies

- Depends on VSDK-395 audit to confirm scope

### Test plan (Phase 3 TDD)

```
test/model/errors/
  telnyx_error_test.dart
    ✓ Constructs with all required fields
    ✓ toString() returns '[code] name: message'
    ✓ toJson() includes all fields
    ✓ originalError is optional
    ✓ fatal flag is respected

  telnyx_warning_test.dart
    ✓ Constructs with all required fields
    ✓ toJson() includes all fields

  telnyx_error_event_test.dart
    ✓ TelnyxErrorEvent recoverable is false
    ✓ TelnyxMediaRecoveryErrorEvent has resume/reject, recoverable is true
    ✓ isMediaRecoveryErrorEvent type guard works

  telnyx_warning_event_test.dart
    ✓ Constructs with warning, reason, source, sessionId

  request_timeout_error_test.dart
    ✓ RequestTimeoutError stores all fields, toString includes them
    ✓ StaleRequestError stores all fields, toString includes them
```

---

## VSDK-397: Define Flutter Native Mapping and Rollout Strategy

### What needs to be built

A design document defining platform-specific error-to-code mapping and rollout strategy.

### Files to create

#### `docs/native-error-mapping.md`

| Source | Platform | Dart Error | Mapped Code |
|--------|----------|------------|-------------|
| `getUserMedia` permission denied | iOS/Android | `PlatformException` with "permission" in code/message | 42001 |
| `getUserMedia` device not found | iOS/Android | `PlatformException` with "NotFound"/"Overconstrained" | 42002 |
| `getUserMedia` generic failure | iOS/Android | `Exception` (unclassified) | 42003 |
| WebSocket connect fails | All | `WebSocketException` / `SocketException` | 45001 |
| WebSocket runtime error | All | `WebSocketException` (post-connect) | 45002 |
| Reconnection exhausted | All | SDK-internal (max retries) | 45003 |
| Gateway failed | All | SDK-internal (gateway FAILED/FAIL_WAIT/TIMEOUT) | 45004 |
| Login rejected | All | SDK-internal (server error) | 46001 |
| Invalid credentials | All | SDK-internal (client validation) | 46002 |
| Auth required | All | SDK-internal (server 401) | 46003 |
| ICE restart failure | All | SDK-internal (Modify fails) | 47001 |
| Network offline | All | `connectivity_plus` → `ConnectivityResult.none` | 48001 |
| Session not reattached | All | SDK-internal (server no reattach) | 48501 |
| SDP offer/answer/description failures | All | `RTCPeerConnection` method throws | 40001-40005 |
| Hold/bye/subscribe failures | All | SDK-internal (send fails) | 44001-44004 |
| Unexpected error | All | Any uncaught exception | 49001 |

#### `docs/rollout-strategy.md`

**Phase 1 (VSDK-396/415):** New structured types alongside existing `TelnyxSocketError`. No breaking changes. Both old and new callbacks fire.

**Phase 2 (VSDK-416/417/418):** New recovery flows use new error types. Legacy `onSocketErrorReceived` continues for backward compat.

**Phase 3 (future):** Deprecate `TelnyxSocketError` / `TelnyxErrorConstants`. Remove in next major.

**Feature flags to add to `Config`:**

```dart
final bool enableStructuredErrors; // default: true
final bool enableSignalingHealthMonitor; // default: true
final MediaPermissionsRecoveryConfig? mediaPermissionsRecovery; // null = disabled
```

### Flutter-specific considerations

- `flutter_webrtc` throws `PlatformException` — inspect `code` and `message` fields
- **No platform channels needed** — all mapping is in Dart land
- Future: could add platform channel for OS-level error classification

### Dependencies

- Depends on VSDK-396 (contract must exist before mapping targets it)

### Test plan (Phase 3 TDD)

```
test/model/errors/
  media_error_classifier_test.dart
    ✓ PlatformException "permission" → 42001
    ✓ PlatformException "NotFound" → 42002
    ✓ PlatformException "Overconstrained" → 42002
    ✓ generic Exception → 42003
    ✓ string "NotAllowedError" → 42001
    ✓ string "NotFoundError" → 42002
```

---

## VSDK-415: Implement Structured Error/Warning Registry

### What needs to be built

Concrete implementations: error code constants, warning code constants, registry maps, factory functions, and event emission hooks. This is the core foundation.

### Files to create

#### `lib/model/errors/telnyx_error_codes.dart`

Static constants class with all 24 error codes matching JS SDK `TELNYX_ERROR_CODES`:

- SDP errors (400xx): 40001–40005
- Media errors (420xx): 42001–42003
- Call-control errors (440xx): 44001–44005
- WebSocket errors (450xx): 45001–45004
- Auth errors (460xx): 46001–46003
- ICE restart errors (470xx): 47001
- Network errors (480xx): 48001
- Session errors (485xx): 48501
- General errors (490xx): 49001

```dart
class TelnyxErrorCodes {
  TelnyxErrorCodes._();
  static const int sdpCreateOfferFailed = 40001;
  static const int sdpCreateAnswerFailed = 40002;
  // ... all 24 codes
}
```

#### `lib/model/errors/telnyx_warning_codes.dart`

Static constants class with all 26 warning codes matching JS SDK `TELNYX_WARNING_CODES`:

- Network quality (310xx): 31001–31006
- Connection/data-flow (320xx): 32001–32004
- Call connection (330xx): 33001–33011
- Authentication (340xx): 34001
- Session/reconnection (350xx): 35002
- Signaling health (360xx): 36003–36005

#### `lib/model/errors/sdk_errors.dart`

`TelnyxErrorDefinition` class + `sdkErrors` const Map with all 24 entries (ported 1:1 from JS `constants/errors.ts`):

```dart
class TelnyxErrorDefinition {
  final String name;
  final String message;
  final String description;
  final List<String> causes;
  final List<String> solutions;
  final bool fatal;
  const TelnyxErrorDefinition({...});
}

const Map<int, TelnyxErrorDefinition> sdkErrors = {
  40001: TelnyxErrorDefinition(name: 'SDP_CREATE_OFFER_FAILED', ...),
  // ... 24 entries
};
```

#### `lib/model/errors/sdk_warnings.dart`

`TelnyxWarningDefinition` class + `sdkWarnings` const Map with all 26 entries (ported 1:1 from JS `constants/warnings.ts`):

```dart
class TelnyxWarningDefinition {
  final String name;
  final String message;
  final String description;
  final List<String> causes;
  final List<String> solutions;
  const TelnyxWarningDefinition({...});
}

const Map<int, TelnyxWarningDefinition> sdkWarnings = {
  31001: TelnyxWarningDefinition(name: 'HIGH_RTT', ...),
  // ... 26 entries
};
```

#### `lib/model/errors/telnyx_error_factory.dart`

```dart
TelnyxError createTelnyxError(int code, {Object? originalError, String? message, bool? fatal});

int classifyMediaErrorCode(Object error) {
  if (error is PlatformException) {
    // inspect code and message for permission/notfound
  }
  // fallback to string matching
  return TelnyxErrorCodes.mediaGetUserMediaFailed;
}
```

#### `lib/model/errors/telnyx_warning_factory.dart`

```dart
TelnyxWarning createTelnyxWarning(int code, {String? message});
```

### Files to modify

#### `lib/telnyx_client.dart`

1. Add `onTelnyxError` and `onTelnyxWarning` callback fields
2. Add `_emitTelnyxError(TelnyxError error, {String? callId})` helper:
   ```dart
   void _emitTelnyxError(TelnyxError error, {String? callId}) {
     if (onTelnyxError != null) {
       onTelnyxError!(TelnyxErrorEvent(error: error, sessionId: sessid, callId: callId));
     }
   }
   ```
3. Add `_emitTelnyxWarning(TelnyxWarning warning, {String? callId, String? reason, String? source})` helper
4. Replace bare error paths with structured error emission:
   - Login failure → `createTelnyxError(TelnyxErrorCodes.loginFailed)`
   - WebSocket connect fails → `createTelnyxError(TelnyxErrorCodes.webSocketConnectionFailed)`
   - WebSocket runtime error → `createTelnyxError(TelnyxErrorCodes.webSocketError)`
   - Reconnection exhausted → `createTelnyxError(TelnyxErrorCodes.reconnectionExhausted)`
   - Gateway failed → `createTelnyxError(TelnyxErrorCodes.gatewayFailed)`
   - Invalid credentials → `createTelnyxError(TelnyxErrorCodes.invalidCredentials)`
   - Auth required → `createTelnyxError(TelnyxErrorCodes.authenticationRequired)`
5. Keep legacy `onSocketErrorReceived` firing alongside new `onTelnyxError` for backward compat

#### `lib/peer/peer.dart`

1. Replace bare `throw Exception(...)` in SDP methods with `createTelnyxError()` calls:
   - `createOffer` fails → `createTelnyxError(TelnyxErrorCodes.sdpCreateOfferFailed, originalError: e)`
   - `createAnswer` fails → `createTelnyxError(TelnyxErrorCodes.sdpCreateAnswerFailed, originalError: e)`
   - `setLocalDescription` fails → `createTelnyxError(TelnyxErrorCodes.sdpSetLocalDescriptionFailed, originalError: e)`
   - `setRemoteDescription` fails → `createTelnyxError(TelnyxErrorCodes.sdpSetRemoteDescriptionFailed, originalError: e)`
2. Add `getUserMedia` error classification via `classifyMediaErrorCode()`:
   - In `createStream()`, catch errors and classify, then emit structured error
3. Add ICE/connection state warnings:
   - `RTCIceConnectionState.disconnected` → `createTelnyxWarning(TelnyxWarningCodes.iceConnectivityLost)`
   - `RTCIceConnectionState.failed` → `createTelnyxWarning(TelnyxWarningCodes.peerConnectionFailed)`
   - ICE gathering timeout → `createTelnyxWarning(TelnyxWarningCodes.iceGatheringTimeout)`
   - ICE gathering empty → `createTelnyxWarning(TelnyxWarningCodes.iceGatheringEmpty)`
   - Only host candidates → `createTelnyxWarning(TelnyxWarningCodes.onlyHostIceCandidates)`

### How the JS SDK implements it

- `SDK_ERRORS` object literal in `constants/errors.ts` — 24 entries with `name`, `message`, `description`, `causes`, `solutions`, `fatal`
- `SDK_WARNINGS` object literal in `constants/warnings.ts` — 26 entries with `name`, `message`, `description`, `causes`, `solutions`
- `createTelnyxError(code, originalError?, message?, fatal?)` factory
- `createTelnyxWarning(code, message?)` factory
- `classifyMediaErrorCode(error)` maps `DOMException.name` to error codes
- Events emitted via `trigger(SwEvent.Error, { error, sessionId, callId })` and `trigger(SwEvent.Warning, { warning, sessionId, callId })`

### Flutter-specific considerations

- Dart `const` maps for registries (compile-time constant, better performance)
- `PlatformException` classification is Flutter-specific (no `DOMException`)
- Both `onTelnyxError` (new) and `onSocketErrorReceived` (legacy) fire during transition

### Dependencies

- Depends on VSDK-396 (types must be defined first)
- Depends on VSDK-397 (mapping strategy for `classifyMediaErrorCode`)

### Test plan (Phase 3 TDD)

```
test/model/errors/
  telnyx_error_codes_test.dart
    ✓ Every code in TelnyxErrorCodes exists in sdkErrors map
    ✓ Every code is unique
    ✓ Code ranges match JS SDK (400xx, 420xx, 440xx, 450xx, 460xx, 470xx, 480xx, 485xx, 490xx)

  telnyx_warning_codes_test.dart
    ✓ Every code in TelnyxWarningCodes exists in sdkWarnings map
    ✓ Every code is unique
    ✓ Code ranges match JS SDK (310xx, 320xx, 330xx, 340xx, 350xx, 360xx)

  sdk_errors_test.dart
    ✓ sdkErrors has 24 entries
    ✓ Every entry has non-empty name, message, description, causes, solutions
    ✓ Every entry has fatal: bool
    ✓ SDP errors (400xx) are fatal: true
    ✓ WebSocket error (45002) is fatal: false
    ✓ Network offline (48001) is fatal: false
    ✓ Session not reattached (48501) is fatal: true

  sdk_warnings_test.dart
    ✓ sdkWarnings has 26 entries
    ✓ Every entry has non-empty name, message, description, causes, solutions

  telnyx_error_factory_test.dart
    ✓ createTelnyxError returns TelnyxError with correct fields from registry
    ✓ createTelnyxError throws ArgumentError for unknown code
    ✓ createTelnyxError overrides message when provided
    ✓ createTelnyxError overrides fatal when provided
    ✓ createTelnyxError wraps string originalError

  telnyx_warning_factory_test.dart
    ✓ createTelnyxWarning returns TelnyxWarning with correct fields
    ✓ createTelnyxWarning throws ArgumentError for unknown code
    ✓ createTelnyxWarning overrides message when provided

  media_error_classifier_test.dart
    ✓ classifyMediaErrorCode maps PlatformException "permission" → 42001
    ✓ classifyMediaErrorCode maps PlatformException "NotFound" → 42002
    ✓ classifyMediaErrorCode maps generic Exception → 42003
```

---

## VSDK-416: Implement SignalingHealthMonitor

### What needs to be built

A Dart class mirroring the JS SDK's `SignalingHealthMonitor` — periodic WebSocket liveness checks, probe/timeout mechanism, single recovery decision authority (socket reconnect vs ICE restart).

### File to create

#### `lib/services/signaling_health_monitor.dart`

**Class signature:**

```dart
/// Monitors WebSocket signaling connection health during active calls.
///
/// Single recovery decision authority:
/// - If signaling unhealthy → socket reconnect + reattach, NEVER ICE restart.
/// - If signaling healthy and peer/media unhealthy → ICE restart, NEVER socket reconnect.
///
/// Lifecycle:
/// - start() when a call becomes active or on reconnect with active calls.
/// - stop() when no active calls remain or on disconnect.
/// - onSocketActivity() on every inbound WS message.
/// - triggerProbe() called by Peer on ICE/connection degradation.
/// - onRequestTimeout() called when a signaling request times out.
/// - onPeerFailure() called when ICE/peer connection state becomes 'failed'.
/// - onNoRtp() called when RTP bytes stop flowing.
class SignalingHealthMonitor {
  SignalingHealthMonitor(this._session);

  final ISignalingHealthSession _session;

  /// Timestamp of the last inbound WS message.
  int _lastInboundAt = 0;

  /// Timestamp of the last health probe sent.
  int _lastProbeSentAt = 0;

  /// True when a probe has been sent and we're waiting for a response.
  bool _probeInFlight = false;

  /// Periodic check timer.
  Timer? _checkTimer;

  /// Media recovery to execute only after a probe proves signaling is healthy.
  PendingMediaRecovery? _pendingMediaRecovery;

  // Constants
  static const int _probeThresholdMs = 20000;
  static const int _probeTimeoutMs = 5000;
  static const int _checkIntervalMs = 3000;
  static const int _recentActivityThresholdMs = 3000;

  // Critical Verto methods that warrant signaling recovery on timeout
  static const Set<String> criticalMethods = {
    'telnyx_rtc.modify',
    'telnyx_rtc.bye',
    'telnyx_rtc.ping',
  };

  // Public API
  void start();
  void stop();
  bool get isRunning;
  bool get isProbeInFlight;
  void onSocketActivity();
  void onRequestTimeout(String requestId, int timeoutMs, [String method = '']);
  void onPeerFailure(String callId, PeerFailureEvidence evidence);
  void onNoRtp(String callId, String direction);
  void onIceRestartFailed(String callId);
  static bool isCriticalMethod(String method);

  // Private
  void _check();
  void _sendProbe();
  void _resolveProbe();
  void _probeIfNeeded(String reason);
  void _recoverMediaOrSignaling(String callId, String mediaReason, String signalingReason, String signalingSource);
  String _getSignalingHealthState(); // 'healthy' | 'unknown' | 'unhealthy'
  void _triggerSignalingRecovery(String reason, String source);
  void _triggerIceRestart(String callId, String reason);
}
```

**Session interface:**

```dart
/// Interface that SignalingHealthMonitor uses to interact with its owning session.
/// Decouples the monitor from TelnyxClient to avoid circular dependencies.
abstract class ISignalingHealthSession {
  String get uuid;
  String get sessionid;
  bool get isConnected;
  bool hasActiveCall();
  void socketDisconnect();
  TriggerIceRestartResult triggerIceRestart(String callId);
}

enum PeerFailureEvidence { iceFailed, connectionFailed }

class TriggerIceRestartResult {
  final bool started;
  final String? reason;
  TriggerIceRestartResult({required this.started, this.reason});
}

class PendingMediaRecovery {
  final String callId;
  final String reason;
  final String source; // 'peer_failure' | 'no_rtp'
  PendingMediaRecovery({required this.callId, required this.reason, required this.source});
}
```

### Files to modify

#### `lib/telnyx_client.dart`

1. Make `TelnyxClient` implement `ISignalingHealthSession`:
   ```dart
   class TelnyxClient implements ISignalingHealthSession {
     // ... existing code ...

     // ISignalingHealthSession implementation
     @override
     String get uuid => sessid; // or separate UUID field

     @override
     String get sessionid => sessid;

     @override
     bool get isConnected => _connected;

     @override
     bool hasActiveCall() => activeCalls().isNotEmpty;

     @override
     void socketDisconnect() => _closeSocketSafely();

     @override
     TriggerIceRestartResult triggerIceRestart(String callId) {
       // Find call by callId, trigger ICE restart on its Peer
       final call = calls[callId];
       if (call == null) return TriggerIceRestartResult(started: false, reason: 'Call not found');
       // Call peer.iceRestart() or equivalent
       return TriggerIceRestartResult(started: true);
     }
   }
   ```

2. Add `SignalingHealthMonitor` field:
   ```dart
   final SignalingHealthMonitor? _healthMonitor;
   ```
   Initialize when `enableSignalingHealthMonitor` is true.

3. Wire `onSocketActivity()` into `onMessage` callback in `TxSocket`:
   ```dart
   txSocket.onMessage = (data) {
     _healthMonitor?.onSocketActivity();
     // ... existing message handling
   };
   ```

4. Call `_healthMonitor?.start()` when a call becomes active
5. Call `_healthMonitor?.stop()` when no active calls remain
6. Call `_healthMonitor?.onRequestTimeout()` when a signaling request times out
7. Call `_healthMonitor?.onPeerFailure()` when `RTCIceConnectionState.failed` is detected
8. Call `_healthMonitor?.onNoRtp()` when `CallReportCollector` detects no RTP bytes

#### `lib/peer/peer.dart`

1. On `RTCIceConnectionState.failed`:
   ```dart
   case RTCIceConnectionState.RTCIceConnectionStateFailed:
     _txClient._healthMonitor?.onPeerFailure(
       currentSession?.callId ?? '',
       PeerFailureEvidence.iceFailed,
     );
     break;
   ```
2. On `RTCPeerConnectionState.failed`:
   ```dart
   case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
     _txClient._healthMonitor?.onPeerFailure(
       currentSession?.callId ?? '',
       PeerFailureEvidence.connectionFailed,
     );
     break;
   ```

#### `lib/utils/stats/call_report_collector.dart`

1. Add RTP flow monitoring — when `bytesReceived == 0` for multiple consecutive intervals:
   ```dart
   _txClient._healthMonitor?.onNoRtp(callId, 'inbound');
   ```

### How the JS SDK implements it

File: `Modules/Verto/services/SignalingHealthMonitor.ts`

Key design principles:
- **Single recovery decision authority** — receives health facts from Connection, Peer, and CallReportCollector. Decides exactly one recovery path: socket reconnect or ICE restart. Never mixes.
- **Core rule:** If signaling is unhealthy → socket reconnect + reattach. If signaling is healthy but peer/media is unhealthy → ICE restart.
- **Probe mechanism:** Periodic check every 3s. If no inbound WS activity for 20s, send a Ping probe. If no response within 5s, declare signaling unhealthy.
- **Probe bypasses execute()** — uses `connection.send()` directly to avoid the 10s active-call request timeout (prevents race condition where stale Ping promise could force-close healthy replacement socket).
- **Critical method timeouts** — only `Modify`, `Bye`, `Ping` trigger signaling recovery. Non-critical request timeouts are logged but don't force-close socket.
- **Pending media recovery** — if peer failure detected while signaling health is unknown (probe in flight), defer ICE restart decision until probe resolves.
- **Browser online/offline** — browser offline emits `NETWORK_OFFLINE` error event and may accelerate a probe. Browser online clears state only. Neither directly triggers recovery.

### Flutter-specific considerations

- Replace `setInterval`/`clearInterval` with Dart `Timer.periodic` / `Timer.cancel()`
- Replace browser `window.addEventListener('online'/'offline')` with `connectivity_plus` stream (already exists in `TelnyxClient`)
- JS `Connection.lastInboundAt` has no Flutter equivalent in `TxSocket` — need to add `lastInboundAt` tracking to `TxSocket` or manage it in the monitor via `onSocketActivity()`
- JS `Connection.socketGeneration` maps to existing `_connectionGeneration` in `TelnyxClient`
- No `trigger()` event system in Flutter — use `_emitTelnyxWarning()` callback instead
- `triggerIceRestart` on the Flutter side needs to call the existing ICE restart flow in `Peer` (renegotiation with ICE restart flag)

### Dependencies

- Depends on VSDK-415 (warning codes needed for `SIGNALING_RECOVERY_REQUIRED`, `MEDIA_RECOVERY_REQUIRED`)

### Test plan (Phase 3 TDD)

```
test/services/
  signaling_health_monitor_test.dart
    ✓ start() begins periodic checks, stop() cancels timer
    ✓ isRunning returns true after start(), false after stop()
    ✓ onSocketActivity() updates _lastInboundAt
    ✓ _check() sends probe when silence > 20s threshold
    ✓ _check() declares unhealthy when probe times out (5s)
    ✓ _sendProbe() sets _probeInFlight, _lastProbeSentAt
    ✓ _resolveProbe() clears probe state, triggers pending media recovery if healthy
    ✓ onRequestTimeout() triggers signaling recovery for critical methods (Modify, Bye, Ping)
    ✓ onRequestTimeout() logs but does NOT trigger recovery for non-critical methods
    ✓ onPeerFailure() with healthy signaling → ICE restart
    ✓ onPeerFailure() with unknown signaling → defers media recovery, probes
    ✓ onPeerFailure() with unhealthy signaling → socket reconnect
    ✓ onNoRtp() with healthy signaling → ICE restart
    ✓ onNoRtp() with unknown signaling → defers media recovery, probes
    ✓ onNoRtp() with unhealthy signaling → socket reconnect
    ✓ onIceRestartFailed() triggers socket reconnect
    ✓ _triggerSignalingRecovery() emits SIGNALING_RECOVERY_REQUIRED warning
    ✓ _triggerIceRestart() emits MEDIA_RECOVERY_REQUIRED warning
    ✓ isCriticalMethod() returns true for Modify, Bye, Ping
    ✓ isCriticalMethod() returns false for Info, other methods
    ✓ start() is idempotent (calling twice does nothing)
    ✓ stop() is idempotent
    ✓ stop() clears pending media recovery
```

---

## VSDK-417: Implement Media Permission Recovery Flow

### What needs to be built

A recovery flow that, when `getUserMedia` fails during inbound call answer, emits a recoverable error event with `resume()` and `reject()` callbacks so the app can prompt the user to fix permissions before the call fails.

### Files to create

#### `lib/model/errors/media_permissions_recovery_config.dart`

```dart
/// Configuration for media permissions recovery on inbound calls.
///
/// When enabled and the initial getUserMedia call fails while answering,
/// the SDK emits a recoverable error event with resume() and reject()
/// callbacks so the app can prompt the user to fix permissions.
class MediaPermissionsRecoveryConfig {
  /// Enable the recovery flow.
  final bool enabled;

  /// Maximum time in ms to wait for the app to call resume() or reject().
  /// Recommended max 25000.
  final int timeout;

  /// Called when the retry getUserMedia succeeds after resume().
  final void Function()? onSuccess;

  /// Called when retry fails, timeout expires, or the app calls reject().
  final void Function(Object error)? onError;

  const MediaPermissionsRecoveryConfig({
    required this.enabled,
    required this.timeout,
    this.onSuccess,
    this.onError,
  });
}
```

### Files to modify

#### `lib/peer/peer.dart`

Modify `createStream()` method to add recovery flow when answering inbound calls:

```dart
Future<MediaStream> createStream(String media, {bool isAnswer = false}) async {
  final Map<String, dynamic> mediaConstraints = {
    'audio': (_audioConstraints ?? AudioConstraints.enabled())
        .toMap(isAndroid: Platform.isAndroid),
    'video': false,
  };

  try {
    final MediaStream stream =
        await navigator.mediaDevices.getUserMedia(mediaConstraints);
    onLocalStream?.call(stream);
    return stream;
  } catch (error) {
    final recovery = _txClient._mediaPermissionsRecovery;

    // Only run recovery for answers (inbound calls), not invites
    if (recovery?.enabled == true && isAnswer) {
      final int errorCode = classifyMediaErrorCode(error);
      final TelnyxError telnyxError = createTelnyxError(
        errorCode,
        originalError: error,
        fatal: false, // recovery flow: fatal=false (override of registry default true)
      );

      Completer<void>? recoveryCompleter = Completer<void>();
      Timer? safetyTimeout;

      // Emit recoverable error event
      _txClient.onTelnyxError?.call(TelnyxMediaRecoveryErrorEvent(
        error: telnyxError,
        sessionId: _txClient.sessid,
        callId: currentSession?.callId ?? '',
        retryDeadline: DateTime.now().millisecondsSinceEpoch + recovery!.timeout,
        resume: () async {
          safetyTimeout?.cancel();
          recoveryCompleter?.complete();
        },
        reject: () async {
          safetyTimeout?.cancel();
          recoveryCompleter?.completeError(
            Exception('Call was rejected during media recovery flow!'));
        },
      ));

      // Set safety timeout
      safetyTimeout = Timer(Duration(milliseconds: recovery!.timeout), () {
        recoveryCompleter?.completeError(
          Exception('Media recovery flow timed out!'));
      });

      try {
        await recoveryCompleter!.future;
        // Retry getUserMedia
        final MediaStream stream =
            await navigator.mediaDevices.getUserMedia(mediaConstraints);
        onLocalStream?.call(stream);
        recovery.onSuccess?.call();
        return stream;
      } catch (recoveryError) {
        recovery.onError?.call(recoveryError);
        rethrow;
      }
    }

    // Non-recovery path: classify and emit structured error
    final int errorCode = classifyMediaErrorCode(error);
    final TelnyxError telnyxError = createTelnyxError(
      errorCode,
      originalError: error,
    );
    _txClient._emitTelnyxError(telnyxError,
        callId: currentSession?.callId);
    rethrow;
  }
}
```

#### `lib/telnyx_client.dart`

1. Add `MediaPermissionsRecoveryConfig? _mediaPermissionsRecovery` field
2. Set it from `Config.mediaPermissionsRecovery` during connect
3. Add `mediaPermissionsRecovery` to `Config` class

#### `lib/config/telnyx_config.dart`

Add to `Config`:
```dart
final MediaPermissionsRecoveryConfig? mediaPermissionsRecovery;
```

### How the JS SDK implements it

File: `Modules/Verto/webrtc/Peer.ts` (lines 534-600)

Key flow:
1. `Peer._retrieveLocalStream()` calls `getUserMedia()`
2. On failure, catches error and checks `this._session.options.mediaPermissionsRecovery`
3. If recovery is enabled AND this is an answer (not invite):
   - Creates a `Promise` that resolves on `resume()` and rejects on `reject()`
   - Sets a safety timeout via `setTimeout` that rejects with "timed out"
   - Emits `trigger(SwEvent.Error, { error, callId, sessionId, recoverable: true, retryDeadline, resume, reject })`
   - On `resume()` → retries `getUserMedia()`, calls `onSuccess`
   - On `reject()` or timeout → calls `onError`, propagates failure
4. If recovery is NOT enabled:
   - `capturedMediaError = error`, returns null
   - Call fails with structured error

The error is created with `fatal: false` (overriding the registry default `true`) because the recovery flow is active.

### Flutter-specific considerations

- Use `Completer<void>` instead of JS `Promise` for the resume/reject gate
- Use `Timer` instead of `setTimeout` for the safety timeout
- `flutter_webrtc` `getUserMedia` throws `PlatformException` — `classifyMediaErrorCode()` handles this
- The recovery flow should only apply to **inbound call answers**, not outbound calls (matches JS behavior)
- Need to pass `isAnswer: true` from `_createSession` when direction is "answer"
- The `resume` and `reject` callbacks are `Future<void> Function()` (async) in Dart, unlike JS `void Function()`

### Dependencies

- Depends on VSDK-415 (error codes and `createTelnyxError`, `classifyMediaErrorCode`)
- Depends on VSDK-396 (TelnyxMediaRecoveryErrorEvent type)

### Test plan (Phase 3 TDD)

```
test/peer/
  media_permission_recovery_test.dart
    ✓ createStream with recovery enabled and isAnswer=true emits TelnyxMediaRecoveryErrorEvent on getUserMedia failure
    ✓ resume() retries getUserMedia and returns stream on success
    ✓ reject() throws error and calls onError callback
    ✓ safety timeout triggers onError and throws
    ✓ recovery disabled does not emit recoverable event
    ✓ recovery enabled but isAnswer=false (outbound) does not emit recoverable event
    ✓ successful getUserMedia does not trigger recovery flow
    ✓ recovery event has correct retryDeadline (now + timeout)
    ✓ recovery event has recoverable: true
    ✓ recovery event error has fatal: false (overridden)
    ✓ onSuccess callback called on successful resume
    ✓ onError callback called on reject
    ✓ onError callback called on timeout
    ✓ onError callback called on retry failure

test/model/errors/
  media_permissions_recovery_config_test.dart
    ✓ Configures with enabled, timeout, onSuccess, onError
    ✓ Default timeout of 25000 when not specified
```

---

## VSDK-418: Implement Reconnect Token / Session Persistence

### What needs to be built

A reconnect token system that persists the `voice_sdk_id` across app restarts using `SharedPreferences`, allowing the SDK to reattach to the previous backend session after app kill/relaunch or deep sleep.

### Files to create

#### `lib/services/reconnect_token_store.dart`

```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Stores and retrieves the reconnect token (voice_sdk_id) and session ID
/// for session reattachment after app restart.
///
/// Ported from JS SDK `Modules/Verto/util/reconnect.ts` which uses
/// `sessionStorage`. Flutter uses `SharedPreferences` as the equivalent
/// persistent key-value store.
class ReconnectTokenStore {
  static const String _reconnectTokenKey = 'telnyx-voice-sdk-id';
  static const String _sessionIdKey = 'telnyx-voice-sdk-session-id';
  static const String _sessionIdStoredAtKey = 'telnyx-voice-sdk-session-id-stored-at';
  static const String _activeCallsKey = 'telnyx-voice-sdk-active-calls';

  /// Max age (ms) for the reconnect session ID to be considered fresh.
  static const int reconnectSessionIdMaxAgeMs = 90 * 1000; // 90s

  /// Max age (ms) for the active-calls recovery marker.
  static const int recoveryMarkerMaxAgeMs = 15 * 60 * 1000; // 15 min

  /// Get the stored reconnect token (voice_sdk_id).
  static Future<String?> getReconnectToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_reconnectTokenKey);
  }

  /// Store the reconnect token.
  static Future<void> setReconnectToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_reconnectTokenKey, token);
  }

  /// Get the stored session ID if it's still fresh, null otherwise.
  static Future<String?> getReconnectSessionId({int? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString(_sessionIdKey);
    if (sessionId == null) return null;

    final storedAt = prefs.getInt(_sessionIdStoredAtKey);
    if (storedAt == null) return null;

    final currentTime = now ?? DateTime.now().millisecondsSinceEpoch;
    if (currentTime - storedAt > reconnectSessionIdMaxAgeMs) {
      // Stale — clean up
      await prefs.remove(_sessionIdKey);
      await prefs.remove(_sessionIdStoredAtKey);
      return null;
    }

    return sessionId;
  }

  /// Store the session ID with a timestamp.
  static Future<void> setReconnectSessionId(
    String sessionId, {
    int? storedAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionIdKey, sessionId);
    await prefs.setInt(
      _sessionIdStoredAtKey,
      storedAt ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Clear all reconnect-related storage.
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_reconnectTokenKey);
    await prefs.remove(_sessionIdKey);
    await prefs.remove(_sessionIdStoredAtKey);
    await prefs.remove(_activeCallsKey);
  }

  /// Check if the reconnect session ID is fresh (within max age).
  static Future<bool> isReconnectSessionIdFresh({int? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final storedAt = prefs.getInt(_sessionIdStoredAtKey);
    if (storedAt == null) return false;

    final currentTime = now ?? DateTime.now().millisecondsSinceEpoch;
    return currentTime - storedAt <= reconnectSessionIdMaxAgeMs;
  }

  // ── Active calls recovery marker ──────────────────────────────

  /// Stored active call projection for session recovery.
  static Future<StoredActiveCalls?> getActiveCallsRecoveryMarker({
    int? now,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_activeCallsKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final parsed = jsonDecode(raw) as Map<String, dynamic>;
      final callsList = parsed['calls'] as List?;
      if (callsList == null || callsList.isEmpty) {
        await prefs.remove(_activeCallsKey);
        return null;
      }

      final storedAt = parsed['storedAt'] as int?;
      if (storedAt == null) {
        await prefs.remove(_activeCallsKey);
        return null;
      }

      final currentTime = now ?? DateTime.now().millisecondsSinceEpoch;
      if (currentTime - storedAt > recoveryMarkerMaxAgeMs) {
        await prefs.remove(_activeCallsKey);
        return null;
      }

      return StoredActiveCalls.fromJson(parsed);
    } catch (_) {
      await prefs.remove(_activeCallsKey);
      return null;
    }
  }

  /// Persist the active-calls recovery marker.
  static Future<void> setActiveCallsRecoveryMarker(
    List<StoredActiveCall> calls,
    String sessionId, {
    int? storedAt,
  }) async {
    if (calls.isEmpty) {
      await clearActiveCallsRecoveryMarker();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final payload = StoredActiveCalls(
      sessionId: sessionId,
      calls: calls,
      storedAt: storedAt ?? DateTime.now().millisecondsSinceEpoch,
    );
    await prefs.setString(_activeCallsKey, jsonEncode(payload.toJson()));
  }

  /// Remove the active-calls recovery marker.
  static Future<void> clearActiveCallsRecoveryMarker() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeCallsKey);
  }
}

/// Narrow projection of an active call for persistence.
class StoredActiveCall {
  final String id;
  final List<Map<String, String>> customHeaders;

  StoredActiveCall({required this.id, required this.customHeaders});

  Map<String, dynamic> toJson() => {
    'id': id,
    'customHeaders': customHeaders,
  };

  factory StoredActiveCall.fromJson(Map<String, dynamic> json) {
    return StoredActiveCall(
      id: json['id'] as String,
      customHeaders: (json['customHeaders'] as List? ?? [])
          .map((e) => Map<String, String>.from(e as Map))
          .toList(),
    );
  }
}

/// Stored active calls recovery marker.
class StoredActiveCalls {
  final String sessionId;
  final List<StoredActiveCall> calls;
  final int storedAt;

  StoredActiveCalls({
    required this.sessionId,
    required this.calls,
    required this.storedAt,
  });

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'calls': calls.map((c) => c.toJson()).toList(),
    'storedAt': storedAt,
  };

  factory StoredActiveCalls.fromJson(Map<String, dynamic> json) {
    return StoredActiveCalls(
      sessionId: json['sessionId'] as String,
      calls: (json['calls'] as List)
          .map((c) => StoredActiveCall.fromJson(c as Map<String, dynamic>))
          .toList(),
      storedAt: json['storedAt'] as int,
    );
  }
}
```

### Files to modify

#### `lib/telnyx_client.dart`

1. **On connect:** Check `ReconnectTokenStore.getReconnectSessionId()` — if fresh, add `voice_sdk_id` as URL query param to WebSocket connect URL (already partially done via `_buildHostAddress` with `voiceSdkId`, but now powered by persistent storage instead of just `_pushMetaData`)

2. **On successful login (REGED):** Store `voice_sdk_id` from server response via `ReconnectTokenStore.setReconnectToken()` and `ReconnectTokenStore.setReconnectSessionId(sessid)`

3. **On WebSocket reconnect:** Read `ReconnectTokenStore.getReconnectToken()` and include it in reconnect URL

4. **On app startup with active calls:** Check `ReconnectTokenStore.getActiveCallsRecoveryMarker()` — if marker exists and is fresh, attempt reattach for each stored call ID

5. **On call end:** Update or clear the active-calls recovery marker

6. **On disconnect:** Call `ReconnectTokenStore.clearAll()` to clean up

7. **Integrate with SignalingHealthMonitor:** When health monitor triggers `_triggerSignalingRecovery()`, the reconnect flow should include the reconnect token

Key integration points in `telnyx_client.dart`:

```dart
// In connect() method:
final reconnectSessionId = await ReconnectTokenStore.getReconnectSessionId();
if (reconnectSessionId != null) {
  // Add voice_sdk_id to WebSocket URL
  _buildHostAddress(config, voiceSdkId: reconnectSessionId);
}

// In _onRegged (login success):
final voiceSdkId = response.voiceSdkId;
if (voiceSdkId != null) {
  await ReconnectTokenStore.setReconnectToken(voiceSdkId);
  await ReconnectTokenStore.setReconnectSessionId(sessid);
}

// In _reconnectToSocket:
final token = await ReconnectTokenStore.getReconnectToken();
if (token != null) {
  _buildHostAddress(config, voiceSdkId: token);
}

// In disconnect():
await ReconnectTokenStore.clearAll();

// On app startup (new TelnyxClient instance):
Future<void> _attemptSessionRecovery() async {
  final marker = await ReconnectTokenStore.getActiveCallsRecoveryMarker();
  if (marker == null) return;

  // Store for reattach after login
  _pendingReattachCalls = marker;
}
```

#### `lib/call.dart`

Add `recoveredCallId` field:

```dart
/// Set during reattachment/recovery to correlate the new call with the ended call.
String? recoveredCallId;
```

### How the JS SDK implements it

File: `Modules/Verto/util/reconnect.ts`

Key elements:
- `STORAGE_KEY = 'telnyx-voice-sdk-id'` — stores `voice_sdk_id` in `sessionStorage`
- `SESSION_ID_STORAGE_KEY = 'telnyx-voice-sdk-session-id'` — stores session ID
- `RECONNECT_SESSION_ID_MAX_AGE_MS = 90 * 1000` — 90 seconds max freshness
- `RECOVERY_MARKER_MAX_AGE_MS = 15 * 60 * 1000` — 15 minutes for active calls marker
- `ACTIVE_CALLS_STORAGE_KEY = 'telnyx-voice-sdk-active-calls'` — persisted call IDs
- `getReconnectToken()` / `setReconnectToken()` — read/write voice_sdk_id
- `getReconnectSessionId()` / `setReconnectSessionId()` — read/write session ID with freshness check
- `getActiveCallsRecoveryMarker()` / `setActiveCallsRecoveryMarker()` — persist narrow call projection (id + customHeaders only, no SDP/credentials/streams)
- `clearReconnectToken()` / `clearActiveCallsRecoveryMarker()` — cleanup
- All storage operations wrapped in try/catch (storage may be unavailable)
- Security: only narrow projection persisted (no credentials, SDP, ICE/TURN secrets, or host objects)

On reconnect:
1. `Connection` class reads `getReconnectToken()` and includes it as URL param
2. Server reattaches to the same backend session
3. Server sends `Attach` messages for active calls
4. SDK restores calls via `handleAttach()` which creates new `Call` objects with `recoveredCallId` set

### Flutter-specific considerations

- `SharedPreferences` replaces `sessionStorage` — persists across app restarts (unlike `sessionStorage` which is per-tab)
- `SharedPreferences` is async (all methods return `Future`) — JS `sessionStorage` is sync. Need to handle async in connect/reconnect paths
- App lifecycle: Flutter apps can be killed and relaunched. `SharedPreferences` survives app kill. `sessionStorage` does NOT survive page reload in JS — the JS SDK uses `sessionStorage` which IS cleared on tab close. **Key difference:** Flutter should persist across app kills (that's the point of this feature), while JS persists across page reloads within the same tab session
- Security: Only persist narrow call projection (id + customHeaders), no SDP/credentials/streams — matches JS SDK security constraints
- `StoredActiveCall` should NOT include `localStream`/`remoteStream` or `RTCPeerConnection` (not serializable, not secure)
- The 90-second max age for session ID freshness may need tuning for mobile (app kill + relaunch takes longer than page reload)

### Dependencies

- Depends on VSDK-415 (structured error codes for `SESSION_NOT_REATTACHED`, `UNEXPECTED_ERROR`)
- Depends on VSDK-416 (SignalingHealthMonitor triggers reconnection which needs reconnect token)
- Existing `PreferencesStorage` class can be referenced for SharedPreferences patterns

### Test plan (Phase 3 TDD)

```
test/services/
  reconnect_token_store_test.dart
    ✓ setReconnectToken stores token, getReconnectToken retrieves it
    ✓ setReconnectSessionId stores ID + timestamp, getReconnectSessionId retrieves it
    ✓ getReconnectSessionId returns null when stale (> 90s)
    ✓ getReconnectSessionId returns null when not stored
    ✓ isReconnectSessionIdFresh returns true within 90s
    ✓ isReconnectSessionIdFresh returns false after 90s
    ✓ clearAll removes all stored data
    ✓ setActiveCallsRecoveryMarker stores calls
    ✓ getActiveCallsRecoveryMarker returns stored marker when fresh
    ✓ getActiveCallsRecoveryMarker returns null when stale (> 15 min)
    ✓ getActiveCallsRecoveryMarker returns null when empty calls list
    ✓ getActiveCallsRecoveryMarker returns null when malformed JSON
    ✓ clearActiveCallsRecoveryMarker removes marker
    ✓ setActiveCallsRecoveryMarker with empty list clears marker

  stored_active_call_test.dart
    ✓ StoredActiveCall toJson/fromJson roundtrip
    ✓ StoredActiveCalls toJson/fromJson roundtrip

test/
  session_recovery_test.dart
    ✓ Connect with stored reconnect session ID adds voice_sdk_id to URL
    ✓ Connect without stored session ID does not add voice_sdk_id
    ✓ Successful login stores voice_sdk_id and session ID
    ✓ Reconnect uses stored voice_sdk_id
    ✓ Disconnect clears all stored data
    ✓ App startup with recovery marker attempts reattach
    ✓ SESSION_NOT_REATTACHED error emitted when server doesn't reattach
    ✓ recoveredCallId is set on recovered calls
    ✓ Active calls marker updated when call state changes
    ✓ Active calls marker cleared when all calls end
```

---

## Summary: New File Tree

```
packages/telnyx_webrtc/lib/
├── model/
│   └── errors/
│       ├── telnyx_error.dart                 (VSDK-396)
│       ├── telnyx_warning.dart                (VSDK-396)
│       ├── telnyx_error_event.dart            (VSDK-396)
│       ├── telnyx_warning_event.dart          (VSDK-396)
│       ├── request_timeout_error.dart        (VSDK-396)
│       ├── telnyx_error_codes.dart            (VSDK-415)
│       ├── telnyx_warning_codes.dart          (VSDK-415)
│       ├── sdk_errors.dart                    (VSDK-415)
│       ├── sdk_warnings.dart                  (VSDK-415)
│       ├── telnyx_error_factory.dart          (VSDK-415)
│       ├── telnyx_warning_factory.dart        (VSDK-415)
│       └── media_permissions_recovery_config.dart  (VSDK-417)
├── services/
│   ├── signaling_health_monitor.dart         (VSDK-416)
│   └── reconnect_token_store.dart            (VSDK-418)
├── config/
│   └── telnyx_config.dart                    (modified — VSDK-397, 417)
├── telnyx_client.dart                        (modified — all tickets)
├── peer/
│   └── peer.dart                              (modified — VSDK-415, 417)
└── call.dart                                  (modified — VSDK-418)

docs/
├── error-audit.md                             (VSDK-395)
├── native-error-mapping.md                    (VSDK-397)
└── rollout-strategy.md                        (VSDK-397)
```

## Summary: Test Tree

```
test/
├── model/
│   └── errors/
│       ├── telnyx_error_test.dart             (VSDK-396)
│       ├── telnyx_warning_test.dart           (VSDK-396)
│       ├── telnyx_error_event_test.dart       (VSDK-396)
│       ├── telnyx_warning_event_test.dart     (VSDK-396)
│       ├── request_timeout_error_test.dart    (VSDK-396)
│       ├── telnyx_error_codes_test.dart        (VSDK-415)
│       ├── telnyx_warning_codes_test.dart     (VSDK-415)
│       ├── sdk_errors_test.dart               (VSDK-415)
│       ├── sdk_warnings_test.dart             (VSDK-415)
│       ├── telnyx_error_factory_test.dart     (VSDK-415)
│       ├── telnyx_warning_factory_test.dart    (VSDK-415)
│       ├── media_error_classifier_test.dart    (VSDK-415)
│       └── media_permissions_recovery_config_test.dart  (VSDK-417)
├── services/
│   ├── signaling_health_monitor_test.dart     (VSDK-416)
│   ├── reconnect_token_store_test.dart        (VSDK-418)
│   └── stored_active_call_test.dart           (VSDK-418)
├── peer/
│   └── media_permission_recovery_test.dart    (VSDK-417)
└── session_recovery_test.dart                 (VSDK-418)
```

## Key Design Decisions

1. **Callbacks over event bus:** Flutter SDK uses callbacks (`onTelnyxError`, `onTelnyxWarning`) matching existing pattern, not a `Stream`-based event bus. This minimizes API surface change.

2. **Backward compatibility:** Both `onSocketErrorReceived` (legacy) and `onTelnyxError` (new) fire during transition. `TelnyxSocketError` / `TelnyxErrorConstants` are deprecated but not removed.

3. **Const maps for registries:** Dart `const Map` for `sdkErrors` and `sdkWarnings` provides compile-time constants and better performance vs runtime construction.

4. **SharedPreferences over sessionStorage:** Flutter uses `SharedPreferences` (persists across app restarts) instead of JS `sessionStorage` (per-tab). This is intentional — the purpose of VSDK-418 is to survive app kills.

5. **PlatformException classification:** `classifyMediaErrorCode()` inspects `PlatformException.code` and `message` fields (Flutter-specific) instead of `DOMException.name` (browser-specific).

6. **SignalingHealthMonitor as separate service:** New `lib/services/` directory. The monitor owns the recovery decision — it's the single authority that decides socket reconnect vs ICE restart.

7. **No platform channels needed:** All error classification and recovery logic is in Dart land. Future phases may add platform channels for more precise OS-level error classification.

8. **Completer for media recovery:** Dart `Completer<void>` replaces JS `Promise` for the resume/reject gate in media permission recovery.

---

*Plan based on source code analysis of JS SDK (`~/telnyx/webrtc/packages/js/src/`) and Flutter SDK (`~/telnyx/flutter-voice-sdk/packages/telnyx_webrtc/lib/`). Guru API was unavailable (401).*
