# TDD Manifest — Reporting & Diagnostics

**Date:** 2026-07-09  
**Phase:** Phase 3 — TDD (Failing Tests Before Implementation)  
**Sprint:** Flutter SDK Reporting and Diagnostics

---

## Test Files Created

| # | File | Ticket | Test Count | Description |
|---|------|--------|------------|-------------|
| 1 | `packages/telnyx_webrtc/test/telnyx_config_debug_test.dart` | VSD-422 | 8 | Granular debug config — 9 new fields on Config, CredentialConfig, TokenConfig. Tests defaults, overrides, debugLogLevel filtering, debugOutput file mode, enableCallReports=false, callReportFlushInterval, maxReconnectAttempts, prefetchIceCandidates. |
| 2 | `packages/telnyx_webrtc/test/log_collector_test.dart` | VSD-420 | 10 | LogCollector — FIFO eviction, level filtering, global singleton, GlobalLogger integration, CallReport integration, context serialization, intermediate flush, concurrent calls lifecycle. |
| 3 | `packages/telnyx_webrtc/test/quality_warning_monitor_test.dart` | VSD-421 | 22 | Call quality warnings — 25 warning codes + 23 error codes registries, createWarning/createError factories, QualityWarningMonitor with threshold detection for HIGH_RTT, HIGH_JITTER, HIGH_PACKET_LOSS, LOW_MOS, LOW_LOCAL_AUDIO (pre/post-confirmation), LOW_INBOUND_AUDIO, LOW_BYTES_RECEIVED, LOW_BYTES_SENT, throttling (15s), ICE_CANDIDATE_PAIR_CHANGED, ICE_CONNECTIVITY_LOST, PEER_CONNECTION_FAILED, fatal/non-fatal errors, warning/error callbacks. |
| 4 | `packages/telnyx_webrtc/test/pre_call_diagnostic_test.dart` | VSD-419 | 15 | PreCallDiagnostic — DiagnosticReport structure, MinMaxAverage computation, MOS computation, quality mapping, ICE candidate extraction, run with token/credential config, SIP 4xx error handling, connection failure, 30s timeout, cleanup on success/failure, jitter/RTT averaging, session stats extraction, TelnyxClient API integration. |

**Total: 55 tests across 4 files**

---

## Dependencies (Implementation Order)

```
VSD-422 (Debug Config) → VSD-420 (LogCollector) → VSD-421 (Quality Warnings) → VSD-419 (PreCallDiagnostic)
```

Tests are written to FAIL at compile time because the following files/classes do not exist yet:

### VSD-422 — New Config Fields
- `Config.enableCallReports` (bool, default: true)
- `Config.debugOutput` (String, default: 'socket')
- `Config.debugLogLevel` (String, default: 'info')
- `Config.debugLogMaxEntries` (int, default: 1000)
- `Config.callReportFlushInterval` (int, default: 180000)
- `Config.prefetchIceCandidates` (bool, default: true)
- `Config.autoRecoverCalls` (bool, default: true)
- `Config.hangupOnBeforeUnload` (bool, default: true)
- `Config.maxReconnectAttempts` (int, default: 10)
- `Config.applyDebugLogLevel()` method
- `CallReportOptions.fromConfig(Config)` factory

### VSD-420 — New Files
- `lib/utils/logging/log_collector.dart`:
  - `LogEntry` class with `timestamp`, `level`, `message`, `context`, `toJson()`
  - `CollectorLogLevel` enum (debug, info, warn, error)
  - `LogCollector` class with `enabled`, `level`, `maxEntries`, `start()`, `stop()`, `addEntry()`, `getLogs()`, `getLogsJson()`, `drain()`, `clear()`, `isActive`, `logCount`
  - `getGlobalLogCollector()` / `setGlobalLogCollector()` singleton functions
- `GlobalLogger` modifications: `d()`, `i()`, `w()`, `e()` accept optional `context` parameter and forward to LogCollector
- `CallReportCollector.configureLogCollector()` and `getLogCollectorEntries()` methods

### VSD-421 — New Files
- `lib/model/telnyx_warning.dart` — `TelnyxWarning` class with `code`, `name`, `message`, `description`, `causes[]`, `solutions[]`, `callId?`, `sessionId?`
- `lib/model/telnyx_error.dart` — `TelnyxError` class with `code`, `name`, `message`, `description`, `causes[]`, `solutions[]`, `fatal`, `callId?`, `sessionId?`
- `lib/model/sdk_warning_codes.dart` — `SdkWarningCode` constants (25 codes, 31001–36005)
- `lib/model/sdk_error_codes.dart` — `SdkErrorCode` constants (23 codes, 40001–49001)
- `lib/model/sdk_warning_registry.dart` — `SdkWarningRegistry` with `get(code)` and `createWarning(code, message?)` factory
- `lib/model/sdk_error_registry.dart` — `SdkErrorRegistry` with `get(code)` and `createError(code, message?, fatalOverride?, callId?, sessionId?)` factory
- `lib/utils/stats/quality_warning_monitor.dart` — `QualityWarningMonitor` class with:
  - `checkStats(StatsInterval stats)` — stats-based threshold detection
  - `onIceConnectionStateChanged(String state)` — ICE connectivity warning
  - `onPeerConnectionStateChanged(String state)` — peer connection warning
  - `reset()` — clear state between calls
  - Threshold constants: `_consecutiveBreachesRequired=3`, `_thresholdRttMs=400`, `_thresholdJitterMs=30`, `_thresholdPacketLossPct=1.0`, `_thresholdMos=3.5`, `_thresholdLocalAudioLevel=0.001`, `_thresholdInboundAudioLevel=0.001`, `_confirmedLocalAudioSilenceMs=30000`, `_warningThrottleMs=15000`

### VSD-419 — New Files
- `lib/utils/pre_call_diagnosis.dart`:
  - `RTCIceCandidateStats` class
  - `MinMaxAverage` class with `fromValues(List<double>)` factory
  - `DiagnosticQuality` enum with `fromMos()` factory
  - `DiagnosticSessionStats` class
  - `DiagnosticReport` class
  - `PreCallDiagnosisOptions` class
  - `PreCallDiagnosticException` class with `sipCode`, `sipReason`, `reason`
  - `PreCallDiagnosticFailureReason` enum
  - `PreCallDiagnostic` class with static `run(PreCallDiagnosisOptions)` method

---

## Test Execution

All tests are designed to FAIL until implementation is complete. Run:

```bash
cd packages/telnyx_webrtc
dart test test/telnyx_config_debug_test.dart
dart test test/log_collector_test.dart
dart test test/quality_warning_monitor_test.dart
dart test test/pre_call_diagnostic_test.dart
```

Expected failure: compilation errors referencing non-existent classes/fields.

---

## Conventions

- Follows existing test patterns: `group()` + `test()` from `flutter_test`
- Ticket IDs included in group descriptions
- Edge cases covered: null inputs, timeouts, concurrent access, empty results
- External dependencies (WebSocket, platform channels, timers) are mocked or stubbed
- Tests verify both positive cases (correct behavior) and negative cases (error handling)
- Each test has descriptive `reason` strings for failed assertions
