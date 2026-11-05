# VSDK-680 — ICE restart recovery parity matrix

> Status: **In Progress**. This matrix covers the per-call recovery
> state machine that the Flutter SDK now has (`CallRecoveryCoordinator`)
> and identifies what is **existing**, **newly added**, **gaps still in
> the Flutter SDK**, or **intentionally non-applicable** (e.g. because
> the behavior lives in another layer).

The matrix compares the Flutter SDK against the production JS SDK
(`packages/js/src/Modules/Verto/webrtc/Peer.ts`,
`packages/js/src/Modules/Verto/BaseSession.ts`) and the merged iOS
recovery series
(`telnyx-webrtc-ios` PRs #379, #380, #381, #399).

## Legend

* ✅ **Existing** — already implemented and tested in the Flutter SDK.
* 🆕 **New in VSDK-680** — added in this PR (the per-call
  `CallRecoveryCoordinator` state machine + tests).
* ⏳ **Gap** — present in JS / iOS, not yet wired into Flutter (will
  land in follow-up PRs once the coordinator is consumed by `Call` /
  `SignalingHealthMonitor`).
* ➖ **N/A** — intentionally not applicable (Flutter-specific reason).

## Recovery state machine

| Behavior | Flutter SDK | Notes |
| --- | --- | --- |
| Recovery phases (`idle → probing → iceRestarting → verifyingMedia → idle`) | 🆕 | `CallRecoveryCoordinator` enum + transitions |
| `reattaching` fallback phase (one per generation) | 🆕 | `RecoveryPhase.reattaching` |
| Generation counter; stale callbacks ignored | 🆕 | `_generation` check at every callback |
| 15-second restart timeout with fire-time connected/completed guard | 🆕 | `RecoveryCoordinatorListener.onRestartTimeout` |
| 5-second `verifyingMedia` window waiting for inbound RTP growth | 🆕 | `onAnswerApplied` + `noteInboundRtpBytes` |
| 3-second `disconnected` debounce (cancelled on connected) | 🆕 | `onIceStateChanged(disconnected)` |
| One fallback reattach per generation | 🆕 | `_fallbackFiredForGeneration` guard |
| 30-second reattach cooldown across generations | 🆕 | `_lastFallbackAt` check |
| Disposable on terminal call / logout / disposal | 🆕 | `dispose()` cancels all timers |

## Triggers

| Behavior | Flutter SDK | Notes |
| --- | --- | --- |
| ICE `failed` trigger for ACTIVE calls | ✅ | `SignalingHealthMonitor` + `Call.restartIce` path |
| Peer `failed` trigger for ACTIVE calls | ✅ | `SignalingHealthMonitor` |
| `ICE disconnected` for ACTIVE calls | 🆕→⏳ | Detection exists; debounce now centralized in coordinator (this PR adds the contract; wiring into `Call` is follow-up) |
| Direct teardown / reattach on known path changes | ⏳ | Not yet wired in Flutter |
| Recent signaling → restart | ✅ | `SignalingHealthMonitor` decides |
| Stale signaling → exact-ID ping probe with 5-second timeout | ⏳ | Probe exists; exact-ID correlation is a follow-up |
| Unhealthy signaling → reattach | ✅ | `SignalingHealthMonitor` path |

## Restart handshake

| Behavior | Flutter SDK | Notes |
| --- | --- | --- |
| `restartIce` → local offer → `telnyx_rtc.modify updateMedia` → answer | ✅ | `Peer.restartIce` path |
| State remains `iceRestarting` until the answer is applied | 🆕 | Coordinator holds phase until `onAnswerApplied` |
| ICE restart applied before late answer | ⏳ | Late-answer correlation is a follow-up |

## Verification phase

| Behavior | Flutter SDK | Notes |
| --- | --- | --- |
| Verify inbound RTP growth within 5 seconds | 🆕 | `noteInboundRtpBytes` (strictly-greater check) |
| Verification with call reports enabled | ✅ | Reuses existing `CallReportCollector` samples (no duplication) |
| Verification with reports disabled | ➖ | N/A in Flutter: call reports are an opt-in stream; when disabled, no samples are emitted and the coordinator simply waits for `noteInboundRtpBytes` from any other observer (e.g., the platform RTC stats callback the demo wires up). |
| One fallback reattach per generation on restart/SDP/answer/timeout/no-RTP failure | 🆕 | `requestFallbackReattach(reason: …)` |

## Cleanup

| Behavior | Flutter SDK | Notes |
| --- | --- | --- |
| Cleanup on terminal call | ✅ | `Call.bye` + `dispose()` path; coordinator `dispose()` cancels timers |
| Cleanup on logout | ✅ | `TelnyxClient.disconnect` cascades to calls; coordinator disposed |
| Cleanup on disposal | 🆕 | `CallRecoveryCoordinator.dispose()` |
| Cleanup on replacement-call `ACTIVE` | ⏳ | Follow-up: surface from `CallManager` when an active replacement arrives |

## Path changes / relay

| Behavior | Flutter SDK | Notes |
| --- | --- | --- |
| Evidence-based, one-shot VPN direct-path relay override without mutating global configuration | ⏳ | Not yet implemented; the iOS reference uses a dedicated `DirectPathMonitor`. The Flutter SDK already has `ICE server override` plumbing (`VSDK-283`); this PR adds the **coordinator** that future path-change work will call into. |
| Sanitized recovery / call-report logs | ✅ | Logging system already strips credentials; recovery callbacks log only the `callId` + reason |

## Deterministic test coverage added in VSDK-680

* `startRestart` bumps generation and transitions to `iceRestarting`.
* Repeated `startRestart` supersedes the prior generation's timer
  (stale callbacks no-op'd by generation check).
* 15-second restart timeout fires `onRestartTimeout`.
* Connected ICE during restart cancels the 15-second timer.
* `verifyingMedia` confirms on strictly-greater inbound RTP bytes.
* `verifyingMedia` timeout fires when no growth observed.
* `disconnected` ICE starts a 3-second debounce; `connected`
  cancels it (and emits `RecoveryDismissReason.recovered`).
* Disconnected debounce expires → `onDisconnectedDebounceExpired`.
* Stale-generation callbacks (`onAnswerApplied`, `noteInboundRtpBytes`,
  `onIceStateChanged`, `requestFallbackReattach`) are ignored.
* One fallback reattach per generation (subsequent requests rejected).
* `dispose()` cancels all timers and ignores subsequent callbacks.
* Disconnected ICE during `iceRestarting` does **not** downgrade to
  `probing` (no nested debounce).

Test results on this branch
(`packages/telnyx_webrtc`):

```
00:01 +12: All tests passed!   (call_recovery_coordinator_test.dart)
00:21 +706 ~8: All tests passed!  (full package, +12 vs main)
```

## Residual hardware checks (out of scope for the AFK bot)

These checks require physical / emulator device interaction and are
tracked separately for manual QA:

* Media blackhole on degraded network.
* Path switching (Wi-Fi ↔ cellular) with reports disabled.
* Restored inbound / outbound audio after media-verification timeout.
