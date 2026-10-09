import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:telnyx_webrtc/model/latency_metrics.dart';
import 'package:telnyx_webrtc/utils/latency_tracker.dart';

/// Retains the latency metrics the SDK emits, so the diagnostics view can show
/// history rather than only what happened while it was open.
///
/// [LatencyTracker.latencyMetricsStream] is a broadcast stream with no replay,
/// and the tracker exposes no getter for the last completed registration. A
/// panel that subscribes when it opens therefore misses the registration
/// metrics entirely — which is the common case, since you connect first and
/// look at diagnostics afterwards. Subscribing once at app start and keeping
/// the history here is what makes the panel useful.
class DiagnosticsLatencyService extends ChangeNotifier {
  DiagnosticsLatencyService._();

  /// The single shared instance.
  static final DiagnosticsLatencyService instance =
      DiagnosticsLatencyService._();

  /// The tracker emits once per registration and once per call, so history
  /// stays small. Bounded anyway for long debug sessions.
  static const int _maxEntries = 50;

  final List<LatencyMetrics> _history = [];
  StreamSubscription<LatencyMetrics>? _subscription;

  /// Metrics captured so far, newest first.
  List<LatencyMetrics> get history => List.unmodifiable(_history);

  /// Starts retaining metrics from [tracker]. Safe to call more than once;
  /// only the first call subscribes.
  void attach(LatencyTracker tracker) {
    if (_subscription != null) {
      return;
    }
    _subscription = tracker.latencyMetricsStream.listen((metrics) {
      _history.insert(0, metrics);
      if (_history.length > _maxEntries) {
        _history.removeLast();
      }
      notifyListeners();
    });
  }

  /// Drops the retained history.
  void clear() {
    _history.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    super.dispose();
  }
}
