# Flutter SDK Reporting & Diagnostics — Implementation Plan

**Date:** 2026-07-09  
**Tickets:** VSDK-419, VSDK-420, VSDK-421, VSDK-422  
**Assignee:** Gonçalo Palma  
**Reference SDK:** JS WebRTC SDK (`~/telnyx/webrtc/packages/js/src/`)  
**Target SDK:** Flutter SDK (`~/telnyx/flutter-voice-sdk/packages/telnyx_webrtc/lib/`)

---

## 1. Ticket Dependencies & Implementation Order

```
VSDK-422 (Debug Config)  ──────┐
                                │
VSDK-420 (LogCollector)  ───────┤
                                ├──► VSDK-421 (Quality Warnings)
                                │         (depends on config + log collector)
                                │
VSDK-419 (PreCallDiagnosis) ───┘
          (depends on config; standalone)
```

**Recommended order:**
1. **VSDK-422** — Granular debug config (foundation — other features read config)
2. **VSDK-420** — LogCollector (build on config; integrate with existing logging)
3. **VSDK-421** — Call quality warnings (needs config for thresholds + LogCollector for warning logs)
4. **VSDK-419** — PreCallDiagnostic (standalone module; uses config + MOS calculator)

---

## 2. VSDK-422: Granular Debug Config Options

### 2.1 What Needs to Be Built

The Flutter SDK `Config` class (`lib/config/telnyx_config.dart`) currently has: `debug` (bool), `callReportInterval` (int, default 5000), `callReportLogLevel` (String, default "debug"), `callReportMaxLogEntries` (int, default 1000).

The JS SDK `IVertoOptions` (`src/Modules/Verto/util/interfaces.ts`) exposes more granular options. We need to add the missing config fields.

### 2.2 Files to Modify

**`lib/config/telnyx_config.dart`** — Add new fields to `Config`:

```dart
final bool enableCallReports;       // toggle call report collection (default: true)
final String debugOutput;          // 'socket' | 'file' (default: 'socket')
final String debugLogLevel;         // 'debug' | 'info' | 'warn' | 'error' (default: 'info')
final int debugLogMaxEntries;       // LogCollector buffer cap (default: 1000)
final int callReportFlushInterval;  // intermediate flush interval ms (default: 180000)
final bool prefetchIceCandidates;   // pre-gather ICE before setLocalDescription (default: true)
final bool autoRecoverCalls;       // attempt call recovery on reconnection (default: true)
final bool hangupOnBeforeUnload;    // BYE on app lifecycle change (default: true)
final int maxReconnectAttempts;     // 0 = unlimited (default: 10)
```

All `Config` subclasses (`CredentialConfig`, `TokenConfig`) pass through the new fields with defaults.

### 2.3 JS SDK Reference

- `src/Modules/Verto/util/interfaces.ts` — `IVertoOptions` with all debug config fields
- `src/Modules/Verto/util/logger.ts` — `setConsoleLoggerMinLevel()` controls console output independently from LogCollector capture
- `src/Modules/Verto/util/debug.ts` — `createWebRTCStatsReporter()` reads `debugOutput` to decide `saveToFile()` vs WebSocket

### 2.4 Flutter-Specific Considerations

- `debugOutput: 'file'` → write to `getApplicationDocumentsDirectory()` (extend existing `call_report_file_helper.dart`)
- `debugLogLevel` → use string values matching portal expectations, separate from existing `LogLevel` enum
- `hangupOnBeforeUnload` → maps to `AppLifecycleState.detached`; expose `onAppLifecycleChange()` method
- No platform channels needed — pure Dart config

### 2.5 Dependencies

None — this is the foundation.

### 2.6 Test Plan

1. Config defaults test: all new fields have correct defaults
2. Config override test: each field can be overridden via constructor
3. debugLogLevel filtering: when 'warn', debug/info messages don't reach console
4. debugOutput file mode: stats written to local file on mobile (mock fs)
5. enableCallReports=false: no stats collection or HTTP POST
6. callReportFlushInterval: intermediate segments flushed at configured interval
7. maxReconnectAttempts: reconnection stops after N attempts, emits RECONNECTION_EXHAUSTED
8. prefetchIceCandidates: ICE gathering starts before setLocalDescription

---

## 3. VSDK-420: LogCollector for Flutter SDK

### 3.1 What Needs to Be Built

The Flutter SDK has `CallReportLogCollector` (`lib/utils/stats/call_report_log_collector.dart`) for structured **call lifecycle events**. It does NOT capture general SDK debug logs like the JS `LogCollector` does.

The JS `LogCollector` hooks into the logger via `methodFactory` — every `log.debug()`, `log.info()`, `log.warn()`, `log.error()` call is intercepted and buffered for call reports.

We need to:
1. Create a `LogCollector` class that intercepts `GlobalLogger` calls
2. Configure it via VSDK-422 debug config options
3. Integrate captured logs into `CallReportPayload`
4. Add a global singleton matching JS `getGlobalLogCollector()`

### 3.2 Files to Create/Modify

**Create: `lib/utils/logging/log_collector.dart`**

```dart
class LogEntry {
  final String timestamp;   // ISO 8601 UTC
  final String level;       // 'debug', 'info', 'warn', 'error'
  final String message;
  final Map<String, dynamic>? context;

  LogEntry({required this.timestamp, required this.level, required this.message, this.context});
  Map<String, dynamic> toJson() => {'timestamp': timestamp, 'level': level, 'message': message, if (context != null) 'context': context};
}

enum CollectorLogLevel { debug, info, warn, error }

class LogCollector {
  final bool enabled;
  final CollectorLogLevel level;
  final int maxEntries;
  final List<LogEntry> _buffer = [];
  bool _isCapturing = false;

  LogCollector({this.enabled = false, this.level = CollectorLogLevel.debug, this.maxEntries = 1000});

  void start() { if (!enabled) return; _isCapturing = true; _buffer.clear(); }
  void stop() { _isCapturing = false; }

  void addEntry({required String level, required String message, Map<String, dynamic>? context}) {
    if (!_isCapturing || !enabled) return;
    if (_priority(level) < this.level.index) return;
    _buffer.add(LogEntry(timestamp: DateTime.now().toUtc().toIso8601String(), level: level, message: message, context: context));
    if (_buffer.length > maxEntries) _buffer.removeAt(0);
  }

  List<LogEntry> getLogs() => List.unmodifiable(_buffer);
  List<Map<String, dynamic>> getLogsJson() => _buffer.map((e) => e.toJson()).toList();
  List<Map<String, dynamic>> drain() { final logs = getLogsJson(); _buffer.clear(); return logs; }
  void clear() => _buffer.clear();
  bool get isActive => _isCapturing;
  bool get isEnabled => enabled;
  int get logCount => _buffer.length;

  int _priority(String level) => switch (level) { 'debug' => 0, 'info' => 1, 'warn' => 2, 'warning' => 2, 'error' => 3, _ => 0 };
}

LogCollector? _globalLogCollector;
LogCollector? getGlobalLogCollector() => _globalLogCollector;
void setGlobalLogCollector(LogCollector? collector) => _globalLogCollector = collector;
```

**Modify: `lib/utils/logging/global_logger.dart`**

Add forwarding to LogCollector in each log method:

```dart
void d(String message, {Map<String, dynamic>? context}) {
  _logger.log(LogLevel.debug, message);
  _forwardToCollector('debug', message, context);
}
void i(String message, {Map<String, dynamic>? context}) {
  _logger.log(LogLevel.info, message);
  _forwardToCollector('info', message, context);
}
void w(String message, {Map<String, dynamic>? context}) {
  _logger.log(LogLevel.warning, message);
  _forwardToCollector('warn', message, context);
}
void e(String message, {Map<String, dynamic>? context}) {
  _logger.log(LogLevel.error, message);
  _forwardToCollector('error', message, context);
}

void _forwardToCollector(String level, String message, Map<String, dynamic>? context) {
  final collector = getGlobalLogCollector();
  if (collector?.isActive == true) collector!.addEntry(level: level, message: message, context: context);
}
```

**Modify: `lib/utils/stats/call_report_collector.dart`**

Add LogCollector integration alongside existing CallReportLogCollector:

```dart
LogCollector? _logCollector;

void configureLogCollector({required bool enabled, required CollectorLogLevel level, required int maxEntries}) {
  _logCollector = LogCollector(enabled: enabled, level: level, maxEntries: maxEntries);
  setGlobalLogCollector(_logCollector);
  _logCollector!.start();
}

// In postReport(): include _logCollector?.getLogsJson() in payload
// In stop(): _logCollector?.stop();
// In cleanup(): _logCollector?.clear(); _logCollector = null;
```

**Modify: `lib/telnyx_client.dart`** — Register LogCollector when call starts, reading from config.

### 3.3 JS SDK Reference

- `src/Modules/Verto/util/LogCollector.ts` — `LogCollector` class with `enabled`, `level`, `maxEntries`, `start()`, `stop()`, `addEntry()`, `getLogs()`, `drain()`, `getLogCount()`, FIFO eviction, global singleton
- `src/Modules/Verto/util/logger.ts` — `methodFactory` intercepts all log calls, forwards to LogCollector; `setConsoleLoggerMinLevel()` controls console independently
- `src/Modules/Verto/webrtc/CallReportCollector.ts` — creates LogCollector in constructor, includes logs in `postReport()` and `flush()`

### 3.4 Flutter-Specific Considerations

- No DOM objects to serialize — Dart objects already JSON-serializable via `toJson()`
- `GlobalLogger` is already a singleton — just add forwarding hook
- Keep existing `CallReportLogCollector` for structured lifecycle events (complementary)
- No platform channels — pure Dart
- FIFO eviction prevents unbounded growth
- Dart single-threaded — no concurrent access concerns

### 3.5 Dependencies

- **VSDK-422** — needs `debug`, `debugLogLevel`, `debugLogMaxEntries` config fields

### 3.6 Test Plan

1. LogCollector start/stop: entries only captured between start() and stop()
2. Level filtering: when level is warn, debug/info entries not captured
3. Max entries eviction: fill beyond maxEntries, oldest evicted (FIFO)
4. Drain: returns all entries and clears buffer
5. GlobalLogger integration: `GlobalLogger().d(...)` forwarded to LogCollector when active
6. GlobalLogger inactive: no entries captured when not started
7. CallReport integration: LogCollector entries in CallReportPayload.logs
8. Context serialization: nested objects serialize correctly
9. Intermediate flush: after drain(), new entries captured for next segment
10. Concurrent calls: LogCollector doesn't leak between calls (start/stop lifecycle)

---

## 4. VSDK-421: Call Quality Warnings

### 4.1 What Needs to Be Built

The Flutter SDK has `CallQualityMetrics` and `CallQuality` (MOS-based) but no structured **warning event system**. The JS SDK has 25+ warning codes with structured `ITelnyxWarning` objects (code, name, message, description, causes, solutions) and 23 error codes with `fatal` flag.

We need to:
1. Port `SDK_WARNINGS` registry (25 codes) to Dart
2. Port `SDK_ERRORS` registry (23 codes) to Dart
3. Create `TelnyxError` and `TelnyxWarning` data classes
4. Add `QualityWarningMonitor` for stats-based warning detection
5. Wire ICE/connection warnings from peer connection event handlers
6. Expose `onWarning` and `onError` callbacks on `TelnyxClient`

### 4.2 Files to Create

**`lib/model/telnyx_error.dart`** — Structured error class with code, name, message, description, causes[], solutions[], fatal flag, optional sessionId/callId.

**`lib/model/telnyx_warning.dart`** — Structured warning class with code, name, message, description, causes[], solutions[], optional sessionId/callId.

**`lib/model/sdk_error_codes.dart`** — Constants for all 23 error codes (40001-49001) ported from `errorCodes.ts`.

**`lib/model/sdk_warning_codes.dart`** — Constants for all 25 warning codes (31001-36005) ported from `errorCodes.ts`.

**`lib/model/sdk_error_registry.dart`** — `Map<int, SdkErrorDefinition>` with full descriptions, causes, solutions, fatal flag. `createError(code)` factory.

**`lib/model/sdk_warning_registry.dart`** — `Map<int, SdkWarningDefinition>` with full descriptions, causes, solutions. `createWarning(code)` factory.

**`lib/utils/stats/quality_warning_monitor.dart`** — Stats-based warning detection:

```dart
class QualityWarningMonitor {
  final void Function(TelnyxWarning warning) onWarning;
  final String callId;
  final String? sessionId;

  // Thresholds (matching JS SDK CallReportCollector constants)
  static const int _consecutiveBreachesRequired = 3;
  static const double _thresholdRttMs = 0.4;       // 400ms (seconds from WebRTC API)
  static const double _thresholdJitterMs = 30.0;    // 30ms
  static const double _thresholdPacketLossPct = 1.0; // 1%
  static const double _thresholdMos = 3.5;
  static const double _thresholdLocalAudioLevel = 0.001;
  static const double _thresholdInboundAudioLevel = 0.001;
  static const int _confirmedLocalAudioSilenceMs = 30000;
  static const int _warningThrottleMs = 15000;

  // State: breach counters, active warnings, throttle timestamps
  final Map<int, int> _breachCounters = {};
  final Set<int> _activeWarnings = {};
  final Map<int, int> _lastWarningEmitted = {};
  int? _prevPacketsReceived, _prevPacketsLost;
  StatsInterval? _previousStatsEntry;
  bool _hasConfirmedLocalAudio = false;
  int _confirmedLocalAudioSilenceMs = 0;

  void checkStats(StatsInterval statsEntry, {Map<String, dynamic>? inboundAudio});
  void _trackBreach(int code, bool isBreach);
  void _trackLowLocalAudio(StatsInterval statsEntry);
  void _trackLowInboundAudio(StatsInterval statsEntry);
  void _emitWarning(int code);
  void reset();
}
```

Warning detection logic (ported from JS `CallReportCollector._checkQualityWarnings()`):
- **HIGH_RTT (31001):** RTT > 0.4s for 3+ consecutive intervals
- **HIGH_JITTER (31002):** jitter > 30ms for 3+ consecutive intervals
- **HIGH_PACKET_LOSS (31003):** packet loss > 1% for 3+ consecutive intervals (delta-based)
- **LOW_MOS (31004):** MOS < 3.5 for 3+ consecutive intervals (simplified E-model)
- **LOW_LOCAL_AUDIO (31005):** audio level < 0.001 for 3+ intervals (before confirmation) or 30s continuous silence (after)
- **LOW_INBOUND_AUDIO (31006):** inbound audio < 0.001 for 3+ consecutive intervals
- **LOW_BYTES_RECEIVED (32001):** bytesReceived delta == 0 for 3+ intervals
- **LOW_BYTES_SENT (32002):** bytesSent delta == 0 for 3+ intervals
- **ICE_CANDIDATE_PAIR_CHANGED (33008):** selected pair ID changed mid-call
- Throttling: re-emit at most once every 15s while condition persists

### 4.3 Files to Modify

**`lib/utils/stats/call_report_collector.dart`** — Integrate `QualityWarningMonitor`:
- Add `QualityWarningMonitor? _warningMonitor` field
- Add `onWarning` callback parameter
- In `_collectStats()`, after creating stats entry, call `_warningMonitor.checkStats()`
- In `start()`, create `QualityWarningMonitor` if `onWarning` is provided

**`lib/peer/peer.dart`** (and `lib/peer/web/peer.dart`) — Wire ICE/connection warnings:
- `onIceConnectionState` == 'disconnected' → emit `ICE_CONNECTIVITY_LOST` (33001)
- ICE gathering complete with 0 candidates → emit `ICE_GATHERING_EMPTY` (33003)
- `onPeerConnectionState` == 'failed' → emit `PEER_CONNECTION_FAILED` (33004)
- Only host candidates gathered → emit `ONLY_HOST_ICE_CANDIDATES` (33005)
- Selected candidate pair ID changed → emit `ICE_CANDIDATE_PAIR_CHANGED` (33008)

**`lib/telnyx_client.dart`** — Add warning/error callbacks:

```dart
typedef TelnyxWarningCallback = void Function(TelnyxWarning warning);
typedef TelnyxErrorCallback = void Function(TelnyxError error);

class TelnyxClient {
  TelnyxWarningCallback? onWarning;
  TelnyxErrorCallback? onError;

  // When creating a call:
  final warningMonitor = QualityWarningMonitor(
    onWarning: (warning) {
      onWarning?.call(warning);
      GlobalLogger().w('Warning: ${warning.name}', context: warning.toJson());
    },
    callId: callId,
    sessionId: sessionId,
  );
  callReportCollector.setWarningMonitor(warningMonitor);
}
```

### 4.4 JS SDK Reference

**Warning Registry:** `src/Modules/Verto/util/constants/warnings.ts`
- `SDK_WARNINGS` — Map of 25 warning codes to `ITelnyxWarning` objects
- Each warning: `code`, `name`, `message`, `description`, `causes[]`, `solutions[]`
- `createTelnyxWarning(code, message?)` factory

**Error Registry:** `src/Modules/Verto/util/constants/errors.ts`
- `_SDK_ERRORS` — Map of 23 error codes to `SdkErrorDefinition` objects
- Each error: `name`, `message`, `description`, `causes[]`, `solutions[]`, `fatal: boolean`
- `createTelnyxError(code, message?, fatalOverride?)` factory

**Error Code Constants:** `src/Modules/Verto/util/constants/errorCodes.ts`
- `TELNYX_ERROR_CODES` and `TELNYX_WARNING_CODES` named constants

**Warning Emission:** `src/Modules/Verto/webrtc/CallReportCollector.ts`
- `_checkQualityWarnings()` called after each stats interval
- `_trackBreach(code, isBreach)` — consecutive breach counter, emits after 3
- `_trackLowLocalAudio()` — confirmation window logic (30s after confirmed audio)
- `_trackLowInboundAudio()` — 3 consecutive breaches below threshold
- `_emitWarning(code)` — creates warning via `createTelnyxWarning()`, calls `onWarning`
- Throttling: `_lastWarningEmitted[code]` with 15s minimum between repeated warnings
- `_activeWarnings` Set tracks ongoing warning episodes

### 4.5 Flutter-Specific Considerations

- **No event emitter pattern:** Flutter uses callbacks, not JS's `.on()/.off()`. Expose `onWarning` and `onError` callbacks on `TelnyxClient`.
- **Stream alternative:** Could use `Stream<TelnyxWarning>` but callbacks are consistent with existing patterns (e.g., `onCallQualityChange`).
- **Warning detection runs inside `CallReportCollector._collectStats()`** — no extra timer needed.
- **ICE warnings from Peer class:** These are event-driven, not stats-driven. Wire in `Peer` class event handlers.
- **MOS calculation:** The JS SDK uses a simplified E-model formula inside `_checkQualityWarnings()`: `R = 93.2 - jitter*0.11 - packetLossPct*2.5 - rttMs*0.01; MOS = max(1, min(4.5, 1 + 0.035*R + R*(R-60)*(100-R)*7e-6))`. This is different from the Flutter SDK's `MosCalculator` class which uses the full E-Model. For warning detection parity, use the same simplified formula as the JS SDK.
- No platform channels — pure Dart.

### 4.6 Dependencies

- **VSDK-422** — needs `debug` flag and `debugLogLevel` for warning log level
- **VSDK-420** — logs warnings into `LogCollector` for call reports

### 4.7 Test Plan

1. Warning registry completeness: all 25 warning codes in `SdkWarningRegistry` with all fields
2. Error registry completeness: all 23 error codes in `SdkErrorRegistry` with all fields including `fatal`
3. createWarning: `SdkWarningRegistry.createWarning(code)` returns correct `TelnyxWarning`
4. createError: `SdkErrorRegistry.createError(code)` returns correct `TelnyxError`
5. HIGH_RTT: RTT > 0.4s for 3 consecutive intervals → warning emitted
6. HIGH_RTT reset: RTT returns to normal → counter reset, warning can fire again
7. HIGH_JITTER: jitter > 30ms for 3 intervals → warning
8. HIGH_PACKET_LOSS: loss > 1% for 3 intervals → warning (delta-based calculation)
9. LOW_MOS: MOS < 3.5 for 3 intervals → warning
10. LOW_LOCAL_AUDIO (pre-confirmation): audio < 0.001 for 3 intervals → warning
11. LOW_LOCAL_AUDIO (post-confirmation): 30s continuous silence → warning
12. LOW_INBOUND_AUDIO: inbound < 0.001 for 3 intervals → warning
13. LOW_BYTES_RECEIVED: bytesReceived delta == 0 for 3 intervals → warning
14. LOW_BYTES_SENT: bytesSent delta == 0 for 3 intervals → warning
15. Throttling: same warning not re-emitted within 15s
16. ICE_CANDIDATE_PAIR_CHANGED: pair ID change → warning
17. ICE_CONNECTIVITY_LOST: iceConnectionState 'disconnected' → warning
18. PEER_CONNECTION_FAILED: peerConnectionState 'failed' → warning
19. Fatal error: `TelnyxError` with `fatal=true` terminates call
20. Non-fatal error: `TelnyxError` with `fatal=false` logged but call continues
21. Warning callback: `onWarning` callback fires with structured `TelnyxWarning`
22. Error callback: `onError` callback fires with structured `TelnyxError`

---

## 5. VSDK-419: PreCallDiagnostic for Flutter SDK

### 5.1 What Needs to Be Built

The JS SDK has `PreCallDiagnosis` (`src/PreCallDiagnosis.ts`) — a static `run()` method that connects to the Telnyx backend, makes a test call to a TexML application number, collects WebRTC stats, and returns a diagnostic `Report` with ICE candidate stats, jitter/RTT MinMaxAverage, MOS, quality rating, and session stats.

The Flutter SDK has no equivalent. We need to create a `PreCallDiagnostic` class that:
1. Connects to the Telnyx backend using existing `TelnyxClient`
2. Makes a test call to a specified destination
3. Collects WebRTC stats during the call
4. Computes MOS and quality from collected stats
5. Returns a structured `DiagnosticReport`
6. Disconnects cleanly

### 5.2 Files to Create

**Create: `lib/utils/pre_call_diagnosis.dart`**

```dart
/// ICE candidate statistics for diagnostic report
class RTCIceCandidateStats {
  final String? address;
  final String? candidateType;
  final bool? deleted;
  final String id;
  final int? port;
  final int? priority;
  final String? protocol;
  final String? relayProtocol;
  final String? timestamp;
  final String? transportId;
  final String? type;
  final String? url;
}

/// Min/max/average for a metric
class MinMaxAverage {
  final double min;
  final double max;
  final double average;
}

/// Quality rating
enum DiagnosticQuality { excellent, good, fair, poor, bad }

/// Session stats from diagnostic call
class DiagnosticSessionStats {
  final int packetsReceived;
  final int packetsLost;
  final int packetsSent;
  final int bytesSent;
  final int bytesReceived;
}

/// Full diagnostic report
class DiagnosticReport {
  final List<RTCIceCandidateStats> iceCandidateStats;
  final Map<String, dynamic>? iceCandidatePairStats;
  final MinMaxAverage jitter;
  final MinMaxAverage rtt;
  final double mos;
  final DiagnosticQuality quality;
  final DiagnosticSessionStats sessionStats;
}

/// Options for pre-call diagnosis
class PreCallDiagnosisOptions {
  final String texMLApplicationNumber;
  final String? sipToken;
  final String? sipUser;
  final String? sipPassword;
  final String sipCallerIDName;
  final String sipCallerIDNumber;

  PreCallDiagnosisOptions({
    required this.texMLApplicationNumber,
    this.sipToken,
    this.sipUser,
    this.sipPassword,
    required this.sipCallerIDName,
    required this.sipCallerIDNumber,
  });
}

/// Pre-call diagnosis for testing call quality before establishing a real call.
///
/// Connects to Telnyx backend, makes a test call, collects stats, and returns
/// a diagnostic report. Mirrors JS SDK's `PreCallDiagnosis.run()`.
class PreCallDiagnostic {
  /// Execute pre-call diagnosis and return a report.
  static Future<DiagnosticReport> run(PreCallDiagnosisOptions options) async {
    // 1. Create TelnyxClient with credentials
    // 2. Connect and wait for Ready
    // 3. Make a new call to texMLApplicationNumber with debug=true
    // 4. Listen for stats reports via WebRTCStatsReporter
    // 5. Collect stats over a few seconds
    // 6. Compute MinMaxAverage for jitter and RTT
    // 7. Compute MOS using MosCalculator
    // 8. Determine quality from MOS
    // 9. Collect ICE candidate stats
    // 10. Hang up and disconnect
    // 11. Return DiagnosticReport
  }
}
```

### 5.3 Implementation Details

The `run()` method flow (mirroring JS `PreCallDiagnosis.run()`):

1. **Create client:** `TelnyxClient` with `TokenConfig` or `CredentialConfig` from options
2. **Connect:** `client.connect()` and wait for `onSocketConnected` 
3. **Make test call:** `client.newCall(destinationNumber: options.texMLApplicationNumber, debug: true)`
4. **Collect stats:** Subscribe to stats updates via `WebRTCStatsReporter.onCallQualityChange` callback. Collect multiple samples over ~5 seconds.
5. **Compute aggregates:** For jitter and RTT, compute min, max, and average across all samples
6. **Compute MOS:** Use existing `MosCalculator.calculateMos()` with average jitter and RTT
7. **Determine quality:** Use `CallQuality.fromMos()` to get quality rating
8. **Collect ICE candidates:** Extract from `WebRTCStatsReporter` debug report data (onIceCandidate events)
9. **Clean up:** Hang up the call and disconnect the client
10. **Return report:** Construct and return `DiagnosticReport`

Key differences from JS implementation:
- JS uses `register(SwEvent.StatsReport, callback)` to intercept stats. Flutter uses `onCallQualityChange` callback on `WebRTCStatsReporter`.
- JS uses `client.newCall({ debug: true })` which triggers stats collection. Flutter already has `debug` flag in config.
- JS uses `mapReport()` to transform raw stats timeline. Flutter needs similar mapping from `CallQualityMetrics` to `DiagnosticReport`.
- JS resolves the report promise when first `StatsReport` event fires (entire timeline). Flutter should collect multiple `CallQualityMetrics` samples over a few seconds for better averaging.

### 5.4 JS SDK Reference

**File: `src/PreCallDiagnosis.ts`**

```typescript
export class PreCallDiagnosis {
  static async run(options: PreCallDiagnosisOptions): Promise<Report> {
    // 1. Create TelnyxRTC client with credentials
    const client = new TelnyxRTC(options.credentials);
    await client.connect();

    // 2. Set up promise for report
    const _reportPromise = deferredPromise<Report>({});
    
    // 3. Listen for errors
    client.on(SwEvent.Notification, (notification) => {
      if (notification.call && notification.call.sipCode >= 400) {
        _reportPromise.reject(new Error(notification.call.sipReason));
      }
    });

    // 4. Register for StatsReport event
    register(SwEvent.StatsReport, (data) => {
      _reportPromise.resolve(PreCallDiagnosis.mapReport(data));
    });

    // 5. Wait for ready, then make test call
    await _clientReadyPromise.promise;
    await client.newCall({
      destinationNumber: options.texMLApplicationNumber,
      debug: true,
    });

    // 6. Wait for report, disconnect, return
    const report = await _reportPromise.promise;
    await client.disconnect();
    return report;
  }

  private static mapReport(report: any): Report {
    // Extract ICE candidates from onicecandidate events
    // Extract stats from stats events
    // Compute MinMaxAverage for jitter and RTT
    // Calculate MOS using calculateMOS()
    // Determine quality using getQuality()
    // Build session stats from last frame
    return { iceCandidateStats, iceCandidatePairStats, summaryStats, sessionStats };
  }
}
```

**File: `src/utils/mos.ts`** — `calculateMOS()` and `getQuality()` functions (already ported to Flutter as `MosCalculator` and `CallQuality`).

### 5.5 Flutter-Specific Considerations

- **No `SwEvent.StatsReport` equivalent:** Flutter uses callbacks. Use `onCallQualityChange` on `WebRTCStatsReporter` to collect metrics.
- **No `register()` for global events:** Flutter uses direct callback wiring. Need to wire the stats callback before making the test call.
- **Stats collection duration:** JS resolves on first `StatsReport` (which is the full timeline from `@peermetrics/webrtc-stats`). Flutter's `onCallQualityChange` fires every 100ms. Collect multiple samples over 3-5 seconds, then compute averages.
- **ICE candidate collection:** The Flutter `WebRTCStatsReporter` already sends `onIceCandidate` events via debug report data. Intercept these to build `iceCandidateStats` list. Alternatively, listen to `peerConnection.onIceCandidate` directly.
- **Call cleanup:** Ensure the test call is hung up and client disconnected even if diagnosis fails. Use try/finally.
- **Error handling:** If the call fails (SIP 4xx/5xx), throw an error with the SIP reason.
- **No platform channels** — uses existing Flutter WebRTC infrastructure.
- **Timeout:** Add a safety timeout (e.g., 30 seconds) to prevent hanging if stats never arrive.

### 5.6 Dependencies

- **VSDK-422** — uses `debug` config flag to enable stats collection
- Existing `MosCalculator` and `CallQuality` classes
- Existing `TelnyxClient`, `Call`, and `WebRTCStatsReporter`

### 5.7 Test Plan

1. **DiagnosticReport structure:** Verify `DiagnosticReport` has all required fields (iceCandidateStats, iceCandidatePairStats, jitter, rtt, mos, quality, sessionStats)
2. **MinMaxAverage computation:** Given [10, 20, 30], verify min=10, max=30, average=20
3. **MOS computation:** Given jitter=5ms, rtt=50ms, packetsLost=0, verify MOS is in excellent range (4.0+)
4. **Quality mapping:** Verify MOS > 4.0 → excellent, 3.5-4.0 → good, 3.0-3.5 → fair, 2.0-3.0 → poor, <2.0 → bad
5. **ICE candidate extraction:** Verify ICE candidates are collected from the test call
6. **Run with token config:** `PreCallDiagnostic.run()` with `sipToken` connects, makes test call, returns report
7. **Run with credential config:** Same with `sipUser`/`sipPassword`
8. **Error handling — SIP 4xx:** If test call returns SIP 4xx, throws error with sipReason
9. **Error handling — connection failure:** If client can't connect, throws error
10. **Timeout:** If no stats received within 30s, throws timeout error
11. **Cleanup on success:** Call is hung up and client disconnected after successful diagnosis
12. **Cleanup on failure:** Call is hung up and client disconnected even if diagnosis fails (try/finally)
13. **Jitter/RTT averaging:** Multiple stats samples collected, correct min/max/average computed
14. **Session stats:** packetsReceived, packetsLost, packetsSent, bytesSent, bytesReceived are correctly extracted from the last stats frame
15. **Integration with existing TelnyxClient:** Verify that PreCallDiagnostic uses TelnyxClient API correctly (connect, newCall, hangup, disconnect)

---

## 6. Test Plan Summary

### VSDK-422 (Debug Config) — 8 tests
1. Config defaults
2. Config override
3. debugLogLevel filtering
4. debugOutput file mode
5. enableCallReports=false
6. callReportFlushInterval
7. maxReconnectAttempts
8. prefetchIceCandidates

### VSDK-420 (LogCollector) — 10 tests
1. LogCollector start/stop
2. Level filtering
3. Max entries eviction (FIFO)
4. Drain
5. GlobalLogger integration
6. GlobalLogger inactive
7. CallReport integration
8. Context serialization
9. Intermediate flush
10. Concurrent calls lifecycle

### VSDK-421 (Quality Warnings) — 22 tests
1. Warning registry completeness
2. Error registry completeness
3. createWarning factory
4. createError factory
5. HIGH_RTT detection
6. HIGH_RTT reset
7. HIGH_JITTER detection
8. HIGH_PACKET_LOSS detection (delta-based)
9. LOW_MOS detection
10. LOW_LOCAL_AUDIO pre-confirmation
11. LOW_LOCAL_AUDIO post-confirmation (30s silence)
12. LOW_INBOUND_AUDIO detection
13. LOW_BYTES_RECEIVED detection
14. LOW_BYTES_SENT detection
15. Warning throttling (15s)
16. ICE_CANDIDATE_PAIR_CHANGED
17. ICE_CONNECTIVITY_LOST
18. PEER_CONNECTION_FAILED
19. Fatal error terminates call
20. Non-fatal error continues
21. Warning callback fires
22. Error callback fires

### VSDK-419 (PreCallDiagnostic) — 15 tests
1. DiagnosticReport structure
2. MinMaxAverage computation
3. MOS computation
4. Quality mapping
5. ICE candidate extraction
6. Run with token config
7. Run with credential config
8. Error handling — SIP 4xx
9. Error handling — connection failure
10. Timeout (30s)
11. Cleanup on success
12. Cleanup on failure (try/finally)
13. Jitter/RTT averaging
14. Session stats extraction
15. Integration with TelnyxClient API

### Total: 55 tests across 4 tickets

---

## Appendix: File Summary

### New Files to Create

| File | Ticket | Purpose |
|------|-------|---------|
| `lib/utils/logging/log_collector.dart` | VSDK-420 | LogCollector class + global singleton |
| `lib/model/telnyx_error.dart` | VSDK-421 | Structured TelnyxError class |
| `lib/model/telnyx_warning.dart` | VSDK-421 | Structured TelnyxWarning class |
| `lib/model/sdk_error_codes.dart` | VSDK-421 | Error code constants (23 codes) |
| `lib/model/sdk_warning_codes.dart` | VSDK-421 | Warning code constants (25 codes) |
| `lib/model/sdk_error_registry.dart` | VSDK-421 | Error registry with descriptions/causes/solutions/fatal |
| `lib/model/sdk_warning_registry.dart` | VSDK-421 | Warning registry with descriptions/causes/solutions |
| `lib/utils/stats/quality_warning_monitor.dart` | VSDK-421 | Stats-based warning detection + thresholds |
| `lib/utils/pre_call_diagnosis.dart` | VSDK-419 | PreCallDiagnostic class + DiagnosticReport |

### Existing Files to Modify

| File | Ticket | Changes |
|------|-------|---------|
| `lib/config/telnyx_config.dart` | VSDK-422 | Add 9 new config fields + update constructors |
| `lib/utils/logging/global_logger.dart` | VSDK-420 | Add LogCollector forwarding in d/i/w/e methods |
| `lib/utils/stats/call_report_collector.dart` | VSDK-420, VSDK-421 | Add LogCollector integration + QualityWarningMonitor |
| `lib/telnyx_client.dart` | VSDK-420, VSDK-421 | Register LogCollector, add onWarning/onError callbacks |
| `lib/peer/peer.dart` | VSDK-421 | Wire ICE/connection warning emission |
| `lib/peer/web/peer.dart` | VSDK-421 | Wire ICE/connection warning emission (web) |
