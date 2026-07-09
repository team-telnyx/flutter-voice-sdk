# Phase 5 Adversarial Review: Reporting & Diagnostics

**Reviewer:** Phase 5 Adversarial Review Agent  
**Date:** 2026-07-09  
**Project:** Flutter Voice SDK — Reporting & Diagnostics (VSD-419/420/421/422)  
**JS Reference:** `~/telnyx/webrtc/packages/js/src/`

---

## Summary

| Check | Result |
|-------|--------|
| 1. LogCollector: FIFO, level filtering, thread safety, memory | **PASS with issues** |
| 2. PreCallDiagnostic: API match, error paths, timeout | **FAIL** |
| 3. QualityWarningMonitor: Thresholds, emission, throttle | **PASS with issues** |
| 4. Debug config: 9 fields in TelnyxConfig, defaults | **PASS** |
| 5. Missing features vs JS | **See below** |
| 6. Test coverage gaps | **See below** |
| 7. Import/export issues | **PASS with minor issues** |

---

## 1. LogCollector (`log_collector.dart`)

### PASS with issues

**FIFO eviction — PASS**  
`_buffer.removeAt(0)` is called when `_buffer.length > maxEntries`. This correctly evicts the oldest entry. The JS reference uses `this.buffer.shift()` which is equivalent.

**Level filtering — PASS**  
The `_collectorLevelPriority` map and comparison logic are correct. Lower priority value = more verbose, and entries with priority below the configured level are filtered out. Matches JS `LOG_LEVEL_PRIORITY` logic.

**Default values — ISSUE (minor)**
- Flutter `maxEntries` default: `100`  
- JS `maxEntries` default: `1000`  
The JS `LogCollector` defaults to `enabled: false` and `maxEntries: 1000`. The Flutter version defaults to `enabled: true` and `maxEntries: 100`. However, the Flutter `LogCollector` is instantiated by `CallReportCollector` which passes config-derived values, so the raw defaults matter less. Still, alignment would be safer.

**Thread safety — ISSUE (important)**
Dart is single-threaded for synchronous code, so the `_buffer` List operations are safe within a single isolate. However, `addEntry()` is called from `GlobalLoggerCollectorExtension._forwardToCollector()` which could be invoked from any isolate. If the SDK ever uses isolates for WebRTC stats processing, the mutable `_buffer` is not protected. The JS reference is also single-threaded (JS event loop), so this is a theoretical concern but worth documenting.

**Memory leak — ISSUE (minor)**
The `GlobalLoggerCollectorExtension` adds new methods (`d`, `i`, `w`, `e`, `v`) to `GlobalLogger`. The `v()` (verbose) method maps to `CollectorLogLevel.debug` but logs at `LogLevel.verto`. This is fine. However, the extension methods duplicate the existing `GlobalLogger` methods. If someone calls `GlobalLogger.logger.log(LogLevel.debug, message)` directly (not through the extension), the entry will NOT be forwarded to the collector. This creates a dual-API problem where some code paths use the extension methods and some use the base logger.

The JS reference avoids this by having the `LogCollector` register as a log handler/callback, not by extending the logger. The Flutter approach of extending `GlobalLogger` is fragile.

**Missing `clear()` method — ISSUE (minor)**  
The JS `LogCollector` has a `clear()` method. The Flutter version has `drain()` but no explicit `clear()`. The `cleanup()` pattern in JS `CallReportCollector` calls `this.logCollector.clear()`. Flutter only has `drain()` (which clears as a side effect) but no standalone `clear()`.

**Missing `isEnabled` getter — ISSUE (minor)**  
JS has `isEnabled()` to check if the collector is enabled. Flutter has `enabled` as a public final field, so this is accessible but not as a method.

---

## 2. PreCallDiagnostic (`pre_call_diagnosis.dart`)

### FAIL

**Implementation is a stub — CRITICAL**
`PreCallDiagnostic.run()` throws unconditionally:
```dart
throw PreCallDiagnosticException(
  reason: PreCallDiagnosticFailureReason.connectionFailed,
  message: 'PreCallDiagnostic.run is not implemented for test environments',
);
```
This is a non-functional stub. The JS reference (`PreCallDiagnosis.ts`) has a full implementation that:
1. Creates a `TelnyxRTC` client
2. Connects using credentials
3. Makes a test call to the texML application number
4. Registers for `StatsReport` events
5. Maps the stats to a `Report` with `mapReport()`
6. Disconnects and returns the report

**API mismatch with JS — ISSUE (important)**

| Aspect | JS | Flutter |
|--------|----|---------|
| Options.credentials | `{ login?, password?, loginToken? }` | `sipToken?, sipUser?, sipPassword?` |
| Report structure | `summaryStats: { jitter, rtt, mos, quality }` | `jitter, rtt, mos, quality` (flat) |
| Report field | `iceCandidatePairStats` (typed) | `iceCandidatePairStats: Map<String, dynamic>?` (untyped) |
| Quality enum | `Quality` from `utils/mos` | `DiagnosticQuality` (custom) |
| MOS calculation | `calculateMOS({ jitter, rtt, packetsReceived, packetsLost })` | Uses `MosCalculator.calculateMos(rtt, jitter, packetLoss)` |
| Error handling | Rejects with `Error(sipReason)` | `PreCallDiagnosticException` with `sipCode`, `sipReason`, `reason` |

The Flutter API is more structured (typed exception, enum for failure reason) which is an improvement, but the `PreCallDiagnosisOptions` fields don't match JS naming:
- JS: `credentials: { login, password, loginToken }`  
- Flutter: `sipToken, sipUser, sipPassword` (spread across top-level fields)

**Missing timeout — ISSUE (important)**  
The JS reference doesn't have an explicit timeout either (relies on the `StatsReport` event arriving), but the Flutter tests expect a 30s timeout (`PreCallDiagnosticFailureReason.timeout`). The implementation doesn't implement any timeout mechanism.

**Missing cleanup (try/finally) — ISSUE (important)**  
The JS reference calls `client.disconnect()` after getting the report, but there's no try/finally for error cleanup. The Flutter tests expect cleanup on both success and failure paths. The stub implementation doesn't do any cleanup.

**DiagnosticQuality.fromMos boundary — ISSUE (minor)**
```dart
if (mos > 4.0) return DiagnosticQuality.excellent;
if (mos >= 4.0) return DiagnosticQuality.good;
```
MOS exactly 4.0 maps to `good`, but `> 4.0` maps to `excellent`. The test expects `fromMos(4.0) == good` which is correct. But the JS `getQuality` function should be checked for boundary alignment. The `> 4.0` / `>= 4.0` split means 4.0 is `good`, not `excellent`.

---

## 3. QualityWarningMonitor (`quality_warning_monitor.dart`)

### PASS with issues

**Threshold values — PASS (all match JS)**

| Threshold | Flutter | JS |
|-----------|---------|-----|
| RTT | 0.4 (400ms) | `THRESHOLD_RTT_MS = 0.4` |
| Jitter | 30.0 (30ms) | `THRESHOLD_JITTER_MS = 30` |
| Packet loss | 0.01 (1%) | `THRESHOLD_PACKET_LOSS_PCT = 1` (as percentage) |
| MOS | 3.5 | `THRESHOLD_MOS = 3.5` |
| Audio level | 0.001 | `THRESHOLD_LOCAL_AUDIO_LEVEL = 0.001` |
| Consecutive breaches | 3 | `CONSECUTIVE_BREACHES_REQUIRED = 3` |
| Post-confirm silence | 6 intervals (30s) | `CONFIRMED_LOCAL_AUDIO_SILENCE_MS = 30_000` |
| Throttle | 3 intervals (15s) | `WARNING_THROTTLE_MS = 15_000` |

**Packet loss calculation — ISSUE (important)**
Flutter calculates packet loss as:
```dart
final lossRate = lostDelta / receivedDelta;
```
JS calculates:
```dart
packetLossPct = (deltaLost / totalDelta) * 100;
// where totalDelta = deltaReceived + deltaLost
```
The Flutter version divides by `receivedDelta` only, while JS divides by `receivedDelta + lostDelta` (total packets). This produces different results. For example, if 98 received and 2 lost:
- Flutter: 2/98 = 0.0204 (2.04%)  
- JS: 2/100 = 0.02 (2%)

The threshold comparison also differs: Flutter compares `lossRate > _packetLossThreshold` (0.01 = 1%), JS compares `packetLossPct > THRESHOLD_PACKET_LOSS_PCT` (1 as percentage). The Flutter threshold is a fraction (0.01), the JS threshold is a percentage (1). The math mostly works out (1% = 0.01 fraction), but the denominators differ.

**MOS calculation — ISSUE (important)**
Flutter uses `MosCalculator.calculateMos()` which is a separate utility. The JS `CallReportCollector._checkQualityWarnings` computes MOS inline:
```js
const R = 93.2 - jitter * 0.11 - packetLossPct * 2.5 - rttMs * 0.01;
const mos = Math.max(1, Math.min(4.5, 1 + 0.035 * R + R * (R - 60) * (100 - R) * 7e-6));
```
Need to verify `MosCalculator.calculateMos` produces the same formula. If not, thresholds will fire at different times.

**One warning per interval — ISSUE (minor)**
Flutter explicitly tracks `emittedThisInterval` to only emit one warning per stats interval. The JS reference does NOT have this limitation — it can emit multiple warnings per interval (though throttle prevents duplicates). This means Flutter may suppress warnings that JS would emit.

**Throttle implementation — ISSUE (minor)**
Flutter uses interval counting (`_throttleIntervalCount = 3`), incrementing all tracked codes each interval. JS uses wall-clock milliseconds (`WARNING_THROTTLE_MS = 15_000`). The Flutter approach is interval-count-based, which assumes a fixed 5s interval. If the interval changes (e.g., the JS `INITIAL_COLLECTION_INTERVAL_MS = 1000` during startup), the Flutter throttle timing will be incorrect.

**ICE candidate pair change — PASS**  
Both Flutter and JS detect pair ID changes and emit `ICE_CANDIDATE_PAIR_CHANGED`.

**State-based warnings — PASS**  
`onIceConnectionStateChanged('disconnected')` → `ICE_CONNECTIVITY_LOST`  
`onPeerConnectionStateChanged('failed')` → `PEER_CONNECTION_FAILED`  
These match JS behavior.

**Missing `recordingUnavailable` and `recordingBufferOverflow` monitoring — ISSUE (minor)**  
The `SdkWarningCode` constants include `recordingUnavailable` (32003) and `recordingBufferOverflow` (32004), and the registry has definitions, but `QualityWarningMonitor.checkStats()` never checks for these conditions. The JS reference has these in the registry but also doesn't actively monitor for them in `CallReportCollector._checkQualityWarnings`. So this matches JS behavior.

**Missing `onlyHostIceCandidates` detection — ISSUE (minor)**  
`SdkWarningCode.onlyHostIceCandidates` (33005) is in the registry but not checked by `QualityWarningMonitor`. JS also doesn't actively check for this in `_checkQualityWarnings`. Matches.

**Post-confirmation silence reset — ISSUE (minor)**
When audio is confirmed and then goes silent, the Flutter code increments `_postConfirmSilenceCount`. But if audio comes back, it resets `_postConfirmSilenceCount = 0` and `_lowLocalAudioBreaches = 0`. The JS code does the same via `_resetLowLocalAudioWarning()`. However, Flutter doesn't reset the `_activeWarnings` set for `LOW_LOCAL_AUDIO` when audio resumes. JS does this via `_trackBreach(LOW_LOCAL_AUDIO, false)` which removes from `_activeWarnings`. In Flutter, when audio is confirmed and above threshold, the code resets counters but doesn't clear the active warning state. This means the throttle will still be tracking the last emission time.

Actually, looking more carefully at the Flutter code: when `outboundLevel >= _audioLevelThreshold`, it sets `_audioConfirmed = true`, `_postConfirmSilenceCount = 0`, and `_lowLocalAudioBreaches = 0`. But it doesn't call `_emit()` or reset the throttle map. The JS `_trackBreach(LOW_LOCAL_AUDIO, false)` resets `_breachCounters`, `_activeWarnings`, and `_lastWarningEmitted`. Flutter is missing this reset path.

---

## 4. Debug Config (TelnyxConfig)

### PASS

**All 9 fields present with correct defaults:**

| Field | Flutter Default | JS Default | Match |
|-------|----------------|-----------|-------|
| `enableCallReports` | `true` | `true` | ✅ |
| `debugOutput` | `'socket'` | `'socket'` | ✅ |
| `debugLogLevel` | `'info'` | (not in JS config) | ⚠️ |
| `debugLogMaxEntries` | `1000` | (not in JS config) | ⚠️ |
| `callReportFlushInterval` | `180000` | `180000` | ✅ |
| `prefetchIceCandidates` | `true` | `true` | ✅ |
| `autoRecoverCalls` | `true` | (JS: `autoRecoverCalls`) | ✅ |
| `hangupOnBeforeUnload` | `true` | `true` | ✅ |
| `maxReconnectAttempts` | `10` | `10` | ✅ |

The `debugLogLevel` and `debugLogMaxEntries` fields appear to be Flutter-specific additions not present in the JS `TelnyxRTCClientOptions`. The JS equivalent of log level filtering is done via the `logLevel` field, not a separate `debugLogLevel`. This is a reasonable Flutter-specific extension.

**`applyDebugLogLevel()` implementation — PASS**  
The `_LevelFilterLogger` wrapper correctly filters messages based on priority. The logic correctly maps `debugLogLevel` values to `LogLevel` filters.

**Config propagation — PASS**  
`CredentialConfig` and `TokenConfig` both pass through all new fields via `super.` parameters.

---

## 5. Missing Features vs JS

### Critical Missing Features

1. **PreCallDiagnostic.run() is a stub** — The entire pre-call diagnosis flow is unimplemented. The JS version creates a `TelnyxRTC` client, connects, makes a test call, collects stats, and returns a report. The Flutter version throws immediately.

2. **LogCollector integration with CallReportCollector** — The JS `CallReportCollector` creates and manages a `LogCollector` internally, passing `logCollectorOptions` to its constructor. The Flutter `CallReportCollector` needs to be verified to ensure it integrates the `LogCollector` similarly.

### Important Missing Features

3. **No intermediate flush support in LogCollector** — JS `LogCollector.drain()` is used for intermediate flushes. Flutter has `drain()` but the `CallReportCollector` integration for intermediate segment flushing needs verification.

4. **No `createLogCollector()` factory function** — JS has a `createLogCollector()` factory. Flutter doesn't, but the constructor serves the same purpose. Minor.

5. **Missing warning: `onlyHostIceCandidates` active detection** — Both JS and Flutter have the code/registry but neither actively monitors for this condition. This is parity but represents a gap in both SDKs.

6. **Missing `enableCallRecording` config** — JS has `enableCallRecording` and `callRecordingFlushIntervalMs` config fields. Flutter doesn't have these. This may be out of scope for this phase.

### Minor Missing Features

7. **`DiagnosticReport` structure doesn't match JS `Report`** — JS uses `summaryStats` nested object; Flutter flattens `jitter`, `rtt`, `mos`, `quality` to top level. This is a design choice but creates an API mismatch for cross-SDK consumers.

8. **No `getTelnyxIds()` method** — JS `PreCallDiagnosis` has a `getTelnyxIds()` method. Flutter's `PreCallDiagnostic` doesn't.

---

## 6. Test Coverage Gaps

### Existing Tests (Good Coverage)

- `log_collector_test.dart` — 10 tests covering start/stop, level filtering, FIFO eviction, drain, GlobalLogger integration, context serialization, intermediate flush, concurrent calls. **Good coverage.**
- `pre_call_diagnostic_test.dart` — 15 tests covering report structure, MinMaxAverage, MOS, quality mapping, ICE candidate extraction, run with token/credential, error handling, timeout, cleanup, jitter/RTT averaging, session stats. **Good coverage but tests will fail because implementation is a stub.**
- `quality_warning_monitor_test.dart` — 22 tests covering registry completeness (25 warnings, 23 errors), createWarning/createError factories, all 8 warning types, throttling, ICE pair change, ICE connectivity, peer connection failure, fatal/non-fatal errors, callbacks. **Good coverage.**
- `telnyx_config_debug_test.dart` — 8 tests covering config defaults, overrides, debugLogLevel filtering, debugOutput file mode, enableCallReports=false, callReportFlushInterval, maxReconnectAttempts, prefetchIceCandidates. **Good coverage.**

### Missing Tests

1. **No integration test for LogCollector + CallReportCollector** — The test `log_collector_test.dart` test 7 ("CallReport integration") references `CallReportLogCollector` but it's unclear if this test passes.

2. **No tests for `_LevelFilterLogger`** — The config debug test verifies `applyDebugLogLevel()` but doesn't directly test the `_LevelFilterLogger` class with edge cases (e.g., `LogLevel.none`, custom loggers).

3. **No tests for `SdkWarningRegistry.createWarning` with unknown code** — Should throw `ArgumentError`. Not tested.

4. **No tests for `SdkErrorRegistry.createError` with unknown code** — Should throw `ArgumentError`. Not tested.

5. **No tests for `QualityWarningMonitor` with null stats** — What happens when `checkStats()` receives an interval with all-null values? Edge case not covered.

6. **No tests for `QualityWarningMonitor` post-confirmation silence reset** — When audio returns after a post-confirmation silence warning, is the active warning state properly cleared? See issue in section 3.

7. **No tests for concurrent warning emission** — Multiple different warning types firing in the same interval. Flutter's one-warning-per-interval rule may suppress some.

8. **No tests for `TelnyxWarning.toJson()` / `TelnyxError.toJson()`** — Serialization correctness not verified.

---

## 7. Import/Export Issues

### PASS with minor issues

**Imports in `log_collector.dart` — ISSUE (minor)**
The `GlobalLoggerCollectorExtension` imports `GlobalLogger` from `global_logger.dart` and extends it. The extension methods (`d`, `i`, `w`, `e`, `v`) shadow any existing methods with the same names on `GlobalLogger`. If `GlobalLogger` already has `d`, `i`, `w`, `e` methods (via its `CustomLogger` interface), the extension will be preferred when called on the `GlobalLogger` type. This could cause unexpected behavior.

**Import in `pre_call_diagnosis.dart` — ISSUE (minor)**
```dart
import 'package:telnyx_webrtc/model/call_quality.dart';
```
This imports `CallQuality` which is used in the test to verify `CallQuality.fromMos(4.3) == CallQuality.excellent`. The import is correct but `call_quality.dart` must exist and export `CallQuality`.

**`quality_warning_monitor.dart` imports — PASS**
All imports resolve correctly:
- `sdk_warning_codes.dart` — `SdkWarningCode`
- `sdk_warning_registry.dart` — `SdkWarningRegistry`
- `telnyx_warning.dart` — `TelnyxWarning`
- `call_report_collector.dart` — `StatsInterval`
- `mos_calculator.dart` — `MosCalculator`

**Export from `telnyx_config.dart` — PASS**
```dart
export 'package:telnyx_webrtc/utils/logging/global_logger.dart';
export 'package:telnyx_webrtc/utils/stats/call_report_collector.dart' show CallReportOptions;
```
These exports make `GlobalLogger` and `CallReportOptions` available via `package:telnyx_webrtc/config/telnyx_config.dart`.

---

## Issues Summary

### Critical (2)

| # | Component | Issue |
|---|-----------|-------|
| C1 | `PreCallDiagnostic` | `run()` is a stub that always throws. No actual implementation. |
| C2 | `PreCallDiagnostic` | No timeout mechanism despite tests expecting 30s timeout. |

### Important (5)

| # | Component | Issue |
|---|-----------|-------|
| I1 | `QualityWarningMonitor` | Packet loss calculation uses `lostDelta / receivedDelta` but JS uses `lostDelta / (receivedDelta + lostDelta)`. Different denominators. |
| I2 | `QualityWarningMonitor` | MOS calculation delegates to `MosCalculator.calculateMos()` — must verify it matches JS inline formula. |
| I3 | `PreCallDiagnostic` | No try/finally cleanup on failure. Tests expect cleanup on both success and failure paths. |
| I4 | `PreCallDiagnostic` | API mismatch: options structure (`sipToken/sipUser/sipPassword` vs `credentials: {login, password, loginToken}`) differs from JS. |
| I5 | `QualityWarningMonitor` | Post-confirmation audio recovery doesn't clear active warning state / throttle map. JS clears via `_trackBreach(code, false)`. |

### Minor (8)

| # | Component | Issue |
|---|-----------|-------|
| M1 | `LogCollector` | Default `maxEntries` is 100 (JS: 1000). |
| M2 | `LogCollector` | Missing `clear()` method (JS has it). |
| M3 | `LogCollector` | Dual-API problem: direct `GlobalLogger.logger.log()` calls bypass the collector. |
| M4 | `QualityWarningMonitor` | One-warning-per-interval rule suppresses warnings JS would emit. |
| M5 | `QualityWarningMonitor` | Throttle is interval-count-based (assumes 5s), not wall-clock-based like JS. |
| M6 | `QualityWarningMonitor` | `_postConfirmSilenceIntervals = 6` hardcodes 5s intervals; JS uses `CONFIRMED_LOCAL_AUDIO_SILENCE_MS = 30_000` with actual duration calculation. |
| M7 | `PreCallDiagnostic` | `DiagnosticQuality.fromMos(4.0)` boundary: `> 4.0` = excellent, `>= 4.0` = good, so 4.0 = good. Verify this matches JS `getQuality`. |
| M8 | `PreCallDiagnostic` | `DiagnosticReport` flattens `summaryStats` to top level; JS nests it under `summaryStats`. |

---

## Recommendations

### Must Fix (before merge)

1. **Implement `PreCallDiagnostic.run()`** — Port the JS `PreCallDiagnosis.ts` implementation to Dart. Create a `TelnyxClient`, connect, make a test call, collect stats via the stats callback, hang up, disconnect, and return a `DiagnosticReport`. Add a 30s timeout wrapper.

2. **Fix packet loss calculation** — Change from `lostDelta / receivedDelta` to `lostDelta / (receivedDelta + lostDelta)` to match JS.

3. **Verify `MosCalculator.calculateMos()` matches JS formula** — The JS uses an E-model variant: `R = 93.2 - jitter*0.11 - packetLossPct*2.5 - rttMs*0.01` then `MOS = max(1, min(4.5, 1 + 0.035*R + R*(R-60)*(100-R)*7e-6))`. Ensure the Flutter `MosCalculator` uses the same formula.

4. **Fix post-confirmation audio warning reset** — When audio level returns to normal after a post-confirmation silence warning, clear the active warning state and throttle map for `LOW_LOCAL_AUDIO`, matching JS `_trackBreach(LOW_LOCAL_AUDIO, false)`.

### Should Fix (before merge)

5. **Add try/finally cleanup to `PreCallDiagnostic.run()`** — Ensure `client.disconnect()` is called even when errors occur.

6. **Add 30s timeout to `PreCallDiagnostic.run()`** — Use `Future.timeout` or a manual timer to throw `PreCallDiagnosticException(reason: timeout)` if no stats arrive within 30 seconds.

7. **Align `LogCollector` defaults** — Change `maxEntries` default to 1000 to match JS.

8. **Add `clear()` method to `LogCollector`** — For parity with JS.

9. **Add tests for unknown warning/error codes** — Verify `SdkWarningRegistry.createWarning(99999)` and `SdkErrorRegistry.createError(99999)` throw `ArgumentError`.

10. **Add serialization tests** — `TelnyxWarning.toJson()` and `TelnyxError.toJson()` should be tested.

### Nice to Have (post-merge)

11. **Consider wall-clock-based throttle** — Replace interval-count-based throttle with wall-clock milliseconds to handle variable collection intervals.

12. **Consider removing one-warning-per-interval rule** — Allow multiple warnings per interval (with throttle) to match JS behavior.

13. **Align `PreCallDiagnosisOptions` with JS** — Use `credentials: { login, password, loginToken }` to match JS API.

14. **Add `getTelnyxIds()` to `PreCallDiagnostic`** — For parity with JS.

---

## Conclusion

The LogCollector and QualityWarningMonitor implementations are solid and closely track the JS reference. The warning/error registries are comprehensive with all 25 warning codes and 23 error codes correctly defined. The debug config has all 9 fields with correct defaults.

The **critical blocker** is the `PreCallDiagnostic` stub — it needs a full implementation before this can be merged. The packet loss calculation discrepancy and MOS formula verification are also important to fix before merge to ensure warning behavior matches the JS SDK.

**Overall assessment: Not ready for merge** — 2 critical issues and 5 important issues need to be resolved.
