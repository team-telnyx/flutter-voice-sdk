# PreCallDiagnostic Verification — VSDK-419

**Date:** 2026-07-31  
**Ticket:** VSDK-419 (marked "Done" in Linear)  
**Investigator:** Subagent deep-dive  
**Verdict:** ✅ **Implemented and functional** — with minor parity gaps vs JS SDK.

---

## 1. Does PreCallDiagnostic exist in the Flutter SDK?

**Yes.** The file `packages/telnyx_webrtc/lib/utils/pre_call_diagnosis.dart` (724 lines) contains a complete, production-quality implementation.

### Key classes exported

| Class | Purpose |
|---|---|
| `PreCallDiagnostic` | Static `run()` entry point — the main API |
| `PreCallDiagnosisOptions` | Config: texMLApplicationNumber, sipToken OR sipUser/sipPassword, caller ID, logLevel |
| `DiagnosticReport` | Return type: ICE candidates, jitter/RTT MinMaxAverage, MOS, quality, session stats |
| `DiagnosticQuality` | Enum: excellent, good, fair, poor, bad (mirrors JS `Quality`) |
| `MinMaxAverage` | min/max/average triple for jitter and RTT |
| `DiagnosticSessionStats` | packetsReceived, packetsLost, packetsSent, bytesSent, bytesReceived |
| `RTCIceCandidateStats` | ICE candidate details (address, type, protocol, port, priority, etc.) |
| `PreCallDiagnosticException` | Exception with sipCode, sipReason, reason enum, message |
| `PreCallDiagnosticFailureReason` | Enum: timeout, connectionFailed, sipError |

---

## 2. What does it actually test?

The Flutter `PreCallDiagnostic.run()` performs a **real end-to-end diagnostic call**:

1. **Creates a `TelnyxClient`** and connects using token or credential config
2. **Waits for `ConnectionStatus.clientReady`** (registered with server) — 5s connection timeout
3. **Places a real outbound call** (`client.newInvite()`) to the configured `texMLApplicationNumber`
4. **Monitors SIP errors** via `onSocketMessageReceived` — checks for SIP 4xx in BYE params
5. **Collects WebRTC stats** via `Call.onCallQualityChange` callback:
   - Jitter samples (min/max/average)
   - RTT samples (min/max/average)
   - ICE candidate stats (address, type, protocol, port, priority, relay protocol)
   - ICE candidate pair stats (nominated, local/remote candidate IDs)
   - Session stats (packets sent/received/lost, bytes sent/received)
6. **Computes MOS** using `MosCalculator.calculateMos()` (ITU-T G.107 E-Model, same as JS)
7. **Maps MOS to quality** using `DiagnosticQuality.fromMos()` (same bands as JS `getQuality`)
8. **Cleans up** — hangs up call and disconnects client in a `try/finally` block
9. **Returns** a `DiagnosticReport`
10. **30-second overall timeout** — throws `PreCallDiagnosticException` with `reason.timeout`

### What it does NOT test

- ❌ **Microphone access/permissions** — no explicit audio device check
- ❌ **Network connectivity independently** — it tests the full call path, not just network reachability
- ❌ **ICE candidate gathering in isolation** — ICE stats are extracted from the call's quality metrics, not from a dedicated ICE gathering phase
- ❌ **No progress events** — single blocking await; the UI widget shows a spinner with no incremental updates

---

## 3. Comparison with JS SDK's PreCallDiagnosis module

### JS SDK file: `~/telnyx/webrtc/packages/js/src/PreCallDiagnosis.ts` (330 lines)

### Architecture comparison

| Aspect | JS SDK | Flutter SDK |
|---|---|---|
| **Entry point** | `PreCallDiagnosis.run(options)` (static) | `PreCallDiagnostic.run(options)` (static) |
| **Connection** | `new TelnyxRTC(credentials)` + `client.connect()` | `TelnyxClient()` + `connectWithToken()` or `connectWithCredential()` |
| **Event handling** | Event emitter: `SwEvent.Ready`, `SwEvent.Error`, `SwEvent.MediaError`, `SwEvent.Notification`, `SwEvent.StatsReport` | Callbacks: `onConnectionStateChanged`, `onSocketMessageReceived`, `onCallQualityChange`, `onCallStateChanged` |
| **Stats collection** | `SwEvent.StatsReport` registered via `register()` | `Call.onCallQualityChange` callback with `CallQualityMetrics` |
| **Report mapping** | `mapReport()` — processes `onicecandidate` and `stats` events | `_extractIceCandidateStats()`, `_extractSessionStats()`, `_extractIceCandidatePairStats()` — processes `CallQualityMetrics` maps |
| **MOS calculation** | `calculateMOS()` from `utils/mos.ts` — uses `jitter`, `rtt`, `packetsReceived`, `packetsLost` | `MosCalculator.calculateMos()` — uses `rtt`, `jitter`, `packetLoss` (ratio, not absolute counts) |
| **Quality mapping** | `getQuality(mos)` → `Quality` enum | `DiagnosticQuality.fromMos(mos)` → `DiagnosticQuality` enum — same bands |
| **Timeout** | ❌ No explicit timeout | ✅ 30s timeout with `PreCallDiagnosticFailureReason.timeout` |
| **Error handling** | SIP 4xx rejection via `notification.call.sipCode >= 400` | SIP 4xx via `byeParams.sipCode >= 400` + connection failure + timeout |
| **Cleanup** | `client.disconnect()` after report promise | `try/finally` — `endCall()` + `disconnect()` with error logging |
| **Options** | `texMLApplicationNumber`, `credentials: {login, password, loginToken}` | `texMLApplicationNumber`, `sipToken` OR `sipUser`/`sipPassword`, `sipCallerIDName`, `sipCallerIDNumber`, `logLevel` |

### MOS calculation differences

**JS SDK** (`utils/mos.ts`):
- Uses `R0 = 93.2`, `Is = 0`, `Id = delay impairment`, `Ie = equipment impairment`, `A = 0`
- Equipment impairment: `20 * log(1 + packetLossPercentage)`
- No jitter impairment factor in equipment impairment
- MOS formula: `1 + 0.035 * R + 0.000007 * R * (R - 60) * (100 - R)`
- Clamps to [1, 5]

**Flutter SDK** (`mos_calculator.dart`):
- Same R0 = 93.2, same delay impairment formula
- Equipment impairment: `jitterImpairment (jitterMs * 0.05) + packetLossImpairment (30 * packetLoss / (packetLoss + 10))`
- Different formula! Uses `30 * packetLoss / (packetLoss + 10)` instead of `20 * log(1 + packetLoss)`
- Adds explicit jitter impairment (JS doesn't)
- Clamps to [1.0, 4.5] (JS clamps to [1, 5])

**Impact:** The Flutter MOS values will diverge slightly from JS for the same network conditions. The Flutter formula is arguably more sophisticated (accounts for jitter separately), but parity is broken.

### Quality bands comparison

| MOS Range | JS `getQuality` | Flutter `DiagnosticQuality.fromMos` | Flutter `CallQuality.fromMos` |
|---|---|---|---|
| > 4.2 | excellent | excellent | excellent |
| 4.1 – 4.2 | good | good | good |
| 3.7 – 4.0 | fair | fair | fair |
| 3.1 – 3.6 | poor | poor | poor |
| ≤ 3.0 | bad | bad | bad |

✅ Quality bands are identical across all three implementations.

### Structural parity gaps

1. **JS `Report` interface** includes `iceCandidatePairStats` as a typed `RTCIceCandidatePairStats`; Flutter uses `Map<String, dynamic>?` (untyped)
2. **JS `getTelnyxIds()`** method exists on `PreCallDiagnosis` (returns empty stub); Flutter omits it entirely
3. **JS has no timeout** — Flutter's 30s timeout is an improvement
4. **JS has no structured exception** — Flutter's `PreCallDiagnosticException` with `reason` enum is an improvement
5. **JS uses `packetsReceived` + `packetsLost` for MOS** (absolute counts); Flutter uses `packetLoss` ratio — this is a semantic difference in how the same E-Model formula is fed

---

## 4. Is it exposed in the public API?

**Yes.** The barrel file `packages/telnyx_webrtc/lib/telnyx_webrtc.dart` exports it:

```dart
// Reporting & Diagnostics (VSDK-419/420/421)
export './utils/pre_call_diagnosis.dart';
```

Apps can import and use it directly:

```dart
import 'package:telnyx_webrtc/telnyx_webrtc.dart';

final options = PreCallDiagnosisOptions(
  texMLApplicationNumber: '+18005551234',
  sipToken: 'my-token',
  sipCallerIDName: 'Diagnostic',
  sipCallerIDNumber: '+15551234567',
);
final report = await PreCallDiagnostic.run(options);
```

### Example app UI

There is also a **fully functional UI widget** at `lib/view/widgets/diagnostics/pre_call_panel.dart` in the example app that:
- Takes a TeXML destination number input
- Shows a confirmation dialog ("Place a real call? ... may incur charges")
- Runs the diagnostic with the active SIP config
- Renders a `DiagnosticReportView` with MOS, quality label, jitter/RTT min-max-avg, packet stats, and ICE candidate count
- Handles `PreCallDiagnosticException` with error display

---

## 5. Are there unit tests?

**Yes.** The file `packages/telnyx_webrtc/test/pre_call_diagnostic_test.dart` contains 17 tests:

### Unit tests (9 passing ✅)

| # | Test | Status |
|---|---|---|
| 1 | DiagnosticReport has all required fields | ✅ Pass |
| 2 | MinMaxAverage given [10, 20, 30] → min=10, max=30, avg=20 | ✅ Pass |
| 3 | MinMaxAverage handles single value | ✅ Pass |
| 4 | MinMaxAverage handles empty list with zeros | ✅ Pass |
| 5 | MOS computation: jitter=5ms, rtt=50ms, loss=0 → MOS ≥ 4.0 | ✅ Pass |
| 6 | Quality mapping: canonical MOS bands match CallQuality | ✅ Pass |
| 7 | RTCIceCandidateStats has all expected fields | ✅ Pass |
| 8 | Jitter/RTT averaging: multiple samples, correct min/max/average | ✅ Pass |
| 9 | Session stats extraction: packetsReceived, packetsLost, etc. | ✅ Pass |

### Integration tests (8 skipped, require live server)

| # | Test | Skip reason |
|---|---|---|
| 10 | Run with token config | Requires live server |
| 11 | Run with credential config | Requires live server |
| 12 | SIP 4xx error handling | Requires live server |
| 13 | Connection failure error handling | Requires live server |
| 14 | Timeout (30s) | Requires live server |
| 15 | Cleanup on success | Requires live server |
| 16 | Cleanup on failure (try/finally) | Requires live server |
| 17 | Integration with TelnyxClient API | Requires live server |

Integration tests are gated behind `--dart-define=RUN_INTEGRATION=true` and are correctly skipped by default.

### JS SDK tests
No tests found for `PreCallDiagnosis` in the JS SDK.

---

## 6. Summary assessment

### What's done well ✅

- **Complete implementation** — 724 lines of well-structured, documented Dart code
- **Public API exposed** — exported from barrel file, ready for app consumption
- **Example app UI** — full widget with confirmation dialog and report rendering
- **Comprehensive unit tests** — 9 passing tests covering models, MOS, quality mapping, stats
- **Error handling** — structured `PreCallDiagnosticException` with typed failure reasons (timeout, connectionFailed, sipError) — better than JS SDK
- **Timeout** — 30s safety timeout, which the JS SDK lacks
- **Cleanup** — `try/finally` ensures call hangup and client disconnect even on failure
- **Quality bands** — identical to JS SDK's `getQuality` and Flutter's existing `CallQuality.fromMos`

### Parity gaps with JS SDK ⚠️

1. **MOS formula divergence** — Flutter's `MosCalculator` uses a different equipment impairment formula (`30 * loss / (loss + 10)`) vs JS (`20 * log(1 + loss)`). Flutter also adds a jitter impairment factor. Same network conditions may yield different MOS values.
2. **`iceCandidatePairStats` untyped** — Flutter uses `Map<String, dynamic>?` vs JS typed `RTCIceCandidatePairStats` interface
3. **No `getTelnyxIds()`** — JS has a stub method; Flutter omits it (minor, since the JS version returns empty strings)
4. **MOS clamp range** — Flutter clamps to [1.0, 4.5], JS clamps to [1, 5]

### What's missing entirely ❌

- **Microphone/audio device check** — no pre-call test for mic permissions or device availability
- **Network-only connectivity test** — no lightweight "can I reach the TURN server?" check without placing a call
- **Progress callbacks** — no way to get incremental updates during the diagnostic (the UI widget shows a static spinner)
- **Integration tests are all skipped** — no CI coverage of the actual diagnostic flow

### Verdict

**VSDK-419 "Done" status is justified.** The PreCallDiagnostic feature is fully implemented, exported, tested at the unit level, and has a working example app UI. The implementation is arguably more robust than the JS SDK version (timeout, structured exceptions, cleanup). The MOS formula divergence is a minor concern that should be documented but doesn't block the "Done" status.
