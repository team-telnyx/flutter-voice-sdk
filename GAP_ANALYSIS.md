# Telnyx Flutter Voice SDK — Gap Analysis vs JS WebRTC SDK

**Date:** 2026-07-09  
**Reference:** JS SDK at `~/telnyx/webrtc/packages/js/src/` (v2.x)  
**Subject:** Flutter SDK at `~/telnyx/flutter-voice-sdk/packages/telnyx_webrtc/lib/`

---

## Executive Summary

The Flutter SDK covers the **core call lifecycle** (connect, invite, answer, hangup, hold, mute, DTMF, push notifications, call reports, latency tracking, AI conversation/transcript) and has some features the JS SDK lacks (multi-call `CallManager`, `LatencyTracker` milestones, push-notification flows). However, it is missing significant pieces of the JS SDK's surface area in **media device management, screen sharing, video calls, conference actions, call recording, structured error/warning systems, pre-call diagnostics, signaling health monitoring, media permission recovery, and bandwidth control**.

| Category | JS SDK | Flutter SDK | Status |
|----------|--------|-------------|--------|
| Call control (invite/answer/hangup/hold/mute/dtmf) | ✅ | ✅ | **Parity** |
| Multi-call management | Partial (calls map) | ✅ CallManager | **Flutter ahead** |
| Push notifications | ❌ (browser-only) | ✅ | **Flutter ahead** |
| Latency tracking | ❌ | ✅ LatencyTracker | **Flutter ahead** |
| Media device management | ✅ Full | ❌ | **Missing** |
| Screen share | ✅ | ❌ | **Missing** |
| Video call support | ✅ | ❌ | **Missing** |
| Conference actions | ✅ | ❌ | **Missing** |
| Call recording | ✅ CallRecorder | ❌ | **Missing** |
| Pre-call diagnostics | ✅ PreCallDiagnosis | ❌ | **Missing** |
| Signaling health monitor | ✅ | ❌ | **Missing** |
| Structured error/warning system | ✅ Full | Minimal | **Partial** |
| Media permission recovery | ✅ | ❌ | **Missing** |
| Bandwidth control | ✅ | ❌ | **Missing** |
| Reconnect token / session persistence | ✅ | ❌ | **Missing** |
| LogCollector | ✅ | ✅ (call_report_log_collector) | **Parity** |
| Call report collector | ✅ | ✅ | **Parity** |
| MOS calculation | ✅ | ✅ | **Parity** |
| AI conversation | ✅ | ✅ | **Parity** |
| ICE servers config | ✅ | ✅ | **Parity** |
| Custom logging | ✅ | ✅ | **Parity** |

---

## Prioritized Gap List

### P0 — Critical (blocking production use cases)

#### 1. No Structured Error/Warning System
- **JS SDK:** `TelnyxError` class with `code`, `name`, `description`, `causes`, `solutions`, `fatal` fields. Full error code registry (`TELNYX_ERROR_CODES`) covering SDP (400xx), Media (420xx), Call-control (440xx), WebSocket (450xx), Auth (460xx), ICE restart (470xx), Network (480xx), Session (485xx), General (490xx). Warning system (`SDK_WARNINGS`, `TELNYX_WARNING_CODES`) for network quality (310xx), connection (320xx), call connection (330xx), auth (340xx), session (350xx).
  - Files: `Modules/Verto/util/errors.ts`, `Modules/Verto/util/constants/errorCodes.ts`, `Modules/Verto/util/constants/warnings.ts`
- **Flutter SDK:** `TelnyxSocketError` (simple `errorCode` + `errorMessage`), `TelnyxErrorConstants` (4 hardcoded constants only).
  - Files: `model/telnyx_socket_error.dart`
- **Impact:** Apps cannot programmatically distinguish error types, show user-facing remediation, or classify fatal vs recoverable errors. No warning events at all.
- **Recommendation:** Port the full `TelnyxError` class, error code registry, warning code registry, and `telnyx.error`/`telnyx.warning` event emission to Flutter.

#### 2. No Signaling Health Monitor
- **JS SDK:** `SignalingHealthMonitor` class — periodic liveness checks, WS probe (Ping), probe timeout, single recovery decision authority (socket reconnect vs ICE restart), browser online/offline detection, critical method timeout tracking.
  - File: `Modules/Verto/services/SignalingHealthMonitor.ts`
- **Flutter SDK:** No equivalent. Has `_checkReconnection()` and connectivity_plus subscription, but no WS-level liveness probing, no unified recovery decision authority, no probe/timeout mechanism.
- **Impact:** Stale WebSocket connections (half-open TCP) go undetected during active calls. The SDK cannot distinguish "signaling unhealthy → reconnect socket" from "signaling healthy but media unhealthy → ICE restart", potentially applying wrong recovery.
- **Recommendation:** Port `SignalingHealthMonitor` with its probe, timeout, and single-decision-authority logic.

#### 3. No Media Permission Recovery
- **JS SDK:** `mediaPermissionsRecovery` config option. On `getUserMedia` failure during inbound call answer, emits a recoverable `telnyx.error` event with `resume()` and `reject()` callbacks. App can prompt user to fix permissions before call fails.
  - File: `utils/interfaces.ts` (`IClientOptions.mediaPermissionsRecovery`)
- **Flutter SDK:** No equivalent. `getUserMedia` failures are terminal.
- **Impact:** On mobile, mic permission denial during incoming call = immediate call failure with no recovery path. Common on first install.
- **Recommendation:** Add media permission recovery flow with `resume()`/`reject()` callbacks.

#### 4. No Reconnect Token / Session Persistence
- **JS SDK:** `reconnect.ts` — stores `voice_sdk_id` (reconnect token) in `sessionStorage`, persists active calls across page reloads, 90-second max age for session recovery, 15-minute recovery marker. On reconnect, sends `voice_sdk_id` as URL param to reattach to same backend session.
  - File: `Modules/Verto/util/reconnect.ts`
- **Flutter SDK:** No equivalent. Has `_pushMetaData?.voiceSdkId` but only used for push notification flows, not session reattachment after network reconnection.
- **Impact:** After app kill/relaunch or deep sleep, the SDK cannot reattach to the previous backend session. Active calls are lost.
- **Recommendation:** Implement reconnect token persistence (SharedPreferences) and session reattachment on app restart.

---

### P1 — Important (degraded functionality, missing key features)

#### 5. No Media Device Management
- **JS SDK:** `BrowserSession` exposes:
  - `checkPermissions(audio, video)` — pre-check mic/camera permissions
  - `getAudioInDevices()`, `getAudioOutDevices()`, `getVideoDevices()` — enumerate devices
  - `getDeviceResolutions(deviceId)` — supported resolutions
  - `setAudioSettings(settings)` — micId, micLabel, echoCancellation, noiseSuppression, autoGainControl
  - `mediaConstraints` getter
  - `speaker` getter/setter
  - Per-call: `setAudioInDevice(deviceId)`, `setAudioOutDevice(deviceId)`, `setVideoDevice(deviceId)`
  - Files: `Modules/Verto/BrowserSession.ts`, `Modules/Verto/webrtc/BaseCall.ts`
- **Flutter SDK:** No device enumeration, no `setAudioInDevice`, no `setAudioOutDevice`, no `setVideoDevice`, no `getDeviceResolutions`. Has `AudioConstraints` (echoCancellation, noiseSuppression, autoGainControl) and `getSupportedAudioCodecs()`, but no device-level management.
- **Impact:** Users cannot switch mic/speaker/bluetooth during a call. No device listing for settings UI.
- **Recommendation:** Add device enumeration via `flutter_webrtc` and per-call device switching methods.

#### 6. No Screen Share
- **JS SDK:** `Call.startScreenShare()`, `Call.stopScreenShare()`, `call.screenShare` property (a child `Call` object for the screen-share stream).
  - File: `Modules/Verto/webrtc/Call.ts` (lines 72–110)
- **Flutter SDK:** No equivalent.
- **Impact:** No screen sharing capability for collaborative use cases.
- **Recommendation:** Implement using `flutter_webrtc`'s `getDisplayMedia()` equivalent on supported platforms.

#### 7. No Video Call Support
- **JS SDK:** Full video call support — `video` constraints in `ICallOptions`, `isVideoCall` getter, `muteVideo()`, `unmuteVideo()`, `setVideoDevice()`, `localElement`/`remoteElement` for video rendering, `camId`/`camLabel` device selection.
  - Files: `Modules/Verto/webrtc/BaseCall.ts`, `Modules/Verto/webrtc/Call.ts`, `utils/interfaces.ts`
- **Flutter SDK:** Audio-only. `Peer` has `_localStream`/`_remoteStreams` but no video-specific API, no video mute, no camera device selection, no video element management.
- **Impact:** No video calling. Significant feature gap for modern communication apps.
- **Recommendation:** Add video constraints to call options, video mute/unmute, camera device selection, and video rendering hooks.

#### 8. No Conference Actions
- **JS SDK:** Full conference support via `BaseCall.handleConferenceUpdate()` — handles Join, Leave, Bootstrap, Add, Modify, Delete, Clear, ChatMessage, LayerInfo, LogoInfo, LayoutInfo, LayoutList, ModCmdResponse. Subscribes to conference chat/info channels. `MCULayoutEventHandler` for canvas/layout events. `ConferenceAction` enum.
  - Files: `Modules/Verto/webrtc/BaseCall.ts` (lines 1551–1720), `Modules/Verto/webrtc/LayoutHandler.ts`, `Modules/Verto/webrtc/constants.ts` (`ConferenceAction`)
- **Flutter SDK:** No conference handling at all. No `ConferenceAction` enum, no `handleConferenceUpdate`, no subscribe/unsubscribe for conference channels.
- **Impact:** Conference/multi-party call scenarios unsupported.
- **Recommendation:** Port conference event handling, `ConferenceAction` enum, and conference channel subscription.

#### 9. No Call Recording
- **JS SDK:** `CallRecorder` class — captures raw audio from `MediaStreamTrackProcessor`, synthesizes RTP packets, bounded ring buffer, intermediate flushes, `.pcap` output. Config options: `callRecording`, `callRecordingTracks`, `callRecordingEndpoint`, `callRecordingFlushIntervalMs`, `callRecordingMaxBufferBytes`.
  - File: `Modules/Verto/webrtc/CallRecorder.ts`
- **Flutter SDK:** No equivalent.
- **Impact:** Cannot capture call audio for debugging/quality diagnosis.
- **Recommendation:** Implement platform-specific audio capture (platform channel for Android/iOS audio recording).

#### 10. No Pre-Call Diagnostics
- **JS SDK:** `PreCallDiagnosis` class — runs ICE candidate stats collection, MOS calculation, quality assessment, network tests before placing a call. Exports `RTCIceCandidateStats`, `MinMaxAverage`, `TelnyxIDs` interfaces.
  - File: `PreCallDiagnosis.ts`
- **Flutter SDK:** No equivalent. Has `MosCalculator` and `CallQualityMetrics` for in-call stats, but no pre-call diagnostic tool.
- **Impact:** Cannot assess network quality before placing a call.
- **Recommendation:** Add a `PreCallDiagnosis` class that runs ICE gathering + network tests and reports quality before call initiation.

#### 11. No `deaf`/`undeaf` Methods
- **JS SDK:** `call.deaf()` disables remote audio tracks (stop hearing remote party), `call.undeaf()` re-enables. Distinct from mute (which stops sending local audio).
  - File: `Modules/Verto/webrtc/BaseCall.ts` (lines 1222–1240)
- **Flutter SDK:** No equivalent. Only has `onMuteUnmutePressed()` / `setMuteState()` for local mic.
- **Impact:** Cannot mute incoming audio (e.g., for privacy or to take notes during a call).
- **Recommendation:** Add `deaf()`/`undeaf()` methods that disable/enable remote stream audio tracks.

#### 12. No `toggleHold` Method
- **JS SDK:** `call.toggleHold()` — smart hold/unhold toggle.
  - File: `Modules/Verto/webrtc/BaseCall.ts` (line 858)
- **Flutter SDK:** Only has `onHoldUnholdPressed()` which does toggle, but it's a UI-oriented method name, not matching the JS API.
- **Impact:** Minor API naming inconsistency.
- **Recommendation:** Alias `toggleHold()` to existing `onHoldUnholdPressed()`.

#### 13. No Bandwidth Control
- **JS SDK:** `setBandwidthEncodingsMaxBps(max, kind)` — dynamically adjust bitrate during a call via RTCRtpSender `setParameters()`. `mediaSettings` with `useSdpASBandwidthKbps` / `sdpASBandwidthKbps`.
  - File: `Modules/Verto/webrtc/BaseCall.ts` (lines 1252–1310)
- **Flutter SDK:** No equivalent.
- **Impact:** Cannot dynamically adjust call quality based on network conditions.
- **Recommendation:** Add bandwidth control via `flutter_webrtc` RTP sender parameters.

#### 14. No `MediaDeviceCollector`
- **JS SDK:** `MediaDeviceCollector` class — logs all audio devices at call start, listens for `devicechange` events mid-call, logs device add/remove. Helps debug "agent can't hear audio" issues.
  - File: `Modules/Verto/webrtc/MediaDeviceCollector.ts`
- **Flutter SDK:** No equivalent.
- **Impact:** Harder to diagnose device-related audio issues in production.
- **Recommendation:** Add device state logging to call report collector.

#### 15. No `telnyx.warning` Event System
- **JS SDK:** Emits structured warnings via `telnyx.warning` event — `ITelnyxWarning` with `code`, `name`, `message`, `description`, `causes`, `solutions`. Covers: HIGH_RTT, HIGH_JITTER, HIGH_PACKET_LOSS, LOW_MOS, LOW_LOCAL_AUDIO, LOW_INBOUND_AUDIO, LOW_BYTES_RECEIVED, LOW_BYTES_SENT, RECORDING_UNAVAILABLE, ICE_CONNECTIVITY_LOST, ICE_GATHERING_TIMEOUT, ICE_GATHERING_EMPTY, PEER_CONNECTION_FAILED, ONLY_HOST_ICE_CANDIDATES, etc.
  - Files: `Modules/Verto/util/constants/warnings.ts`, `Modules/Verto/util/errors.ts`
- **Flutter SDK:** No warning event system. `CallQualityMetrics` reports quality but doesn't emit structured warnings.
- **Impact:** Apps cannot proactively warn users about degraded conditions or take automated corrective action.
- **Recommendation:** Port the warning code registry and emit `telnyx.warning` events.

---

### P2 — Nice-to-Have (API completeness, developer experience)

#### 16. No `webRTCInfo()` / `webRTCSupportedBrowserList()` Static Methods
- **JS SDK:** `TelnyxRTC.webRTCInfo()` returns WebRTC support info, `TelnyxRTC.webRTCSupportedBrowserList()` returns supported OS/browser matrix.
  - File: `TelnyxRTC.ts` (lines 275–307)
- **Flutter SDK:** No equivalent (not needed on mobile, but useful for web target).
- **Impact:** Minimal — `flutter_webrtc` handles platform support.
- **Recommendation:** Skip for mobile-only; add if Flutter web target is supported.

#### 17. No `vertoSubscribe`/`vertoUnsubscribe` Public API
- **JS SDK:** `BrowserSession.vertoSubscribe({nodeId, channels, handler})` and `vertoUnsubscribe({nodeId, channels})` — subscribe to arbitrary Verto event channels.
  - File: `Modules/Verto/BrowserSession.ts` (lines 904–940)
- **Flutter SDK:** No public subscribe/unsubscribe API.
- **Impact:** Cannot subscribe to custom event channels (used by conference chat, conference info, MCU layout).
- **Recommendation:** Add as internal API if conference support is implemented.

#### 18. No `localElement`/`remoteElement` Media Element Management
- **JS SDK:** `BrowserSession.localElement`/`remoteElement` setters/getters — manage HTML `<audio>`/`<video>` elements for local/remote media rendering.
  - File: `Modules/Verto/BrowserSession.ts` (lines 794–885)
- **Flutter SDK:** Uses `flutter_webrtc` `RTCVideoRenderer` instead (platform-appropriate). Has `onLocalStream`/`onAddRemoteStream` callbacks on `Peer`.
- **Impact:** N/A — different rendering paradigm. No action needed.
- **Recommendation:** No change — Flutter uses stream callbacks which is the correct platform approach.

#### 19. No `autoRecoverCalls` Configuration
- **JS SDK:** `BrowserSession.autoRecoverCalls` boolean (default `true`) — controls whether calls are automatically recovered on reconnection.
  - File: `Modules/Verto/BrowserSession.ts` (line 174)
- **Flutter SDK:** Has `autoReconnect` on `Config` but no `autoRecoverCalls` toggle. Call recovery is automatic.
- **Impact:** Apps cannot opt out of automatic call recovery.
- **Recommendation:** Add `autoRecoverCalls` config option.

#### 20. No `hangupOnBeforeUnload` Configuration
- **JS SDK:** `IClientOptions.hangupOnBeforeUnload` (default `true`) — sends BYE on page unload.
  - File: `utils/interfaces.ts`
- **Flutter SDK:** Has `BackgroundDetector` in demo app, but not in SDK itself.
- **Impact:** Minor — app lifecycle management is the app's responsibility on mobile.
- **Recommendation:** Consider adding `onAppLifecycleStateChange` hook to SDK.

#### 21. No `debugOutput` Option ('socket' | 'file')
- **JS SDK:** `IClientOptions.debugOutput` — route debug data to WebSocket or file.
- **Flutter SDK:** Has `debug` boolean and `callReportLogLevel`/`callReportMaxLogEntries` but no `debugOutput` mode selector.
- **Impact:** Minor — debug output goes to logger only.
- **Recommendation:** Add `debugOutput` option for routing stats to file vs WebSocket.

#### 22. No `prefetchIceCandidates` Per-Call Option
- **JS SDK:** `ICallOptions.prefetchIceCandidates` (default `true`) — pre-gather ICE candidates before `setLocalDescription`.
  - File: `utils/interfaces.ts`
- **Flutter SDK:** Has `useTrickleIce` per-call option but no `prefetchIceCandidates`.
- **Impact:** Minor — trickle ICE partially addresses this.
- **Recommendation:** Add `prefetchIceCandidates` option for non-trickle ICE calls.

#### 23. No `recoveredCallId` on Call Object
- **JS SDK:** `BaseCall.recoveredCallId` — set during reattachment/recovery to correlate new call with ended call.
  - File: `Modules/Verto/webrtc/BaseCall.ts` (line 143)
- **Flutter SDK:** Has `isReconnection` boolean flag but no `recoveredCallId`.
- **Impact:** Apps cannot correlate recovered call with original call for UI cleanup.
- **Recommendation:** Add `recoveredCallId` field to `Call`.

#### 24. No `LogCollector` as Separate Class
- **JS SDK:** `LogCollector` class — captures debug-level logs during calls for inclusion in call reports. Configurable level, max entries.
  - File: `Modules/Verto/util/LogCollector.ts`
- **Flutter SDK:** Has `CallReportLogCollector` (in `utils/stats/call_report_log_collector.dart`) which serves the same purpose.
- **Impact:** **Parity** — just different naming.
- **Recommendation:** No change needed.

#### 25. No `MCULayoutEventHandler`
- **JS SDK:** `LayoutHandler.ts` — handles MCU canvas/layout events for video conferences (layer-info, layout-info).
  - File: `Modules/Verto/webrtc/LayoutHandler.ts`
- **Flutter SDK:** No equivalent.
- **Impact:** No MCU video layout management.
- **Recommendation:** Implement if conference + video support is added.

#### 26. No `RequestTimeoutError` / `StaleRequestError` Classes
- **JS SDK:** `RequestTimeoutError` and `StaleRequestError` custom error classes for signaling request lifecycle.
  - File: `Modules/Verto/util/errors.ts` (lines 213–250)
- **Flutter SDK:** No equivalent custom error classes.
- **Impact:** Cannot distinguish request timeout vs stale request vs generic error.
- **Recommendation:** Add as part of the structured error system (P0 #1).

#### 27. No `CallReportCollector.shouldForceRelayCandidateForRecovery()` Method
- **JS SDK:** `CallReportCollector.shouldForceRelayCandidateForRecovery()` — determines if ICE restart should force relay based on stats history.
  - File: `Modules/Verto/webrtc/CallReportCollector.ts` (line 1001)
- **Flutter SDK:** Has `forceRelayCandidate` config but no dynamic recovery decision from stats.
- **Impact:** Less intelligent ICE restart recovery.
- **Recommendation:** Add stats-based relay candidate force decision.

#### 28. No `Call.flushIntermediateCallReport()` Method
- **JS SDK:** `BaseCall.flushIntermediateCallReport(reason)` — flush intermediate call report data during an active call (not just at end).
  - File: `Modules/Verto/webrtc/BaseCall.ts` (line 2771)
- **Flutter SDK:** Posts call report at end of call only (`_stopStatsAndPostReport`).
- **Impact:** Long calls lose all stats if app crashes.
- **Recommendation:** Add intermediate call report flushing on a timer.

#### 29. No `Connection` Class with WebSocket State Tracking
- **JS SDK:** `Connection` class — manages WebSocket lifecycle, `socketGeneration`, `lastInboundAt` timestamp, `upDur`/`downDur` timing, `DEFAULT_REQUEST_TIMEOUT_MS`, reconnect token injection, canary URL logic, `onSocketActivity()` for signaling health.
  - File: `Modules/Verto/services/Connection.ts`
- **Flutter SDK:** Uses `TxSocket` class with `onOpen`/`onClose`/`onMessage` callbacks. Has `_connectionGeneration` and `latencyTracker` but no `lastInboundAt` tracking or request timeout mechanism.
- **Impact:** Less robust WebSocket lifecycle management.
- **Recommendation:** Port key Connection features into `TxSocket` or a new `Connection` wrapper.

#### 30. No `SwEvent` Enum / Event Emitter Pattern
- **JS SDK:** `SwEvent` enum with all event types (`telnyx.ready`, `telnyx.error`, `telnyx.warning`, `telnyx.notification`, `telnyx.stats.frame`, `telnyx.stats.report`, `telnyx.ai.conversation`, etc.) and `.on()`/`.off()` event listener pattern.
  - File: `Modules/Verto/util/constants/index.ts` (SwEvent enum)
- **Flutter SDK:** Uses callback-based pattern (`onSocketMessageReceived`, `onSocketErrorReceived`, `onTranscriptUpdate`, `onConnectionStateChanged`, `onConnectionMetricsUpdate`) instead of event emitter.
- **Impact:** Different API paradigm. Not a gap per se, but fewer event types are exposed. Missing: `telnyx.error`, `telnyx.warning`, `telnyx.stats.frame`, `telnyx.stats.report`, `telnyx.rtc.mediaError`, `telnyx.rtc.peerConnectionFailureError`.
- **Recommendation:** Either add more callbacks or migrate to a Dart `Stream`-based event bus.

---

## Demo App Coverage

The demo app (`~/telnyx/flutter-voice-sdk/lib/`) demonstrates:

| Feature | Demonstrated? |
|---------|--------------|
| Credential login | ✅ |
| Token login | ✅ |
| Anonymous (AI) login | ✅ |
| Outbound call | ✅ |
| Inbound call | ✅ |
| Hold/Unhold | ✅ |
| Mute/Unmute | ✅ |
| Speaker phone | ✅ |
| DTMF | ✅ |
| Call quality metrics | ✅ |
| Call history | ✅ |
| Push notifications (FCM/APNS) | ✅ |
| CallKit integration | ✅ |
| AI conversation / transcript | ✅ |
| Multi-call (hold+accept, end+accept) | ✅ |
| Trickle ICE | ✅ |
| Codec selection | ✅ |
| Audio constraints (echo/noise/AGC) | ✅ |
| Region selection | ✅ |
| Force relay candidate | ✅ |
| Custom ICE servers | ✅ |
| Connection metrics | ✅ |
| Latency tracking | ✅ |
| Screen share | ❌ |
| Video call | ❌ |
| Conference | ❌ |
| Call recording | ❌ |
| Pre-call diagnostics | ❌ |
| Device enumeration/switching | ❌ |
| Bandwidth control | ❌ |
| Deaf/undeaf | ❌ |
| Media permission recovery | ❌ |

---

## Summary by Priority

| Priority | Count | Key Themes |
|----------|-------|------------|
| **P0** | 4 | Structured errors/warnings, signaling health, media permission recovery, reconnect token |
| **P1** | 11 | Device management, screen share, video, conference, recording, diagnostics, deaf/undeaf, bandwidth, warning events |
| **P2** | 15 | API completeness, event system parity, MCU layout, intermediate reports, request timeouts, recovered call ID |

## Recommended Implementation Order

1. **P0 #1** — Structured error/warning system (foundation for all other error handling)
2. **P0 #2** — Signaling health monitor (critical for call stability)
3. **P0 #3** — Media permission recovery (common mobile scenario)
4. **P0 #4** — Reconnect token / session persistence (call survival across app restart)
5. **P1 #5** — Media device management (most user-visible feature gap)
6. **P1 #15** — Warning event system (companion to P0 #1)
7. **P1 #11** — Deaf/undeaf (quick win)
8. **P1 #7** — Video call support (large effort but high value)
9. **P1 #8** — Conference actions (depends on video for full value)
10. **P1 #9** — Call recording (platform-specific work)
11. **P1 #10** — Pre-call diagnostics
12. **P1 #6** — Screen share (depends on video)
13. **P1 #13** — Bandwidth control
14. **P1 #14** — MediaDeviceCollector
15. **P1 #12** — toggleHold alias (trivial)
16. **P2 items** — As time permits

---

*Generated by auditing source code in both repositories. File references point to JS SDK paths under `~/telnyx/webrtc/packages/js/src/` and Flutter SDK paths under `~/telnyx/flutter-voice-sdk/packages/telnyx_webrtc/lib/`.*
