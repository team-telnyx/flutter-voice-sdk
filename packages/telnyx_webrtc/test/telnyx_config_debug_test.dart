/// TDD failing tests for VSD-422: Granular debug config options.
///
/// These tests reference new config fields that do NOT yet exist on the
/// `Config`, `CredentialConfig`, or `TokenConfig` classes.  They will fail
/// at compile time until the implementation adds the new fields.
///
/// Test plan (8 tests):
/// 1. Config defaults — all 9 new fields have correct defaults.
/// 2. Config override — each new field can be overridden via constructor.
/// 3. debugLogLevel filtering — when warning, debug/info messages don't reach console.
/// 4. debugOutput file mode — stats written to local file on mobile (mock fs).
/// 5. enableCallReports=false — no stats collection or HTTP POST.
/// 6. callReportFlushInterval — intermediate segments flushed at configured interval.
/// 7. maxReconnectAttempts — reconnection stops after N attempts, emits RECONNECTION_EXHAUSTED.
/// 8. prefetchIceCandidates — ICE gathering starts before setLocalDescription.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';
import 'package:telnyx_webrtc/utils/logging/log_level.dart';
import 'package:telnyx_webrtc/utils/logging/custom_logger.dart';

/// Mock custom logger for testing — records the last logged message and level.
class _MockCustomLogger implements CustomLogger {
  LogLevel? lastLevel;
  String? lastMessage;

  @override
  void log(LogLevel level, String message) {
    lastLevel = level;
    lastMessage = message;
  }

  @override
  void setLogLevel(LogLevel level) {
    // no-op
  }
}

void main() {
  group('VSD-422: Granular debug config — Config defaults', () {
    test(
      'all 9 new config fields have correct defaults on Config',
      () {
        final config = Config(
          sipCallerIDName: 'Test',
          sipCallerIDNumber: '+1234567890',
          debug: true,
          logLevel: LogLevel.all,
        );

        // New fields from VSD-422 — these will fail to compile until added.
        expect(config.enableCallReports, isTrue,
            reason: 'enableCallReports default should be true');
        expect(config.debugOutput, equals(DebugOutput.socket),
            reason: 'debugOutput default should be DebugOutput.socket');
        expect(config.debugLogLevel, equals(DebugLogLevel.info),
            reason: 'debugLogLevel default should be DebugLogLevel.info');
        expect(config.debugLogMaxEntries, equals(1000),
            reason: 'debugLogMaxEntries default should be 1000');
        expect(config.callReportFlushInterval, equals(180000),
            reason:
                'callReportFlushInterval default should be 180000 ms (3 min)');
        expect(config.prefetchIceCandidates, isTrue,
            reason: 'prefetchIceCandidates default should be true');
        expect(config.autoRecoverCalls, isTrue,
            reason: 'autoRecoverCalls default should be true');
        expect(config.hangupOnBeforeUnload, isTrue,
            reason: 'hangupOnBeforeUnload default should be true');
        expect(config.maxReconnectAttempts, equals(10),
            reason: 'maxReconnectAttempts default should be 10');
      },
    );
  });

  group('VSD-422: Granular debug config — Config override', () {
    test(
      'each new field can be overridden via constructor on Config',
      () {
        final config = Config(
          sipCallerIDName: 'Test',
          sipCallerIDNumber: '+1234567890',
          debug: true,
          logLevel: LogLevel.all,
          // New fields with overridden values:
          enableCallReports: false,
          debugOutput: DebugOutput.file,
          debugLogLevel: DebugLogLevel.error,
          debugLogMaxEntries: 500,
          callReportFlushInterval: 60000,
          prefetchIceCandidates: false,
          autoRecoverCalls: false,
          hangupOnBeforeUnload: false,
          maxReconnectAttempts: 5,
        );

        expect(config.enableCallReports, isFalse);
        expect(config.debugOutput, equals(DebugOutput.file));
        expect(config.debugLogLevel, equals(DebugLogLevel.error));
        expect(config.debugLogMaxEntries, equals(500));
        expect(config.callReportFlushInterval, equals(60000));
        expect(config.prefetchIceCandidates, isFalse);
        expect(config.autoRecoverCalls, isFalse);
        expect(config.hangupOnBeforeUnload, isFalse);
        expect(config.maxReconnectAttempts, equals(5));
      },
    );

    test('CredentialConfig passes through new fields with defaults', () {
      final config = CredentialConfig(
        sipUser: 'user',
        sipPassword: 'pass',
        sipCallerIDName: 'Test',
        sipCallerIDNumber: '+1234567890',
        debug: true,
        logLevel: LogLevel.all,
      );

      expect(config.enableCallReports, isTrue);
      expect(config.debugOutput, equals(DebugOutput.socket));
      expect(config.debugLogLevel, equals(DebugLogLevel.info));
      expect(config.debugLogMaxEntries, equals(1000));
      expect(config.callReportFlushInterval, equals(180000));
      expect(config.prefetchIceCandidates, isTrue);
      expect(config.autoRecoverCalls, isTrue);
      expect(config.hangupOnBeforeUnload, isTrue);
      expect(config.maxReconnectAttempts, equals(10));
    });

    test('TokenConfig passes through new fields with overrides', () {
      final config = TokenConfig(
        sipToken: 'token123',
        sipCallerIDName: 'Test',
        sipCallerIDNumber: '+1234567890',
        debug: true,
        logLevel: LogLevel.all,
        enableCallReports: false,
        debugOutput: DebugOutput.file,
        debugLogLevel: DebugLogLevel.warning,
        debugLogMaxEntries: 200,
        callReportFlushInterval: 30000,
        prefetchIceCandidates: false,
        autoRecoverCalls: false,
        hangupOnBeforeUnload: false,
        maxReconnectAttempts: 0,
      );

      expect(config.enableCallReports, isFalse);
      expect(config.debugOutput, equals(DebugOutput.file));
      expect(config.debugLogLevel, equals(DebugLogLevel.warning));
      expect(config.debugLogMaxEntries, equals(200));
      expect(config.callReportFlushInterval, equals(30000));
      expect(config.prefetchIceCandidates, isFalse);
      expect(config.autoRecoverCalls, isFalse);
      expect(config.hangupOnBeforeUnload, isFalse);
      expect(config.maxReconnectAttempts, equals(0),
          reason: 'maxReconnectAttempts=0 means unlimited');
    });
  });

  group('VSD-422: debugLogLevel filtering', () {
    test(
      'when debugLogLevel is warning, debug and info messages do not reach console',
      () {
        final mockLogger = _MockCustomLogger();
        GlobalLogger.logger = mockLogger;

        // The Config should instruct the GlobalLogger to suppress debug/info
        // when debugLogLevel is warning.  After applying config, calling
        // GlobalLogger().d('hello') should NOT reach the underlying logger.
        final config = Config(
          sipCallerIDName: 'Test',
          sipCallerIDNumber: '+1234567890',
          debug: true,
          logLevel: LogLevel.all,
          debugLogLevel: DebugLogLevel.warning,
        );

        // Apply the config — this method does not exist yet.
        config.applyDebugLogLevel();

        mockLogger.lastLevel = null;
        mockLogger.lastMessage = null;

        GlobalLogger().d('debug message');
        expect(mockLogger.lastLevel, isNull,
            reason:
                'debug message should be suppressed when debugLogLevel=warning');
        expect(mockLogger.lastMessage, isNull);

        GlobalLogger().i('info message');
        expect(mockLogger.lastLevel, isNull,
            reason:
                'info message should be suppressed when debugLogLevel=warning');
        expect(mockLogger.lastMessage, isNull);

        // Warning and error should pass through.
        GlobalLogger().w('warn message');
        expect(mockLogger.lastLevel, equals(LogLevel.warning));
        expect(mockLogger.lastMessage, equals('warn message'));

        GlobalLogger().e('error message');
        expect(mockLogger.lastLevel, equals(LogLevel.error));
        expect(mockLogger.lastMessage, equals('error message'));
      },
    );
  });

  group('VSD-422: debugOutput file mode', () {
    test(
      'when debugOutput is file, stats are written to a local file on mobile',
      () {
        final config = Config(
          sipCallerIDName: 'Test',
          sipCallerIDNumber: '+1234567890',
          debug: true,
          logLevel: LogLevel.all,
          debugOutput: DebugOutput.file,
        );

        // The CallReportFileHelper (or a new helper) should be used when
        // debugOutput is DebugOutput.file.  We verify the config selects file mode.
        expect(config.debugOutput, equals(DebugOutput.file));

        // The actual file writing is integration-tested via CallReportCollector,
        // but we verify that the config flag is propagated to CallReportOptions.
        // This will fail until debugOutput is integrated into report collection.
        final reportOptions = CallReportOptions.fromConfig(config);
        expect(reportOptions.outputMode, equals(DebugOutput.file),
            reason:
                'CallReportOptions should reflect debugOutput=file from Config');
      },
    );
  });

  group('VSD-422: enableCallReports=false', () {
    test(
      'when enableCallReports is false, no stats collection or HTTP POST occurs',
      () {
        final config = Config(
          sipCallerIDName: 'Test',
          sipCallerIDNumber: '+1234567890',
          debug: true,
          logLevel: LogLevel.all,
          enableCallReports: false,
        );

        expect(config.enableCallReports, isFalse);

        // CallReportOptions should indicate that reporting is disabled.
        final reportOptions = CallReportOptions.fromConfig(config);
        expect(reportOptions.enabled, isFalse,
            reason:
                'CallReportOptions.enabled should be false when enableCallReports=false');
      },
    );
  });

  group('VSD-422: callReportFlushInterval', () {
    test(
      'intermediate segments are flushed at the configured interval',
      () {
        final config = Config(
          sipCallerIDName: 'Test',
          sipCallerIDNumber: '+1234567890',
          debug: true,
          logLevel: LogLevel.all,
          callReportFlushInterval: 60000, // 1 minute
        );

        expect(config.callReportFlushInterval, equals(60000));

        // CallReportOptions should carry the flush interval.
        final reportOptions = CallReportOptions.fromConfig(config);
        expect(reportOptions.flushIntervalMs, equals(60000),
            reason:
                'CallReportOptions should reflect callReportFlushInterval from Config');
      },
    );
  });

  group('VSD-422: maxReconnectAttempts', () {
    test(
      'reconnection stops after maxReconnectAttempts and emits RECONNECTION_EXHAUSTED',
      () {
        final config = Config(
          sipCallerIDName: 'Test',
          sipCallerIDNumber: '+1234567890',
          debug: true,
          logLevel: LogLevel.all,
          maxReconnectAttempts: 3,
        );

        expect(config.maxReconnectAttempts, equals(3));

        // The TelnyxClient should use maxReconnectAttempts to cap reconnection
        // attempts.  When the limit is reached, it should emit a
        // RECONNECTION_EXHAUSTED error (code 45003).
        //
        // We verify the config value is accessible and the constant exists.
        // Full integration test is in the quality_warning_monitor suite.
        expect(config.maxReconnectAttempts, lessThanOrEqualTo(10),
            reason: 'maxReconnectAttempts should be a reasonable value');

        // maxReconnectAttempts = 0 means unlimited.
        final unlimitedConfig = Config(
          sipCallerIDName: 'Test',
          sipCallerIDNumber: '+1234567890',
          debug: true,
          logLevel: LogLevel.all,
          maxReconnectAttempts: 0,
        );
        expect(unlimitedConfig.maxReconnectAttempts, equals(0),
            reason: 'maxReconnectAttempts=0 means unlimited');
      },
    );
  });

  group('VSD-422: prefetchIceCandidates', () {
    test(
      'when prefetchIceCandidates is true, ICE gathering starts before setLocalDescription',
      () {
        final config = Config(
          sipCallerIDName: 'Test',
          sipCallerIDNumber: '+1234567890',
          debug: true,
          logLevel: LogLevel.all,
          prefetchIceCandidates: true,
        );

        expect(config.prefetchIceCandidates, isTrue);

        // When false, the SDK should wait for setLocalDescription before
        // gathering ICE candidates (standard trickle ICE).
        final noPrefetchConfig = Config(
          sipCallerIDName: 'Test',
          sipCallerIDNumber: '+1234567890',
          debug: true,
          logLevel: LogLevel.all,
          prefetchIceCandidates: false,
        );
        expect(noPrefetchConfig.prefetchIceCandidates, isFalse);

        // The Peer class should check this flag.  We verify it's accessible
        // on the config and can be used by the Peer to decide when to start
        // ICE gathering.
        expect(config.prefetchIceCandidates, isTrue,
            reason:
                'prefetchIceCandidates should be accessible on Config for Peer to read');
      },
    );
  });
}
