# VSDK-680: ICE restart recovery parity

Flutter now uses the per-call `SignalingHealthMonitor` design shipped on
the other Telnyx mobile SDKs:

* iOS: `telnyx-webrtc-ios` #379, #380, #381, #399
* Android: `telnyx-webrtc-android` #868 (VSDK-678)
* React Native: `react-native-voice-commons` #133 (VSDK-679)

The Flutter port is `CallRecoveryMonitor`
(`packages/telnyx_webrtc/lib/src/recovery/call_recovery_monitor.dart`). It is
internal (not exported) and lands as a stack of PRs:

| PR | Scope |
| --- | --- |
| 1 (#335) | `CallRecoveryMonitor` state machine + deterministic tests. No runtime behavior change. |
| 2 (#358) | Wire the monitor into `Peer` (native and web), `Call` and `TelnyxClient`; retire the client-level `SignalingHealthMonitor` (`TelnyxClient.healthMonitor` stays as a deprecated getter that returns `null`). |
| 3 (#359) | Public `Call.iceRestart()`, demo-app "Restart ICE" action, docs, CHANGELOG. |
| 4 | Live selected-candidate evidence for the VPN relay override; network path change hand-off. |

## Legend

* ✅ PR n: done in that PR of the stack. Notes describe `main` before the
  stack where behavior changed.

## Recovery state machine

| Behavior | Status | Notes |
| --- | --- | --- |
| States `idle → probing → iceRestarting → verifyingMedia → idle`, `reattaching` fallback | ✅ PR 2 | `CallRecoveryState` |
| Generation captured by every async continuation; `cancel()` bumps it | ✅ PR 2 | Late probes, offers, answers and stats reads are no-ops |
| Duplicate failures suppressed while an episode runs | ✅ PR 2 | |
| One reattach per episode; after a failed reattach no new episode until media is seen connected | ✅ PR 2 | `_recoveryFailedLatch` |
| Sanitized logs (call-id prefix + generation; no SDP, addresses or credentials) | ✅ PR 2 | |

## Triggers

| Behavior | Status | Notes |
| --- | --- | --- |
| ICE `failed` on an active call | ✅ PR 2 | Today: client-level `SignalingHealthMonitor.onPeerFailure` |
| Peer-connection `failed`, even while ICE reports connected (DTLS) | ✅ PR 2 | Not handled on `main` |
| ICE / peer-connection `disconnected` for 3 s, judged at fire time | ✅ PR 2 | `main` only emits `iceConnectivityLost` and stops stats |
| Already-connected guard for ICE-triggered episodes | ✅ PR 2 | |
| Ignore non-active calls and failures while the client reconnect flow owns recovery | ✅ PR 2 | |
| Failure during media verification → immediate fallback | ✅ PR 2 | |
| Network path change pre-empts per-call recovery | ✅ PR 4 | Android `onNetworkPathDidChange` |

## Signaling gating

| Behavior | Status | Notes |
| --- | --- | --- |
| Inbound ≤ 3 s **and** confirmed request/response ≤ 45 s → ICE restart | ✅ PR 2 | `main` uses inbound activity only |
| Stale signaling → one correlated `telnyx_rtc.ping` probe, 5 s timeout | ✅ PR 2 | `main` matches the request id but also accepts a `null` id from any ping response; PR 2 removes that path |
| Signaling unavailable → reattach | ✅ PR 2 | |
| Periodic 3 s active-call check: inbound idle ≥ 20 s or confirmed idle ≥ 45 s → health probe | ✅ PR 2 | Runs even while media is connected |
| Media failure during a health probe is deferred, not dropped | ✅ PR 2 | Kept per source and re-checked against the live ICE / peer state when the probe settles, so ICE reconnecting cannot erase a still-failed peer connection (Android behavior; RN #133 keeps one slot) |

## Restart handshake

| Behavior | Status | Notes |
| --- | --- | --- |
| `createOffer(IceRestart)` → `telnyx_rtc.modify` `updateMedia` → answer on the same peer | ✅ PR 2 | `Peer.createIceRestartOffer` / `applyIceRestartAnswer`. On `main` the existing path never ran: the peer session was looked up by the signaling session id |
| Answer correlated with the request that carried the offer | ✅ PR 2 | `main` applies any `updateMedia` response. While a recovery `updateMedia` is in flight, other `updateMedia` responses for that call are ignored, as are late responses to answered, expired or reset recovery ids (Android parity) |
| State stays `iceRestarting` until the answer is applied | ✅ PR 2 | |
| 15 s restart timeout; media reconnected at fire time → verification, else fallback | ✅ PR 2 | |
| Offer / send / apply failure → fallback | ✅ PR 2 | `main` logs `iceRestartFailed` and reconnects without a one-shot guard; a missing local description fails silently |
| A restart that already fell back cannot send its late offer | ✅ PR 2 | Stricter than RN #133 |

## Media verification

| Behavior | Status | Notes |
| --- | --- | --- |
| Baseline sampled on entry; first poll is a warm-up; growth required within 5 s | ✅ PR 2 | An unavailable read is not a baseline: the first later usable counter is (iOS / Android use the first post-answer sample). The deadline is not extended |
| Deadline armed before the first stats read | ✅ PR 2 | |
| Works with call reports disabled | ✅ PR 2 | Reads `getStats()` directly rather than call-report samples |

## Fallback / relay

| Behavior | Status | Notes |
| --- | --- | --- |
| Reattach via the client reconnect flow (VSDK-1197 attach rules) | ✅ PR 2 | |
| Candidate evidence read bounded to 1 s; media episodes only | ✅ PR 4 | |
| One-shot relay override for a failed direct VPN path, without mutating global config | ✅ PR 4 | Live `getStats()` evidence captured at fallback (works without call reports), consumed by the ATTACH for that call; the call-report heuristic still applies |

## Cleanup

| Behavior | Status | Notes |
| --- | --- | --- |
| Cancel on terminal call, hangup, peer disposal, logout / disconnect | ✅ PR 2 | `cancel()` / `dispose()` |
| Cancel when a replacement call becomes active | ✅ PR 2 | |

## Public API

| Behavior | Status | Notes |
| --- | --- | --- |
| `Call.iceRestart(): bool` rejected when not active / no signaling / no peer / recovery running | ✅ PR 3 | `CallRecoveryMonitor.requestIceRestart()` implements the policy |
| Forward to the replacement call after reattach | ✅ PR 3 | |
| `Call.restartIce()` kept as a deprecated alias | ✅ PR 3 | |
| Demo-app "Restart ICE" action on active calls | ✅ PR 3 | |

## Out of scope

* Verto message changes (Android added `trickle` to `ModifyParams`); not
  planned without explicit approval.
* Hardware QA (media blackhole, Wi-Fi ↔ cellular, reports disabled), run
  after PR 2.
