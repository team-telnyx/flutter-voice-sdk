import 'dart:math';

/// Represents the quality level of a WebSocket connection based on ping interval and jitter metrics.
///
/// Quality levels for 30-second server ping intervals:
/// - [disconnected]: Not connected to the socket
/// - [calculating]: Initial connection phase, not enough data to assess quality yet
/// - [excellent]: Ping intervals close to 30s with minimal jitter (±100ms, <100ms jitter)
/// - [good]: Ping intervals reasonably close to 30s with moderate jitter (±200ms, <200ms jitter)
/// - [fair]: Ping intervals somewhat variable but functional (±300ms, <300ms jitter)
/// - [poor]: Significant deviation from expected intervals or high jitter
enum SocketConnectionQuality {
  /// Not connected to socket
  disconnected,

  /// Initial connection, insufficient data
  calculating,

  /// ~30s ±100ms interval, <100ms jitter
  excellent,

  /// ~30s ±200ms interval, <200ms jitter
  good,

  /// ~30s ±300ms interval, <300ms jitter
  fair,

  /// Significant deviation from 30s or high jitter
  poor,
}

/// Contains comprehensive metrics about the WebSocket connection health.
class SocketConnectionMetrics {
  /// Time between the last two PING messages received (milliseconds)
  final int? intervalMs;

  /// Rolling average of ping intervals (milliseconds)
  final int? averageIntervalMs;

  /// Minimum observed ping interval (milliseconds)
  final int? minIntervalMs;

  /// Maximum observed ping interval (milliseconds)
  final int? maxIntervalMs;

  /// Variation in ping intervals (standard deviation in milliseconds)
  final int? jitterMs;

  /// Count of expected pings that were not received within the expected interval plus tolerance
  final int missedPings;

  /// Total number of pings received
  final int totalPings;

  /// Overall connection quality assessment
  final SocketConnectionQuality quality;

  /// System time when these metrics were calculated
  final int timestamp;

  /// System time of the last received ping
  final int? lastPingTimestamp;

  const SocketConnectionMetrics({
    this.intervalMs,
    this.averageIntervalMs,
    this.minIntervalMs,
    this.maxIntervalMs,
    this.jitterMs,
    this.missedPings = 0,
    this.totalPings = 0,
    this.quality = SocketConnectionQuality.disconnected,
    int? timestamp,
    this.lastPingTimestamp,
  }) : timestamp = timestamp ?? 0;

  /// Calculates the percentage of successfully received pings.
  /// Returns success rate as a percentage (0-100), or 100 if no pings expected yet
  double getSuccessRate() {
    final expectedPings = totalPings + missedPings;
    return expectedPings > 0 ? (totalPings / expectedPings) * 100.0 : 100.0;
  }

  /// Connection quality thresholds (milliseconds)
  static const int _expectedPingIntervalMs = 30000; // 30 seconds
  static const int _excellentToleranceMs = 100; // ±100ms
  static const int _goodToleranceMs = 200; // ±200ms
  static const int _fairToleranceMs = 300; // ±300ms

  /// Jitter thresholds (milliseconds)
  static const int _lowJitterThresholdMs = 100;
  static const int _moderateJitterThresholdMs = 200;
  static const int _highJitterThresholdMs = 300;

  /// Calculates connection quality based on available interval and jitter metrics.
  /// Handles cases where we don't have enough data yet during initial connection.
  ///
  /// [averageInterval] Average time between pings (null if not enough data)
  /// [jitter] Variation in ping intervals (null if not enough data)
  /// Returns calculated [SocketConnectionQuality] based on available data
  static SocketConnectionQuality calculateQuality(
    int? averageInterval,
    int? jitter,
  ) {
    if (averageInterval == null && jitter == null) {
      return SocketConnectionQuality.calculating;
    } else if (averageInterval != null && jitter == null) {
      return _assessByIntervalOnly(averageInterval);
    } else if (averageInterval == null && jitter != null) {
      return _assessByJitterOnly(jitter);
    } else {
      return _assessByBothMetrics(averageInterval!, jitter!);
    }
  }

  /// Assesses connection quality based on interval metrics only.
  static SocketConnectionQuality _assessByIntervalOnly(int averageInterval) {
    final excellentRange = _createIntervalRange(_excellentToleranceMs);
    final goodRange = _createIntervalRange(_goodToleranceMs);
    final fairRange = _createIntervalRange(_fairToleranceMs);

    if (_isInRange(averageInterval, excellentRange)) {
      return SocketConnectionQuality.excellent;
    } else if (_isInRange(averageInterval, goodRange)) {
      return SocketConnectionQuality.good;
    } else if (_isInRange(averageInterval, fairRange)) {
      return SocketConnectionQuality.fair;
    } else {
      return SocketConnectionQuality.poor;
    }
  }

  /// Assesses connection quality based on jitter metrics only.
  static SocketConnectionQuality _assessByJitterOnly(int jitter) {
    if (jitter < _lowJitterThresholdMs) {
      return SocketConnectionQuality.good;
    } else if (jitter < _moderateJitterThresholdMs) {
      return SocketConnectionQuality.fair;
    } else {
      return SocketConnectionQuality.poor;
    }
  }

  /// Assesses connection quality using both interval and jitter metrics.
  static SocketConnectionQuality _assessByBothMetrics(
    int averageInterval,
    int jitter,
  ) {
    final excellentRange = _createIntervalRange(_excellentToleranceMs);
    final goodRange = _createIntervalRange(_goodToleranceMs);
    final fairRange = _createIntervalRange(_fairToleranceMs);

    if (jitter < _lowJitterThresholdMs &&
        _isInRange(averageInterval, excellentRange)) {
      return SocketConnectionQuality.excellent;
    } else if (jitter < _moderateJitterThresholdMs &&
        _isInRange(averageInterval, goodRange)) {
      return SocketConnectionQuality.good;
    } else if (jitter < _highJitterThresholdMs &&
        _isInRange(averageInterval, fairRange)) {
      return SocketConnectionQuality.fair;
    } else {
      return SocketConnectionQuality.poor;
    }
  }

  /// Creates an interval range based on the expected ping interval and tolerance.
  static _IntervalRange _createIntervalRange(int toleranceMs) {
    return _IntervalRange(
      _expectedPingIntervalMs - toleranceMs,
      _expectedPingIntervalMs + toleranceMs,
    );
  }

  /// Checks if a value is within the given range.
  static bool _isInRange(int value, _IntervalRange range) {
    return value >= range.min && value <= range.max;
  }

  /// Creates a copy of this metrics object with updated values
  SocketConnectionMetrics copyWith({
    int? intervalMs,
    int? averageIntervalMs,
    int? minIntervalMs,
    int? maxIntervalMs,
    int? jitterMs,
    int? missedPings,
    int? totalPings,
    SocketConnectionQuality? quality,
    int? timestamp,
    int? lastPingTimestamp,
  }) {
    return SocketConnectionMetrics(
      intervalMs: intervalMs ?? this.intervalMs,
      averageIntervalMs: averageIntervalMs ?? this.averageIntervalMs,
      minIntervalMs: minIntervalMs ?? this.minIntervalMs,
      maxIntervalMs: maxIntervalMs ?? this.maxIntervalMs,
      jitterMs: jitterMs ?? this.jitterMs,
      missedPings: missedPings ?? this.missedPings,
      totalPings: totalPings ?? this.totalPings,
      quality: quality ?? this.quality,
      timestamp: timestamp ?? this.timestamp,
      lastPingTimestamp: lastPingTimestamp ?? this.lastPingTimestamp,
    );
  }

  @override
  String toString() {
    return 'SocketConnectionMetrics('
        'intervalMs: $intervalMs, '
        'averageIntervalMs: $averageIntervalMs, '
        'minIntervalMs: $minIntervalMs, '
        'maxIntervalMs: $maxIntervalMs, '
        'jitterMs: $jitterMs, '
        'missedPings: $missedPings, '
        'totalPings: $totalPings, '
        'quality: $quality, '
        'timestamp: $timestamp, '
        'lastPingTimestamp: $lastPingTimestamp'
        ')';
  }
}

/// Helper class to represent an interval range
class _IntervalRange {
  final int min;
  final int max;

  const _IntervalRange(this.min, this.max);
}