import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'package:telnyx_webrtc/config/telnyx_config.dart'
    show Config, CredentialConfig, TokenConfig;
import 'package:telnyx_webrtc/model/tx_ice_server.dart';
import 'package:telnyx_webrtc/model/audio_constraints.dart';
import 'package:telnyx_webrtc/config/debug_output.dart';
import 'package:telnyx_webrtc/utils/logging/global_logger.dart';
import 'package:telnyx_webrtc/utils/logging/log_collector.dart';
import 'package:telnyx_webrtc/utils/stats/call_report_log_collector.dart';
import 'package:telnyx_webrtc/utils/version_utils.dart';

// Conditional import for file I/O (mobile only)
import 'package:telnyx_webrtc/utils/stats/call_report_file_helper_stub.dart'
    if (dart.library.io) 'package:telnyx_webrtc/utils/stats/call_report_file_helper.dart'
    as file_helper;

/// Configuration options for call report collection
class CallReportOptions {
  /// Stats collection interval in milliseconds (default: 5000)
  final int intervalMs;

  /// Maximum number of stats intervals to buffer (default: 360 = 30 mins at 5s intervals)
  final int maxBufferSize;

  /// Whether call report collection is enabled (default: true)
  final bool enabled;

  /// Output destination for call reports (default: [DebugOutput.socket])
  final DebugOutput outputMode;

  /// Flush interval for intermediate segments in milliseconds (default: 180000 = 3 min)
  final int flushIntervalMs;

  /// Creates a set of call report collection options with sensible defaults.
  const CallReportOptions({
    this.intervalMs = 5000,
    this.maxBufferSize = 360,
    this.enabled = true,
    this.outputMode = DebugOutput.socket,
    this.flushIntervalMs = 180000,
  });

  /// Create [CallReportOptions] from a [Config] instance.
  factory CallReportOptions.fromConfig(Config config) {
    return CallReportOptions(
      enabled: config.enableCallReports,
      outputMode: config.debugOutput,
      flushIntervalMs: config.callReportFlushInterval,
    );
  }
}

/// Why an intermediate call-report segment was requested.
enum CallReportFlushReasonType {
  bufferLimit('buffer-limit'),
  manual('manual'),
  socketClose('socket-close'),
  socketError('socket-error'),
  safetyInterval('safety-interval');

  const CallReportFlushReasonType(this.value);

  /// Wire value expected by voice-sdk-proxy.
  final String value;
}

/// Optional details attached to socket close/error flushes.
class CallReportSocketCloseDetails {
  final int? code;
  final String? codeName;
  final String? reason;
  final bool? wasClean;
  final String? error;

  const CallReportSocketCloseDetails({
    this.code,
    this.codeName,
    this.reason,
    this.wasClean,
    this.error,
  });

  Map<String, dynamic> toJson() => {
        if (code != null) 'code': code,
        if (codeName != null) 'codeName': codeName,
        if (reason != null) 'reason': reason,
        if (wasClean != null) 'wasClean': wasClean,
        if (error != null) 'error': error,
      };
}

/// Structured reason included with intermediate report segments.
class CallReportFlushReason {
  final CallReportFlushReasonType type;
  final CallReportSocketCloseDetails? socketClose;

  const CallReportFlushReason({required this.type, this.socketClose});

  Map<String, dynamic> toJson() => {
        'type': type.value,
        if (socketClose != null) 'socketClose': socketClose!.toJson(),
      };
}

/// Authentication type used to connect to the Telnyx platform.
enum AuthenticationType {
  loginPassword,
  token,
  unknown;

  String toJson() => switch (this) {
        AuthenticationType.loginPassword => 'login_password',
        AuthenticationType.token => 'token',
        AuthenticationType.unknown => 'unknown',
      };
}

/// Sanitized ICE server entry — URL is preserved but credentials are redacted
/// to boolean flags so the server-side dashboard knows whether auth was
/// configured without exposing the actual secrets.
class SanitizedIceServer {
  final List<String>? urls;
  final bool hasUsername;
  final bool hasCredential;

  const SanitizedIceServer({
    this.urls,
    required this.hasUsername,
    required this.hasCredential,
  });

  Map<String, dynamic> toJson() => {
        if (urls != null) 'urls': urls,
        'hasUsername': hasUsername,
        'hasCredential': hasCredential,
      };

  @override
  String toString() =>
      'SanitizedIceServer(urls: $urls, hasUsername: $hasUsername, hasCredential: $hasCredential)';
}

/// Authentication section of [ClientSummary].
class ClientAuthenticationSummary {
  final AuthenticationType type;

  const ClientAuthenticationSummary({
    required this.type,
  });

  Map<String, dynamic> toJson() => {
        'type': type.toJson(),
      };
}

/// Connection section of [ClientSummary].
class ClientConnectionSummary {
  final String? env;
  final String? host;
  final String? project;
  final String? region;
  final String? dc;
  final String? rtcIp;
  final int? rtcPort;
  final bool? autoReconnect;
  final int? maxReconnectAttempts;
  final bool? keepConnectionAliveOnSocketClose;
  final bool? hangupOnBeforeUnload;
  final bool? useCanaryRtcServer;
  final bool? skipLastVoiceSdkId;
  final bool? skipTrailing;

  const ClientConnectionSummary({
    this.env,
    this.host,
    this.project,
    this.region,
    this.dc,
    this.rtcIp,
    this.rtcPort,
    this.autoReconnect,
    this.maxReconnectAttempts,
    this.keepConnectionAliveOnSocketClose,
    this.hangupOnBeforeUnload,
    this.useCanaryRtcServer,
    this.skipLastVoiceSdkId,
    this.skipTrailing,
  });

  ClientConnectionSummary copyWith({String? region, String? dc}) =>
      ClientConnectionSummary(
        env: env,
        host: host,
        project: project,
        region: region ?? this.region,
        dc: dc ?? this.dc,
        rtcIp: rtcIp,
        rtcPort: rtcPort,
        autoReconnect: autoReconnect,
        maxReconnectAttempts: maxReconnectAttempts,
        keepConnectionAliveOnSocketClose: keepConnectionAliveOnSocketClose,
        hangupOnBeforeUnload: hangupOnBeforeUnload,
        useCanaryRtcServer: useCanaryRtcServer,
        skipLastVoiceSdkId: skipLastVoiceSdkId,
        skipTrailing: skipTrailing,
      );

  Map<String, dynamic> toJson() => {
        if (env != null) 'env': env,
        if (host != null) 'host': host,
        if (project != null) 'project': project,
        if (region != null) 'region': region,
        if (dc != null) 'dc': dc,
        if (rtcIp != null) 'rtcIp': rtcIp,
        if (rtcPort != null) 'rtcPort': rtcPort,
        if (autoReconnect != null) 'autoReconnect': autoReconnect,
        if (maxReconnectAttempts != null)
          'maxReconnectAttempts': maxReconnectAttempts,
        if (keepConnectionAliveOnSocketClose != null)
          'keepConnectionAliveOnSocketClose': keepConnectionAliveOnSocketClose,
        if (hangupOnBeforeUnload != null)
          'hangupOnBeforeUnload': hangupOnBeforeUnload,
        if (useCanaryRtcServer != null)
          'useCanaryRtcServer': useCanaryRtcServer,
        if (skipLastVoiceSdkId != null)
          'skipLastVoiceSdkId': skipLastVoiceSdkId,
        if (skipTrailing != null) 'skipTrailing': skipTrailing,
      };
}

/// Media section of [ClientSummary].
class ClientMediaSummary {
  final dynamic audio;
  final dynamic video;
  final bool? mutedMicOnStart;
  final bool? prefetchIceCandidates;
  final bool? forceRelayCandidate;
  final bool? trickleIce;
  final List<SanitizedIceServer>? iceServers;

  const ClientMediaSummary({
    this.audio,
    this.video,
    this.mutedMicOnStart,
    this.prefetchIceCandidates,
    this.forceRelayCandidate,
    this.trickleIce,
    this.iceServers,
  });

  Map<String, dynamic> toJson() => {
        if (audio != null) 'audio': audio,
        if (video != null) 'video': video,
        if (mutedMicOnStart != null) 'mutedMicOnStart': mutedMicOnStart,
        if (prefetchIceCandidates != null)
          'prefetchIceCandidates': prefetchIceCandidates,
        if (forceRelayCandidate != null)
          'forceRelayCandidate': forceRelayCandidate,
        if (trickleIce != null) 'trickleIce': trickleIce,
        if (iceServers != null)
          'iceServers': iceServers!.map((s) => s.toJson()).toList(),
      };
}

/// Call-reports section of [ClientSummary].
class ClientCallReportsSummary {
  final bool? enabled;
  final int? intervalMs;
  final int? flushIntervalMs;
  final String? debugLogLevel;
  final int? debugLogMaxEntries;

  const ClientCallReportsSummary({
    this.enabled,
    this.intervalMs,
    this.flushIntervalMs,
    this.debugLogLevel,
    this.debugLogMaxEntries,
  });

  Map<String, dynamic> toJson() => {
        if (enabled != null) 'enabled': enabled,
        if (intervalMs != null) 'intervalMs': intervalMs,
        if (flushIntervalMs != null) 'flushIntervalMs': flushIntervalMs,
        if (debugLogLevel != null) 'debugLogLevel': debugLogLevel,
        if (debugLogMaxEntries != null)
          'debugLogMaxEntries': debugLogMaxEntries,
      };
}

/// Sanitized snapshot of the SDK/client configuration in effect for a call.
///
/// Mirrors `IClientSummary` from the webrtc-js SDK so the call-report-stats
/// dashboard receives the same structure regardless of which platform
/// produced the report.
class ClientSummary {
  final ClientAuthenticationSummary? authentication;
  final ClientConnectionSummary? connection;
  final ClientMediaSummary? media;
  final ClientCallReportsSummary? callReports;

  const ClientSummary({
    this.authentication,
    this.connection,
    this.media,
    this.callReports,
  });

  ClientSummary copyWithResolvedConnection({String? region, String? dc}) =>
      ClientSummary(
        authentication: authentication,
        connection: connection?.copyWith(region: region, dc: dc),
        media: media,
        callReports: callReports,
      );

  /// Build a [ClientSummary] from a [Config] instance, mirroring the JS SDK's
  /// `_getClientSummary()` in `BaseCall.ts`.
  ///
  /// [iceServers] are the effective ICE servers (after resolving config /
  /// server-configuration precedence) so we can sanitize them here.
  /// [host] is the WebSocket host the SDK actually connected to.
  /// [region] and [dc] may override the configured routing values when the
  /// signaling layer has authoritative resolved-location metadata. The current
  /// Flutter signaling protocol does not expose that metadata for auto routing.
  factory ClientSummary.fromConfig({
    required Config config,
    required List<TxIceServer> iceServers,
    String? host,
    String? region,
    String? dc,
    bool? useTrickleIce,
    bool? mutedMicOnStart,
    AudioConstraints? audioConstraints,
  }) {
    // Determine authentication type
    AuthenticationType authType;
    if (config is CredentialConfig) {
      authType = AuthenticationType.loginPassword;
    } else if (config is TokenConfig) {
      authType = AuthenticationType.token;
    } else {
      authType = AuthenticationType.unknown;
    }

    // Sanitize ICE servers — preserve URLs, redact credentials to booleans
    final sanitizedIceServers = iceServers.isEmpty
        ? null
        : iceServers
            .map(
              (s) => SanitizedIceServer(
                urls: s.urls,
                hasUsername: s.username != null && s.username!.isNotEmpty,
                hasCredential: s.credential != null && s.credential!.isNotEmpty,
              ),
            )
            .toList();

    return ClientSummary(
      authentication: ClientAuthenticationSummary(
        type: authType,
      ),
      connection: ClientConnectionSummary(
        env: config.serverConfiguration?.environment.name ?? 'production',
        host: host,
        region: region ?? config.region.value,
        dc: dc,
        autoReconnect: config.autoReconnect ?? true,
        maxReconnectAttempts: config.maxReconnectAttempts,
        // These JS SDK connection knobs are not configurable on Flutter.
        keepConnectionAliveOnSocketClose: false,
        hangupOnBeforeUnload: config.hangupOnBeforeUnload,
        useCanaryRtcServer: false,
        skipLastVoiceSdkId: false,
        skipTrailing: false,
      ),
      media: ClientMediaSummary(
        // Dashboard capability labels mirror JS booleans. Detailed Flutter
        // constraints are reported through diagnostics instead.
        audio: true,
        video: false,
        mutedMicOnStart: mutedMicOnStart ?? false,
        prefetchIceCandidates: config.prefetchIceCandidates,
        forceRelayCandidate: config.forceRelayCandidate,
        trickleIce: useTrickleIce ?? false,
        iceServers: sanitizedIceServers,
      ),
      callReports: ClientCallReportsSummary(
        enabled: config.enableCallReports,
        intervalMs: config.callReportInterval,
        flushIntervalMs: config.callReportFlushInterval,
        debugLogLevel: config.callReportLogLevel,
        debugLogMaxEntries: config.callReportMaxLogEntries,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        if (authentication != null) 'authentication': authentication!.toJson(),
        if (connection != null) 'connection': connection!.toJson(),
        if (media != null) 'media': media!.toJson(),
        if (callReports != null) 'callReports': callReports!.toJson(),
      };
}

/// Summary information about the call
class CallSummary {
  /// Unique identifier of the call this summary describes.
  final String callId;

  /// Number that was dialed for an outbound call, if known.
  final String? destinationNumber;

  /// Number of the caller for an inbound call, if known.
  final String? callerNumber;

  /// Direction of the call, either `'inbound'` or `'outbound'`.
  final String direction; // 'inbound' or 'outbound'

  /// Final or current state of the call (e.g. `'active'`, `'done'`).
  final String? state;

  /// Total call duration in seconds, if the call has ended.
  final double? durationSeconds;

  /// Telnyx session identifier associated with the call.
  final String? telnyxSessionId;

  /// Telnyx leg identifier for this call leg.
  final String? telnyxLegId;

  /// Voice SDK identifier used to correlate the call server-side.
  final String? voiceSdkId;

  /// Version of the Telnyx WebRTC SDK that produced this report.
  final String sdkVersion;

  /// UTC ISO-8601 timestamp of when the call started.
  final String? startTimestamp;

  /// UTC ISO-8601 timestamp of when the call ended.
  final String? endTimestamp;

  /// Sanitized client/session/call options in effect for this call.
  final ClientSummary? clientSummary;

  /// Creates a summary describing a single call.
  CallSummary({
    required this.callId,
    this.destinationNumber,
    this.callerNumber,
    required this.direction,
    this.state,
    this.durationSeconds,
    this.telnyxSessionId,
    this.telnyxLegId,
    this.voiceSdkId,
    required this.sdkVersion,
    this.startTimestamp,
    this.endTimestamp,
    this.clientSummary,
  });

  /// Serializes this summary to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'callId': callId,
        if (destinationNumber != null) 'destinationNumber': destinationNumber,
        if (callerNumber != null) 'callerNumber': callerNumber,
        'direction': direction,
        if (state != null) 'state': state,
        if (durationSeconds != null) 'durationSeconds': durationSeconds,
        if (telnyxSessionId != null) 'telnyxSessionId': telnyxSessionId,
        if (telnyxLegId != null) 'telnyxLegId': telnyxLegId,
        if (voiceSdkId != null) 'voiceSdkId': voiceSdkId,
        'sdkVersion': sdkVersion,
        if (startTimestamp != null) 'startTimestamp': startTimestamp,
        if (endTimestamp != null) 'endTimestamp': endTimestamp,
        if (clientSummary != null) 'clientSummary': clientSummary!.toJson(),
      };
}

/// Stats collected during a single interval
class StatsInterval {
  /// UTC ISO-8601 timestamp marking the start of the interval.
  final String intervalStartUtc;

  /// UTC ISO-8601 timestamp marking the end of the interval.
  final String intervalEndUtc;

  /// Audio statistics aggregated over the interval, if available.
  final AudioStats? audio;

  /// Connection statistics aggregated over the interval, if available.
  final ConnectionStats? connection;

  /// ICE statistics captured during the interval, if available.
  final IceStats? ice;

  /// Transport state captured during the interval, if available.
  final TransportStats? transport;

  /// Audio playout statistics reported by the receiver, if available.
  final MediaPlayoutStats? mediaPlayout;

  /// RTCP reports describing the remote peer's view of the RTP streams.
  final RemoteRtcpStats? remoteRtcp;

  /// Creates a stats entry covering a single collection interval.
  StatsInterval({
    required this.intervalStartUtc,
    required this.intervalEndUtc,
    this.audio,
    this.connection,
    this.ice,
    this.transport,
    this.mediaPlayout,
    this.remoteRtcp,
  });

  /// Serializes this interval to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'intervalStartUtc': intervalStartUtc,
        'intervalEndUtc': intervalEndUtc,
        if (audio != null) 'audio': audio!.toJson(),
        if (connection != null) 'connection': connection!.toJson(),
        if (ice != null) 'ice': ice!.toJson(),
        if (transport != null) 'transport': transport!.toJson(),
        if (mediaPlayout != null) 'mediaPlayout': mediaPlayout!.toJson(),
        if (remoteRtcp != null) 'remoteRtcp': remoteRtcp!.toJson(),
      };
}

/// Remote RTCP receiver and sender reports for the audio streams.
class RemoteRtcpStats {
  final RemoteInboundRtpStats? inbound;
  final RemoteOutboundRtpStats? outbound;

  RemoteRtcpStats({this.inbound, this.outbound});

  Map<String, dynamic> toJson() => {
        if (inbound != null) 'inbound': inbound!.toJson(),
        if (outbound != null) 'outbound': outbound!.toJson(),
      };
}

/// Remote receiver report for this endpoint's outbound audio stream.
class RemoteInboundRtpStats {
  final int? packetsReceived;
  final int? packetsLost;
  final double? fractionLost;
  final double? jitter;
  final double? roundTripTime;
  final double? totalRoundTripTime;
  final int? roundTripTimeMeasurements;
  final double? roundTripTimeAvg;
  final int? nackCount;
  final int? reportsReceived;
  final int? packetsDiscarded;

  RemoteInboundRtpStats({
    this.packetsReceived,
    this.packetsLost,
    this.fractionLost,
    this.jitter,
    this.roundTripTime,
    this.totalRoundTripTime,
    this.roundTripTimeMeasurements,
    this.roundTripTimeAvg,
    this.nackCount,
    this.reportsReceived,
    this.packetsDiscarded,
  });

  Map<String, dynamic> toJson() => {
        if (packetsReceived != null) 'packetsReceived': packetsReceived,
        if (packetsLost != null) 'packetsLost': packetsLost,
        if (fractionLost != null) 'fractionLost': fractionLost,
        if (jitter != null) 'jitter': jitter,
        if (roundTripTime != null) 'roundTripTime': roundTripTime,
        if (totalRoundTripTime != null)
          'totalRoundTripTime': totalRoundTripTime,
        if (roundTripTimeMeasurements != null)
          'roundTripTimeMeasurements': roundTripTimeMeasurements,
        if (roundTripTimeAvg != null) 'roundTripTimeAvg': roundTripTimeAvg,
        if (nackCount != null) 'nackCount': nackCount,
        if (reportsReceived != null) 'reportsReceived': reportsReceived,
        if (packetsDiscarded != null) 'packetsDiscarded': packetsDiscarded,
      };
}

/// Remote sender report for this endpoint's inbound audio stream.
class RemoteOutboundRtpStats {
  final int? packetsSent;
  final int? bytesSent;
  final int? reportsCount;
  final double? roundTripTime;
  final double? totalPacketSendDelay;

  RemoteOutboundRtpStats({
    this.packetsSent,
    this.bytesSent,
    this.reportsCount,
    this.roundTripTime,
    this.totalPacketSendDelay,
  });

  Map<String, dynamic> toJson() => {
        if (packetsSent != null) 'packetsSent': packetsSent,
        if (bytesSent != null) 'bytesSent': bytesSent,
        if (reportsCount != null) 'reportsCount': reportsCount,
        if (roundTripTime != null) 'roundTripTime': roundTripTime,
        if (totalPacketSendDelay != null)
          'totalPacketSendDelay': totalPacketSendDelay,
      };
}

/// Statistics describing decoded audio delivered to the playout device.
class MediaPlayoutStats {
  final int? synthesizedSamples;
  final double? synthesizedDuration;
  final double? totalPlayoutDelay;
  final int? totalSampleCount;

  MediaPlayoutStats({
    this.synthesizedSamples,
    this.synthesizedDuration,
    this.totalPlayoutDelay,
    this.totalSampleCount,
  });

  Map<String, dynamic> toJson() => {
        if (synthesizedSamples != null)
          'synthesizedSamples': synthesizedSamples,
        if (synthesizedDuration != null)
          'synthesizedDuration': synthesizedDuration,
        if (totalPlayoutDelay != null) 'totalPlayoutDelay': totalPlayoutDelay,
        if (totalSampleCount != null) 'totalSampleCount': totalSampleCount,
      };
}

/// WebRTC transport statistics for a single interval.
class TransportStats {
  final String? iceState;
  final String? dtlsState;
  final String? srtpCipher;
  final String? tlsVersion;
  final int? selectedCandidatePairChanges;
  final String? selectedCandidatePairId;

  TransportStats({
    this.iceState,
    this.dtlsState,
    this.srtpCipher,
    this.tlsVersion,
    this.selectedCandidatePairChanges,
    this.selectedCandidatePairId,
  });

  Map<String, dynamic> toJson() => {
        if (iceState != null) 'iceState': iceState,
        if (dtlsState != null) 'dtlsState': dtlsState,
        if (srtpCipher != null) 'srtpCipher': srtpCipher,
        if (tlsVersion != null) 'tlsVersion': tlsVersion,
        if (selectedCandidatePairChanges != null)
          'selectedCandidatePairChanges': selectedCandidatePairChanges,
        if (selectedCandidatePairId != null)
          'selectedCandidatePairId': selectedCandidatePairId,
      };
}

/// Codec identity resolved from an RTP stream's `codecId` reference.
class CodecStats {
  final String? mimeType;
  final int? clockRate;
  final int? channels;
  final String? sdpFmtpLine;
  final int? payloadType;
  final String? codecId;

  CodecStats({
    this.mimeType,
    this.clockRate,
    this.channels,
    this.sdpFmtpLine,
    this.payloadType,
    this.codecId,
  });

  Map<String, dynamic> toJson() => {
        if (mimeType != null) 'mimeType': mimeType,
        if (clockRate != null) 'clockRate': clockRate,
        if (channels != null) 'channels': channels,
        if (sdpFmtpLine != null) 'sdpFmtpLine': sdpFmtpLine,
        if (payloadType != null) 'payloadType': payloadType,
        if (codecId != null) 'codecId': codecId,
      };
}

/// Audio statistics for inbound and outbound streams
class AudioStats {
  /// Statistics for the outbound (sent) audio stream, if available.
  final OutboundAudioStats? outbound;

  /// Statistics for the inbound (received) audio stream, if available.
  final InboundAudioStats? inbound;

  /// Creates an audio statistics container for a single interval.
  AudioStats({this.outbound, this.inbound});

  /// Serializes these audio statistics to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        if (outbound != null) 'outbound': outbound!.toJson(),
        if (inbound != null) 'inbound': inbound!.toJson(),
      };
}

/// Outbound audio statistics
class OutboundAudioStats {
  /// Total number of audio packets sent.
  final int? packetsSent;

  /// Total number of audio bytes sent.
  final int? bytesSent;

  final int? retransmittedPacketsSent;
  final int? retransmittedBytesSent;
  final int? headerBytesSent;
  final int? nackCount;
  final double? targetBitrate;
  final double? totalPacketSendDelay;
  final bool? active;

  /// Average outbound audio level over the interval.
  final double? audioLevelAvg;

  /// Average outbound bitrate in bits per second over the interval.
  final double? bitrateAvg;

  /// Negotiated codec for this RTP stream.
  final CodecStats? codec;

  /// Snapshot of the local sender track used for this stream.
  final LocalAudioTrackSnapshot? localTrack;

  /// Media-source counters backing the local sender track.
  final LocalAudioSourceStats? mediaSource;

  /// Creates outbound audio statistics for a single interval.
  OutboundAudioStats({
    this.packetsSent,
    this.bytesSent,
    this.retransmittedPacketsSent,
    this.retransmittedBytesSent,
    this.headerBytesSent,
    this.nackCount,
    this.targetBitrate,
    this.totalPacketSendDelay,
    this.active,
    this.audioLevelAvg,
    this.bitrateAvg,
    this.codec,
    this.localTrack,
    this.mediaSource,
  });

  /// Serializes these outbound audio statistics to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        if (packetsSent != null) 'packetsSent': packetsSent,
        if (bytesSent != null) 'bytesSent': bytesSent,
        if (retransmittedPacketsSent != null)
          'retransmittedPacketsSent': retransmittedPacketsSent,
        if (retransmittedBytesSent != null)
          'retransmittedBytesSent': retransmittedBytesSent,
        if (headerBytesSent != null) 'headerBytesSent': headerBytesSent,
        if (nackCount != null) 'nackCount': nackCount,
        if (targetBitrate != null) 'targetBitrate': targetBitrate,
        if (totalPacketSendDelay != null)
          'totalPacketSendDelay': totalPacketSendDelay,
        if (active != null) 'active': active,
        if (audioLevelAvg != null) 'audioLevelAvg': audioLevelAvg,
        if (bitrateAvg != null) 'bitrateAvg': bitrateAvg,
        if (codec != null) 'codec': codec!.toJson(),
        if (localTrack != null) 'localTrack': localTrack!.toJson(),
        if (mediaSource != null) 'mediaSource': mediaSource!.toJson(),
      };
}

/// Selected settings and state for the local audio sender track.
class LocalAudioTrackSnapshot {
  final String? id;
  final String? label;
  final bool? enabled;
  final bool? muted;
  final Map<String, dynamic>? settings;

  const LocalAudioTrackSnapshot({
    this.id,
    this.label,
    this.enabled,
    this.muted,
    this.settings,
  });

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (label != null) 'label': label,
        if (enabled != null) 'enabled': enabled,
        if (muted != null) 'muted': muted,
        if (settings != null && settings!.isNotEmpty) 'settings': settings,
      };
}

/// Audio media-source counters associated with the outbound RTP stream.
class LocalAudioSourceStats {
  final String? id;
  final String? trackIdentifier;
  final double? audioLevel;
  final double? totalAudioEnergy;
  final double? totalSamplesDuration;
  final double? echoReturnLoss;
  final double? echoReturnLossEnhancement;

  const LocalAudioSourceStats({
    this.id,
    this.trackIdentifier,
    this.audioLevel,
    this.totalAudioEnergy,
    this.totalSamplesDuration,
    this.echoReturnLoss,
    this.echoReturnLossEnhancement,
  });

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (trackIdentifier != null) 'trackIdentifier': trackIdentifier,
        if (audioLevel != null) 'audioLevel': audioLevel,
        if (totalAudioEnergy != null) 'totalAudioEnergy': totalAudioEnergy,
        if (totalSamplesDuration != null)
          'totalSamplesDuration': totalSamplesDuration,
        if (echoReturnLoss != null) 'echoReturnLoss': echoReturnLoss,
        if (echoReturnLossEnhancement != null)
          'echoReturnLossEnhancement': echoReturnLossEnhancement,
      };
}

/// Inbound audio statistics
class InboundAudioStats {
  /// Total number of audio packets received.
  final int? packetsReceived;

  /// Total number of audio bytes received.
  final int? bytesReceived;

  /// Total number of audio packets lost in transit.
  final int? packetsLost;

  /// Total number of received audio packets that were discarded.
  final int? packetsDiscarded;

  final int? nackCount;
  final int? headerBytesReceived;
  final int? fecPacketsReceived;
  final int? fecPacketsDiscarded;

  /// Cumulative jitter buffer delay in seconds.
  final double? jitterBufferDelay;

  /// Number of samples emitted from the jitter buffer.
  final int? jitterBufferEmittedCount;

  final double? jitterBufferTargetDelay;
  final double? jitterBufferMinimumDelay;

  /// Total number of audio samples received.
  final int? totalSamplesReceived;

  /// Number of samples synthesized to conceal lost audio.
  final int? concealedSamples;

  /// Number of concealment events used to hide packet loss.
  final int? concealmentEvents;

  final int? totalSamplesDecoded;
  final int? samplesDecodedWithSilence;
  final int? samplesDecodedWithConcealment;
  final double? totalAudioEnergy;
  final double? totalSamplesDuration;

  /// Average inbound audio level over the interval.
  final double? audioLevelAvg;

  /// Average inbound jitter in milliseconds over the interval.
  final double? jitterAvg;

  /// Average inbound bitrate in bits per second over the interval.
  final double? bitrateAvg;

  /// Negotiated codec for this RTP stream.
  final CodecStats? codec;

  /// Creates inbound audio statistics for a single interval.
  InboundAudioStats({
    this.packetsReceived,
    this.bytesReceived,
    this.packetsLost,
    this.packetsDiscarded,
    this.nackCount,
    this.headerBytesReceived,
    this.fecPacketsReceived,
    this.fecPacketsDiscarded,
    this.jitterBufferDelay,
    this.jitterBufferEmittedCount,
    this.jitterBufferTargetDelay,
    this.jitterBufferMinimumDelay,
    this.totalSamplesReceived,
    this.concealedSamples,
    this.concealmentEvents,
    this.totalSamplesDecoded,
    this.samplesDecodedWithSilence,
    this.samplesDecodedWithConcealment,
    this.totalAudioEnergy,
    this.totalSamplesDuration,
    this.audioLevelAvg,
    this.jitterAvg,
    this.bitrateAvg,
    this.codec,
  });

  /// Serializes these inbound audio statistics to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        if (packetsReceived != null) 'packetsReceived': packetsReceived,
        if (bytesReceived != null) 'bytesReceived': bytesReceived,
        if (packetsLost != null) 'packetsLost': packetsLost,
        if (packetsDiscarded != null) 'packetsDiscarded': packetsDiscarded,
        if (nackCount != null) 'nackCount': nackCount,
        if (headerBytesReceived != null)
          'headerBytesReceived': headerBytesReceived,
        if (fecPacketsReceived != null)
          'fecPacketsReceived': fecPacketsReceived,
        if (fecPacketsDiscarded != null)
          'fecPacketsDiscarded': fecPacketsDiscarded,
        if (jitterBufferDelay != null) 'jitterBufferDelay': jitterBufferDelay,
        if (jitterBufferEmittedCount != null)
          'jitterBufferEmittedCount': jitterBufferEmittedCount,
        if (jitterBufferTargetDelay != null)
          'jitterBufferTargetDelay': jitterBufferTargetDelay,
        if (jitterBufferMinimumDelay != null)
          'jitterBufferMinimumDelay': jitterBufferMinimumDelay,
        if (totalSamplesReceived != null)
          'totalSamplesReceived': totalSamplesReceived,
        if (concealedSamples != null) 'concealedSamples': concealedSamples,
        if (concealmentEvents != null) 'concealmentEvents': concealmentEvents,
        if (totalSamplesDecoded != null)
          'totalSamplesDecoded': totalSamplesDecoded,
        if (samplesDecodedWithSilence != null)
          'samplesDecodedWithSilence': samplesDecodedWithSilence,
        if (samplesDecodedWithConcealment != null)
          'samplesDecodedWithConcealment': samplesDecodedWithConcealment,
        if (totalAudioEnergy != null) 'totalAudioEnergy': totalAudioEnergy,
        if (totalSamplesDuration != null)
          'totalSamplesDuration': totalSamplesDuration,
        if (audioLevelAvg != null) 'audioLevelAvg': audioLevelAvg,
        if (jitterAvg != null) 'jitterAvg': jitterAvg,
        if (bitrateAvg != null) 'bitrateAvg': bitrateAvg,
        if (codec != null) 'codec': codec!.toJson(),
      };
}

/// Connection statistics
class ConnectionStats {
  /// Average round-trip time in seconds over the interval.
  final double? roundTripTimeAvg;

  /// Total number of packets sent over the connection.
  final int? packetsSent;

  /// Total number of packets received over the connection.
  final int? packetsReceived;

  /// Total number of bytes sent over the connection.
  final int? bytesSent;

  /// Total number of bytes received over the connection.
  final int? bytesReceived;

  /// Creates connection statistics for a single interval.
  ConnectionStats({
    this.roundTripTimeAvg,
    this.packetsSent,
    this.packetsReceived,
    this.bytesSent,
    this.bytesReceived,
  });

  /// Serializes these connection statistics to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        if (roundTripTimeAvg != null) 'roundTripTimeAvg': roundTripTimeAvg,
        if (packetsSent != null) 'packetsSent': packetsSent,
        if (packetsReceived != null) 'packetsReceived': packetsReceived,
        if (bytesSent != null) 'bytesSent': bytesSent,
        if (bytesReceived != null) 'bytesReceived': bytesReceived,
      };
}

/// ICE candidate statistics (local or remote)
class IceCandidateStats {
  /// IP address of the candidate.
  final String? address;

  /// Type of candidate (e.g. `'host'`, `'srflx'`, `'prflx'`, `'relay'`).
  final String? candidateType;

  /// Network type the candidate was gathered on, if reported.
  final String? networkType;

  /// Port number of the candidate.
  final int? port;

  /// Transport protocol of the candidate (e.g. `'udp'`, `'tcp'`).
  final String? protocol;

  /// Priority value assigned to the candidate.
  final int? priority;

  /// Related (base) address for reflexive or relay candidates.
  final String? relatedAddress;

  /// Related (base) port for reflexive or relay candidates.
  final int? relatedPort;

  /// Creates statistics describing a single ICE candidate.
  IceCandidateStats({
    this.address,
    this.candidateType,
    this.networkType,
    this.port,
    this.protocol,
    this.priority,
    this.relatedAddress,
    this.relatedPort,
  });

  /// Serializes this ICE candidate to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        if (address != null) 'address': address,
        if (candidateType != null) 'candidateType': candidateType,
        if (networkType != null) 'networkType': networkType,
        if (port != null) 'port': port,
        if (priority != null) 'priority': priority,
        if (relatedAddress != null) 'relatedAddress': relatedAddress,
        if (relatedPort != null) 'relatedPort': relatedPort,
        if (protocol != null) 'protocol': protocol,
      };
}

/// ICE connection statistics including selected candidate pair
class IceStats {
  /// Identifier of the selected candidate pair.
  final String? id;

  /// Local candidate of the selected pair, if resolved.
  final IceCandidateStats? local;

  /// Remote candidate of the selected pair, if resolved.
  final IceCandidateStats? remote;

  /// Whether the candidate pair has been nominated for use.
  final bool? nominated;

  /// Number of connectivity check requests sent on this pair.
  final int? requestsSent;

  /// Number of connectivity check responses received on this pair.
  final int? responsesReceived;

  /// State of the candidate pair (e.g. `'succeeded'`).
  final String? state;

  /// Whether the candidate pair is currently writable.
  final bool? writable;

  /// Creates ICE statistics for the selected candidate pair.
  IceStats({
    this.id,
    this.local,
    this.remote,
    this.nominated,
    this.requestsSent,
    this.responsesReceived,
    this.state,
    this.writable,
  });

  /// Serializes these ICE statistics to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (local != null) 'local': local!.toJson(),
        if (remote != null) 'remote': remote!.toJson(),
        if (nominated != null) 'nominated': nominated,
        if (requestsSent != null) 'requestsSent': requestsSent,
        if (responsesReceived != null) 'responsesReceived': responsesReceived,
        if (state != null) 'state': state,
        if (writable != null) 'writable': writable,
      };
}

/// The full call report payload sent to voice-sdk-proxy
class CallReportPayload {
  /// Summary information describing the call.
  final CallSummary summary;

  /// Ordered list of per-interval statistics collected during the call.
  final List<StatsInterval> stats;

  /// Optional structured event log entries associated with the call.
  final List<Map<String, dynamic>>? logs;

  /// Segment index used when the report is split across multiple uploads.
  final int? segment;

  /// Why this intermediate segment was flushed.
  final CallReportFlushReason? flushReason;

  /// Creates a full call report payload for upload to voice-sdk-proxy.
  CallReportPayload({
    required this.summary,
    required this.stats,
    this.logs,
    this.segment,
    this.flushReason,
  });

  /// Serializes this payload to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'summary': summary.toJson(),
        'stats': stats.map((s) => s.toJson()).toList(),
        if (logs != null && logs!.isNotEmpty) 'logs': logs,
        if (segment != null) 'segment': segment,
        if (flushReason != null) 'flushReason': flushReason!.toJson(),
      };
}

/// CallReportCollector
///
/// Collects WebRTC statistics during a call and posts them to voice-sdk-proxy
/// at the end of the call for quality analysis and debugging.
///
/// Features:
/// - Stats collection at regular intervals (default 5 seconds)
/// - Retry logic with exponential backoff for failed uploads
/// - Payload chunking for large reports (>1.9MB)
/// - Local file backup on mobile before uploading
/// - Intermediate segment flushing for long calls (~25 min)
/// - Structured event log integration
class CallReportCollector {
  /// Configuration options controlling how stats are collected and uploaded.
  final CallReportOptions options;
  RTCPeerConnection? _peerConnection;
  Timer? _collectionTimer;
  final List<StatsInterval> _statsBuffer = [];
  DateTime? _intervalStartTime;
  final DateTime _callStartTime;
  DateTime? _callEndTime;

  /// Optional listener fired after each stats interval is finalized.
  ///
  /// Wired by [Peer.startStats] to feed [QualityWarningMonitor] so quality
  /// warnings (LOW_BYTES_RECEIVED / LOW_BYTES_SENT) can be bridged into the
  /// signaling-health monitor as no-RTP evidence.
  void Function(StatsInterval interval)? onStatsInterval;

  /// Optional owner callback fired when buffered data should be uploaded.
  ///
  /// When absent, the collector uses the upload configuration supplied to
  /// [storeUploadConfig] and performs the intermediate upload itself.
  FutureOr<void> Function(CallReportFlushReason reason)? onFlushNeeded;

  /// Log collector for structured event logging
  CallReportLogCollector? logCollector;

  // Retry configuration
  static const int _maxRetryAttempts = 3;
  static const List<int> _retryDelaysMs = [1000, 2000, 4000];

  // Payload size limits
  static final int _safePayloadSize = (1.9 * 1024 * 1024).toInt(); // 1.9MB

  // Intermediate segment flushing threshold (~300 entries = ~25 min at 5s)
  static const int _segmentFlushThreshold = 300;
  static const int _logFlushThreshold = 800;

  // Segment counter for chunked uploads
  int _segmentCounter = 0;
  bool _flushing = false;
  bool _flushRequestInProgress = false;
  Future<void>? _collectionInProgress;
  late DateTime _lastIntermediateFlushTime;

  // Upload config stored at start for intermediate flushing
  String? _storedCallReportId;
  String? _storedHost;
  String? _storedVoiceSdkId;
  CallSummary? _storedSummary;

  // Last saved report file path (mobile only)
  String? _lastReportFilePath;

  // Accumulated values for averaging within an interval
  final List<double> _intervalOutboundAudioLevels = [];
  final List<double> _intervalInboundAudioLevels = [];
  final List<double> _intervalJitters = [];
  final List<double> _intervalRTTs = [];
  final List<double> _intervalOutboundBitrates = [];
  final List<double> _intervalInboundBitrates = [];

  // Previous values for rate calculations
  int? _previousOutboundBytes;
  int? _previousInboundBytes;
  int? _previousTimestamp;
  double? _previousOutboundAudioEnergy;
  double? _previousOutboundSamplesDuration;
  double? _previousInboundAudioEnergy;
  double? _previousInboundSamplesDuration;

  // Last collected raw stats for interval creation
  Map<String, dynamic>? _lastOutboundAudio;
  Map<String, dynamic>? _lastInboundAudio;
  Map<String, dynamic>? _lastCandidatePair;
  Map<String, dynamic>? _lastTransport;
  Map<String, dynamic>? _lastMediaPlayout;
  Map<String, dynamic>? _lastRemoteInboundRtp;
  Map<String, dynamic>? _lastRemoteOutboundRtp;
  LocalAudioTrackSnapshot? _lastLocalAudioTrack;
  String? _lastLocalAudioTrackSnapshotJson;

  final Map<String, Map<String, dynamic>> _candidatePairCache = {};
  final Map<String, Map<String, dynamic>> _codecCache = {};
  final Map<String, Map<String, dynamic>> _trackStatsCache = {};
  final Map<String, Map<String, dynamic>> _mediaSourceCache = {};

  // ICE candidate data
  String? _selectedLocalCandidateId;
  String? _selectedRemoteCandidateId;

  // Cache of all candidates for lookup
  final Map<String, Map<String, dynamic>> _candidateCache = {};

  /// Creates a collector and records the call start time.
  CallReportCollector({
    this.options = const CallReportOptions(),
    this.logCollector,
  }) : _callStartTime = DateTime.now() {
    _lastIntermediateFlushTime = _callStartTime;
  }

  /// Configure the global [LogCollector] for this call report.
  /// Creates a new [LogCollector], sets it as the global singleton,
  /// and starts capturing.
  void configureLogCollector({
    required bool enabled,
    required CollectorLogLevel level,
    required int maxEntries,
  }) {
    // Only create a new collector if one isn't already active.
    final existing = getGlobalLogCollector();
    if (existing != null && existing.isActive) {
      return;
    }
    final collector = LogCollector(
      enabled: enabled,
      level: level,
      maxEntries: maxEntries,
    );
    setGlobalLogCollector(collector);
    collector.start();
  }

  /// Drain and return all log entries from the global [LogCollector].
  /// Returns `null` if no collector is active.
  List<Map<String, dynamic>>? getLogCollectorEntries() {
    final collector = getGlobalLogCollector();
    if (collector == null || !collector.isActive) return null;
    return collector.drain();
  }

  /// Start collecting stats from the peer connection
  void start(RTCPeerConnection peerConnection) {
    _peerConnection = peerConnection;
    _intervalStartTime = DateTime.now();

    GlobalLogger().i(
      'CallReportCollector: Starting stats collection (interval: ${options.intervalMs}ms)',
    );

    _collectionTimer = Timer.periodic(
      Duration(milliseconds: options.intervalMs),
      (_) => _collectStats(),
    );
  }

  /// Store upload config at call start for intermediate segment flushing
  void storeUploadConfig({
    required String callReportId,
    required String host,
    required CallSummary summary,
    String? voiceSdkId,
  }) {
    _storedCallReportId = callReportId;
    _storedHost = host;
    _storedVoiceSdkId = voiceSdkId;
    _storedSummary = summary;
  }

  /// Refreshes late-arriving client metadata used by intermediate segments.
  void updateStoredCallMetadata({
    ClientSummary? clientSummary,
    String? telnyxSessionId,
    String? telnyxLegId,
  }) {
    final summary = _storedSummary;
    if (summary == null) return;
    _storedSummary = CallSummary(
      callId: summary.callId,
      destinationNumber: summary.destinationNumber,
      callerNumber: summary.callerNumber,
      direction: summary.direction,
      state: summary.state,
      durationSeconds: summary.durationSeconds,
      telnyxSessionId: telnyxSessionId ?? summary.telnyxSessionId,
      telnyxLegId: telnyxLegId ?? summary.telnyxLegId,
      voiceSdkId: summary.voiceSdkId,
      sdkVersion: summary.sdkVersion,
      startTimestamp: summary.startTimestamp,
      endTimestamp: summary.endTimestamp,
      clientSummary: clientSummary ?? summary.clientSummary,
    );
  }

  /// Exposes the summary cached for intermediate flushes to unit tests.
  @visibleForTesting
  CallSummary? get storedSummaryForTesting => _storedSummary;

  /// Rebuilds the terminal summary while preserving call-time configuration.
  @visibleForTesting
  CallSummary buildFinalSummary(CallSummary summary, {String? voiceSdkId}) {
    final durationSeconds = _callEndTime != null
        ? (_callEndTime!.difference(_callStartTime).inMilliseconds / 1000)
        : null;

    return CallSummary(
      callId: summary.callId,
      destinationNumber: summary.destinationNumber,
      callerNumber: summary.callerNumber,
      direction: summary.direction,
      state: summary.state,
      durationSeconds: durationSeconds,
      telnyxSessionId: summary.telnyxSessionId,
      telnyxLegId: summary.telnyxLegId,
      voiceSdkId: voiceSdkId,
      sdkVersion: VersionUtils.getSDKVersion(),
      startTimestamp: _callStartTime.toUtc().toIso8601String(),
      endTimestamp: _callEndTime?.toUtc().toIso8601String(),
      clientSummary: summary.clientSummary,
    );
  }

  /// Cache an ICE candidate from the onIceCandidate callback.
  /// This is needed because Flutter WebRTC doesn't return local-candidate/remote-candidate
  /// stats from getStats(), so we cache them during ICE gathering instead.
  ///
  /// [candidate] The ICE candidate string (e.g., "candidate:... typ srflx ...")
  /// [sdpMid] The SDP media ID
  /// [sdpMLineIndex] The SDP m-line index
  /// [isLocal] True for local candidates, false for remote
  void cacheIceCandidate({
    required String candidate,
    String? sdpMid,
    int? sdpMLineIndex,
    required bool isLocal,
  }) {
    // Parse the candidate string to extract details
    // Format: "candidate:foundation component protocol priority ip port typ type [raddr relatedAddr] [rport relatedPort] ..."
    final parsed = _parseIceCandidateString(candidate);
    if (parsed == null) return;

    // Generate a unique ID for this candidate (similar to WebRTC stats ID format)
    final candidateId =
        'RTCIce${isLocal ? "Lc" : "Rc"}_${parsed['foundation']}_${parsed['port']}';

    _cacheBounded(_candidateCache, candidateId, {
      'id': candidateId,
      'address': parsed['address'],
      'ip': parsed['address'], // Some platforms use 'ip' instead of 'address'
      'port': parsed['port'],
      'protocol': parsed['protocol'],
      'candidateType': parsed['candidateType'],
      'priority': parsed['priority'],
      'relatedAddress': parsed['relatedAddress'],
      'relatedPort': parsed['relatedPort'],
      'foundation': parsed['foundation'],
      'component': parsed['component'],
    });

    GlobalLogger().d(
      'CallReportCollector: Cached ${isLocal ? "local" : "remote"} candidate $candidateId (${parsed['candidateType']}) at ${parsed['address']}:${parsed['port']}',
    );
  }

  /// Parse an ICE candidate string into its components
  Map<String, dynamic>? _parseIceCandidateString(String candidateStr) {
    try {
      // Remove "candidate:" prefix if present
      String str = candidateStr;
      if (str.startsWith('candidate:')) {
        str = str.substring('candidate:'.length);
      } else if (str.startsWith('a=candidate:')) {
        str = str.substring('a=candidate:'.length);
      }

      final parts = str.split(' ');
      if (parts.length < 8) return null;

      // Standard format: foundation component protocol priority address port typ type [extensions]
      final foundation = parts[0];
      final component = int.tryParse(parts[1]);
      final protocol = parts[2].toLowerCase();
      final priority = int.tryParse(parts[3]);
      final address = parts[4];
      final port = int.tryParse(parts[5]);
      // parts[6] is "typ"
      final candidateType = parts[7]; // host, srflx, prflx, relay

      String? relatedAddress;
      int? relatedPort;

      // Parse optional extensions (raddr, rport, etc.)
      for (int i = 8; i < parts.length - 1; i++) {
        if (parts[i] == 'raddr' && i + 1 < parts.length) {
          relatedAddress = parts[i + 1];
        } else if (parts[i] == 'rport' && i + 1 < parts.length) {
          relatedPort = int.tryParse(parts[i + 1]);
        }
      }

      return {
        'foundation': foundation,
        'component': component,
        'protocol': protocol,
        'priority': priority,
        'address': address,
        'port': port,
        'candidateType': candidateType,
        'relatedAddress': relatedAddress,
        'relatedPort': relatedPort,
      };
    } catch (e) {
      GlobalLogger().w(
        'CallReportCollector: Failed to parse ICE candidate: $e',
      );
      return null;
    }
  }

  /// Extract and cache ICE candidates from an SDP string.
  /// This is needed because remote candidates are often embedded in the SDP
  /// rather than sent via trickle ICE.
  ///
  /// [sdp] The SDP string (offer or answer)
  /// [isLocal] True for local SDP, false for remote SDP
  void cacheIceCandidatesFromSdp(String sdp, {required bool isLocal}) {
    try {
      final lines = sdp.split('\n');
      int candidateCount = 0;

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('a=candidate:')) {
          // Extract the candidate string (remove 'a=' prefix)
          final candidateStr = trimmed.substring(2); // Remove 'a='
          cacheIceCandidate(candidate: candidateStr, isLocal: isLocal);
          candidateCount++;
        }
      }

      if (candidateCount > 0) {
        GlobalLogger().d(
          'CallReportCollector: Extracted $candidateCount ${isLocal ? "local" : "remote"} candidates from SDP',
        );
      }
    } catch (e) {
      GlobalLogger().w(
        'CallReportCollector: Failed to parse SDP for candidates: $e',
      );
    }
  }

  /// Stop collecting stats and prepare for final report.
  /// Awaits final stats collection to ensure no data is lost.
  Future<void> stop() async {
    _collectionTimer?.cancel();
    _collectionTimer = null;
    _callEndTime = DateTime.now();

    // Collect final stats before stopping (await to ensure buffer is complete)
    if (_peerConnection != null && _intervalStartTime != null) {
      await _collectStats();
    }

    _candidatePairCache.clear();
    _codecCache.clear();
    _trackStatsCache.clear();
    _mediaSourceCache.clear();
    _candidateCache.clear();

    GlobalLogger().i(
      'CallReportCollector: Stopped (${_statsBuffer.length} intervals collected)',
    );
  }

  /// Get the file path of the last saved report (null on web)
  String? getLastReportFilePath() => _lastReportFilePath;

  /// Post the collected stats to voice-sdk-proxy
  Future<void> postReport({
    required CallSummary summary,
    required String callReportId,
    required String host,
    String? voiceSdkId,
  }) async {
    if (_statsBuffer.isEmpty) {
      GlobalLogger().d('CallReportCollector: Skipping post (buffer empty)');
      return;
    }

    final finalSummary = buildFinalSummary(summary, voiceSdkId: voiceSdkId);

    // Get logs from log collector if available
    final logs = logCollector?.getLogsJson();

    // Build the full payload
    final payload = CallReportPayload(
      summary: finalSummary,
      stats: List.from(_statsBuffer),
      logs: logs,
      segment: _segmentCounter > 0 ? _segmentCounter : null,
    );

    final payloadJson = jsonEncode(payload.toJson());

    // Save local backup before uploading (mobile only)
    await _saveLocalBackup(summary.callId, payloadJson);

    // Convert WebSocket URL to HTTP endpoint
    final endpoint = _buildEndpoint(host);
    if (endpoint == null) return;

    final headers = _buildHeaders(callReportId, summary.callId, voiceSdkId);

    // Check payload size and chunk if needed
    if (payloadJson.length > _safePayloadSize) {
      await _postChunkedReport(
        summary: finalSummary,
        stats: List.from(_statsBuffer),
        logs: logs,
        endpoint: endpoint,
        headers: headers,
      );
    } else {
      await _postWithRetry(endpoint, headers, payloadJson);
    }
  }

  /// Post an intermediate segment during a long call
  Future<bool> flushIntermediateReport({
    CallReportFlushReason reason = const CallReportFlushReason(
      type: CallReportFlushReasonType.manual,
    ),
  }) =>
      _flushIntermediateSegment(reason);

  Future<bool> _flushIntermediateSegment(CallReportFlushReason reason) async {
    if (_flushing) return false;
    if (_storedCallReportId == null ||
        _storedHost == null ||
        _storedSummary == null) {
      GlobalLogger().d(
        'CallReportCollector: Cannot flush segment, upload config not stored',
      );
      return false;
    }

    final stats = List<StatsInterval>.from(_statsBuffer);
    final logEntries = logCollector?.getLogBuffer();
    final logs = logEntries?.map((entry) => entry.toJson()).toList();
    // The ingest contract requires report content; do not send a reason-only
    // socket segment when collection has not produced stats or logs yet.
    if (stats.isEmpty && (logs == null || logs.isEmpty)) {
      return false;
    }

    final segmentPayload = CallReportPayload(
      summary: _storedSummary!,
      stats: stats,
      logs: logs,
      segment: _segmentCounter,
      flushReason: reason,
    );

    final payloadJson = jsonEncode(segmentPayload.toJson());
    final endpoint = _buildEndpoint(_storedHost!);
    if (endpoint == null) return false;

    final headers = _buildHeaders(
      _storedCallReportId!,
      _storedSummary!.callId,
      _storedVoiceSdkId,
    );

    GlobalLogger().i(
      'CallReportCollector: Flushing intermediate segment $_segmentCounter (${_statsBuffer.length} intervals)',
    );

    _flushing = true;
    try {
      final uploaded = await _postWithRetry(endpoint, headers, payloadJson);
      if (!uploaded) return false;

      // Remove only the snapshot that was uploaded. Entries collected while
      // the request was in flight remain queued for the next segment.
      final statsToRemove = stats.length.clamp(0, _statsBuffer.length);
      _statsBuffer.removeRange(0, statsToRemove);
      if (logEntries != null && logEntries.isNotEmpty) {
        logCollector?.removeThrough(logEntries.last);
      }
      _segmentCounter++;
      _lastIntermediateFlushTime = DateTime.now();
      return true;
    } finally {
      _flushing = false;
    }
  }

  /// Post payload with retry logic and exponential backoff
  Future<bool> _postWithRetry(
    Uri endpoint,
    Map<String, String> headers,
    String body,
  ) async {
    for (int attempt = 0; attempt < _maxRetryAttempts; attempt++) {
      try {
        GlobalLogger().i(
          'CallReportCollector: Posting report to $endpoint (attempt ${attempt + 1}/$_maxRetryAttempts)',
        );

        final response = await http.post(
          endpoint,
          headers: headers,
          body: body,
        );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          GlobalLogger().i(
            'CallReportCollector: Successfully posted report for call: ${headers['x-call-id']}',
          );
          return true;
        } else if (response.statusCode >= 400 && response.statusCode < 500) {
          // Client error - don't retry
          GlobalLogger().e(
            'CallReportCollector: Client error (${response.statusCode}), not retrying: ${response.body}',
          );
          return false;
        } else {
          // Server error (5xx) - retry
          GlobalLogger().e(
            'CallReportCollector: Server error (${response.statusCode}): ${response.body}',
          );
          if (attempt < _maxRetryAttempts - 1) {
            await Future.delayed(
              Duration(milliseconds: _retryDelaysMs[attempt]),
            );
          }
        }
      } catch (e) {
        // Network exception - retry
        GlobalLogger().e(
          'CallReportCollector: Network error posting report (attempt ${attempt + 1}): $e',
        );
        if (attempt < _maxRetryAttempts - 1) {
          await Future.delayed(Duration(milliseconds: _retryDelaysMs[attempt]));
        }
      }
    }

    GlobalLogger().e(
      'CallReportCollector: Failed to post report after $_maxRetryAttempts attempts',
    );
    return false;
  }

  /// Post a large report in chunks
  Future<void> _postChunkedReport({
    required CallSummary summary,
    required List<StatsInterval> stats,
    required List<Map<String, dynamic>>? logs,
    required Uri endpoint,
    required Map<String, String> headers,
  }) async {
    GlobalLogger().i(
      'CallReportCollector: Payload too large, splitting into chunks',
    );

    // Estimate per-stat entry size for chunking
    final summaryJson = jsonEncode({'summary': summary.toJson()});
    final overheadSize = summaryJson.length + 200; // JSON structure overhead
    final availableSize = _safePayloadSize - overheadSize;

    // Calculate chunk size based on average stat entry size
    final statsJson = jsonEncode(stats.map((s) => s.toJson()).toList());
    final avgEntrySize =
        stats.isNotEmpty ? statsJson.length ~/ stats.length : 500;
    final entriesPerChunk =
        availableSize ~/ avgEntrySize.clamp(1, availableSize);

    int chunkSegment = _segmentCounter;
    for (int i = 0; i < stats.length; i += entriesPerChunk) {
      final end = (i + entriesPerChunk > stats.length)
          ? stats.length
          : i + entriesPerChunk;
      final chunk = stats.sublist(i, end);

      // Only include logs in the first chunk
      final chunkLogs = (i == 0) ? logs : null;

      final chunkPayload = CallReportPayload(
        summary: summary,
        stats: chunk,
        logs: chunkLogs,
        segment: chunkSegment,
      );

      final chunkBody = jsonEncode(chunkPayload.toJson());

      GlobalLogger().i(
        'CallReportCollector: Posting chunk segment $chunkSegment (${chunk.length} stats, ${chunkBody.length} bytes)',
      );

      await _postWithRetry(endpoint, headers, chunkBody);
      chunkSegment++;
    }

    _segmentCounter = chunkSegment;
  }

  /// Save a local backup of the report JSON (mobile only)
  Future<void> _saveLocalBackup(String callId, String payloadJson) async {
    if (kIsWeb) return; // Skip on web — no filesystem

    try {
      final path = await file_helper.saveCallReportToFile(callId, payloadJson);
      if (path != null) {
        _lastReportFilePath = path;
        GlobalLogger().i('CallReportCollector: Saved local backup to $path');
      }
    } catch (e) {
      GlobalLogger().w('CallReportCollector: Failed to save local backup: $e');
    }
  }

  /// Build the HTTP endpoint from a WebSocket URL
  Uri? _buildEndpoint(String host) {
    try {
      final wsUri = Uri.parse(host);
      final httpScheme = wsUri.scheme.replaceFirst('ws', 'http');
      return Uri(
        scheme: httpScheme,
        host: wsUri.host,
        port: wsUri.port,
        path: '/call_report',
      );
    } catch (e) {
      GlobalLogger().e(
        'CallReportCollector: Failed to build endpoint from host $host: $e',
      );
      return null;
    }
  }

  /// Build request headers
  Map<String, String> _buildHeaders(
    String callReportId,
    String callId,
    String? voiceSdkId,
  ) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'x-call-report-id': callReportId,
      'x-call-id': callId,
    };
    if (voiceSdkId != null) {
      headers['x-voice-sdk-id'] = voiceSdkId;
    }
    return headers;
  }

  /// Get the current stats buffer (for debugging)
  List<StatsInterval> getStatsBuffer() => List.unmodifiable(_statsBuffer);

  /// Returns whether a recovered call should escalate its next ICE attempt to
  /// relay-only candidates.
  ///
  /// This deliberately requires all three high-confidence signals used by the
  /// JS SDK: a VPN path, a selected local candidate that is not already a TURN
  /// relay, and evidence that the path stalled. Two intervals are required so
  /// cumulative counters can be compared without treating call startup as a
  /// stall.
  ///
  /// On mobile, flutter_webrtc may omit the non-standard `networkType` ICE
  /// candidate stat. In that case this intentionally returns false: forcing
  /// relay without a reliable VPN signal would escalate ordinary path stalls.
  bool shouldForceRelayCandidateForRecovery() {
    if (_statsBuffer.length < 2) return false;

    final tail = List<StatsInterval>.of(
      _statsBuffer.sublist(_statsBuffer.length - 2),
    );
    final previous = tail.first;
    final latest = tail.last;
    final localCandidate = latest.ice?.local;
    final isVpnNonRelayPath =
        localCandidate?.networkType?.toLowerCase() == 'vpn' &&
            localCandidate?.candidateType?.toLowerCase() != 'relay';
    if (!isVpnNonRelayPath) return false;

    final transportState = latest.transport?.iceState?.toLowerCase();
    final iceNotWritable = latest.ice?.writable == false;
    final iceTransportFailed =
        transportState == 'disconnected' || transportState == 'failed';

    final requestsSentDelta = _positiveDelta(
      latest.ice?.requestsSent,
      previous.ice?.requestsSent,
    );
    final responsesReceivedDelta = _positiveDelta(
      latest.ice?.responsesReceived,
      previous.ice?.responsesReceived,
    );
    final iceChecksStalled =
        requestsSentDelta > 0 && responsesReceivedDelta == 0;

    final outboundBytesDelta = _positiveDelta(
      latest.audio?.outbound?.bytesSent,
      previous.audio?.outbound?.bytesSent,
    );
    final inboundBytesDelta = _positiveDelta(
      latest.audio?.inbound?.bytesReceived,
      previous.audio?.inbound?.bytesReceived,
    );
    final inboundMediaStalled =
        outboundBytesDelta > 0 && inboundBytesDelta == 0;

    return iceNotWritable ||
        iceTransportFailed ||
        iceChecksStalled ||
        inboundMediaStalled;
  }

  static int _positiveDelta(int? latest, int? previous) {
    if (latest == null || previous == null) return 0;
    final delta = latest - previous;
    // Counter resets/wraps are deliberately treated as no progress. This
    // keeps recovery conservative instead of interpreting a reset as a stall.
    return delta > 0 ? delta : 0;
  }

  /// Adds a finalized interval without a live peer connection in unit tests.
  @visibleForTesting
  void injectIntervalForTest(StatsInterval interval) {
    _statsBuffer.add(interval);
  }

  /// Collect stats from the peer connection
  Future<void> _collectStats() {
    final activeCollection = _collectionInProgress;
    if (activeCollection != null) return activeCollection;

    late final Future<void> collection;
    collection = _collectStatsOnce().whenComplete(() {
      if (identical(_collectionInProgress, collection)) {
        _collectionInProgress = null;
      }
    });
    _collectionInProgress = collection;
    return collection;
  }

  Future<void> _collectStatsOnce() async {
    if (_peerConnection == null || _intervalStartTime == null) {
      return;
    }

    try {
      await _refreshLocalAudioTrackSnapshot();
      final stats = await _peerConnection!.getStats();
      final now = DateTime.now();

      _processStatsReports(stats, now);

      _previousTimestamp = now.millisecondsSinceEpoch;

      // Check if interval is complete
      final intervalDuration =
          now.difference(_intervalStartTime!).inMilliseconds;
      if (intervalDuration >= options.intervalMs) {
        // Finalize and notify listeners before considering an upload so
        // quality warnings always observe the interval being flushed.
        _createStatsEntry(now);
        _intervalStartTime = now;
        _resetIntervalAccumulators();

        _requestIntermediateFlushIfNeeded(now);
      }
    } catch (e) {
      GlobalLogger().e('CallReportCollector: Error collecting stats: $e');
    }
  }

  void _requestIntermediateFlushIfNeeded(DateTime now) {
    if (_flushing || _flushRequestInProgress) return;
    final statsCount = _statsBuffer.length;
    final logCount = logCollector?.length ?? 0;
    if (statsCount == 0 && logCount == 0) return;

    CallReportFlushReason? reason;
    if (statsCount >= _segmentFlushThreshold ||
        logCount >= _logFlushThreshold) {
      reason = const CallReportFlushReason(
        type: CallReportFlushReasonType.bufferLimit,
      );
    } else if (options.flushIntervalMs > 0 &&
        now.difference(_lastIntermediateFlushTime).inMilliseconds >=
            options.flushIntervalMs) {
      reason = const CallReportFlushReason(
        type: CallReportFlushReasonType.safetyInterval,
      );
    }
    if (reason == null) return;
    final selectedReason = reason;

    final callback = onFlushNeeded;
    if (callback != null) {
      _flushRequestInProgress = true;
      unawaited(
        Future<void>.sync(() => callback(selectedReason)).then<void>((_) {
          _lastIntermediateFlushTime = now;
        }).catchError((Object error) {
          GlobalLogger().e(
            'CallReportCollector: onFlushNeeded callback error: $error',
          );
        }).whenComplete(() => _flushRequestInProgress = false),
      );
      return;
    }
    // Upload retries/backoff must not block stats sampling, quality warnings,
    // or recovery decisions.
    unawaited(_flushIntermediateSegment(selectedReason));
  }

  /// Runs the intermediate-flush policy without a live peer connection.
  @visibleForTesting
  Future<void> requestIntermediateFlushForTesting(DateTime now) async {
    _requestIntermediateFlushIfNeeded(now);
    await Future<void>.delayed(Duration.zero);
  }

  /// Processes a stats snapshot without requiring a live peer connection.
  @visibleForTesting
  void processStatsReportsForTesting(List<StatsReport> stats, {DateTime? now}) {
    _intervalStartTime ??= now ?? DateTime.now();
    _processStatsReports(stats, now ?? DateTime.now());
  }

  /// Finalizes the currently accumulated interval for unit tests.
  @visibleForTesting
  StatsInterval createStatsEntryForTesting({DateTime? endTime}) {
    final resolvedEndTime = endTime ?? DateTime.now();
    _intervalStartTime ??= resolvedEndTime;
    _createStatsEntry(resolvedEndTime);
    return _statsBuffer.last;
  }

  void _processStatsReports(List<StatsReport> stats, DateTime now) {
    for (final report in stats) {
      final type = report.type;
      // Cast values to Map<String, dynamic>
      final values = Map<String, dynamic>.from(report.values);
      values.putIfAbsent('id', () => report.id);

      switch (type) {
        case 'outbound-rtp':
          if (values['kind'] == 'audio') {
            _lastOutboundAudio = values;
            _processOutboundAudio(values, now);
          }
          break;
        case 'inbound-rtp':
          if (values['kind'] == 'audio') {
            _lastInboundAudio = values;
            _processInboundAudio(values, now);
          }
          break;
        case 'candidate-pair':
          _cacheBounded(_candidatePairCache, report.id, values);
          if (values['nominated'] == true || values['state'] == 'succeeded') {
            _lastCandidatePair = values;
            _processCandidatePair(values);
            // Store candidate IDs for lookup
            _selectedLocalCandidateId = values['localCandidateId'] as String?;
            _selectedRemoteCandidateId = values['remoteCandidateId'] as String?;
          }
          break;
        case 'transport':
          _lastTransport = values;
          break;
        case 'codec':
          _cacheBounded(_codecCache, report.id, values);
          break;
        case 'media-playout':
          _lastMediaPlayout = values;
          break;
        case 'remote-inbound-rtp':
          if (values['kind'] == 'audio') {
            _lastRemoteInboundRtp = values;
          }
          break;
        case 'remote-outbound-rtp':
          if (values['kind'] == 'audio') {
            _lastRemoteOutboundRtp = values;
          }
          break;
        case 'media-source':
          if (values['kind'] == 'audio' || values['kind'] == null) {
            _cacheBounded(_mediaSourceCache, report.id, values);
          }
          break;
        case 'track':
          _cacheBounded(_trackStatsCache, report.id, values);
          break;
        case 'local-candidate':
          // Cache local candidates
          final candidateId = values['id'] as String?;
          if (candidateId != null) {
            _cacheBounded(_candidateCache, candidateId, values);
            GlobalLogger().d(
              'CallReportCollector: Cached local candidate $candidateId (${values['candidateType']})',
            );
          }
          break;
        case 'remote-candidate':
          // Cache remote candidates
          final candidateId = values['id'] as String?;
          if (candidateId != null) {
            _cacheBounded(_candidateCache, candidateId, values);
            GlobalLogger().d(
              'CallReportCollector: Cached remote candidate $candidateId (${values['candidateType']})',
            );
          }
          break;
      }
    }

    final selectedCandidatePairId =
        _lastTransport?['selectedCandidatePairId'] as String?;
    if (selectedCandidatePairId != null) {
      final selectedPair = _candidatePairCache[selectedCandidatePairId];
      final selectedPairState = selectedPair?['state'] as String?;
      if (selectedPair != null &&
          (selectedPairState == 'succeeded' ||
              selectedPairState == 'connected')) {
        _lastCandidatePair = selectedPair;
        _selectedLocalCandidateId = selectedPair['localCandidateId'] as String?;
        _selectedRemoteCandidateId =
            selectedPair['remoteCandidateId'] as String?;
        _processCandidatePair(selectedPair);
      }
    }

    _logLocalAudioTrackSnapshot();
  }

  void _cacheBounded(
    Map<String, Map<String, dynamic>> cache,
    String id,
    Map<String, dynamic> values,
  ) {
    cache.remove(id);
    cache[id] = values;
    while (cache.length > options.maxBufferSize) {
      cache.remove(cache.keys.first);
    }
  }

  void _processOutboundAudio(Map<String, dynamic> stats, DateTime now) {
    final mediaSource = _resolveOutboundMediaSource(stats);
    final audioLevel = (stats['audioLevel'] as num?)?.toDouble() ??
        (mediaSource?['audioLevel'] as num?)?.toDouble() ??
        _computeAudioLevelFromEnergy(
          (mediaSource?['totalAudioEnergy'] as num?)?.toDouble(),
          (mediaSource?['totalSamplesDuration'] as num?)?.toDouble(),
          inbound: false,
        ) ??
        _resolveTrackAudioLevel(stats['trackId'] as String?);
    if (audioLevel != null) {
      _intervalOutboundAudioLevels.add(audioLevel);
    }

    // Calculate bitrate
    final bytesSent = (stats['bytesSent'] as num?)?.toInt();
    if (bytesSent != null &&
        _previousOutboundBytes != null &&
        _previousTimestamp != null) {
      final bytesDelta = bytesSent - _previousOutboundBytes!;
      final timeDelta = now.millisecondsSinceEpoch - _previousTimestamp!;
      if (timeDelta > 0) {
        final bitrate = (bytesDelta * 8 * 1000) / timeDelta; // bps
        _intervalOutboundBitrates.add(bitrate);
      }
    }
    _previousOutboundBytes = bytesSent;
  }

  void _processInboundAudio(Map<String, dynamic> stats, DateTime now) {
    final audioLevel = (stats['audioLevel'] as num?)?.toDouble() ??
        _computeAudioLevelFromEnergy(
          (stats['totalAudioEnergy'] as num?)?.toDouble(),
          (stats['totalSamplesDuration'] as num?)?.toDouble(),
          inbound: true,
        ) ??
        _resolveTrackAudioLevel(stats['trackId'] as String?);
    if (audioLevel != null) {
      _intervalInboundAudioLevels.add(audioLevel);
    }

    // Jitter (convert to ms)
    final jitter = (stats['jitter'] as num?)?.toDouble();
    if (jitter != null) {
      _intervalJitters.add(jitter * 1000);
    }

    // Calculate bitrate
    final bytesReceived = (stats['bytesReceived'] as num?)?.toInt();
    if (bytesReceived != null &&
        _previousInboundBytes != null &&
        _previousTimestamp != null) {
      final bytesDelta = bytesReceived - _previousInboundBytes!;
      final timeDelta = now.millisecondsSinceEpoch - _previousTimestamp!;
      if (timeDelta > 0) {
        final bitrate = (bytesDelta * 8 * 1000) / timeDelta; // bps
        _intervalInboundBitrates.add(bitrate);
      }
    }
    _previousInboundBytes = bytesReceived;
  }

  void _processCandidatePair(Map<String, dynamic> stats) {
    // RTT (already in seconds in WebRTC stats)
    final rtt = (stats['currentRoundTripTime'] as num?)?.toDouble();
    if (rtt != null) {
      _intervalRTTs.add(rtt);
    }
  }

  void _createStatsEntry(DateTime endTime) {
    final entry = StatsInterval(
      intervalStartUtc: _intervalStartTime!.toUtc().toIso8601String(),
      intervalEndUtc: endTime.toUtc().toIso8601String(),
      audio: _createAudioStats(),
      connection: _createConnectionStats(),
      ice: _createIceStats(),
      transport: _createTransportStats(),
      mediaPlayout: _createMediaPlayoutStats(),
      remoteRtcp: _createRemoteRtcpStats(),
    );

    _statsBuffer.add(entry);

    // Notify any attached listener (e.g. QualityWarningMonitor) so it can
    // evaluate thresholds against this interval.
    try {
      onStatsInterval?.call(entry);
    } catch (_) {
      // Listener failures must not break stats collection.
    }

    // Enforce buffer size limit
    if (_statsBuffer.length > options.maxBufferSize) {
      _statsBuffer.removeAt(0);
      GlobalLogger().w(
        'CallReportCollector: Buffer limit reached, removed oldest entry',
      );
    }
  }

  AudioStats? _createAudioStats() {
    OutboundAudioStats? outbound;
    InboundAudioStats? inbound;

    if (_lastOutboundAudio != null) {
      outbound = OutboundAudioStats(
        packetsSent: (_lastOutboundAudio!['packetsSent'] as num?)?.toInt(),
        bytesSent: (_lastOutboundAudio!['bytesSent'] as num?)?.toInt(),
        retransmittedPacketsSent:
            (_lastOutboundAudio!['retransmittedPacketsSent'] as num?)?.toInt(),
        retransmittedBytesSent:
            (_lastOutboundAudio!['retransmittedBytesSent'] as num?)?.toInt(),
        headerBytesSent:
            (_lastOutboundAudio!['headerBytesSent'] as num?)?.toInt(),
        nackCount: (_lastOutboundAudio!['nackCount'] as num?)?.toInt(),
        targetBitrate:
            (_lastOutboundAudio!['targetBitrate'] as num?)?.toDouble(),
        totalPacketSendDelay:
            (_lastOutboundAudio!['totalPacketSendDelay'] as num?)?.toDouble(),
        active: _lastOutboundAudio!['active'] as bool?,
        audioLevelAvg: _average(_intervalOutboundAudioLevels),
        bitrateAvg: _average(_intervalOutboundBitrates),
        codec: _resolveCodec(_lastOutboundAudio!['codecId'] as String?),
        localTrack: _lastLocalAudioTrack,
        mediaSource: _createLocalAudioSourceStats(
          _resolveOutboundMediaSource(_lastOutboundAudio!),
        ),
      );
    }

    if (_lastInboundAudio != null) {
      inbound = InboundAudioStats(
        packetsReceived:
            (_lastInboundAudio!['packetsReceived'] as num?)?.toInt(),
        bytesReceived: (_lastInboundAudio!['bytesReceived'] as num?)?.toInt(),
        packetsLost: (_lastInboundAudio!['packetsLost'] as num?)?.toInt(),
        packetsDiscarded:
            (_lastInboundAudio!['packetsDiscarded'] as num?)?.toInt(),
        nackCount: (_lastInboundAudio!['nackCount'] as num?)?.toInt(),
        headerBytesReceived:
            (_lastInboundAudio!['headerBytesReceived'] as num?)?.toInt(),
        fecPacketsReceived:
            (_lastInboundAudio!['fecPacketsReceived'] as num?)?.toInt(),
        fecPacketsDiscarded:
            (_lastInboundAudio!['fecPacketsDiscarded'] as num?)?.toInt(),
        jitterBufferDelay:
            (_lastInboundAudio!['jitterBufferDelay'] as num?)?.toDouble(),
        jitterBufferEmittedCount:
            (_lastInboundAudio!['jitterBufferEmittedCount'] as num?)?.toInt(),
        jitterBufferTargetDelay:
            (_lastInboundAudio!['jitterBufferTargetDelay'] as num?)?.toDouble(),
        jitterBufferMinimumDelay:
            (_lastInboundAudio!['jitterBufferMinimumDelay'] as num?)
                ?.toDouble(),
        totalSamplesReceived:
            (_lastInboundAudio!['totalSamplesReceived'] as num?)?.toInt(),
        concealedSamples:
            (_lastInboundAudio!['concealedSamples'] as num?)?.toInt(),
        concealmentEvents:
            (_lastInboundAudio!['concealmentEvents'] as num?)?.toInt(),
        totalSamplesDecoded:
            (_lastInboundAudio!['totalSamplesDecoded'] as num?)?.toInt(),
        samplesDecodedWithSilence:
            (_lastInboundAudio!['samplesDecodedWithSilence'] as num?)?.toInt(),
        samplesDecodedWithConcealment:
            (_lastInboundAudio!['samplesDecodedWithConcealment'] as num?)
                ?.toInt(),
        totalAudioEnergy:
            (_lastInboundAudio!['totalAudioEnergy'] as num?)?.toDouble(),
        totalSamplesDuration:
            (_lastInboundAudio!['totalSamplesDuration'] as num?)?.toDouble(),
        audioLevelAvg: _average(_intervalInboundAudioLevels),
        jitterAvg: _average(_intervalJitters),
        bitrateAvg: _average(_intervalInboundBitrates),
        codec: _resolveCodec(_lastInboundAudio!['codecId'] as String?),
      );
    }

    if (outbound == null && inbound == null) {
      return null;
    }

    return AudioStats(outbound: outbound, inbound: inbound);
  }

  ConnectionStats? _createConnectionStats() {
    if (_lastCandidatePair == null) {
      return null;
    }

    return ConnectionStats(
      roundTripTimeAvg: _average(_intervalRTTs),
      packetsSent: (_lastCandidatePair!['packetsSent'] as num?)?.toInt(),
      packetsReceived:
          (_lastCandidatePair!['packetsReceived'] as num?)?.toInt(),
      bytesSent: (_lastCandidatePair!['bytesSent'] as num?)?.toInt(),
      bytesReceived: (_lastCandidatePair!['bytesReceived'] as num?)?.toInt(),
    );
  }

  CodecStats? _resolveCodec(String? codecId) {
    if (codecId == null) return null;
    final codec = _codecCache[codecId];
    if (codec == null) return null;
    return CodecStats(
      mimeType: codec['mimeType'] as String?,
      clockRate: (codec['clockRate'] as num?)?.toInt(),
      channels: (codec['channels'] as num?)?.toInt(),
      sdpFmtpLine: codec['sdpFmtpLine'] as String?,
      payloadType: (codec['payloadType'] as num?)?.toInt(),
      codecId: codecId,
    );
  }

  Future<void> _refreshLocalAudioTrackSnapshot() async {
    final peerConnection = _peerConnection;
    if (peerConnection == null) return;

    try {
      final senders = await peerConnection.getSenders();
      MediaStreamTrack? audioTrack;
      for (final sender in senders) {
        final track = sender.track;
        if (track?.kind == 'audio') {
          audioTrack = track;
          break;
        }
      }
      if (audioTrack == null) return;

      Map<String, dynamic>? settings;
      try {
        settings = Map<String, dynamic>.from(audioTrack.getSettings());
      } catch (_) {
        // getSettings is not implemented by every flutter_webrtc platform.
      }
      _lastLocalAudioTrack = LocalAudioTrackSnapshot(
        id: audioTrack.id,
        label: audioTrack.label,
        enabled: audioTrack.enabled,
        muted: audioTrack.muted,
        settings: settings,
      );
    } catch (error) {
      GlobalLogger().d(
        'CallReportCollector: Unable to snapshot local audio track: $error',
      );
    }
  }

  void _logLocalAudioTrackSnapshot() {
    final snapshot = _lastLocalAudioTrack;
    if (snapshot == null || logCollector == null) return;
    final encoded = jsonEncode(snapshot.toJson());
    if (encoded == _lastLocalAudioTrackSnapshotJson) return;
    _lastLocalAudioTrackSnapshotJson = encoded;
    logCollector!.addLog(
      level: 'debug',
      message: 'Local audio track snapshot changed',
      context: {'localTrack': snapshot.toJson()},
    );
  }

  Map<String, dynamic>? _resolveOutboundMediaSource(
    Map<String, dynamic> outbound,
  ) {
    final sourceId = outbound['mediaSourceId'] as String?;
    return sourceId == null ? null : _mediaSourceCache[sourceId];
  }

  double? _resolveTrackAudioLevel(String? trackId) {
    if (trackId == null) return null;
    return (_trackStatsCache[trackId]?['audioLevel'] as num?)?.toDouble();
  }

  double? _computeAudioLevelFromEnergy(
    double? totalEnergy,
    double? totalDuration, {
    required bool inbound,
  }) {
    if (totalEnergy == null || totalDuration == null) return null;

    final previousEnergy =
        inbound ? _previousInboundAudioEnergy : _previousOutboundAudioEnergy;
    final previousDuration = inbound
        ? _previousInboundSamplesDuration
        : _previousOutboundSamplesDuration;

    if (inbound) {
      _previousInboundAudioEnergy = totalEnergy;
      _previousInboundSamplesDuration = totalDuration;
    } else {
      _previousOutboundAudioEnergy = totalEnergy;
      _previousOutboundSamplesDuration = totalDuration;
    }

    if (previousEnergy == null || previousDuration == null) return null;
    final energyDelta = totalEnergy - previousEnergy;
    final durationDelta = totalDuration - previousDuration;
    if (energyDelta < 0 || durationDelta <= 0) return null;
    return math.sqrt(energyDelta / durationDelta).clamp(0.0, 1.0);
  }

  LocalAudioSourceStats? _createLocalAudioSourceStats(
    Map<String, dynamic>? source,
  ) {
    if (source == null) return null;
    return LocalAudioSourceStats(
      id: source['id'] as String?,
      trackIdentifier: source['trackIdentifier'] as String?,
      audioLevel: (source['audioLevel'] as num?)?.toDouble(),
      totalAudioEnergy: (source['totalAudioEnergy'] as num?)?.toDouble(),
      totalSamplesDuration:
          (source['totalSamplesDuration'] as num?)?.toDouble(),
      echoReturnLoss: (source['echoReturnLoss'] as num?)?.toDouble(),
      echoReturnLossEnhancement:
          (source['echoReturnLossEnhancement'] as num?)?.toDouble(),
    );
  }

  TransportStats? _createTransportStats() {
    if (_lastTransport == null) return null;
    return TransportStats(
      iceState: _lastTransport!['iceState'] as String?,
      dtlsState: _lastTransport!['dtlsState'] as String?,
      srtpCipher: _lastTransport!['srtpCipher'] as String?,
      tlsVersion: _lastTransport!['tlsVersion'] as String?,
      selectedCandidatePairChanges:
          (_lastTransport!['selectedCandidatePairChanges'] as num?)?.toInt(),
      selectedCandidatePairId:
          _lastTransport!['selectedCandidatePairId'] as String?,
    );
  }

  MediaPlayoutStats? _createMediaPlayoutStats() {
    if (_lastMediaPlayout == null) return null;
    return MediaPlayoutStats(
      synthesizedSamples:
          (_lastMediaPlayout!['synthesizedSamples'] as num?)?.toInt(),
      synthesizedDuration:
          (_lastMediaPlayout!['synthesizedDuration'] as num?)?.toDouble(),
      totalPlayoutDelay:
          (_lastMediaPlayout!['totalPlayoutDelay'] as num?)?.toDouble(),
      totalSampleCount:
          (_lastMediaPlayout!['totalSampleCount'] as num?)?.toInt(),
    );
  }

  RemoteRtcpStats? _createRemoteRtcpStats() {
    RemoteInboundRtpStats? inbound;
    RemoteOutboundRtpStats? outbound;

    if (_lastRemoteInboundRtp != null) {
      final totalRoundTripTime =
          (_lastRemoteInboundRtp!['totalRoundTripTime'] as num?)?.toDouble();
      final measurements =
          (_lastRemoteInboundRtp!['roundTripTimeMeasurements'] as num?)
              ?.toInt();
      inbound = RemoteInboundRtpStats(
        packetsReceived:
            (_lastRemoteInboundRtp!['packetsReceived'] as num?)?.toInt(),
        packetsLost: (_lastRemoteInboundRtp!['packetsLost'] as num?)?.toInt(),
        fractionLost:
            (_lastRemoteInboundRtp!['fractionLost'] as num?)?.toDouble(),
        jitter: (_lastRemoteInboundRtp!['jitter'] as num?)?.toDouble(),
        roundTripTime:
            (_lastRemoteInboundRtp!['roundTripTime'] as num?)?.toDouble(),
        totalRoundTripTime: totalRoundTripTime,
        roundTripTimeMeasurements: measurements,
        roundTripTimeAvg: totalRoundTripTime != null &&
                measurements != null &&
                measurements > 0
            ? totalRoundTripTime / measurements
            : null,
        nackCount: (_lastRemoteInboundRtp!['nackCount'] as num?)?.toInt(),
        reportsReceived:
            (_lastRemoteInboundRtp!['reportsReceived'] as num?)?.toInt(),
        packetsDiscarded:
            (_lastRemoteInboundRtp!['packetsDiscarded'] as num?)?.toInt(),
      );
    }

    if (_lastRemoteOutboundRtp != null) {
      outbound = RemoteOutboundRtpStats(
        packetsSent: (_lastRemoteOutboundRtp!['packetsSent'] as num?)?.toInt(),
        bytesSent: (_lastRemoteOutboundRtp!['bytesSent'] as num?)?.toInt(),
        reportsCount:
            (_lastRemoteOutboundRtp!['reportsCount'] as num?)?.toInt(),
        roundTripTime:
            (_lastRemoteOutboundRtp!['roundTripTime'] as num?)?.toDouble(),
        totalPacketSendDelay:
            (_lastRemoteOutboundRtp!['totalPacketSendDelay'] as num?)
                ?.toDouble(),
      );
    }

    if (inbound == null && outbound == null) return null;
    return RemoteRtcpStats(inbound: inbound, outbound: outbound);
  }

  IceStats? _createIceStats() {
    if (_lastCandidatePair == null) {
      return null;
    }

    // Debug: log candidate cache state and candidate-pair details
    GlobalLogger().d(
      'CallReportCollector: Creating ICE stats - localId=$_selectedLocalCandidateId, remoteId=$_selectedRemoteCandidateId, cacheSize=${_candidateCache.length}',
    );

    // Try to find local candidate - first by ID, then by searching cache
    IceCandidateStats? localCandidate;
    Map<String, dynamic>? localData;

    // Method 1: Direct ID lookup (works on some platforms)
    if (_selectedLocalCandidateId != null &&
        _candidateCache.containsKey(_selectedLocalCandidateId)) {
      localData = _candidateCache[_selectedLocalCandidateId];
    }

    // Method 2: Search cache for a local candidate (any will do for basic info)
    // Since we mark local candidates with 'RTCIceLc_' prefix
    if (localData == null) {
      for (final entry in _candidateCache.entries) {
        if (entry.key.contains('Lc_')) {
          localData = entry.value;
          GlobalLogger().d(
            'CallReportCollector: Found local candidate by prefix: ${entry.key}',
          );
          break;
        }
      }
    }

    if (localData != null) {
      localCandidate = IceCandidateStats(
        address: localData['address'] as String? ?? localData['ip'] as String?,
        candidateType: localData['candidateType'] as String?,
        networkType: localData['networkType'] as String?,
        port: (localData['port'] as num?)?.toInt(),
        protocol: localData['protocol'] as String?,
        priority: (localData['priority'] as num?)?.toInt(),
        relatedAddress: localData['relatedAddress'] as String?,
        relatedPort: (localData['relatedPort'] as num?)?.toInt(),
      );
    } else {
      GlobalLogger().w(
        'CallReportCollector: No local candidate found in cache. Available: ${_candidateCache.keys.toList()}',
      );
    }

    // Try to find remote candidate - first by ID, then by searching cache
    IceCandidateStats? remoteCandidate;
    Map<String, dynamic>? remoteData;

    // Method 1: Direct ID lookup
    if (_selectedRemoteCandidateId != null &&
        _candidateCache.containsKey(_selectedRemoteCandidateId)) {
      remoteData = _candidateCache[_selectedRemoteCandidateId];
    }

    // Method 2: Search cache for a remote candidate
    if (remoteData == null) {
      for (final entry in _candidateCache.entries) {
        if (entry.key.contains('Rc_')) {
          remoteData = entry.value;
          GlobalLogger().d(
            'CallReportCollector: Found remote candidate by prefix: ${entry.key}',
          );
          break;
        }
      }
    }

    if (remoteData != null) {
      remoteCandidate = IceCandidateStats(
        address:
            remoteData['address'] as String? ?? remoteData['ip'] as String?,
        candidateType: remoteData['candidateType'] as String?,
        networkType: remoteData['networkType'] as String?,
        port: (remoteData['port'] as num?)?.toInt(),
        protocol: remoteData['protocol'] as String?,
        priority: (remoteData['priority'] as num?)?.toInt(),
        relatedAddress: remoteData['relatedAddress'] as String?,
        relatedPort: (remoteData['relatedPort'] as num?)?.toInt(),
      );
    } else {
      GlobalLogger().w(
        'CallReportCollector: No remote candidate found in cache. Available: ${_candidateCache.keys.toList()}',
      );
    }

    return IceStats(
      id: _lastCandidatePair!['id'] as String?,
      local: localCandidate,
      remote: remoteCandidate,
      nominated: _lastCandidatePair!['nominated'] as bool?,
      requestsSent: (_lastCandidatePair!['requestsSent'] as num?)?.toInt(),
      responsesReceived:
          (_lastCandidatePair!['responsesReceived'] as num?)?.toInt(),
      state: _lastCandidatePair!['state'] as String?,
      writable: _lastCandidatePair!['writable'] as bool?,
    );
  }

  double? _average(List<double> values) {
    if (values.isEmpty) return null;
    final sum = values.reduce((a, b) => a + b);
    return double.parse((sum / values.length).toStringAsFixed(4));
  }

  void _resetIntervalAccumulators() {
    _intervalOutboundAudioLevels.clear();
    _intervalInboundAudioLevels.clear();
    _intervalJitters.clear();
    _intervalRTTs.clear();
    _intervalOutboundBitrates.clear();
    _intervalInboundBitrates.clear();
  }
}
