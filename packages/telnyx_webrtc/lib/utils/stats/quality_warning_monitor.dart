import 'package:telnyx_webrtc/model/sdk_warning_codes.dart';
import 'package:telnyx_webrtc/model/sdk_warning_registry.dart';
import 'package:telnyx_webrtc/model/telnyx_warning.dart';
import 'package:telnyx_webrtc/utils/stats/call_report_collector.dart';
import 'package:telnyx_webrtc/utils/stats/mos_calculator.dart';

/// Monitors WebRTC stats intervals and emits [TelnyxWarning]s when quality
/// thresholds are breached for a sustained number of consecutive intervals.
class QualityWarningMonitor {
  /// The call ID these quality warnings are associated with.
  final String callId;

  /// The session ID these quality warnings are associated with, if known.
  final String? sessionId;

  /// Callback invoked whenever a quality [TelnyxWarning] is emitted.
  final void Function(TelnyxWarning warning)? onWarning;

  // ── Thresholds ─────────────────────────────────────────────────────────
  static const double _rttThreshold = 0.4; // 400 ms
  static const double _jitterThreshold = 30.0; // 30 ms
  static const double _packetLossThreshold = 0.01; // 1%
  static const double _mosThreshold = 3.5;
  static const double _audioLevelThreshold = 0.001;
  static const int _consecutiveBreachesRequired = 3;
  static const int _postConfirmSilenceIntervals = 6; // 6 × 5s = 30s
  // Throttle: number of intervals to wait before re-emitting the same warning.
  // 15s / 5s per interval = 3 intervals.
  static const int _throttleIntervalCount = 3;

  // ── Breach counters ────────────────────────────────────────────────────
  int _highRttBreaches = 0;
  int _highJitterBreaches = 0;
  int _highPacketLossBreaches = 0;
  int _lowMosBreaches = 0;
  int _lowLocalAudioBreaches = 0;
  int _lowBytesReceivedBreaches = 0;
  int _lowBytesSentBreaches = 0;
  int _postConfirmSilenceCount = 0;

  // ── State ──────────────────────────────────────────────────────────────
  bool _audioConfirmed = false;
  bool _inboundAudioConfirmed = false;
  int _postConfirmInboundSilenceCount = 0;
  String? _lastIceCandidatePairId;

  // Previous cumulative values for delta calculations
  int? _prevPacketsReceived;
  int? _prevPacketsLost;
  int? _prevBytesReceived;
  int? _prevBytesSent;

  // Throttle: interval count since last emission per warning code
  final Map<int, int> _intervalsSinceEmission = {};

  /// Creates a monitor for [callId] (and optional [sessionId]) that reports
  /// quality warnings through [onWarning].
  QualityWarningMonitor({
    required this.callId,
    this.sessionId,
    this.onWarning,
  });

  /// Check a stats interval and emit warnings as needed.
  void checkStats(StatsInterval stats) {
    final audio = stats.audio;
    final connection = stats.connection;
    final ice = stats.ice;

    // Track whether any warning was emitted this interval — only one warning
    // per interval to avoid noise.
    bool emittedThisInterval = false;

    // Extract common values.
    final rtt = connection?.roundTripTimeAvg;
    final jitter = audio?.inbound?.jitterAvg;
    final packetsReceived = audio?.inbound?.packetsReceived;
    final packetsLost = audio?.inbound?.packetsLost;

    // ── LOW_MOS (checked first so it takes priority over individual
    //    metric warnings when multiple conditions are bad) ───────────────
    if (rtt != null &&
        jitter != null &&
        packetsReceived != null &&
        packetsLost != null) {
      // Use per-interval packet-loss deltas (matching HIGH_PACKET_LOSS) so all
      // three MOS inputs describe the same time window. Cumulative counters
      // would dilute a late loss burst with earlier clean traffic (LOW_MOS
      // never fires) and keep an early burst elevated for the rest of the call
      // (persistent false LOW_MOS). Read the previous cumulative values here,
      // before the HIGH_PACKET_LOSS block updates them below.
      double packetLossRatio = 0.0;
      if (_prevPacketsReceived != null && _prevPacketsLost != null) {
        final receivedDelta = packetsReceived - _prevPacketsReceived!;
        final lostDelta = packetsLost - _prevPacketsLost!;
        final totalDelta = receivedDelta + lostDelta;
        if (totalDelta > 0) {
          packetLossRatio = lostDelta / totalDelta;
        }
      }
      final mos = MosCalculator.calculateMos(
        rtt: rtt,
        jitter: jitter / 1000, // convert ms → seconds
        packetLoss: packetLossRatio,
      );
      if (mos < _mosThreshold) {
        _lowMosBreaches++;
        if (_lowMosBreaches >= _consecutiveBreachesRequired &&
            !emittedThisInterval) {
          if (_emit(SdkWarningCode.lowMos)) {
            emittedThisInterval = true;
          }
        }
      } else {
        _lowMosBreaches = 0;
      }
    }

    // ── HIGH_RTT ──────────────────────────────────────────────────────────
    if (rtt != null && rtt > _rttThreshold) {
      _highRttBreaches++;
      if (_highRttBreaches >= _consecutiveBreachesRequired &&
          !emittedThisInterval) {
        if (_emit(SdkWarningCode.highRtt)) {
          emittedThisInterval = true;
        }
      }
    } else {
      _highRttBreaches = 0;
    }

    // ── HIGH_JITTER ──────────────────────────────────────────────────────
    if (jitter != null && jitter > _jitterThreshold) {
      _highJitterBreaches++;
      if (_highJitterBreaches >= _consecutiveBreachesRequired &&
          !emittedThisInterval) {
        if (_emit(SdkWarningCode.highJitter)) {
          emittedThisInterval = true;
        }
      }
    } else {
      _highJitterBreaches = 0;
    }

    // ── HIGH_PACKET_LOSS (delta-based) ────────────────────────────────────
    if (packetsReceived != null && packetsLost != null) {
      if (_prevPacketsReceived != null && _prevPacketsLost != null) {
        final receivedDelta = packetsReceived - _prevPacketsReceived!;
        final lostDelta = packetsLost - _prevPacketsLost!;
        final totalDelta = receivedDelta + lostDelta;
        if (totalDelta > 0) {
          final lossRate = lostDelta / totalDelta;
          if (lossRate > _packetLossThreshold) {
            _highPacketLossBreaches++;
            if (_highPacketLossBreaches >= _consecutiveBreachesRequired &&
                !emittedThisInterval) {
              if (_emit(SdkWarningCode.highPacketLoss)) {
                emittedThisInterval = true;
              }
            }
          } else {
            _highPacketLossBreaches = 0;
          }
        }
      }
      _prevPacketsReceived = packetsReceived;
      _prevPacketsLost = packetsLost;
    }

    // ── LOW_LOCAL_AUDIO ──────────────────────────────────────────────────
    final outboundLevel = audio?.outbound?.audioLevelAvg;
    if (outboundLevel != null) {
      if (outboundLevel >= _audioLevelThreshold) {
        _audioConfirmed = true;
        _postConfirmSilenceCount = 0;
        _lowLocalAudioBreaches = 0;
      } else {
        // Below threshold
        if (!_audioConfirmed) {
          // Pre-confirmation: 3 consecutive intervals
          _lowLocalAudioBreaches++;
          if (_lowLocalAudioBreaches >= _consecutiveBreachesRequired &&
              !emittedThisInterval) {
            if (_emit(SdkWarningCode.lowLocalAudio)) {
              emittedThisInterval = true;
            }
          }
        } else {
          // Post-confirmation: 30s continuous silence
          _postConfirmSilenceCount++;
          if (_postConfirmSilenceCount >= _postConfirmSilenceIntervals &&
              !emittedThisInterval) {
            if (_emit(SdkWarningCode.lowLocalAudio)) {
              emittedThisInterval = true;
            }
          }
        }
      }
    }

    // ── LOW_INBOUND_AUDIO ────────────────────────────────────────────────
    // Only treat inbound silence as a problem once real inbound audio has been
    // observed at least once. At call start the remote party is legitimately
    // silent (no inbound RTP audio yet), so firing before confirmation would
    // produce a spurious warning on virtually every call. Mirrors the
    // post-confirmation gating used for LOW_LOCAL_AUDIO.
    final inboundLevel = audio?.inbound?.audioLevelAvg;
    if (inboundLevel != null) {
      if (inboundLevel >= _audioLevelThreshold) {
        _inboundAudioConfirmed = true;
        _postConfirmInboundSilenceCount = 0;
      } else if (_inboundAudioConfirmed) {
        // Post-confirmation: sustained silence after audio was flowing.
        _postConfirmInboundSilenceCount++;
        if (_postConfirmInboundSilenceCount >= _postConfirmSilenceIntervals &&
            !emittedThisInterval) {
          if (_emit(SdkWarningCode.lowInboundAudio)) {
            emittedThisInterval = true;
          }
        }
      }
    }

    // ── LOW_BYTES_RECEIVED ──────────────────────────────────────────────
    final bytesReceived = connection?.bytesReceived;
    if (bytesReceived != null) {
      if (_prevBytesReceived != null) {
        final delta = bytesReceived - _prevBytesReceived!;
        if (delta == 0) {
          _lowBytesReceivedBreaches++;
          if (_lowBytesReceivedBreaches >= _consecutiveBreachesRequired &&
              !emittedThisInterval) {
            if (_emit(SdkWarningCode.lowBytesReceived)) {
              emittedThisInterval = true;
            }
          }
        } else {
          _lowBytesReceivedBreaches = 0;
        }
      }
      _prevBytesReceived = bytesReceived;
    }

    // ── LOW_BYTES_SENT ───────────────────────────────────────────────────
    final bytesSent = connection?.bytesSent;
    if (bytesSent != null) {
      if (_prevBytesSent != null) {
        final delta = bytesSent - _prevBytesSent!;
        if (delta == 0) {
          _lowBytesSentBreaches++;
          if (_lowBytesSentBreaches >= _consecutiveBreachesRequired &&
              !emittedThisInterval) {
            if (_emit(SdkWarningCode.lowBytesSent)) {
              emittedThisInterval = true;
            }
          }
        } else {
          _lowBytesSentBreaches = 0;
        }
      }
      _prevBytesSent = bytesSent;
    }

    // ── ICE_CANDIDATE_PAIR_CHANGED ───────────────────────────────────────
    final pairId = ice?.id;
    if (pairId != null) {
      if (_lastIceCandidatePairId != null &&
          pairId != _lastIceCandidatePairId) {
        _emit(SdkWarningCode.iceCandidatePairChanged);
      }
      _lastIceCandidatePairId = pairId;
    }

    // Increment throttle counters for all tracked codes.
    for (final code in _intervalsSinceEmission.keys.toList()) {
      _intervalsSinceEmission[code] = _intervalsSinceEmission[code]! + 1;
    }
  }

  /// Called when ICE connection state changes.
  void onIceConnectionStateChanged(String state) {
    if (state == 'disconnected') {
      _emit(SdkWarningCode.iceConnectivityLost);
    }
  }

  /// Called when peer connection state changes.
  void onPeerConnectionStateChanged(String state) {
    if (state == 'failed') {
      _emit(SdkWarningCode.peerConnectionFailed);
    }
  }

  /// Emit a warning, respecting the throttle window.
  ///
  /// Returns `true` if the warning was emitted, `false` if throttled.
  bool _emit(int code) {
    final since = _intervalsSinceEmission[code];
    if (since != null && since < _throttleIntervalCount) {
      return false; // throttled
    }
    _intervalsSinceEmission[code] = 0;

    final warning = SdkWarningRegistry.createWarning(
      code,
      callId: callId,
      sessionId: sessionId,
    );
    onWarning?.call(warning);
    return true;
  }
}
