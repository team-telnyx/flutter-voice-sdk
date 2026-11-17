# VSDK-680: ICE restart recovery parity

Flutter is moving to the per-call `SignalingHealthMonitor` design already
shipped on the other Telnyx mobile SDKs:

* iOS: `telnyx-webrtc-ios` #379, #380, #381, #399
* Android: `telnyx-webrtc-android` #868 (VSDK-678)
* React Native: `react-native-voice-commons` #133 (VSDK-679)

The Flutter port is `CallRecoveryMonitor`
(`packages/telnyx_webrtc/lib/src/recovery/call_recovery_monitor.dart`). It is
internal (not exported) and lands as a stack of PRs:

| PR | Scope |
| --- | --- |
| 1 | `CallRecoveryMonitor` state machine + deterministic tests. **No runtime behavior change.** |
| 2 | Wire the monitor into `Peer` (native and web), `Call` and `TelnyxClient`; retire the client-level `SignalingHealthMonitor`. |
| 3 | Public `Call.iceRestart()`, demo-app "Restart ICE" action, docs, CHANGELOG. |
| 4 | Feed live selected-candidate evidence into the existing VPN relay override; network path change hand-off. |

## Legend

* ✅ on `main` today
* 🧩 implemented in `CallRecoveryMonitor` (PR 1), not yet driving calls
* 🔌 wired in PR 2 · 🧑‍💻 PR 3 · 🛰️ PR 4

## Recovery state machine

| Behavior | Status | Notes |
| --- | --- | --- |
| States `idle → probing → iceRestarting → verifyingMedia → idle`, `reattaching` fallback | 🧩 → 🔌 | `CallRecoveryState` |
| Generation captured by every async continuation; `cancel()` bumps it | 🧩 → 🔌 | Late probes, offers, answers and stats reads are no-ops |
| Duplicate failures suppressed while an episode runs | 🧩 → 🔌 | |
| One reattach per episode; after a failed reattach no new episode until media is seen connected | 🧩 → 🔌 | `_recoveryFailedLatch` |
| Sanitized logs (call-id prefix + generation; no SDP, addresses or credentials) | 🧩 → 🔌 | |

## Triggers

| Behavior | Status | Notes |
| --- | --- | --- |
| ICE `failed` on an active call | ✅ / 🧩 → 🔌 | Today: client-level `SignalingHealthMonitor.onPeerFailure` |
| Peer-connection `failed`, even while ICE reports connected (DTLS) | 🧩 → 🔌 | Not handled on `main` |
| ICE / peer-connection `disconnected` for 3 s, judged at fire time | 🧩 → 🔌 | `main` only emits `iceConnectivityLost` and stops stats |
| Already-connected guard for ICE-triggered episodes | 🧩 → 🔌 | |
| Ignore non-active calls and failures while the client reconnect flow owns recovery | 🧩 → 🔌 | |
| Failure during media verification → immediate fallback | 🧩 → 🔌 | |
| Network path change pre-empts per-call recovery | 🛰️ | Android `onNetworkPathDidChange` |

## Signaling gating

| Behavior | Status | Notes |
| --- | --- | --- |
| Inbound ≤ 3 s **and** confirmed request/response ≤ 45 s → ICE restart | 🧩 → 🔌 | `main` uses inbound activity only |
| Stale signaling → one correlated `telnyx_rtc.ping` probe, 5 s timeout | ✅ partial / 🧩 → 🔌 | `main` matches the request id but also accepts a `null` id from any ping response; PR 2 removes that path |
| Signaling unavailable → reattach | ✅ / 🧩 → 🔌 | |
| Periodic 3 s active-call check: inbound idle ≥ 20 s or confirmed idle ≥ 45 s → health probe | 🧩 → 🔌 | Runs even while media is connected |
| Media failure during a health probe is deferred, not dropped | 🧩 → 🔌 | Kept per source and re-checked against the live ICE / peer state when the probe settles, so ICE reconnecting cannot erase a still-failed peer connection (Android behavior; RN #133 keeps one slot) |

## Restart handshake

| Behavior | Status | Notes |
| --- | --- | --- |
| `createOffer(IceRestart)` → `telnyx_rtc.modify` `updateMedia` → answer on the same peer | ✅ | `Peer.startIceRenegotiation` / `handleUpdateMediaResponse` |
| Answer correlated with the request that carried the offer | 🔌 | `main` applies any `updateMedia` response |
| State stays `iceRestarting` until the answer is applied | 🧩 → 🔌 | |
| 15 s restart timeout; media reconnected at fire time → verification, else fallback | 🧩 → 🔌 | |
| Offer / send / apply failure → fallback | 🧩 → 🔌 | `main` logs `iceRestartFailed` and reconnects without a one-shot guard; a missing local description fails silently |
| A restart that already fell back cannot send its late offer | 🧩 → 🔌 | Stricter than RN #133 |

## Media verification

| Behavior | Status | Notes |
| --- | --- | --- |
| Baseline sampled on entry; first poll is a warm-up; growth required within 5 s | 🧩 → 🔌 | An unavailable read is not a baseline: the first later usable counter is (iOS / Android use the first post-answer sample). The deadline is not extended |
| Deadline armed before the first stats read | 🧩 → 🔌 | |
| Works with call reports disabled | 🔌 | Reads `getStats()` directly rather than call-report samples |

## Fallback / relay

| Behavior | Status | Notes |
| --- | --- | --- |
| Reattach via the client reconnect flow (VSDK-1197 attach rules) | ✅ / 🔌 | |
| Candidate evidence read bounded to 1 s; media episodes only | 🧩 → 🛰️ | |
| One-shot relay override for a failed direct VPN path, without mutating global config | ✅ partial / 🛰️ | `main` derives it from call-report samples at reattach; PR 4 feeds live evidence |

## Cleanup

| Behavior | Status | Notes |
| --- | --- | --- |
| Cancel on terminal call, hangup, peer disposal, logout / disconnect | 🧩 → 🔌 | `cancel()` / `dispose()` |
| Cancel when a replacement call becomes active | 🔌 | |

## Public API

| Behavior | Status | Notes |
| --- | --- | --- |
| `Call.iceRestart(): bool` rejected when not active / no signaling / no peer / recovery running | 🧩 → 🧑‍💻 | `CallRecoveryMonitor.requestIceRestart()` implements the policy |
| Forward to the replacement call after reattach | 🧑‍💻 | |
| `Call.restartIce()` kept as a deprecated alias | 🧑‍💻 | |
| Demo-app "Restart ICE" action on active calls | 🧑‍💻 | |

## Out of scope

* Verto message changes (Android added `trickle` to `ModifyParams`); not
  planned without explicit approval.
* Hardware QA (media blackhole, Wi-Fi ↔ cellular, reports disabled), run
  after PR 2.
