// ignore: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html';
import 'dart:math';

import 'package:telnyx_webrtc/model/socket_connection_metrics.dart';
import 'package:telnyx_webrtc/utils/logging/global_logger.dart';

/// Message callback for when a message is received
typedef OnMessageCallback = void Function(dynamic msg);

/// Close callback for when the connection is closed
typedef OnCloseCallback = void Function(int code, String reason);

/// Open callback for when the connection is opened
typedef OnOpenCallback = void Function();

/// Ping callback for when ping metrics are updated
typedef OnPingCallback = void Function(SocketConnectionMetrics metrics);

/// TxSocket class to handle the WebSocket connection
class TxSocket {
  /// Default constructor that initializes the host address and logger
  TxSocket(this.hostAddress) {
    hostAddress = hostAddress.replaceAll('https:', 'wss:');
  }

  String hostAddress;

  late WebSocket _socket;
  late OnOpenCallback onOpen;
  late OnMessageCallback onMessage;
  late OnCloseCallback onClose;
  OnPingCallback? onPing;

  // Connection metrics tracking
  final List<int> _pingTimestamps = [];
  final List<int> _pingIntervals = [];
  int? _lastPingTimestamp;
  int? _connectionStartTime;
  Timer? _expectedPingTimer;
  int _missedPingCount = 0;

  // Constants
  static const int _maxPingHistorySize = 30;
  static const int _expectedPingIntervalMs = 30000;
  static const int _pingToleranceMs = 500;

  /// Connect to the WebSocket server
  void connect() async {
    try {
      _socket = WebSocket(hostAddress);
      
      _socket.onOpen.listen((e) {
        // Initialize connection tracking
        _cleanPingIntervals();
        _connectionStartTime = DateTime.now().millisecondsSinceEpoch;
        onOpen.call();

        // Emit initial calculating state
        final initialMetrics = _calculateConnectionMetrics();
        onPing?.call(initialMetrics);
      });

      _socket.onMessage.listen((e) {
        // Check if this is a ping/pong message
        if (_isPingMessage(e.data)) {
          _handlePingReceived();
        }
        onMessage.call(e.data);
      });

      _socket.onClose.listen((e) {
        _cleanPingIntervals();
        onClose.call(e.code ?? 0, e.reason ?? 'Closed for unknown reason');
      });
    } catch (e) {
      _cleanPingIntervals();
      onClose.call(500, e.toString());
    }
  }

  /// Send data to the WebSocket server
  void send(data) {
    if (_socket.readyState == WebSocket.OPEN) {
      _socket.send(data);
      GlobalLogger().i('TxSocket :: send : \n\n$data');
    } else {
      GlobalLogger().d('WebSocket not connected, message $data not sent');
    }
  }

  /// Close the WebSocket connection
  void close() {
    _cleanPingIntervals();
    _socket.close();
  }

  /// Checks if the received message is a ping message
  bool _isPingMessage(dynamic data) {
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
  void _handlePingReceived() {
    final currentTime = DateTime.now().millisecondsSinceEpoch;

    // Calculate interval from last ping or connection start time
    final referenceTime = _lastPingTimestamp ?? _connectionStartTime;
    if (referenceTime != null) {
      final interval = currentTime - referenceTime;
      _pingIntervals.add(interval);

      // Keep only recent intervals
      while (_pingIntervals.length > _maxPingHistorySize) {
        _pingIntervals.removeAt(0);
      }
    }

    // Track timestamp
    _lastPingTimestamp = currentTime;
    _pingTimestamps.add(currentTime);
    while (_pingTimestamps.length > _maxPingHistorySize) {
      _pingTimestamps.removeAt(0);
    }

    // Reset missed ping counter and restart timer
    _resetExpectedPingTimer();

    // Calculate and emit metrics
    final metrics = _calculateConnectionMetrics();
    onPing?.call(metrics);
  }

  /// Resets the timer that tracks expected pings
  void _resetExpectedPingTimer() {
    _expectedPingTimer?.cancel();
    _expectedPingTimer = Timer(
      Duration(milliseconds: _expectedPingIntervalMs + _pingToleranceMs),
      () {
        // If this fires, we missed an expected ping (with tolerance)
        _missedPingCount++;
        GlobalLogger().w(
          'Expected ping not received within ${_expectedPingIntervalMs + _pingToleranceMs}ms',
        );
      },
    );
  }

  /// Calculates current connection metrics based on ping history.
  /// Returns CALCULATING quality when insufficient data is available,
  /// then progressively provides better assessment as more pings are received.
  SocketConnectionMetrics _calculateConnectionMetrics() {
    if (_pingIntervals.isEmpty) {
      return SocketConnectionMetrics(
        timestamp: DateTime.now().millisecondsSinceEpoch,
        totalPings: _pingTimestamps.length,
        quality: SocketConnectionQuality.calculating,
        lastPingTimestamp: _lastPingTimestamp,
      );
    }

    final currentInterval = _pingIntervals.isNotEmpty ? _pingIntervals.last : null;
    final averageInterval = _pingIntervals.isNotEmpty
        ? (_pingIntervals.reduce((a, b) => a + b) / _pingIntervals.length).round()
        : null;
    final minInterval = _pingIntervals.isNotEmpty
        ? _pingIntervals.reduce((a, b) => a < b ? a : b)
        : null;
    final maxInterval = _pingIntervals.isNotEmpty
        ? _pingIntervals.reduce((a, b) => a > b ? a : b)
        : null;

    // Calculate jitter (standard deviation)
    int? jitter;
    if (_pingIntervals.length > 1 && averageInterval != null) {
      final variance = _pingIntervals
          .map((interval) => pow(interval - averageInterval, 2))
          .reduce((a, b) => a + b) / _pingIntervals.length;
      jitter = sqrt(variance).round();
    }

    // Calculate quality based on metrics
    final quality = SocketConnectionMetrics.calculateQuality(averageInterval, jitter);

    return SocketConnectionMetrics(
      intervalMs: currentInterval,
      averageIntervalMs: averageInterval,
      minIntervalMs: minInterval,
      maxIntervalMs: maxInterval,
      jitterMs: jitter,
      missedPings: _missedPingCount,
      totalPings: _pingTimestamps.length,
      quality: quality,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      lastPingTimestamp: _lastPingTimestamp,
    );
  }

  /// Cleans up ping tracking data
  void _cleanPingIntervals() {
    _connectionStartTime = null;
    _lastPingTimestamp = null;
    _pingTimestamps.clear();
    _pingIntervals.clear();
    _missedPingCount = 0;
    _expectedPingTimer?.cancel();
    _expectedPingTimer = null;
  }

  /// Gets the current connection metrics
  SocketConnectionMetrics getConnectionMetrics() {
    return _calculateConnectionMetrics();
  }
}
