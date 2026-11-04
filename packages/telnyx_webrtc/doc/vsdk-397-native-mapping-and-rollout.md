# VSDK-397 — Flutter Native Mapping & Rollout Strategy

## Objective

Map the remaining JS SDK parity gaps to a concrete implementation plan for
the Flutter Voice SDK and define a rollout strategy for the structured
error/warning system.

## Background

PR #312 ([VSDK-395/396/415/416]) merged the core structured error reporting
system: 24 error codes, 26 warning codes, unified stream API,
SignalingHealthMonitor, RequestTimeoutTracker, and migration docs. Five
parity review agents compared every layer against the JS SDK and found gaps.
Four fix agents closed all critical and major gaps. This document covers the
remaining minor gaps and the rollout plan.

## Remaining Parity Gaps (this PR)

### 1. TOKEN_EXPIRING_SOON (34001) — Warning

**JS:** `BaseSession._checkTokenExpiry()` decodes the JWT `login_token`,
extracts `exp`, and schedules a `setTimeout` to fire `TOKEN_EXPIRING_SOON`
120 s before expiry. If already within 120 s of expiry, emits immediately.

**Flutter plan:** Add `_checkTokenExpiry()` to `TelnyxClient`, called after
`tokenLogin()`. Decode the JWT payload (base64url), extract `exp`, schedule a
`Timer` to emit `TelnyxWarningCodes.tokenExpiringSoon` 120 s before expiry.
Clear the timer on disconnect and on new login.

**Mobile relevance:** ✅ JWT tokens are used by Flutter clients (TokenConfig).
Proactive expiry warnings let the app refresh credentials before the session
drops.

### 2. UNKNOWN_REATTACHED_SESSION (35002) — Warning

**JS:** `VertoHandler` Attach handler: when an Attach arrives for a `callID`
that doesn't match any active call AND the SDK has active calls in cache, it
emits `UNKNOWN_REATTACHED_SESSION`. If the SDK has NO active calls (page
reload scenario), it recovers the first arrived Attach without warning.

**Flutter plan:** In `telnyx_client.dart` `SocketMethod.attach` handler: before
creating the new call, check if `calls` is non-empty AND the Attach's callID
is not in `calls`. If so, emit `TelnyxWarningCodes.unknownReattachedSession`.
Proceed with call creation/acceptance (don't block).

**Mobile relevance:** ✅ Flutter uses reconnect tokens (VSDK-418). After a
socket reconnect, Attach messages arrive to restore calls. An unknown Attach
with other active calls indicates server-side state mismatch — important
diagnostic signal.

### 3. RECONNECTION_FAILED_WITH_NO_AUTO_RECONNECT (36005) — Warning

**JS:** `BaseSession.onNetworkClose()`: when auto-reconnect is disabled and
the socket closes unexpectedly (not intentional), emits
`RECONNECTION_FAILED_WITH_NO_AUTO_RECONNECT`. Intentional disconnects are
excluded via `_intentionalClose` flag.

**Flutter plan:** In `_onClose()`: when `!wasClean && !_autoReconnectLogin &&
!_explicitDisconnectInProgress`, emit
`TelnyxWarningCodes.reconnectionFailedWithNoAutoReconnect`. The existing
`_explicitDisconnectInProgress` flag serves the same purpose as JS
`_intentionalClose`.

**Mobile relevance:** ✅ Mobile clients may disable auto-reconnect (battery
or network management). Surfacing the warning lets the app decide whether to
prompt the user or retry manually.

### 4. Probe Timeout Without Media Recovery — Health Monitor Fix

**JS:** `_check()` tests probe timeout unconditionally — if the probe has been
in flight longer than `PROBE_TIMEOUT_MS`, it triggers socket reconnect
regardless of whether media recovery is pending.

**Flutter plan:** In `SignalingHealthMonitor._onCheck()`: add a probe-timeout
check before the `_pendingMediaRecovery` check. If `_isProbeInFlight` and
`_probeStartedAt` exceeds `_probeTimeout`, call `_session.socketDisconnect()`.

**Mobile relevance:** ✅ A dangling probe (send failed, response lost) should
not persist indefinitely. On mobile, network transitions can cause probe
send failures, and the probe must time out to trigger recovery.

### 5. ICE Restart "Not Started" Over-Escalation — Health Monitor Fix

**JS:** When `triggerIceRestart()` returns `{started: false}`, the monitor
logs and returns. It does NOT call `onIceRestartFailed`. Only actual ICE
failures (via `onPeerFailure`) or Modify request failures (via timeout)
trigger socket reconnect.

**Flutter plan:** In `_healthTriggerIceRestart()`: when `call.restartIce()`
returns `false`, distinguish "not started" (benign — call in terminal state,
no peer connection) from "started but failed". For "not started", log and
return without calling `onIceRestartFailed`. Remove the structured error
emission for this case (it's not a real failure).

**Mobile relevance:** ✅ On mobile, `restartIce()` may return `false` when
the call is ending (user hangs up during recovery). Escalating to socket
reconnect in this case causes unnecessary network churn.

### 6. One-Warning-Per-Tick → Per-Code Throttling — QualityWarningMonitor Fix

**JS:** `CallReportCollector._trackBreach()` evaluates each code
independently. Multiple metrics can breach on the same interval, and each
emits its own warning (throttled independently by 15 s per code).

**Flutter plan:** Remove the `emittedThisInterval` flag from
`QualityWarningMonitor.checkStats()`. Each `_emit()` call already has its own
per-code throttle (`_intervalsSinceEmission`). The flag was over-suppressing
legitimate simultaneous warnings.

**Mobile relevance:** ✅ On mobile networks, multiple quality metrics often
degrade simultaneously (e.g., high RTT + high jitter + low MOS). Suppressing
all but one hides the full picture from diagnostics.

## Gaps Not Being Addressed (Justified)

| Code | Reason |
|------|--------|
| 32003/32004 RECORDING_* | Flutter has no call recorder. Feature gap, not parity gap. |
| 33011 SHARED_REMOTE_ELEMENT_OVERWRITE | Web-only DOM concept. N/A for Flutter. |
| 44004 SUBSCRIBE_FAILED | No subscribe flow in Flutter. Out of scope. |
| Type-level media error narrowing | Dart doesn't have TS literal unions. Runtime behavior is equivalent. |
| Sealed class error events | Nice-to-have refactor, not a parity gap. Medium effort, changes public API. |
| `isCriticalMethod` enforcement in tracker | Convention-based in Flutter. Low risk. |

## Rollout Strategy

### Phase 1: This PR (VSDK-397 completion)

All changes are additive (new emission sites, bug fixes in existing logic).
No breaking changes to public API. All changes are behind the existing
`_enableStructuredErrors` flag (default: true).

**Testing:**
- Existing 629 tests must pass
- `dart analyze` must show no new issues
- `dart format` clean
- Manual verification: token expiry warning, unknown reattach warning,
  no-auto-reconnect warning, probe timeout recovery, multi-warning emission

### Phase 2: Post-merge

- Monitor production telemetry for new warning emissions
- Verify no false positives in normal call flows
- Document any behavioral differences from JS in the migration guide

### Phase 3: Future cleanup (v3.0.0)

- Remove deprecated `SdkErrorCode`, `SdkWarningCode`, legacy aliases
- Consider sealed class hierarchy for error events
- Evaluate whether `TelnyxWarning.callId/sessionId` should move to event only

## Summary

| Gap | Type | Severity | Action |
|-----|------|----------|--------|
| 34001 TOKEN_EXPIRING_SOON | Warning emission | Minor | Implement |
| 35002 UNKNOWN_REATTACHED_SESSION | Warning emission | Minor | Implement |
| 36005 RECONNECTION_FAILED_WITH_NO_AUTO_RECONNECT | Warning emission | Minor | Implement |
| Probe timeout without media recovery | Health monitor fix | Minor | Fix |
| ICE restart "not started" over-escalation | Health monitor fix | Minor | Fix |
| One-warning-per-tick suppression | QWM behavioral fix | Minor | Fix |
| 32003/32004 RECORDING_* | Feature gap | Info | Defer (no recorder) |
| 33011 SHARED_REMOTE_ELEMENT_OVERWRITE | N/A | Info | Defer (web-only) |
| 44004 SUBSCRIBE_FAILED | Out of scope | Info | Defer |
