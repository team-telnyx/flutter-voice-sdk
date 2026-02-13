import 'dart:async';
import 'dart:math';

import 'package:telnyx_webrtc/model/socket_connection_metrics.dart';
import 'package:telnyx_webrtc/utils/logging/global_logger.dart';

/// Ping callback for when ping metrics are updated
typedef OnPingCallback = void Function(SocketConnectionMetrics metrics);

/// Mixin that provides ping metrics tracking for WebSocket connections.
///
/// This mixin extracts shared ping/pong handling logic that is common
/// across platform-specific TxSocket implementations (io and web).
mixin TxSocketPingMetricsMixin {
  // Connection metrics tracking
  final List<int> pingTimestamps = [];
  final List<int> pingIntervals = [];
  int? lastPingTimestamp;
  int? connectionStartTime;
  Timer? expectedPingTimer;
  int missedPingCount = 0;

  // Ping callback
  OnPingCallback? onPing;

  // Constants
  static const int maxPingHistorySize = 30;
  static const int expectedPingIntervalMs = 30000;
  static const int pingToleranceMs = 500;

  /// Checks if the received message is a ping message
  bool isPingMessage(dynamic data) {
    if (data is String) {
      try {
        // Check for ping/pong patterns in the message
        return data.contains('"method":"telnyx_rtc.ping"') ||
            data.contains('"method":"telnyx_rtc.pong"') ||
            data.contains('ping') ||
            data.contains('pong');
      } catch (e) {
        return false;
      }
    }
    return false;
  }

  /// Handles a received ping from the server and tracks timing information
  void handlePingReceived() {
    final currentTime = DateTime.now().millisecondsSinceEpoch;

    // Calculate interval from last ping or connection start time
    final referenceTime = lastPingTimestamp ?? connectionStartTime;
    if (referenceTime != null) {
      final interval = currentTime - referenceTime;
      pingIntervals.add(interval);

      // Keep only recent intervals
      while (pingIntervals.length > maxPingHistorySize) {
        pingIntervals.removeAt(0);
      }
    }

    // Track timestamp
    lastPingTimestamp = currentTime;
    pingTimestamps.add(currentTime);
    while (pingTimestamps.length > maxPingHistorySize) {
      pingTimestamps.removeAt(0);
    }

    // Reset missed ping counter and restart timer
    resetExpectedPingTimer();

    // Calculate and emit metrics
    final metrics = calculateConnectionMetrics();
    onPing?.call(metrics);
  }

  /// Resets the timer that tracks expected pings
  void resetExpectedPingTimer() {
    expectedPingTimer?.cancel();
    expectedPingTimer = Timer(
      Duration(milliseconds: expectedPingIntervalMs + pingToleranceMs),
      () {
        // If this fires, we missed an expected ping (with tolerance)
        missedPingCount++;
        GlobalLogger().w(
          'Expected ping not received within ${expectedPingIntervalMs + pingToleranceMs}ms',
        );
      },
    );
  }

  /// Calculates current connection metrics based on ping history.
  /// Returns CALCULATING quality when insufficient data is available,
  /// then progressively provides better assessment as more pings are received.
  SocketConnectionMetrics calculateConnectionMetrics() {
    if (pingIntervals.isEmpty) {
      return SocketConnectionMetrics(
        timestamp: DateTime.now().millisecondsSinceEpoch,
        totalPings: pingTimestamps.length,
        quality: SocketConnectionQuality.calculating,
        lastPingTimestamp: lastPingTimestamp,
      );
    }

    final currentInterval =
        pingIntervals.isNotEmpty ? pingIntervals.last : null;
    final averageInterval = pingIntervals.isNotEmpty
        ? (pingIntervals.reduce((a, b) => a + b) / pingIntervals.length).round()
        : null;
    final minInterval = pingIntervals.isNotEmpty
        ? pingIntervals.reduce((a, b) => a < b ? a : b)
        : null;
    final maxInterval = pingIntervals.isNotEmpty
        ? pingIntervals.reduce((a, b) => a > b ? a : b)
        : null;

    // Calculate jitter (standard deviation)
    int? jitter;
    if (pingIntervals.length > 1 && averageInterval != null) {
      final variance = pingIntervals
              .map((interval) => pow(interval - averageInterval, 2))
              .reduce((a, b) => a + b) /
          pingIntervals.length;
      jitter = sqrt(variance).round();
    }

    // Calculate quality based on metrics
    final quality =
        SocketConnectionMetrics.calculateQuality(averageInterval, jitter);

    return SocketConnectionMetrics(
      intervalMs: currentInterval,
      averageIntervalMs: averageInterval,
      minIntervalMs: minInterval,
      maxIntervalMs: maxInterval,
      jitterMs: jitter,
      missedPings: missedPingCount,
      totalPings: pingTimestamps.length,
      quality: quality,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      lastPingTimestamp: lastPingTimestamp,
    );
  }

  /// Cleans up ping tracking data
  void cleanPingIntervals() {
    connectionStartTime = null;
    lastPingTimestamp = null;
    pingTimestamps.clear();
    pingIntervals.clear();
    missedPingCount = 0;
    expectedPingTimer?.cancel();
    expectedPingTimer = null;
  }

  /// Gets the current connection metrics
  SocketConnectionMetrics getConnectionMetrics() {
    return calculateConnectionMetrics();
  }

  /// Initializes ping tracking at connection start
  void initializePingTracking() {
    cleanPingIntervals();
    connectionStartTime = DateTime.now().millisecondsSinceEpoch;
  }

  /// Emits the initial metrics in calculating state
  void emitInitialMetrics() {
    final initialMetrics = calculateConnectionMetrics();
    onPing?.call(initialMetrics);
  }
}
