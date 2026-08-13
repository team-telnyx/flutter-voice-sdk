import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:telnyx_webrtc/config.dart';
import 'package:telnyx_webrtc/model/call_termination_reason.dart';
import 'package:telnyx_webrtc/model/connection_status.dart';
import 'package:telnyx_webrtc/model/network_reason.dart';
import 'package:telnyx_webrtc/model/tx_ice_server.dart';
import 'package:telnyx_webrtc/model/verto/receive/update_media_response.dart';
import 'package:telnyx_webrtc/model/verto/send/attach_call_message.dart';
import 'package:telnyx_webrtc/peer/peer.dart'
    if (dart.library.html) 'package:telnyx_webrtc/peer/web/peer.dart';
import 'package:telnyx_webrtc/call.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';
import 'package:telnyx_webrtc/model/gateway_state.dart';
import 'package:telnyx_webrtc/model/socket_method.dart';
import 'package:telnyx_webrtc/model/telnyx_socket_error.dart';
import 'package:telnyx_webrtc/model/verto/receive/receive_bye_message_body.dart';
import 'package:telnyx_webrtc/model/verto/receive/received_message_body.dart';
import 'package:telnyx_webrtc/model/verto/receive/ai_conversation_message.dart';
import 'package:telnyx_webrtc/model/transcript_item.dart';
import 'package:telnyx_webrtc/model/verto/send/gateway_request_message_body.dart';
import 'package:telnyx_webrtc/model/verto/send/login_message_body.dart';
import 'package:telnyx_webrtc/model/verto/send/anonymous_login_message.dart';
import 'package:telnyx_webrtc/model/telnyx_message.dart';
import 'package:telnyx_webrtc/tx_socket.dart'
    if (dart.library.js) 'package:telnyx_webrtc/tx_socket_web.dart';
import 'package:telnyx_webrtc/utils/codec_utils.dart';
import 'package:telnyx_webrtc/utils/constants.dart';
import 'package:telnyx_webrtc/utils/logging/custom_logger.dart';
import 'package:telnyx_webrtc/utils/logging/default_logger.dart';
import 'package:telnyx_webrtc/utils/logging/log_level.dart';
import 'package:telnyx_webrtc/utils/preference_storage.dart';
import 'package:telnyx_webrtc/utils/version_utils.dart';
import 'package:telnyx_webrtc/utils/websocket_utils.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'package:telnyx_webrtc/model/call_state.dart';
import 'package:telnyx_webrtc/model/jsonrpc.dart';
import 'package:telnyx_webrtc/model/push_notification.dart';
import 'package:telnyx_webrtc/model/verto/send/pong_message_body.dart';
import 'package:telnyx_webrtc/model/verto/send/ringing_ack_message.dart';
import 'package:telnyx_webrtc/model/verto/send/disable_push_body.dart';
import 'package:telnyx_webrtc/model/region.dart';
import 'package:telnyx_webrtc/model/audio_codec.dart';
import 'package:telnyx_webrtc/model/pending_ice_candidate.dart';
import 'package:telnyx_webrtc/utils/candidate_utils.dart';
import 'package:telnyx_webrtc/model/socket_connection_metrics.dart';
import 'package:telnyx_webrtc/model/tx_server_configuration.dart';
import 'package:telnyx_webrtc/model/audio_constraints.dart';
import 'package:telnyx_webrtc/call_manager.dart';
import 'package:telnyx_webrtc/utils/latency_tracker.dart';
import 'package:telnyx_webrtc/model/errors/telnyx_error.dart';
import 'package:telnyx_webrtc/model/errors/telnyx_error_codes.dart';
import 'package:telnyx_webrtc/model/errors/telnyx_error_event.dart';
import 'package:telnyx_webrtc/model/errors/telnyx_error_factory.dart';
import 'package:telnyx_webrtc/model/errors/telnyx_warning.dart';
import 'package:telnyx_webrtc/model/errors/telnyx_warning_codes.dart';
import 'package:telnyx_webrtc/model/errors/telnyx_warning_factory.dart';
import 'package:telnyx_webrtc/model/errors/telnyx_warning_event.dart';
import 'package:telnyx_webrtc/services/signaling_health_monitor.dart';
import 'package:telnyx_webrtc/services/reconnect_token_store.dart';
import 'package:telnyx_webrtc/services/request_timeout_tracker.dart';

/// Callback for when the socket receives a message
typedef OnSocketMessageReceived = void Function(TelnyxMessage message);

/// Callback for when the socket receives an error
@Deprecated(
  'Use TelnyxClient.onTelnyxError or the errors stream instead. '
  'Will be removed in v3.0.0',
)
typedef OnSocketErrorReceived = void Function(TelnyxSocketError message);

/// Callback for structured SDK error events (VSDK-415).
///
/// The [event] is either a [TelnyxErrorEvent] (non-recoverable) or a
/// [TelnyxMediaRecoveryErrorEvent] (recoverable inbound media failure). Use
/// [isMediaRecoveryErrorEvent] to discriminate.
typedef OnTelnyxError = void Function(Object event);

/// Callback for structured SDK warning events (VSDK-415).
typedef OnTelnyxWarning = void Function(TelnyxWarningEvent event);

/// Callback for when transcript updates occur
typedef OnTranscriptUpdate = void Function(List<TranscriptItem> transcript);

/// Callback for when connection state changes
typedef OnConnectionStateChanged = void Function(ConnectionStatus status);

/// Callback for when connection metrics are updated
typedef OnConnectionMetricsUpdate = void Function(
  SocketConnectionMetrics metrics,
);

/// Provides connectivity change events for [TelnyxClient].
typedef ConnectivityChangesProvider = Stream<List<ConnectivityResult>>
    Function();

/// Represents the main entry point for interacting with the Telnyx RTC SDK.
///
/// This class manages the WebSocket connection to the Telnyx backend, handles
/// user authentication, and facilitates call creation and management. It provides
/// methods to connect, disconnect, send and receive calls, and monitor the
/// connection status.
///
/// Callbacks like [onSocketMessageReceived] and [onSocketErrorReceived] must be
/// implemented to handle events and errors from the socket.
class TelnyxClient {
  /// Callback for when the socket receives a message
  late OnSocketMessageReceived onSocketMessageReceived;

  /// Callback for when the socket receives an error
  @Deprecated(
    'Use onTelnyxError or the errors stream instead. '
    'Will be removed in v3.0.0',
  )
  late OnSocketErrorReceived onSocketErrorReceived;

  /// Optional callback for structured SDK error events (VSDK-415).
  ///
  /// Fires *alongside* the legacy [onSocketErrorReceived] — never instead of
  /// it. Receives a [TelnyxErrorEvent] or a [TelnyxMediaRecoveryErrorEvent].
  /// Only invoked when structured errors are enabled via
  /// [Config.enableStructuredErrors] (default true).
  OnTelnyxError? onTelnyxError;

  /// Optional callback for structured SDK warning events (VSDK-415).
  ///
  /// Only invoked when structured errors are enabled via
  /// [Config.enableStructuredErrors] (default true).
  OnTelnyxWarning? onTelnyxWarning;

  /// Callback for when transcript updates occur
  /// Note: this is only relevant for Assistant AI conversations
  OnTranscriptUpdate? onTranscriptUpdate;

  /// Callback for when connection state changes
  OnConnectionStateChanged? onConnectionStateChanged;

  /// Callback for when connection metrics are updated
  OnConnectionMetricsUpdate? onConnectionMetricsUpdate;

  /// The path to the ringtone file (audio to play when receiving a call)
  String _ringtonePath = '';

  /// The path to the ringback file (audio to play when calling)
  String _ringBackpath = '';

  CustomLogger _logger = DefaultLogger();

  PushMetaData? _pushMetaData;
  bool _isAttaching = false;
  bool _debug = false;

  // Stores the last known connectivity result to detect actual changes.
  List<ConnectivityResult>? _previousConnectivityResult;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  final ConnectivityChangesProvider _connectivityChanges;
  final Set<Timer> _delayedConnectionTimers = <Timer>{};
  int _connectionGeneration = 0;

  // Map to track reconnection timers for each call
  final Map<String?, Timer> _reconnectionTimers = {};

  // Current widget settings from AI conversation
  WidgetSettings? _currentWidgetSettings;

  // Transcript management
  final List<TranscriptItem> _transcript = [];
  final Map<String, StringBuffer> _assistantResponseBuffers = {};

  /// Default constructor for the TelnyxClient
  TelnyxClient({ConnectivityChangesProvider? connectivityChanges})
      : _connectivityChanges = connectivityChanges ??
            (() => Connectivity().onConnectivityChanged) {
    onSocketMessageReceived = (TelnyxMessage message) {
      switch (message.socketMethod) {
        case SocketMethod.invite:
          {
            GlobalLogger().i(
              'TelnyxClient :: onSocketMessageReceived  Override this on client side: ${message.message}',
            );
            break;
          }
        case SocketMethod.bye:
          {
            GlobalLogger().i(
              'TelnyxClient :: onSocketMessageReceived  Override this on client side: ${message.message}',
            );
            break;
          }
        default:
          GlobalLogger().i(
            'TelnyxClient :: onSocketMessageReceived  Override this on client side: ${message.message}',
          );
      }
      GlobalLogger().i(
        'TelnyxClient :: onSocketMessageReceived  Override this on client side: ${message.message}',
      );
    };

    _checkReconnection();
  }

  /// The latency tracker instance for this client.
  /// Access via `telnyxClient.latencyTracker` to read metrics or set a listener.
  final LatencyTracker latencyTracker = LatencyTracker();

  /// The current instance of [TxSocket] associated with this client
  TxSocket txSocket = TxSocket(DefaultConfig.socketHostAddress);

  bool _closed = true;
  bool _disposed = false;
  bool _latencyTrackerDisposed = false;
  bool _connected = false;
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;

  /// The current session ID related to this client
  String sessid = const Uuid().v4();

  /// The call report ID received from voice-sdk-proxy on REGED.
  /// Used for authenticating call report POST requests after call ends.
  String? callReportId;

  /// The WebSocket host URL for deriving the call report endpoint.
  String? _socketHost;

  /// Gets the WebSocket host URL (used for call report endpoint derivation).
  String? get socketHost => _socketHost;

  /// Gets the voice SDK ID received from the server (used for call report headers).
  String? get voiceSdkId => _pushMetaData?.voiceSdkId;

  Timer? _gatewayResponseTimer;
  bool _waitingForReg = true;
  bool _pendingAnswerFromPush = false;

  /// The device token (FCM/APNS) to include when answering a push notification call.
  /// This is stored when handlePushNotification is called and automatically passed
  /// to acceptCall when auto-answering, allowing the backend to identify which
  /// device answered and dismiss the call on other devices.
  String? _answeredDeviceToken;
  bool _pendingDeclineFromPush = false;
  bool _isCallFromPush = false;
  bool _registered = false;
  int _registrationRetryCounter = 0;

  /// Timer for handling push notification answer timeout
  Timer? _pendingAnswerTimeout;

  /// Override value for push answer timeout (used when set via handlePushNotification)
  int? _pushAnswerTimeoutOverride;

  /// Gets the timeout duration for pending answer from push notification
  /// Precedence: handlePushNotification override → Config value → Default (10 seconds)
  Duration get _pushAnswerTimeoutDuration {
    final timeoutMs = _pushAnswerTimeoutOverride ??
        _storedCredentialConfig?.pushAnswerTimeout ??
        _storedTokenConfig?.pushAnswerTimeout ??
        Constants.pushAnswerTimeout;
    return Duration(milliseconds: timeoutMs);
  }

  /// Controls whether the client should automatically attempt to reconnect
  /// when the socket connection fails or network connectivity is restored.
  /// This value is set from the CredentialConfig or TokenConfig during login.
  bool _autoReconnectLogin = true;

  /// Tracks the number of connection retry attempts made.
  /// This counter is incremented with each reconnection attempt and reset
  /// when a successful connection is established or when the retry limit is reached.
  int _connectRetryCounter = 0;

  /// The current gateway state for the socket connection
  String gatewayState = GatewayState.idle;

  /// A map of all current calls, with the call ID as the key and the [Call] object as the value.
  Map<String, Call> calls = {};

  /// Manages multi-call state: tracks the current active call and held calls.
  ///
  /// Use [callManager] to decide how to handle an incoming call when there is
  /// already an active call (hold+accept, end+accept, or reject).
  final CallManager callManager = CallManager();

  /// A map of pending ICE candidates, with the call ID as the key and a list of candidates as the value.
  /// These candidates are queued and will be processed after the remote description is set.
  final Map<String, List<PendingIceCandidate>> pendingIceCandidates = {};

  /// The current active calls being handled by the TelnyxClient instance
  /// The Map key is the callId [String] and the value is the [Call] instance
  Map<String, Call> activeCalls() {
    return Map.fromEntries(
      calls.entries.where(
        (entry) =>
            entry.value.callState.isActive ||
            entry.value.callState.isDropped ||
            entry.value.callState.isReconnecting,
      ),
    );
  }

  /// Called when a call state changes to active
  /// This will cancel any reconnection timer for the call
  void onCallStateChangedToActive(String? callId) {
    if (callId != null) {
      GlobalLogger().i(
        'Call $callId state changed to ACTIVE, cancelling reconnection timer',
      );
      _cancelReconnectionTimer(callId);
    }
    // Keep the signaling-health monitor lifecycle in sync with active calls.
    _syncHealthMonitorLifecycle();
    // Persist a narrow recovery marker for the current active calls.
    _persistActiveCallsMarker();
  }

  // ── Structured error/warning surface (VSDK-415) ─────────────────────

  /// Whether structured error/warning callbacks are enabled for the current
  /// session. Set from [Config.enableStructuredErrors] during connect.
  bool _enableStructuredErrors = true;

  /// Whether the [SignalingHealthMonitor] is enabled for the current session.
  bool _enableSignalingHealthMonitor = true;

  /// The media-permission recovery configuration retained from [Config].
  MediaPermissionsRecoveryConfig? _mediaPermissionsRecovery;

  /// The media-permission recovery configuration for the current session, or
  /// null when disabled. Consumed by the [Peer.createStream] answer path.
  MediaPermissionsRecoveryConfig? get mediaPermissionsRecovery =>
      _mediaPermissionsRecovery;

  /// The signaling-health monitor instance, created when enabled.
  SignalingHealthMonitor? _healthMonitor;

  /// The signaling-health monitor for the current session (test/inspection).
  SignalingHealthMonitor? get healthMonitor => _healthMonitor;

  /// Per-request timeout tracker for critical JSON-RPC methods (VSDK-416).
  /// Active only when the health monitor is enabled; null otherwise.
  RequestTimeoutTracker? _requestTimeoutTracker;

  /// The reconnect policy currently applied to health-triggered recovery.
  @visibleForTesting
  bool get autoReconnectLoginForTest => _autoReconnectLogin;

  // ── Stream-based error/warning surface (VSDK-415) ──────────────────

  /// Controller for error events. Typed as [Object] because both
  /// [TelnyxErrorEvent] and [TelnyxMediaRecoveryErrorEvent] flow through it,
  /// matching the [OnTelnyxError] callback signature.
  late final StreamController<Object> _errorStreamController;
  late final StreamController<TelnyxWarningEvent> _warningStreamController;
  bool _streamControllersInitialized = false;

  void _initStreamControllers() {
    if (_streamControllersInitialized) return;
    _errorStreamController = StreamController<Object>.broadcast(sync: true);
    _warningStreamController =
        StreamController<TelnyxWarningEvent>.broadcast(sync: true);
    _streamControllersInitialized = true;
  }

  /// Structured error stream. Mirrors JS SDK's `client.on('telnyx.error', ...)`.
  ///
  /// Emits both [TelnyxErrorEvent] (non-recoverable) and
  /// [TelnyxMediaRecoveryErrorEvent] (recoverable) instances, matching the
  /// [onTelnyxError] callback. Use [isMediaRecoveryErrorEvent] to
  /// discriminate, or the [fatalErrors] / [recoverableErrors] convenience
  /// getters.
  Stream<Object> get errors {
    _initStreamControllers();
    return _errorStreamController.stream;
  }

  /// Structured warning stream. Mirrors JS SDK's `client.on('telnyx.warning', ...)`.
  ///
  /// Provides a Dart-idiomatic API that composes with StreamBuilder, Riverpod,
  /// and Bloc. Events are emitted alongside the [onTelnyxWarning] callback.
  Stream<TelnyxWarningEvent> get warnings {
    _initStreamControllers();
    return _warningStreamController.stream;
  }

  /// Convenience: terminal (fatal, non-recoverable) errors only.
  Stream<TelnyxErrorEvent> get fatalErrors => errors
      .where((e) => e is TelnyxErrorEvent && e.error.fatal)
      .cast<TelnyxErrorEvent>();

  /// Convenience: recoverable (media permission recovery) errors only.
  Stream<TelnyxMediaRecoveryErrorEvent> get recoverableErrors => errors
      .where((e) => e is TelnyxMediaRecoveryErrorEvent)
      .cast<TelnyxMediaRecoveryErrorEvent>();

  /// Captures the enable flags and recovery config from [config] at connect.
  void _applyStructuredConfig(Config config) {
    // A fresh connect is not an explicit logout — re-enable marker persistence.
    _explicitDisconnectInProgress = false;
    // Supersede any in-flight explicit-disconnect clear so it cannot erase the
    // recovery data this new session is about to persist (VSDK-418).
    _recoveryEpoch++;
    _enableStructuredErrors = config.enableStructuredErrors;
    _enableSignalingHealthMonitor = config.enableSignalingHealthMonitor;
    _mediaPermissionsRecovery = config.mediaPermissionsRecovery;

    // Apply autoReconnect immediately (?? true) so the health monitor and
    // reconnect logic never read a prior session's stale value before the
    // login message is sent (VSDK-415/416 adversarial hardening).
    _autoReconnectLogin = config.autoReconnect ?? true;

    // Instantiate the health monitor when enabled (idempotent per session).
    if (_enableSignalingHealthMonitor) {
      _healthMonitor ??= SignalingHealthMonitor(_TelnyxHealthSession(this));
      // Create the request-timeout tracker alongside the health monitor.
      // It feeds SignalingHealthMonitor.onRequestTimeout() when critical
      // methods (modify, bye, ping) don't receive a response in time.
      _requestTimeoutTracker = RequestTimeoutTracker(
        onTimeout: (method, requestId, timeoutMs) {
          GlobalLogger().w(
            'Request timeout: $method (id=$requestId) after ${timeoutMs}ms',
          );
          _healthMonitor?.onRequestTimeout(requestId, timeoutMs, method);
          // Also emit a structured error for critical methods.
          if (SignalingHealthMonitor.isCriticalMethod(method)) {
            emitStructuredErrorCode(
              TelnyxErrorCodes.webSocketError,
              message:
                  'Signaling request $method timed out after ${timeoutMs}ms',
              originalError:
                  'request_timeout:$method:$requestId:${timeoutMs}ms',
            );
          }
        },
      );
    } else {
      _healthMonitor?.stop();
      _healthMonitor = null;
      _requestTimeoutTracker?.cancelAll();
      _requestTimeoutTracker = null;
    }

    // Reset health-monitor transient state on every fresh/reconnect config
    // application so no pending/probe state from a prior session survives a
    // reconnect. Stop clears all transient state (probe-in-flight, pending
    // media recovery, last-inbound timestamp), then lifecycle sync restarts it
    // only when an initialized active call exists.
    final monitor = _healthMonitor;
    if (monitor != null) {
      monitor.stop();
      // Cancel any pending request-timeout timers from the prior session so
      // stale responses on a new socket don't fire against a dead tracker.
      _requestTimeoutTracker?.cancelAll();
      _syncHealthMonitorLifecycle();
    }
  }

  /// Test seam: apply the structured-config flags/recovery from [config]
  /// without opening a socket. Mirrors what the connect paths do.
  @visibleForTesting
  void applyStructuredConfigForTest(Config config) =>
      _applyStructuredConfig(config);

  /// Test seam: build a copy of [config] with the region changed to
  /// [Region.auto], preserving every other Config option. Mirrors the
  /// region-fallback path in [_onClose].
  @visibleForTesting
  Config copyConfigWithAutoRegionForTest(Config config) =>
      _copyConfigWithAutoRegion(config);

  /// Central helper: emit a structured [TelnyxErrorEvent] via [onTelnyxError]
  /// and the [errors] stream.
  ///
  /// Respects the [Config.enableStructuredErrors] flag. Never throws — a
  /// failing app callback must not break SDK internals.
  void emitTelnyxError(TelnyxError error, {String? callId}) {
    if (!_enableStructuredErrors) return;
    _initStreamControllers();
    final event =
        TelnyxErrorEvent(error: error, sessionId: sessid, callId: callId);
    // Existing callback
    final cb = onTelnyxError;
    if (cb != null) {
      try {
        cb(event);
      } catch (e) {
        GlobalLogger().e('onTelnyxError callback threw: $e');
      }
    }
    // Stream emission
    _errorStreamController.add(event);
  }

  /// Central helper: emit a recoverable [TelnyxMediaRecoveryErrorEvent] via
  /// [onTelnyxError] and the [errors] stream.
  void emitTelnyxMediaRecoveryError(TelnyxMediaRecoveryErrorEvent event) {
    if (!_enableStructuredErrors) return;
    _initStreamControllers();
    // Existing callback
    final cb = onTelnyxError;
    if (cb != null) {
      try {
        cb(event);
      } catch (e) {
        GlobalLogger().e('onTelnyxError callback threw: $e');
      }
    }
    // Stream emission
    _errorStreamController.add(event);
  }

  /// Central helper: emit a structured [TelnyxWarningEvent] via
  /// [onTelnyxWarning] and the [warnings] stream. Respects the feature flag
  /// and never throws.
  void emitTelnyxWarning(
    TelnyxWarning warning, {
    String? callId,
    String? reason,
    String? source,
  }) {
    if (!_enableStructuredErrors) return;
    _initStreamControllers();
    final event = TelnyxWarningEvent(
      warning: warning,
      reason: reason,
      source: source,
      sessionId: sessid,
      callId: callId,
    );
    // Existing callback
    final cb = onTelnyxWarning;
    if (cb != null) {
      try {
        cb(event);
      } catch (e) {
        GlobalLogger().e('onTelnyxWarning callback threw: $e');
      }
    }
    // Stream emission
    _warningStreamController.add(event);
  }

  /// Convenience: build a structured warning from [code] and emit it.
  void emitWarningCode(
    int code, {
    String? callId,
    String? reason,
    String? source,
  }) {
    if (!_enableStructuredErrors) return;
    emitTelnyxWarning(
      createTelnyxWarning(code),
      callId: callId,
      reason: reason,
      source: source,
    );
  }

  /// Convenience: build a structured error from [code] and emit it.
  void emitStructuredErrorCode(
    int code, {
    Object? originalError,
    String? message,
    bool? fatal,
    String? callId,
  }) {
    emitTelnyxError(
      createTelnyxError(
        code,
        originalError: originalError,
        message: message,
        fatal: fatal,
      ),
      callId: callId,
    );
  }

  /// Maps a legacy [TelnyxSocketError] (from a server `error` message) onto a
  /// structured error code and emits it alongside the legacy callback.
  void _emitStructuredForSocketError(TelnyxSocketError error) {
    if (!_enableStructuredErrors) return;
    final int code;
    switch (error.errorCode) {
      case TelnyxErrorConstants.credentialErrorCode:
        code = TelnyxErrorCodes.invalidCredentials;
        break;
      case TelnyxErrorConstants.tokenErrorCode:
        code = TelnyxErrorCodes.authenticationRequired;
        break;
      case TelnyxErrorConstants.gatewayFailedErrorCode:
      case TelnyxErrorConstants.gatewayTimeoutErrorCode:
        code = TelnyxErrorCodes.gatewayFailed;
        break;
      default:
        // An unrecognized server error is NOT necessarily a login failure —
        // map it to a generic code and carry the raw server context (VSDK-415).
        code = TelnyxErrorCodes.unexpectedError;
    }
    emitStructuredErrorCode(
      code,
      message: error.errorMessage,
      originalError: 'server error ${error.errorCode}: ${error.errorMessage}',
    );
  }

  // ── Signaling-health session hooks (VSDK-416) ───────────────────────
  //
  // TelnyxClient owns a lightweight production adapter
  // ([_TelnyxHealthSession]) that implements [ISignalingHealthSession] and
  // delegates to these methods. An adapter is used instead of `implements`
  // because the interface's `isConnected` getter would collide with the
  // long-standing public `isConnected()` method.

  /// Signaling recovery authority: force a socket reconnect/reattach when
  /// signaling is unhealthy. Never also triggers ICE restart — the monitor
  /// guarantees exactly one recovery path.
  void _healthSocketDisconnect() {
    GlobalLogger().i(
      'SignalingHealthMonitor requested socket reconnect (signaling unhealthy)',
    );
    emitTelnyxWarning(
      createTelnyxWarning(TelnyxWarningCodes.signalingRecoveryRequired),
      reason: 'Signaling unhealthy — reconnecting socket',
      source: 'health_monitor',
    );
    if (_autoReconnectLogin) {
      _reconnectToSocket();
    } else {
      _closeSocketSafely();
    }
  }

  /// Media recovery authority: restart ICE for [callId] when signaling is
  /// healthy but media has degraded.
  TriggerIceRestartResult _healthTriggerIceRestart(String? callId) {
    if (callId == null) {
      return const TriggerIceRestartResult(started: false);
    }
    final call = calls[callId];
    if (call == null) {
      return const TriggerIceRestartResult(started: false);
    }
    emitTelnyxWarning(
      createTelnyxWarning(TelnyxWarningCodes.mediaRecoveryRequired),
      callId: callId,
      reason: 'Signaling healthy, media degraded — restarting ICE',
      source: 'health_monitor',
    );
    final started = call.restartIce();
    if (!started) {
      // ICE restart could not start — the call is likely in a terminal state
      // (peer already closed, no active connection). This is benign, not a
      // failure. Log and return without escalating to socket reconnect.
      // JS mirrors: BaseSession.triggerIceRestart() → started:false → log only.
      // (VSDK-397)
      GlobalLogger().d(
        'ICE restart not started for call $callId — call may be in terminal state',
      );
    }
    return TriggerIceRestartResult(started: started);
  }

  /// Signaling probe authority: send a `telnyx_rtc.ping` on the current socket
  /// so the [SignalingHealthMonitor] can resolve "unknown" signaling health by
  /// provoking a response (VSDK-416). The JSON is the standard, already
  /// supported ping request — only the SDK is now the sender.
  ///
  /// NOTE: The probe is NOT tracked by [_requestTimeoutTracker] because the
  /// health monitor already bounds probe timeout via [_probeTimeout] (5 s).
  /// Adding a second timer would be redundant and can leak in tests.
  void _sendSignalingProbe() {
    try {
      final probeId = const Uuid().v4();
      final probe = <String, dynamic>{
        'jsonrpc': JsonRPCConstant.jsonrpc,
        'id': probeId,
        'method': SocketMethod.ping,
        'params': <String, dynamic>{},
      };
      txSocket.send(jsonEncode(probe));
      // Attach the probe request id to the health monitor so it can release
      // the in-flight probe only when the matching JSON-RPC response arrives
      // (not for any unrelated inbound frame). See
      // [SignalingHealthMonitor.attachProbeRequestId] and
      // [SignalingHealthMonitor.resolveProbe].
      _healthMonitor?.attachProbeRequestId(probeId);
    } catch (e) {
      GlobalLogger().w('Failed to send signaling probe: $e');
    }
  }

  /// Start the health monitor when a call becomes active; stop it when there
  /// are no active calls. Idempotent — safe to call repeatedly.
  void _syncHealthMonitorLifecycle() {
    final monitor = _healthMonitor;
    if (monitor == null) return;
    if (activeCalls().isNotEmpty) {
      monitor.start();
    } else {
      monitor.stop();
    }
  }

  /// Single recovery authority for a peer-connection ICE failure (VSDK-416).
  ///
  /// Called by both the native and web [Peer] implementations so the recovery
  /// behavior is identical across platforms. Emits a structured
  /// `peerConnectionFailed` warning, then takes *exactly one* recovery action:
  ///
  /// - When the signaling-health monitor is enabled it is the sole authority —
  ///   it decides ICE restart (healthy signaling) vs. socket reconnect
  ///   (unhealthy). The peer must NOT also renegotiate directly.
  /// - When the monitor is disabled, the legacy self-heal applies: a direct ICE
  ///   restart, but only when the failure followed a disconnect
  ///   ([afterDisconnect]).
  void handlePeerIceConnectionFailed(
    String callId, {
    required bool afterDisconnect,
  }) {
    emitWarningCode(
      TelnyxWarningCodes.peerConnectionFailed,
      callId: callId,
      reason: 'ICE connection failed',
      source: 'peer_failure',
    );
    final monitor = _healthMonitor;
    if (monitor != null) {
      // The monitor owns recovery — it decides ICE restart vs. socket
      // reconnect. Do NOT also renegotiate directly (would double-restart).
      monitor.onPeerFailure(callId, PeerFailureEvidence.iceFailed);
      return;
    }
    // Legacy self-heal when the monitor is disabled: direct ICE restart, but
    // only when the failure followed a disconnect.
    if (afterDisconnect) {
      calls[callId]?.restartIce();
    }
  }

  /// Single recovery authority for a peer-connection state failure (VSDK-416).
  ///
  /// Emits a structured `peerConnectionFailed` warning and routes the failure
  /// to the health monitor (when enabled). Shared by native and web peers.
  void handlePeerConnectionFailed(String callId) {
    emitWarningCode(
      TelnyxWarningCodes.peerConnectionFailed,
      callId: callId,
      reason: 'Peer connection failed',
      source: 'peer_failure',
    );
    _healthMonitor?.onPeerFailure(callId, PeerFailureEvidence.connectionFailed);
  }

  // ── Reconnect / session persistence (VSDK-418) ──────────────────────

  /// Whether an explicit user disconnect/logout is in progress. When true,
  /// active-call marker persistence is suppressed so an explicit clear is not
  /// immediately re-populated. Internal network recovery does NOT set this.
  bool _explicitDisconnectInProgress = false;

  // ── Token expiry warning (VSDK-397) ─────────────────────────────────

  /// Timer for the TOKEN_EXPIRING_SOON warning. Set after tokenLogin when
  /// the login token is a JWT, fired 120 s before expiry. Mirrors JS
  /// BaseSession._tokenExpiryTimeout.
  Timer? _tokenExpiryTimer;
  static const int _tokenExpiryWarningSeconds = 120;

  /// Monotonic epoch bumped on every connect (in [_applyStructuredConfig]).
  ///
  /// An explicit disconnect captures the current epoch and hands it to
  /// [_clearPersistedRecovery]; if a rapid subsequent connect bumps the epoch
  /// before the (asynchronous) clear runs, the clear is superseded and skipped
  /// so it cannot erase the new session's freshly persisted recovery data
  /// (VSDK-418).
  int _recoveryEpoch = 0;

  /// Test-only awaitable that gates [_clearPersistedRecovery] so a deterministic
  /// test can hold an in-flight clear open while a reconnect persists new data.
  /// Null in production (zero overhead).
  @visibleForTesting
  Future<void>? recoveryClearGate;

  /// The recovery marker read at startup, awaiting reattachment after login.
  StoredActiveCalls? _pendingReattach;

  /// The startup recovery marker awaiting reattachment (inspection/testing).
  StoredActiveCalls? get pendingReattach => _pendingReattach;

  /// Defensively read a fresh persisted reconnect session id for URL injection.
  /// Returns null (leaving the URL unchanged) on any storage failure or when
  /// nothing fresh is stored.
  Future<String?> _resolveReconnectVoiceSdkId() async {
    try {
      return await ReconnectTokenStore.getReconnectSessionId();
    } catch (e) {
      GlobalLogger().w('Failed to read reconnect session id: $e');
      return null;
    }
  }

  /// Persist the server-provided voice_sdk_id, current session id, and a
  /// timestamp after a successful registration/login (VSDK-418).
  Future<void> _persistReconnectSession({String? voiceSdkIdOverride}) async {
    try {
      final serverVoiceSdkId = voiceSdkIdOverride ?? voiceSdkId;
      if (serverVoiceSdkId != null && serverVoiceSdkId.isNotEmpty) {
        await ReconnectTokenStore.setReconnectToken(serverVoiceSdkId);
      }
      await ReconnectTokenStore.setReconnectSessionId(sessid);
    } catch (e) {
      GlobalLogger().w('Failed to persist reconnect session: $e');
    }
  }

  /// Test/inspection seam for [_persistReconnectSession].
  @visibleForTesting
  Future<void> persistReconnectSessionForTest() => _persistReconnectSession();

  /// Build a narrow projection of the current active calls — only the call ID
  /// and custom headers. Never credentials, access tokens, SDP, ICE/TURN data,
  /// media streams, peer objects, or arbitrary call state (VSDK-418 security).
  List<StoredActiveCall> _activeCallProjection() {
    return activeCalls()
        .values
        .where((c) => c.callId != null)
        .map(
          (c) => StoredActiveCall(
            id: c.callId!,
            customHeaders: [Map<String, String>.from(c.customHeaders)],
          ),
        )
        .toList();
  }

  /// Persist (or clear when empty) the active-calls recovery marker (VSDK-418).
  void _persistActiveCallsMarker() {
    if (_explicitDisconnectInProgress) return;
    final projection = _activeCallProjection();
    final currentSessid = sessid;
    unawaited(() async {
      try {
        if (projection.isEmpty) {
          await ReconnectTokenStore.clearActiveCallsRecoveryMarker();
        } else {
          await ReconnectTokenStore.setActiveCallsRecoveryMarker(
            projection,
            currentSessid,
          );
        }
      } catch (e) {
        GlobalLogger().w('Failed to persist active-calls marker: $e');
      }
    }());
  }

  /// Whether the cold-start recovery marker has been auto-loaded for this
  /// client instance. Reset only by constructing a new client.
  bool _startupRecoveryMarkerLoaded = false;

  /// Auto-load the persisted active-calls recovery marker exactly once per
  /// client lifetime (cold start), before the first registration completes.
  ///
  /// This makes [_attemptPendingReattach] reachable after REGED on a real
  /// connect path without the app having to invoke
  /// [readRecoveryMarkerAtStartup] manually (VSDK-418). Subsequent in-session
  /// reconnects are no-ops so the client never reattaches against markers it
  /// persisted itself during the current session.
  Future<void> _ensureStartupRecoveryMarkerLoaded() async {
    if (_startupRecoveryMarkerLoaded) return;
    _startupRecoveryMarkerLoaded = true;
    await readRecoveryMarkerAtStartup();
  }

  /// Read a fresh active-calls recovery marker at startup and stash it for a
  /// reattachment attempt once login completes (VSDK-418).
  Future<StoredActiveCalls?> readRecoveryMarkerAtStartup() async {
    try {
      _pendingReattach =
          await ReconnectTokenStore.getActiveCallsRecoveryMarker();
      return _pendingReattach;
    } catch (e) {
      GlobalLogger().w('Failed to read recovery marker at startup: $e');
      return null;
    }
  }

  /// Attempt reattachment for a pending startup marker after login.
  ///
  /// The Flutter SDK reattaches through the existing `attach_call` login flow
  /// (see [SocketMethod.attach]); there is no bespoke Verto reattach RPC. This
  /// method therefore correlates the persisted call IDs against the calls the
  /// backend re-established for the current session: matched calls get their
  /// [Call.recoveredCallId] set; unmatched calls surface a structured
  /// `SESSION_NOT_REATTACHED` (48501) error. The stale marker is always cleared.
  Future<void> _attemptPendingReattach() async {
    final marker = _pendingReattach;
    if (marker == null) return;
    _pendingReattach = null;

    for (final stored in marker.calls) {
      final reestablished = calls[stored.id];
      if (reestablished != null) {
        reestablished.recoveredCallId = stored.id;
      } else {
        emitStructuredErrorCode(
          TelnyxErrorCodes.sessionNotReattached,
          message:
              'Session/call ${stored.id} was not reattached by the backend',
          callId: stored.id,
        );
      }
    }

    try {
      await ReconnectTokenStore.clearActiveCallsRecoveryMarker();
    } catch (e) {
      GlobalLogger().w('Failed to clear stale recovery marker: $e');
    }
  }

  /// Test/inspection seam for [_attemptPendingReattach].
  @visibleForTesting
  Future<void> attemptPendingReattachForTest() => _attemptPendingReattach();

  /// Clear all persisted recovery data. Called on explicit user
  /// disconnect/logout only — never from internal network recovery.
  Future<void> _clearPersistedRecovery(int epoch) async {
    try {
      // Test-only delay hook (null in production).
      final gate = recoveryClearGate;
      if (gate != null) await gate;
      // Superseded by a newer connect → skip so we don't erase its fresh data.
      if (epoch != _recoveryEpoch) return;
      await ReconnectTokenStore.clearAll();
    } catch (e) {
      GlobalLogger().w('Failed to clear persisted recovery data: $e');
    }
  }

  // For instances where the SDP is not contained within ANSWER, but received early via a MEDIA message
  bool _earlySDP = false;

  /// Build the host address with region support
  String _buildHostAddress(Config config, {String? voiceSdkId}) {
    // Use the configured server URL instead of hardcoded default
    String baseHost = _serverConfiguration.socketUrl;

    // If region is not AUTO, prepend the region to the host
    if (config.region != Region.auto) {
      // Extract the base host from the WebSocket URL
      final uri = Uri.parse(_serverConfiguration.socketUrl);
      final hostWithoutProtocol = uri.host;
      final regionHost = '${config.region.value}.$hostWithoutProtocol';

      // Rebuild the WebSocket URL with the region
      baseHost = '${uri.scheme}://$regionHost:${uri.port}';

      GlobalLogger().i('Using region-specific host: $baseHost');
    }

    // Add voice SDK ID if provided
    if (voiceSdkId != null) {
      final uri = Uri.parse(baseHost);
      final newUri = uri.replace(queryParameters: {'voice_sdk_id': voiceSdkId});
      baseHost = newUri.toString();
    }

    return baseHost;
  }

  CredentialConfig? _storedCredentialConfig;

  TokenConfig? _storedTokenConfig;

  // Track current config for region fallback
  Config? _currentConfig;
  bool _isRegionFallbackAttempt = false;

  /// The stored [CredentialConfig] for the client - if no stored credential is present, this will be null
  CredentialConfig? get storedCredential => _storedCredentialConfig;

  /// The stored [TokenConfig] for the client - if no stored token is present, this will be null
  TokenConfig? get storedToken => _storedTokenConfig;

  /// The current widget settings from AI conversation
  WidgetSettings? get currentWidgetSettings => _currentWidgetSettings;

  /// Returns the forceRelayCandidate setting from the current config
  bool getForceRelayCandidate() {
    final config = _storedCredentialConfig ?? _storedTokenConfig;
    return config?.forceRelayCandidate ?? false;
  }

  /// The current server configuration for TURN/STUN servers.
  /// Defaults to production servers.
  TxServerConfiguration _serverConfiguration =
      TxServerConfiguration.production();

  /// Gets the current server configuration.
  TxServerConfiguration get serverConfiguration => _serverConfiguration;

  /// Sets the server configuration for TURN/STUN servers.
  ///
  /// This should be called before connecting to the socket.
  /// Use [TxServerConfiguration.production()] for production servers
  /// or [TxServerConfiguration.development()] for development servers.
  ///
  /// Example:
  /// ```dart
  /// telnyxClient.setServerConfiguration(TxServerConfiguration.development());
  /// ```
  void setServerConfiguration(TxServerConfiguration configuration) {
    _serverConfiguration = configuration;
    GlobalLogger().i(
      'TelnyxClient :: Server configuration updated: ${configuration.socketUrl}',
    );
  }

  /// Gets the effective ICE servers for WebRTC peer connections.
  ///
  /// Priority order:
  /// 1. Custom ICE servers from Config (iceServers property)
  /// 2. ICE servers from serverConfiguration (webRTCIceServers property)
  /// 3. Default ICE servers from serverConfiguration
  List<TxIceServer> _getEffectiveIceServers() {
    final config = _storedCredentialConfig ?? _storedTokenConfig;

    // First priority: custom ICE servers from Config
    final configIceServers = config?.iceServers;
    if (configIceServers != null && configIceServers.isNotEmpty) {
      final valid = configIceServers.where((s) => s.urls.isNotEmpty).toList();
      if (valid.isNotEmpty) {
        GlobalLogger().i(
          'TelnyxClient :: Using custom ICE servers from Config (${valid.length} servers)',
        );
        return valid;
      }
      GlobalLogger().w(
        'TelnyxClient :: Custom ICE servers from Config all have empty URLs, falling back',
      );
    }

    // Second priority: ICE servers from serverConfiguration in Config
    final serverConfig = config?.serverConfiguration;
    if (serverConfig != null) {
      final valid = serverConfig.webRTCIceServers
          .where((s) => s.urls.isNotEmpty)
          .toList();
      if (valid.isNotEmpty) {
        GlobalLogger().i(
          'TelnyxClient :: Using ICE servers from serverConfiguration (${valid.length} servers)',
        );
        return valid;
      }
      GlobalLogger().w(
        'TelnyxClient :: serverConfiguration ICE servers all have empty URLs, falling back to defaults',
      );
    }

    // Third priority: ICE servers from _serverConfiguration (client-level default)
    GlobalLogger().i(
      'TelnyxClient :: Using ICE servers from default serverConfiguration (${_serverConfiguration.webRTCIceServers.length} servers)',
    );
    return _serverConfiguration.webRTCIceServers;
  }

  /// Returns whether or not the client is connected to the socket connection
  bool isConnected() {
    return _connected;
  }

  /// Returns the current connection status
  ConnectionStatus getConnectionStatus() {
    return _connectionStatus;
  }

  /// Returns whether or not debug is enabled for the client
  bool isDebug() {
    return _debug;
  }

  /// Returns whether autoReconnect is enabled for the client
  /// When enabled, the client will automatically attempt to reconnect
  /// when the socket connection fails or network connectivity is restored
  bool isAutoReconnectEnabled() {
    return _autoReconnectLogin;
  }

  /// Returns the current connection retry counter
  /// This shows how many reconnection attempts have been made
  int getConnectionRetryCount() {
    return _connectRetryCounter;
  }

  /// Returns the current Gateway state for the socket connection
  String getGatewayStatus() {
    return gatewayState;
  }

  bool get _isTornDown => _closed || _disposed;

  bool _isActiveConnectionGeneration(int generation) {
    return !_isTornDown && generation == _connectionGeneration;
  }

  void _invalidateConnectionGeneration() {
    _connectionGeneration++;
    _cancelDelayedConnectionTimers();
    _isAttaching = false;
  }

  Timer _scheduleConnectionTimer(
    Duration duration,
    void Function() callback, {
    int? generation,
  }) {
    final timerGeneration = generation ?? _connectionGeneration;
    late final Timer timer;
    timer = Timer(duration, () {
      _delayedConnectionTimers.remove(timer);
      if (!_isActiveConnectionGeneration(timerGeneration)) {
        return;
      }

      callback();
    });
    _delayedConnectionTimers.add(timer);
    return timer;
  }

  void _cancelDelayedConnectionTimers() {
    for (final timer in _delayedConnectionTimers) {
      timer.cancel();
    }
    _delayedConnectionTimers.clear();
  }

  bool _prepareForConnection() {
    if (_disposed) {
      GlobalLogger().w('TelnyxClient is disposed and cannot reconnect');
      return false;
    }
    _invalidateConnectionGeneration();
    _invalidateGatewayResponseTimer();
    _closed = false;
    _checkReconnection();
    return true;
  }

  void _checkReconnection() {
    if (_disposed || _connectivitySubscription != null) return;

    _connectivitySubscription = _connectivityChanges().listen((
      List<ConnectivityResult> connectivityResult,
    ) {
      if (_isTornDown) return;

      GlobalLogger().i(
        'Connectivity changed: ${connectivityResult.join(", ")}',
      );

      // On the first emission, just store the initial state and do nothing.
      // This prevents treating the initial status report as a connectivity change.
      if (_previousConnectivityResult == null) {
        _previousConnectivityResult = connectivityResult;
        return;
      }

      // Use sets for comparison as the order of results is not guaranteed.
      final currentSet = Set.of(connectivityResult);
      final previousSet = Set.of(_previousConnectivityResult!);

      // If the connectivity state hasn't changed, there's nothing to do.
      if (setEquals(currentSet, previousSet)) {
        GlobalLogger().i('Connectivity state is the same as before, ignoring.');
        return;
      }

      // Update the state for the next change detection.
      _previousConnectivityResult = connectivityResult;

      if (_isAttaching) return;

      if (connectivityResult.contains(ConnectivityResult.none)) {
        GlobalLogger().i('No available network types');
        _handleNetworkLost();
        return;
      }

      if (connectivityResult.contains(ConnectivityResult.mobile) ||
          connectivityResult.contains(ConnectivityResult.wifi)) {
        GlobalLogger().i('Network available: ${connectivityResult.join(", ")}');
        if (!_isAttaching) {
          _handleNetworkReconnection(NetworkReason.networkSwitch);
        }
      }
    });
  }

  void _cancelConnectivitySubscription() {
    final subscription = _connectivitySubscription;
    if (subscription == null) return;

    unawaited(subscription.cancel());
    _connectivitySubscription = null;
    _previousConnectivityResult = null;
  }

  void _closeSocketSafely() {
    try {
      txSocket.close();
    } catch (error) {
      GlobalLogger().e('close() | error closing the WebSocket: $error');
    }
  }

  /// Set the custom logger for the SDK
  void setCustomLogger(CustomLogger logger) {
    _logger = logger;
    GlobalLogger.logger = logger;
  }

  /// Set or adjust the log level for the SDK
  void setLogLevel(LogLevel level) {
    _logger.setLogLevel(level);
  }

  /// Get the custom logger for the SDK
  CustomLogger get logger => _logger;

  /// Gets the current conversation transcript
  List<TranscriptItem> get transcript => List.unmodifiable(_transcript);

  /// Clears the conversation transcript
  void clearTranscript() {
    _transcript.clear();
    _assistantResponseBuffers.clear();
    onTranscriptUpdate?.call(_transcript);
  }

  /// Returns a list of audio codecs supported by WebRTC for this device.
  ///
  /// This method queries the native WebRTC RTP sender capabilities API to retrieve
  /// the actual audio codecs supported by the WebRTC library. This lightweight query
  /// uses the platform's built-in codec discovery without creating any peer connections.
  /// The returned codec list matches exactly what WebRTC will use during actual calls.
  ///
  /// **Common codecs** returned include: Opus, PCMU, PCMA, G722, RED, CN, and telephone-event.
  ///
  /// **Usage**:
  /// - Call this method **before** initiating a call to get the list of supported WebRTC codecs
  /// - Use the returned list to construct your preferred codec order
  /// - Pass your preferences to [newInvite] or [acceptCall] via the `preferredCodecs` parameter
  ///
  /// Returns a [Future<List<AudioCodec>>] containing the audio codecs supported by the device.
  /// Returns an empty list if codec detection fails.
  ///
  /// Example:
  /// ```dart
  /// // Query supported codecs before making a call
  /// final supportedCodecs = await telnyxClient.getSupportedAudioCodecs();
  /// print('WebRTC supports: ${supportedCodecs.map((c) => c.mimeType)}');
  ///
  /// // Prefer Opus, then PCMU as fallback
  /// final preferredCodecs = supportedCodecs.where(
  ///   (c) => c.mimeType == 'audio/opus' || c.mimeType == 'audio/PCMU'
  /// ).toList();
  ///
  /// // Use in call
  /// final call = telnyxClient.newInvite(
  ///   'John',
  ///   '+1234567890',
  ///   'sip:destination',
  ///   'state',
  ///   preferredCodecs: preferredCodecs,
  /// );
  /// ```
  Future<List<AudioCodec>> getSupportedAudioCodecs() async {
    try {
      GlobalLogger().d('Querying WebRTC audio codecs via RTP capabilities');
      // Convert to AudioCodec list
      final codecs = await CodecUtils.getSupportedAudioCodecs();

      GlobalLogger().d(
        'Retrieved ${codecs.length} audio codecs: ${codecs.map((c) => c.mimeType).toList()}',
      );

      return codecs;
    } catch (e) {
      GlobalLogger().e('Error retrieving supported audio codecs: $e');
      return [];
    }
  }

  /// Helper method to update connection state and notify listener
  void _updateConnectionState(bool connected) {
    if (_connected != connected) {
      _connected = connected;
      _updateConnectionStatus();
    }
  }

  /// Updates the connection status based on current connection and registration states
  void _updateConnectionStatus() {
    ConnectionStatus newStatus;

    if (!_connected) {
      newStatus = ConnectionStatus.disconnected;
    } else if (_connected && !_registered) {
      newStatus = ConnectionStatus.connected;
    } else {
      newStatus = ConnectionStatus.clientReady;
    }

    if (_connectionStatus != newStatus) {
      _connectionStatus = newStatus;
      onConnectionStateChanged?.call(_connectionStatus);
    }
  }

  void _handleNetworkLost() {
    _updateConnectionState(false);
    for (var call in activeCalls().values) {
      call.callHandler.changeState(
        CallState.dropped.withNetworkReason(NetworkReason.networkLost),
      );
      // Start a reconnection timeout timer for this call
      _startReconnectionTimer(call);
    }
  }

  void _handleNetworkReconnection(NetworkReason reason) {
    // Check if autoReconnect is enabled before attempting network reconnection
    if (!_autoReconnectLogin) {
      GlobalLogger().i(
        'AutoReconnect is disabled, not attempting network reconnection',
      );
      for (var call in activeCalls().values) {
        call.callHandler.changeState(
          CallState.dropped.withNetworkReason(NetworkReason.networkLost),
        );
        call.endCall();
      }
      return;
    }

    GlobalLogger().i(
      'Handling network reconnection (reason: $reason, autoReconnect: $_autoReconnectLogin)',
    );
    _reconnectToSocket();

    for (var call in activeCalls().values) {
      if (call.callState.isDropped) {
        call.callHandler.changeState(
          CallState.reconnecting.withNetworkReason(reason),
        );

        // Start a reconnection timeout timer for this call
        _startReconnectionTimer(call);
      }
    }
  }

  /// Starts a reconnection timer for a call
  /// If the call is still in RECONNECTING state after the timeout,
  /// it will be marked as DROPPED
  void _startReconnectionTimer(Call call) {
    // Cancel any existing timer for this call
    _cancelReconnectionTimer(call.callId);

    GlobalLogger().i('Starting reconnection timer for call ${call.callId}');
    final connectionGeneration = _connectionGeneration;

    // Create a new timer
    _reconnectionTimers[call.callId] = Timer(
      Duration(
        milliseconds: _storedCredentialConfig?.reconnectionTimeout ??
            _storedTokenConfig?.reconnectionTimeout ??
            Constants.reconnectionTimeout,
      ),
      () {
        if (!_isActiveConnectionGeneration(connectionGeneration)) return;

        // Check if the call is still in the reconnecting state
        if (calls.containsKey(call.callId)) {
          GlobalLogger().i('Reconnection timeout for call ${call.callId}');

          // Change the call state to dropped
          call.callHandler.changeState(
            CallState.dropped.withNetworkReason(NetworkReason.networkLost),
          );

          // End the call
          call.endCall();
        }
        // Remove the timer from the map
        _reconnectionTimers.remove(call.callId);
      },
    );
  }

  /// Cancels the reconnection timer for a call
  void _cancelReconnectionTimer(String? callId) {
    if (callId != null && _reconnectionTimers.containsKey(callId)) {
      _reconnectionTimers[callId]?.cancel();
      _reconnectionTimers.remove(callId);
      GlobalLogger().i('Cancelled reconnection timer for call $callId');
    }
  }

  void _cancelReconnectionTimers() {
    for (final timer in _reconnectionTimers.values) {
      timer.cancel();
    }
    _reconnectionTimers.clear();
  }

  /// Starts the timeout timer for pending answer from push notification
  void _startPendingAnswerTimeout() {
    // Cancel any existing timeout
    _cancelPendingAnswerTimeout();

    GlobalLogger().i(
      'Starting pending answer timeout (${_pushAnswerTimeoutDuration.inSeconds}s)',
    );

    _pendingAnswerTimeout = Timer(_pushAnswerTimeoutDuration, () {
      if (_isTornDown) return;

      _handlePendingAnswerTimeout();
    });
  }

  /// Cancels the pending answer timeout timer
  void _cancelPendingAnswerTimeout() {
    if (_pendingAnswerTimeout != null) {
      _pendingAnswerTimeout?.cancel();
      _pendingAnswerTimeout = null;
      GlobalLogger().i('Cancelled pending answer timeout');
    }
  }

  void _disposeLatencyTracker() {
    if (_latencyTrackerDisposed) return;

    latencyTracker.dispose();
    _latencyTrackerDisposed = true;
  }

  /// Processes and queues the ICE candidate for the specified call.
  ///
  /// [callId] The ID of the call this candidate belongs to
  /// [sdpMid] The SDP media identifier
  /// [sdpMLineIndex] The SDP media line index
  /// [candidateString] The normalized candidate string
  void _processAndQueueCandidate(
    String callId,
    String sdpMid,
    int sdpMLineIndex,
    String candidateString,
  ) {
    final call = calls[callId];
    if (call != null) {
      // Create pending ICE candidate and queue it instead of immediately adding
      // Note: We don't enhance the candidate string here because remoteIceParameters
      // won't be available until after the remote description is set in onAnswerReceived
      final pendingCandidate = PendingIceCandidate(
        callId: callId,
        sdpMid: sdpMid,
        sdpMLineIndex: sdpMLineIndex,
        candidateString: candidateString,
        enhancedCandidateString:
            candidateString, // Store original for now, will enhance later
      );

      // Add to pending candidates map
      final candidates = pendingIceCandidates.putIfAbsent(callId, () => [])
        ..add(pendingCandidate);
      GlobalLogger().i(
        'Queued ICE candidate for call $callId. Total queued: ${candidates.length}',
      );
    } else {
      GlobalLogger().w('No call found for ID: $callId');
    }
  }

  /// Processes any queued ICE candidates after remote description is set.
  ///
  /// [callId] The ID of the call whose candidates should be processed
  void _processQueuedIceCandidates(String callId) {
    final call = calls[callId];
    if (call == null) {
      GlobalLogger().w(
        'No call found for ID: $callId when processing queued candidates',
      );
      return;
    }

    final candidates = pendingIceCandidates[callId];
    if (candidates == null || candidates.isEmpty) {
      GlobalLogger().i('No queued ICE candidates to process for call $callId');
      return;
    }

    GlobalLogger().i(
      'Processing ${candidates.length} queued ICE candidates for call $callId',
    );

    // Process each queued candidate
    for (final candidate in candidates) {
      try {
        if (call.peerConnection != null) {
          call.peerConnection!.handleRemoteCandidate(
            candidate.callId,
            candidate.enhancedCandidateString,
            candidate.sdpMid,
            candidate.sdpMLineIndex,
          );
          GlobalLogger().i(
            'Successfully processed queued candidate for call $callId',
          );
        } else {
          GlobalLogger().w(
            'Peer connection is null for call $callId, cannot process candidate',
          );
        }
      } catch (e) {
        GlobalLogger().e(
          'Error processing queued candidate for call $callId: ${e.toString()}',
        );
      }
    }

    // Clear the processed candidates
    pendingIceCandidates.remove(callId);
    GlobalLogger().i('Cleared processed candidates for call $callId');
  }

  /// Handles the timeout when no INVITE is received after accepting from push
  void _handlePendingAnswerTimeout() {
    if (_isTornDown) return;

    GlobalLogger().i(
      'Pending answer timeout expired - no INVITE received within ${_pushAnswerTimeoutDuration.inSeconds} seconds',
    );

    // Reset the pending answer flag
    _pendingAnswerFromPush = false;

    // Create termination reason for originator cancel
    final terminationReason = CallTerminationReason(
      cause: 'ORIGINATOR_CANCEL',
      causeCode: 487,
      sipCode: 487,
      sipReason: 'Request Terminated',
    );

    // Use call ID from push metadata, or generate a timeout-specific ID
    final callId = _pushMetaData?.callId ?? 'timeout-${const Uuid().v4()}';

    final byeMessage = ReceiveByeMessage(
      jsonrpc: JsonRPCConstant.jsonrpc,
      id: 0,
      method: SocketMethod.bye,
      params: ReceiveByeParams(
        callID: callId,
        sipCallId: callId,
        sipCode: terminationReason.sipCode,
        causeCode: terminationReason.causeCode,
        cause: terminationReason.cause,
        sipReason: terminationReason.sipReason,
      ),
    );

    final byeMessageJson = jsonEncode(byeMessage.toJson());
    GlobalLogger().i(
      'Sending BYE message due to pending answer timeout: $byeMessageJson',
    );

    final receivedMessage = ReceivedMessage(
      jsonrpc: JsonRPCConstant.jsonrpc,
      id: byeMessage.id,
      method: byeMessage.method,
      byeParams: byeMessage.params,
    );

    // Send the BYE message through the normal message flow
    final message = TelnyxMessage(
      socketMethod: SocketMethod.bye,
      message: receivedMessage,
    );
    onSocketMessageReceived.call(message);

    // Clear the timeout timer reference
    _pendingAnswerTimeout = null;

    GlobalLogger().i(
      'Pending answer timeout handled - call terminated with ORIGINATOR_CANCEL',
    );
  }

  /// Handles an incoming push notification to initiate a call flow.
  ///
  /// This method connects the client and logs in using the provided configuration,
  /// preparing it to receive an incoming call invitation. It should be called when
  /// your application receives a push notification from Telnyx.
  ///
  /// **Note:** Do not call [connectWithCredential] or [connectWithToken] separately
  /// if you are using this method, as it handles the connection process internally.
  ///
  /// - [pushMetaData]: The metadata received from the push notification.
  /// - [credentialConfig]: The credential configuration for login (if using credentials).
  /// - [tokenConfig]: The token configuration for login (if using a token).
  void handlePushNotification(
    PushMetaData pushMetaData,
    CredentialConfig? credentialConfig,
    TokenConfig? tokenConfig,
  ) {
    GlobalLogger().i(
      'TelnyxClient.handlePushNotification: Called. PushMetaData: ${jsonEncode(pushMetaData.toJson())}',
    );

    if (pushMetaData.isDecline == true) {
      GlobalLogger().i(
        'TelnyxClient.handlePushNotification: Decline case - using simplified decline logic with decline_push parameter',
      );
      // For decline, we use a simplified approach: connect, login with decline_push=true, then disconnect
      _connectWithCallBack(pushMetaData, () {
        if (credentialConfig != null) {
          _credentialLoginWithDecline(credentialConfig);
        } else if (tokenConfig != null) {
          _tokenLoginWithDecline(tokenConfig);
        }
      });
      return;
    }

    // For accept and normal cases, use the existing logic
    _isCallFromPush = true;
    if (pushMetaData.isAnswer == true) {
      GlobalLogger().i(
        'TelnyxClient.handlePushNotification: _pendingAnswerFromPush will be set to true',
      );
      _pendingAnswerFromPush = true;
      // Store the device token for use when auto-answering
      // This allows the backend to dismiss the call on other devices
      _answeredDeviceToken =
          credentialConfig?.notificationToken ?? tokenConfig?.notificationToken;
      GlobalLogger().i(
        'TelnyxClient.handlePushNotification: Stored answeredDeviceToken: ${_answeredDeviceToken != null ? "[present]" : "null"}',
      );
      // Start the timeout timer for pending answer
      _startPendingAnswerTimeout();
    } else {
      GlobalLogger().i(
        'TelnyxClient.handlePushNotification: _pendingAnswerFromPush remains false',
      );
    }

    _connectWithCallBack(pushMetaData, () {
      if (credentialConfig != null) {
        credentialLogin(credentialConfig);
      } else if (tokenConfig != null) {
        tokenLogin(tokenConfig);
      }
    });
  }

  /// Internal method for credential login with decline_push parameter
  void _credentialLoginWithDecline(CredentialConfig config) {
    GlobalLogger().i(
      'TelnyxClient._credentialLoginWithDecline: Sending login with decline_push=true',
    );
    final uuid = const Uuid().v4();
    final user = config.sipUser;
    final password = config.sipPassword;
    final notificationToken = config.notificationToken;
    UserVariables? notificationParams;

    notificationParams = UserVariables(
      pushDeviceToken: notificationToken,
      pushNotificationProvider:
          defaultTargetPlatform == TargetPlatform.android ? 'android' : 'ios',
    );

    final loginParams = LoginParams(
      login: user,
      passwd: password,
      loginParams: {'decline_push': 'true'},
      sessionId: sessid,
      userVariables: notificationParams,
      userAgent: VersionUtils.getUserAgent(),
    );
    final loginMessage = LoginMessage(
      id: uuid,
      method: SocketMethod.login,
      params: loginParams,
      jsonrpc: JsonRPCConstant.jsonrpc,
    );

    final String jsonLoginMessage = jsonEncode(loginMessage);
    txSocket.send(jsonLoginMessage);

    // Disconnect after sending the decline login message
    _scheduleConnectionTimer(const Duration(milliseconds: 1000), () {
      GlobalLogger().i(
        'TelnyxClient._credentialLoginWithDecline: Disconnecting after decline login',
      );
      disconnect();
    });
  }

  /// Internal method for token login with decline_push parameter
  void _tokenLoginWithDecline(TokenConfig config) {
    GlobalLogger().i(
      'TelnyxClient._tokenLoginWithDecline: Sending login with decline_push=true',
    );
    final uuid = const Uuid().v4();
    final token = config.sipToken;
    final notificationToken = config.notificationToken;
    UserVariables? notificationParams;

    notificationParams = UserVariables(
      pushDeviceToken: notificationToken,
      pushNotificationProvider:
          defaultTargetPlatform == TargetPlatform.android ? 'android' : 'ios',
    );

    final loginParams = LoginParams(
      loginToken: token,
      loginParams: {'decline_push': 'true'},
      userVariables: notificationParams,
      sessionId: sessid,
      userAgent: VersionUtils.getUserAgent(),
    );
    final loginMessage = LoginMessage(
      id: uuid,
      method: SocketMethod.login,
      params: loginParams,
      jsonrpc: JsonRPCConstant.jsonrpc,
    );

    final String jsonLoginMessage = jsonEncode(loginMessage);
    txSocket.send(jsonLoginMessage);

    // Disconnect after sending the decline login message
    _scheduleConnectionTimer(const Duration(milliseconds: 1000), () {
      GlobalLogger().i(
        'TelnyxClient._tokenLoginWithDecline: Disconnecting after decline login',
      );
      disconnect();
    });
  }

  /// Sets the push metadata for the client and saves it to the shared preferences
  /// The [isAnswer] flag is used to determine if the push notification indicates that we should answer the pending invite
  /// The [isDecline] flag is used to determine if the push notification indicates that we should decline the pending invite
  static void setPushMetaData(
    Map<String, dynamic> pushMetaData, {
    bool isAnswer = false,
    bool isDecline = false,
  }) {
    final Map<String, dynamic> metaData = jsonDecode(pushMetaData['metadata']);
    metaData['isAnswer'] = isAnswer;
    metaData['isDecline'] = isDecline;
    PreferencesStorage.saveMetadata(jsonEncode(metaData));
  }

  /// Gets the push metadata for the client
  static Future<Map<String, dynamic>?> getPushData() async {
    return await PreferencesStorage.getMetaData();
  }

  /// Clears the push metadata for the client
  static void clearPushMetaData() {
    PreferencesStorage.saveMetadata('');
  }

  /// Create a socket connection for
  /// communication with the Telnyx backend
  void _connectWithCallBack(
    PushMetaData? pushMetaData,
    OnOpenCallback openCallback,
  ) {
    if (!_prepareForConnection()) return;
    final connectionGeneration = _connectionGeneration;

    GlobalLogger().i(
      'TelnyxClient._connectWithCallBack: Called. PushMetaData: ${pushMetaData?.toJson()}',
    );
    if (pushMetaData != null) {
      _pushMetaData = pushMetaData;
    }
    try {
      if (pushMetaData?.voiceSdkId != null) {
        txSocket.hostAddress =
            '${_serverConfiguration.socketUrl}?voice_sdk_id=${pushMetaData?.voiceSdkId}';
        GlobalLogger().i(
          'Connecting to WebSocket with voice_sdk_id :: ${pushMetaData?.voiceSdkId}',
        );
      } else {
        txSocket.hostAddress = _serverConfiguration.socketUrl;
        GlobalLogger().i(
          'TelnyxClient._connectWithCallBack: connecting to WebSocket $_serverConfiguration.socketUrl',
        );
      }
      txSocket
        ..onOpen = () {
          if (!_isActiveConnectionGeneration(connectionGeneration)) {
            return;
          }
          _closed = false;
          _updateConnectionState(true);
          GlobalLogger().i(
            'TelnyxClient._connectWithCallBack (via _onOpen): Web Socket is now connected',
          );
          _onOpen();
          openCallback.call();
        }
        ..onMessage = (dynamic data) {
          if (!_isActiveConnectionGeneration(connectionGeneration)) return;
          _onMessage(data);
        }
        ..onClose = (int closeCode, String closeReason) {
          if (!_isActiveConnectionGeneration(connectionGeneration)) return;
          GlobalLogger().i('Closed [$closeCode, $closeReason]!');
          _updateConnectionState(false);
          final wasClean = WebSocketUtils.isCleanClose(closeCode, closeReason);
          _onClose(wasClean, closeCode, closeReason);
        }
        ..onPing = (SocketConnectionMetrics metrics) {
          if (!_isActiveConnectionGeneration(connectionGeneration)) return;
          onConnectionMetricsUpdate?.call(metrics);
        }
        ..connect();
    } catch (e, string) {
      GlobalLogger().e('${e.toString()} :: $string');
      _updateConnectionState(false);
      GlobalLogger().e('WebSocket $_serverConfiguration.socketUrl error: $e');
    }
  }

  /// Wires the [txSocket] callbacks for the given [connectionGeneration] and
  /// opens the connection to [hostAddress]. Shared by the token and credential
  /// connect paths. [onOpenLogin] performs the appropriate login once open;
  /// [updateStateOnClose] preserves the historical per-path close behavior.
  void _wireSocketAndConnect({
    required int connectionGeneration,
    required String hostAddress,
    required void Function() onOpenLogin,
    required String onOpenLogTag,
    required bool updateStateOnClose,
  }) {
    txSocket.hostAddress = hostAddress;
    _socketHost = hostAddress; // Store for call report endpoint
    GlobalLogger().i('connecting to WebSocket $hostAddress');
    txSocket
      ..onOpen = () {
        if (!_isActiveConnectionGeneration(connectionGeneration)) {
          return;
        }
        _closed = false;
        _updateConnectionState(true);
        _isRegionFallbackAttempt =
            false; // Reset fallback flag on successful connection
        GlobalLogger().i('$onOpenLogTag (via _onOpen): Web Socket is now '
            'connected');
        latencyTracker.markRegistrationMilestone(
          LatencyTracker.milestoneSocketConnected,
        );
        _onOpen();
        onOpenLogin();
      }
      ..onMessage = (dynamic data) {
        if (!_isActiveConnectionGeneration(connectionGeneration)) return;
        _onMessage(data);
      }
      ..onClose = (int closeCode, String closeReason) {
        if (!_isActiveConnectionGeneration(connectionGeneration)) return;
        GlobalLogger().i('Closed [$closeCode, $closeReason]!');
        if (updateStateOnClose) {
          _updateConnectionState(false);
        }
        final wasClean = WebSocketUtils.isCleanClose(closeCode, closeReason);
        _onClose(wasClean, closeCode, closeReason);
      }
      ..onPing = (SocketConnectionMetrics metrics) {
        if (!_isActiveConnectionGeneration(connectionGeneration)) return;
        onConnectionMetricsUpdate?.call(metrics);
      }
      ..connect();
  }

  /// Connects to the WebSocket using the provided [tokenConfig]
  void connectWithToken(TokenConfig tokenConfig) {
    if (!_prepareForConnection()) return;
    final connectionGeneration = _connectionGeneration;

    // Store current config for potential fallback
    _currentConfig = tokenConfig;
    _applyStructuredConfig(tokenConfig);
    // Auto-load the cold-start recovery marker so reattach can fire after REGED
    // without the app calling readRecoveryMarkerAtStartup manually (VSDK-418).
    unawaited(_ensureStartupRecoveryMarkerLoaded());

    // Start registration latency tracking
    latencyTracker.startRegistrationTracking();

    // First check if there is a custom logger set within the config - if so, we set it here
    _logger = tokenConfig.customLogger ?? DefaultLogger();
    GlobalLogger.logger = _logger;
    GlobalLogger().i('TelnyxClient.connectWithToken: Attempting to connect.');

    // Now that a logger is set, we can set the log level
    _logger
      ..setLogLevel(tokenConfig.logLevel)
      ..log(LogLevel.info, 'connect()')
      ..log(
        LogLevel.info,
        'connecting to WebSocket $_serverConfiguration.socketUrl',
      );
    // Defensively read a fresh persisted reconnect session id (VSDK-418) and
    // inject it as voice_sdk_id before the initial connection. Push metadata
    // takes precedence; a missing/failed read leaves the URL unchanged.
    unawaited(() async {
      final resolvedVoiceSdkId =
          _pushMetaData?.voiceSdkId ?? await _resolveReconnectVoiceSdkId();
      if (!_isActiveConnectionGeneration(connectionGeneration)) return;
      try {
        final hostAddress = _buildHostAddress(
          tokenConfig,
          voiceSdkId: resolvedVoiceSdkId,
        );
        _wireSocketAndConnect(
          connectionGeneration: connectionGeneration,
          hostAddress: hostAddress,
          onOpenLogin: () => tokenLogin(tokenConfig),
          onOpenLogTag: 'TelnyxClient.connectWithToken',
          updateStateOnClose: true,
        );
      } catch (e) {
        GlobalLogger().e(e.toString());
        _updateConnectionState(false);
        GlobalLogger().e('WebSocket $_serverConfiguration.socketUrl error: $e');
        // Structured WebSocket connect failure (VSDK-415).
        emitStructuredErrorCode(
          TelnyxErrorCodes.webSocketConnectionFailed,
          originalError: e,
        );
      }
    }());
  }

  /// Connects to the WebSocket using the provided [CredentialConfig]
  void connectWithCredential(CredentialConfig credentialConfig) {
    if (!_prepareForConnection()) return;
    final connectionGeneration = _connectionGeneration;

    // Store current config for potential fallback
    _currentConfig = credentialConfig;
    _applyStructuredConfig(credentialConfig);
    // Auto-load the cold-start recovery marker so reattach can fire after REGED
    // without the app calling readRecoveryMarkerAtStartup manually (VSDK-418).
    unawaited(_ensureStartupRecoveryMarkerLoaded());

    // Start registration latency tracking
    latencyTracker.startRegistrationTracking();

    // First check if there is a custom logger set within the config - if so, we set it here
    // Use custom logger if provided or fallback to default.
    _logger = credentialConfig.customLogger ?? DefaultLogger();
    GlobalLogger.logger = _logger;
    GlobalLogger().i(
      'TelnyxClient.connectWithCredential: Attempting to connect.',
    );

    // Now that a logger is set, we can set the log level
    _logger
      ..setLogLevel(credentialConfig.logLevel)
      ..log(LogLevel.info, 'connect()');
    // Defensively read a fresh persisted reconnect session id (VSDK-418) and
    // inject it as voice_sdk_id before the initial connection. Push metadata
    // takes precedence; a missing/failed read leaves the URL unchanged.
    unawaited(() async {
      final resolvedVoiceSdkId =
          _pushMetaData?.voiceSdkId ?? await _resolveReconnectVoiceSdkId();
      if (!_isActiveConnectionGeneration(connectionGeneration)) return;
      try {
        final hostAddress = _buildHostAddress(
          credentialConfig,
          voiceSdkId: resolvedVoiceSdkId,
        );
        _wireSocketAndConnect(
          connectionGeneration: connectionGeneration,
          hostAddress: hostAddress,
          onOpenLogin: () => credentialLogin(credentialConfig),
          onOpenLogTag: 'TelnyxClient.connectWithCredential',
          updateStateOnClose: false,
        );
      } catch (e) {
        GlobalLogger().e(e.toString());
        _updateConnectionState(false);
        GlobalLogger().e('WebSocket $_serverConfiguration.socketUrl error: $e');
        // Structured WebSocket connect failure (VSDK-415).
        emitStructuredErrorCode(
          TelnyxErrorCodes.webSocketConnectionFailed,
          originalError: e,
        );
      }
    }());
  }

  @Deprecated(
    'Use connect with token or credential login i.e connectWithCredential(..) or connectWithToken(..)',
  )

  /// Connects to the WebSocket with a previously provided [Config]
  void connect() {
    GlobalLogger().i('connect()');
    if (isConnected()) {
      GlobalLogger().i(
        'WebSocket $_serverConfiguration.socketUrl is already connected',
      );
      return;
    }
    if (!_prepareForConnection()) return;
    final connectionGeneration = _connectionGeneration;

    // Reapply the structured-error / health-monitor / media-recovery config
    // from the stored config so a bare reconnect stays consistent with the
    // last connectWith* call (VSDK-415/416/418).
    if (_currentConfig != null) {
      _applyStructuredConfig(_currentConfig!);
    }

    GlobalLogger().i('connecting to WebSocket $_serverConfiguration.socketUrl');
    try {
      if (_pushMetaData != null) {
        txSocket.hostAddress =
            '${_serverConfiguration.socketUrl}?voice_sdk_id=${_pushMetaData?.voiceSdkId}';
        GlobalLogger().i(
          'Connecting to WebSocket with voice_sdk_id :: ${_pushMetaData?.voiceSdkId}',
        );
      } else {
        txSocket.hostAddress = _serverConfiguration.socketUrl;
        GlobalLogger().i(
          'connecting to WebSocket $_serverConfiguration.socketUrl',
        );
      }
      txSocket
        ..onOpen = () {
          if (!_isActiveConnectionGeneration(connectionGeneration)) {
            return;
          }
          _closed = false;
          _updateConnectionState(true);
          GlobalLogger().i('Web Socket is now connected');
          _onOpen();
        }
        ..onMessage = (dynamic data) {
          if (!_isActiveConnectionGeneration(connectionGeneration)) return;
          _onMessage(data);
        }
        ..onClose = (int closeCode, String closeReason) {
          if (!_isActiveConnectionGeneration(connectionGeneration)) return;
          GlobalLogger().i('Closed [$closeCode, $closeReason]!');
          _updateConnectionState(false);
          final bool wasClean = WebSocketUtils.isCleanClose(
            closeCode,
            closeReason,
          );
          _onClose(wasClean, closeCode, closeReason);
        }
        ..onPing = (SocketConnectionMetrics metrics) {
          if (!_isActiveConnectionGeneration(connectionGeneration)) return;
          onConnectionMetricsUpdate?.call(metrics);
        }
        ..connect();
    } catch (e) {
      GlobalLogger().e(e.toString());
      _updateConnectionState(false);
      GlobalLogger().e('WebSocket $_serverConfiguration.socketUrl error: $e');
    }
  }

  /// Reconnects to the socket using stored configuration
  /// This method is used for both network-based reconnections and gateway failures
  /// It respects the autoReconnect settings and provides better logging
  void _reconnectToSocket() {
    if (_isTornDown) return;
    final connectionGeneration = _connectionGeneration;

    // Set reconnecting status
    if (_connectionStatus != ConnectionStatus.reconnecting) {
      _connectionStatus = ConnectionStatus.reconnecting;
      onConnectionStateChanged?.call(_connectionStatus);
    }

    GlobalLogger().i(
      'Reconnecting to socket (autoReconnect: $_autoReconnectLogin, retryCount: $_connectRetryCounter)',
    );

    _isAttaching = true;
    _scheduleConnectionTimer(
      Duration(milliseconds: Constants.gatewayResponseDelay),
      () {
        _isAttaching = false;
      },
      generation: connectionGeneration,
    );

    _closeSocketSafely();

    // Delay to allow connection with exponential backoff for retries
    final delayMs = _connectRetryCounter > 0
        ? Constants.reconnectTimer * (1 << (_connectRetryCounter - 1))
        : 1000;

    _scheduleConnectionTimer(
      Duration(milliseconds: delayMs),
      () {
        if (_storedCredentialConfig != null) {
          GlobalLogger().i('Reconnecting with credential config');
          connectWithCredential(_storedCredentialConfig!);
        } else if (_storedTokenConfig != null) {
          GlobalLogger().i('Reconnecting with token config');
          connectWithToken(_storedTokenConfig!);
        } else {
          GlobalLogger().e(
            'No stored configuration available for socket reconnection',
          );
          final error = TelnyxSocketError(
            errorCode: TelnyxErrorConstants.gatewayFailedErrorCode,
            errorMessage:
                'No stored configuration available for socket reconnection',
          );
          onSocketErrorReceived(error);
        }
      },
      generation: connectionGeneration,
    );
  }

  /// The current instance of [Call] associated with this client. Can be used
  /// to call call related functions such as hold/mute
  Call? _call;

  // Public getter to lazily initialize and return the value.
  @Deprecated(
    'telnyxClient.call is deprecated, use telnyxClient.invite() or  telnyxClient.accept()',
  )

  /// The current instance of [Call] associated with this client.
  ///
  /// This is deprecated. Use [newInvite] to create a new call or
  /// [acceptCall] to answer an incoming one. For existing calls, retrieve them
  /// from the [calls] map using their call ID.
  Call get call {
    // If _call is null, initialize it with the default value.
    _call ??= _createCall();
    return _call!;
  }

  void _callEnded() {
    GlobalLogger().i('Call Ended');
    _call = null;
  }

  /// Creates an instance of [Call] that can be used to create invitations or
  /// perform common call related functions such as ending the call or placing
  /// yourself on hold/mute.
  Call _createCall() {
    // Create a placeholder for the CallHandler
    late CallHandler callHandler;

    // Create the Call object
    _call = Call(
      txSocket,
      this,
      sessid,
      _ringtonePath,
      _ringBackpath,
      callHandler = CallHandler(
        (state) {
          GlobalLogger().i(
            'Call state not overridden :Call State Changed to $state',
          );
        },
        null,
      ),
      // Pass null initially
      _callEnded,
      _debug,
    );

    // Set the call property of CallHandler
    callHandler.call = _call!;

    return _call!;
  }

  /// Uses the provided [config] to send a credential login message to the Telnyx backend.
  /// If successful, the gateway registration process will start.
  ///
  /// May return a [TelnyxSocketError] in the case of an authentication error
  @Deprecated('Use connectWithCredential(..) instead')
  void credentialLogin(CredentialConfig config) {
    _storedCredentialConfig = config;
    // Only start registration tracking if not already started by connectWithCredential
    if (!latencyTracker.isTrackingRegistration) {
      latencyTracker.startRegistrationTracking();
    }
    latencyTracker.markRegistrationMilestone(LatencyTracker.milestoneLoginSent);
    final uuid = const Uuid().v4();
    final user = config.sipUser;
    final password = config.sipPassword;
    final fcmToken = config.notificationToken;
    _ringBackpath = config.ringbackPath ?? '';
    _ringtonePath = config.ringTonePath ?? '';
    _debug = config.debug;
    UserVariables? notificationParams;
    _autoReconnectLogin = config.autoReconnect ?? true;

    if (defaultTargetPlatform == TargetPlatform.android) {
      notificationParams = UserVariables(
        pushDeviceToken: fcmToken,
        pushNotificationProvider: 'android',
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      notificationParams = UserVariables(
        pushDeviceToken: fcmToken,
        pushNotificationProvider: 'ios',
      );
    }

    final loginParams = LoginParams(
      login: user,
      passwd: password,
      loginParams: {'attach_call': 'true'},
      sessionId: sessid,
      userVariables: notificationParams,
      userAgent: VersionUtils.getUserAgent(),
    );
    final loginMessage = LoginMessage(
      id: uuid,
      method: SocketMethod.login,
      params: loginParams,
      jsonrpc: JsonRPCConstant.jsonrpc,
    );

    final String jsonLoginMessage = jsonEncode(loginMessage);
    if (isConnected()) {
      txSocket.send(jsonLoginMessage);
    } else {
      _connectWithCallBack(_pushMetaData, () {
        txSocket.send(jsonLoginMessage);
      });
    }
  }

  /// Uses the provided [config] to send a token login message to the Telnyx backend.
  /// If successful, the gateway registration process will start.
  ///
  /// May return a [TelnyxSocketError] in the case of an authentication error
  @Deprecated('Use connectWithToken(..) instead')
  void tokenLogin(TokenConfig config) {
    _storedTokenConfig = config;
    // Only start registration tracking if not already started by connectWithToken
    if (!latencyTracker.isTrackingRegistration) {
      latencyTracker.startRegistrationTracking();
    }
    latencyTracker.markRegistrationMilestone(LatencyTracker.milestoneLoginSent);
    final uuid = const Uuid().v4();
    final token = config.sipToken;
    final fcmToken = config.notificationToken;
    _ringBackpath = config.ringbackPath ?? '';
    _ringtonePath = config.ringTonePath ?? '';
    _debug = config.debug;
    UserVariables? notificationParams;
    _autoReconnectLogin = config.autoReconnect ?? true;

    if (defaultTargetPlatform == TargetPlatform.android) {
      notificationParams = UserVariables(
        pushDeviceToken: fcmToken,
        pushNotificationProvider: 'android',
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      notificationParams = UserVariables(
        pushDeviceToken: fcmToken,
        pushNotificationProvider: 'ios',
      );
    }

    final loginParams = LoginParams(
      loginToken: token,
      loginParams: {'attach_call': 'true'},
      userVariables: notificationParams,
      sessionId: sessid,
      userAgent: VersionUtils.getUserAgent(),
    );
    final loginMessage = LoginMessage(
      id: uuid,
      method: SocketMethod.login,
      params: loginParams,
      jsonrpc: JsonRPCConstant.jsonrpc,
    );

    final String jsonLoginMessage = jsonEncode(loginMessage);
    GlobalLogger().i('Token Login Message $jsonLoginMessage');
    if (isConnected()) {
      txSocket.send(jsonLoginMessage);
    } else {
      _connectWithCallBack(null, () {
        txSocket.send(jsonLoginMessage);
      });
    }

    // Schedule TOKEN_EXPIRING_SOON warning if the token is a JWT (VSDK-397).
    _checkTokenExpiry(config.sipToken);
  }

  /// Decodes the JWT [token] and schedules a [TelnyxWarningCodes.tokenExpiringSoon]
  /// warning 120 s before expiry. If already within 120 s of expiry, emits
  /// immediately. Non-JWT tokens are skipped silently.
  ///
  /// Mirrors JS BaseSession._checkTokenExpiry() (VSDK-397).
  ///
  /// Note: The warning is advisory, not authoritative — the server is the
  /// source of truth for token validity. On mobile, device clock skew (NTP
  /// not synced, manual time change, timezone jumps) can cause the warning
  /// to fire early/late. This matches the JS implementation which has the
  /// same caveat with Date.now() (AFK review N1).
  void _checkTokenExpiry(String? token) {
    _clearTokenExpiryTimer();
    if (token == null || token.isEmpty) return;

    try {
      final parts = token.split('.');
      if (parts.length != 3) return; // not a JWT

      // JWT payload is base64url-encoded.
      String payload = parts[1];
      // Pad to a multiple of 4 for base64 decode.
      payload += '=' * ((4 - payload.length % 4) % 4);
      final decoded = utf8.decode(base64Url.decode(payload));
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      final exp = json['exp'];
      if (exp is! num) return;

      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final secondsUntilExpiry = exp.toInt() - nowSec;

      if (secondsUntilExpiry <= 0) {
        // Already expired — login will fail and error handler will fire.
        return;
      } else if (secondsUntilExpiry <= _tokenExpiryWarningSeconds) {
        // Expiring very soon — emit immediately.
        _emitTokenExpiryWarning();
      } else {
        // Schedule warning for 120 s before expiry.
        final delayMs =
            (secondsUntilExpiry - _tokenExpiryWarningSeconds) * 1000;
        _tokenExpiryTimer = Timer(
          Duration(milliseconds: delayMs),
          _emitTokenExpiryWarning,
        );
      }
    } catch (e) {
      // Not a valid JWT — skip silently.
      GlobalLogger()
          .d('login_token is not a decodable JWT, skipping expiry check: $e');
    }
  }

  void _emitTokenExpiryWarning() {
    emitWarningCode(
      TelnyxWarningCodes.tokenExpiringSoon,
      reason: 'JWT token expiring soon',
      source: 'auth',
    );
  }

  void _clearTokenExpiryTimer() {
    _tokenExpiryTimer?.cancel();
    _tokenExpiryTimer = null;
  }

  /// Performs an anonymous login to the Telnyx backend for AI assistant connections.
  ///
  /// This method allows connecting to AI assistants without traditional authentication.
  /// It takes the target ID, target type (defaults to 'ai_assistant'), and optional
  /// target version ID.
  ///
  /// Note: Any call, no matter the destination, after this login will be directed to the AI agent specified by the target ID.
  ///
  /// Parameters:
  /// - [targetId]: The ID of the target (e.g., assistant ID)
  /// - [targetType]: The type of target (defaults to 'ai_assistant')
  /// - [targetVersionId]: Optional version ID of the target
  /// - [conversationId]: Optional conversation ID to join an existing conversation
  /// - [userVariables]: Optional user variables to include
  /// - [reconnection]: Whether this is a reconnection attempt (defaults to false)
  ///
  /// Throws [ArgumentError] if [conversationId] is provided but empty.
  Future<void> anonymousLogin({
    required String targetId,
    String targetType = 'ai_assistant',
    String? targetVersionId,
    String? conversationId,
    Map<String, dynamic>? userVariables,
    bool reconnection = false,
    LogLevel logLevel = LogLevel.none,
  }) async {
    // Validate conversationId if provided
    if (conversationId != null && conversationId.trim().isEmpty) {
      throw ArgumentError('conversationId cannot be empty when provided');
    }

    final uuid = const Uuid().v4();

    setLogLevel(logLevel);

    final versionData = VersionUtils.getSDKVersion();
    final userAgentData = VersionUtils.getUserAgent();

    final userAgent = UserAgent(sdkVersion: versionData, data: userAgentData);

    final anonymousLoginParams = AnonymousLoginParams(
      targetType: targetType,
      targetId: targetId,
      targetVersionId: targetVersionId,
      conversationId: conversationId,
      userVariables: userVariables,
      reconnection: reconnection,
      userAgent: userAgent,
      sessionId: sessid,
    );

    final anonymousLoginMessage = AnonymousLoginMessage(
      id: uuid,
      method: SocketMethod.anonymousLogin,
      params: anonymousLoginParams,
      jsonrpc: JsonRPCConstant.jsonrpc,
    );

    final String jsonAnonymousLoginMessage = jsonEncode(anonymousLoginMessage);
    GlobalLogger().i('Anonymous Login Message $jsonAnonymousLoginMessage');

    if (isConnected()) {
      txSocket.send(jsonAnonymousLoginMessage);
    } else {
      _connectWithCallBack(null, () {
        txSocket.send(jsonAnonymousLoginMessage);
      });
    }
  }

  /// Disables push notifications for the currently authenticated user.
  ///
  /// This method requires a user to be logged in via [connectWithCredential] or
  /// [connectWithToken] and have a `notificationToken` provided in the config.
  /// It sends a request to the Telnyx backend to stop sending push notifications
  /// to the associated device token.
  void disablePushNotifications() {
    final config = _storedCredentialConfig ?? _storedTokenConfig;
    if (config != null && config.notificationToken != null) {
      final uuid = const Uuid().v4();
      final disablePushParams = DisablePushParams(
        user: config is CredentialConfig ? config.sipUser : null,
        loginToken: config is TokenConfig ? config.sipToken : null,
        userVariables: PushUserVariables(
          pushNotificationToken: config.notificationToken!,
          pushNotificationProvider:
              defaultTargetPlatform == TargetPlatform.android
                  ? 'android'
                  : 'ios',
        ),
      );
      final disablePushMessage = DisablePushMessage(
        id: uuid,
        method: SocketMethod.disablePush,
        params: disablePushParams,
        jsonrpc: JsonRPCConstant.jsonrpc,
      );

      final String jsonDisablePushMessage = jsonEncode(disablePushMessage);
      txSocket.send(jsonDisablePushMessage);
    } else {
      GlobalLogger().e(
        'No user or associated notification token found - we cannot disable push notifications',
      );
    }
  }

  /// Creates and sends a new call invitation.
  ///
  /// This method initiates an outgoing call to a [destinationNumber] (which can be
  /// a SIP URI or a phone number).
  ///
  /// - [callerName]: The name to be displayed to the callee.
  /// - [callerNumber]: The phone number or SIP URI of the caller.
  /// - [destinationNumber]: The phone number or SIP URI to call.
  /// - [clientState]: A custom string that can be used to store and retrieve state
  ///   between applications. It is passed to the remote party.
  /// - [customHeaders]: Optional custom SIP headers to add to the INVITE message.
  /// - [preferredCodecs]: Optional list of preferred audio codecs in order of preference.
  ///   If any codec in the list is not supported by the platform or remote party,
  ///   the system will automatically fall back to a supported codec.
  /// - [debug]: Enables detailed logging for this specific call if set to true.
  /// - [useTrickleIce]: When true, enables trickle ICE for the call. Trickle ICE allows
  ///   ICE candidates to be sent incrementally as they are discovered, rather than
  ///   waiting for all candidates to be gathered before sending the SDP. This can
  ///   significantly reduce call setup time. Defaults to false.
  /// - [mutedMicOnStart]: When true, starts the call with the microphone muted.
  ///   Defaults to false.
  /// - [audioConstraints]: Optional audio constraints for the call.
  ///
  /// Returns a [Call] object representing the new outgoing call.
  Call newInvite(
    String callerName,
    String callerNumber,
    String destinationNumber,
    String clientState, {
    Map<String, String> customHeaders = const {},
    List<AudioCodec>? preferredCodecs,
    bool debug = false,
    bool useTrickleIce = false,
    bool mutedMicOnStart = false,
    AudioConstraints? audioConstraints,
  }) {
    final Call inviteCall = _createCall()
      ..sessionCallerName = callerName
      ..sessionCallerNumber = callerNumber
      ..sessionDestinationNumber = destinationNumber
      ..sessionClientState = clientState;
    customHeaders = customHeaders;
    inviteCall.callId = const Uuid().v4();
    final base64State = base64.encode(utf8.encode(clientState));
    updateCall(inviteCall);

    // Start latency tracking for outbound call
    latencyTracker.startCallTracking(
      inviteCall.callId!,
      isOutbound: true,
      useTrickleIce: useTrickleIce,
    );

    // Create the peer connection with debug enabled if requested
    inviteCall.peerConnection = Peer(
      inviteCall.txSocket,
      debug || _debug,
      this,
      getForceRelayCandidate(),
      useTrickleIce,
      audioConstraints,
      mutedMicOnStart,
      _getEffectiveIceServers(),
    );
    // Apply call report config from stored config
    final callReportConfig = _storedCredentialConfig ?? _storedTokenConfig;
    inviteCall.peerConnection?.setCallReportConfig(
      callReportInterval: callReportConfig?.callReportInterval ?? 5000,
      callReportLogLevel: callReportConfig?.callReportLogLevel ?? 'debug',
      callReportMaxLogEntries:
          callReportConfig?.callReportMaxLogEntries ?? 1000,
    );
    // Convert AudioCodec objects to Map format for the peer connection
    List<Map<String, dynamic>>? codecMaps;
    if (preferredCodecs != null && preferredCodecs.isNotEmpty) {
      codecMaps = preferredCodecs.map((codec) => codec.toJson()).toList();
    }

    inviteCall.peerConnection?.invite(
      callerName,
      callerNumber,
      destinationNumber,
      base64State,
      inviteCall.callId!,
      inviteCall.sessid,
      customHeaders,
      preferredCodecs: codecMaps,
    );

    if (debug) {
      inviteCall.initCallMetrics();
    } //play ringback tone
    inviteCall.playAudio(_ringBackpath);
    inviteCall.callHandler.changeState(CallState.newCall);

    // Register the outbound call with CallManager and set as current.
    callManager
      ..registerCall(inviteCall)
      ..setCurrentCall(inviteCall);

    return inviteCall;
  }

  /// Accepts an incoming call.
  ///
  /// This method should be called in response to an `invite` event received via
  /// the [onSocketMessageReceived] callback.
  ///
  /// - [invite]: The [IncomingInviteParams] object from the received invite message.
  /// - [callerName]: The name of the user accepting the call.
  /// - [callerNumber]: The number or SIP URI of the user accepting the call.
  /// - [clientState]: A custom string for application-specific state.
  /// - [isAttach]: Set to true if this is a call being re-attached (e.g., after network reconnection).
  /// - [customHeaders]: Optional custom SIP headers to add to the response.
  /// - [debug]: Enables detailed logging for this specific call if set to true.
  /// - [useTrickleIce]: When true, enables trickle ICE for the call. Trickle ICE allows
  ///   ICE candidates to be sent incrementally as they are discovered, rather than
  ///   waiting for all candidates to be gathered before sending the SDP. This can
  ///   significantly reduce call setup time. Defaults to false.
  /// - [mutedMicOnStart]: When true, starts the call with the microphone muted.
  ///   Defaults to false.
  /// - [audioConstraints]: Optional audio constraints for the call.
  /// - [answeredDeviceToken]: Optional device token (FCM/APNS) to include when
  ///   answering a push notification call. This allows the backend to identify
  ///   which device answered the call.
  ///
  /// Returns the [Call] object associated with the accepted call.
  Call acceptCall(
    IncomingInviteParams invite,
    String callerName,
    String callerNumber,
    String clientState, {
    bool isAttach = false,
    Map<String, String> customHeaders = const {},
    bool debug = false,
    bool useTrickleIce = false,
    bool mutedMicOnStart = false,
    AudioConstraints? audioConstraints,
    String? answeredDeviceToken,
  }) {
    final Call answerCall = getCallOrNull(invite.callID!) ?? _createCall()
      ..callId = invite.callID
      ..sessionCallerName = callerName
      ..sessionCallerNumber = callerNumber
      ..callState = CallState.connecting
      ..sessionDestinationNumber = invite.callerIdNumber ?? '-1'
      ..sessionClientState = clientState;

    final destinationNum = invite.callerIdNumber;

    // Start latency tracking for inbound call
    latencyTracker
      ..startCallTracking(
        answerCall.callId!,
        isOutbound: false,
        useTrickleIce: useTrickleIce,
      )
      ..markAnswerInitiated(answerCall.callId!);

    // Create the peer connection
    answerCall.peerConnection = Peer(
      txSocket,
      debug || _debug,
      this,
      getForceRelayCandidate(),
      useTrickleIce,
      audioConstraints,
      mutedMicOnStart,
      _getEffectiveIceServers(),
    );
    // Apply call report config from stored config
    final answerCallReportConfig =
        _storedCredentialConfig ?? _storedTokenConfig;
    answerCall.peerConnection?.setCallReportConfig(
      callReportInterval: answerCallReportConfig?.callReportInterval ?? 5000,
      callReportLogLevel: answerCallReportConfig?.callReportLogLevel ?? 'debug',
      callReportMaxLogEntries:
          answerCallReportConfig?.callReportMaxLogEntries ?? 1000,
    );

    // Set up the session with the callback if debug is enabled
    answerCall.peerConnection?.accept(
      callerName,
      callerNumber,
      destinationNum!,
      clientState,
      answerCall.callId!,
      invite,
      customHeaders,
      isAttach,
      answeredDeviceToken: answeredDeviceToken,
    );
    answerCall.callHandler.changeState(CallState.connecting);
    if (debug) {
      answerCall.initCallMetrics();
    }
    answerCall.stopAudio();
    if (answerCall.callId != null) {
      updateCall(answerCall);
    }

    // Register the accepted call with CallManager and set it as the current
    // active call. If there was a previous currentCall it should already have
    // been put on hold by holdCurrentAndAcceptIncoming before this point.
    callManager
      ..registerCall(answerCall)
      ..setCurrentCall(answerCall);

    clearPushMetaData();
    return answerCall;
  }

  /// Provides the current [Call] instance associated with the [callId] otherwise returns null
  Call? getCallOrNull(String callId) {
    if (calls.containsKey(callId)) {
      GlobalLogger().d('Invite Call found');
      return calls[callId];
    }
    GlobalLogger().d('Invite Call not found');
    return null;
  }

  /// Update the [Call] instance associated with the [callId]
  void updateCall(Call call) {
    if (calls.containsKey(call.callId)) {
      calls[call.callId!] = call;
    } else {
      calls[call.callId!] = call;
    }
  }

  // ===========================================================================
  // Multi-call convenience methods
  // ===========================================================================

  /// Holds the current active call (if any) and accepts the incoming call
  /// identified by [incomingCallId].
  ///
  /// Use this when the user wants to put the current call on hold and answer
  /// an incoming call. The current call will be placed on hold via
  /// [Call.onHoldUnholdPressed] and the incoming call will be accepted.
  ///
  /// Returns the accepted [Call].
  ///
  /// **Example:**
  /// ```dart
  /// telnyxClient.onSocketMessageReceived = (message) {
  ///   if (message.socketMethod == SocketMethod.invite) {
  ///     if (telnyxClient.callManager.hasActiveCall) {
  ///       telnyxClient.holdCurrentAndAcceptIncoming(
  ///         incomingCallId,
  ///         inviteParams,
  ///         callerName,
  ///         callerNumber,
  ///         clientState,
  ///       );
  ///     } else {
  ///       telnyxClient.acceptCall(...);
  ///     }
  ///   }
  /// };
  /// ```
  Call holdCurrentAndAcceptIncoming(
    String incomingCallId,
    IncomingInviteParams invite,
    String callerName,
    String callerNumber,
    String clientState, {
    Map<String, String> customHeaders = const {},
    bool debug = false,
    bool useTrickleIce = false,
    bool mutedMicOnStart = false,
    AudioConstraints? audioConstraints,
    String? answeredDeviceToken,
  }) {
    return callManager.holdCurrentAndAcceptIncoming(
      incomingCallId,
      (callId) => acceptCall(
        invite,
        callerName,
        callerNumber,
        clientState,
        customHeaders: customHeaders,
        debug: debug,
        useTrickleIce: useTrickleIce,
        mutedMicOnStart: mutedMicOnStart,
        audioConstraints: audioConstraints,
        answeredDeviceToken: answeredDeviceToken,
      ),
    );
  }

  /// Ends the current active call and accepts the incoming call identified by
  /// [incomingCallId].
  ///
  /// Use this when the user wants to hang up the current call and answer an
  /// incoming call.
  ///
  /// Returns the accepted [Call].
  Call endCurrentAndAcceptIncoming(
    String incomingCallId,
    IncomingInviteParams invite,
    String callerName,
    String callerNumber,
    String clientState, {
    Map<String, String> customHeaders = const {},
    bool debug = false,
    bool useTrickleIce = false,
    bool mutedMicOnStart = false,
    AudioConstraints? audioConstraints,
    String? answeredDeviceToken,
  }) {
    return callManager.endCurrentAndAcceptIncoming(
      incomingCallId,
      endCall: (callId) {
        final call = calls[callId];
        call?.endCall();
      },
      acceptCall: (callId) => acceptCall(
        invite,
        callerName,
        callerNumber,
        clientState,
        customHeaders: customHeaders,
        debug: debug,
        useTrickleIce: useTrickleIce,
        mutedMicOnStart: mutedMicOnStart,
        audioConstraints: audioConstraints,
        answeredDeviceToken: answeredDeviceToken,
      ),
    );
  }

  /// Rejects an incoming call by sending BYE with USER_BUSY cause.
  ///
  /// Use this to decline an incoming call without affecting the current active
  /// call (if any). The call must be in [CallState.ringing] state.
  void rejectCall(String callId) {
    final call = calls[callId];
    if (call == null) {
      GlobalLogger().w('rejectCall: Call not found for ID: $callId');
      return;
    }
    call.endCall();
    callManager.onIncomingCallRejected(callId);
  }

  /// Closes the socket connection and provides a callback upon completion.
  ///
  /// This method logs the user out and terminates the WebSocket connection.
  /// The [closeCallback] is invoked when the disconnection is complete.
  void disconnectWithCallBack(OnCloseCallback? closeCallback) {
    _invalidateConnectionGeneration();
    _invalidateGatewayResponseTimer();
    _resetGatewayCounters();
    _cancelPendingAnswerTimeout();
    _cancelReconnectionTimers();
    _cancelConnectivitySubscription();
    clearPushMetaData();
    GlobalLogger().i('disconnect()');
    // Explicit user disconnect/logout clears all persisted recovery data
    // (VSDK-418) and stops the signaling-health monitor (VSDK-416).
    _explicitDisconnectInProgress = true;
    _healthMonitor?.stop();
    _clearTokenExpiryTimer();
    unawaited(_clearPersistedRecovery(_recoveryEpoch));
    if (_closed) {
      GlobalLogger().i('WebSocket is already closed');
      closeCallback?.call(0, 'Client send disconnect');
      return;
    }
    // Don't wait for the WebSocket 'close' event, do it now.
    _closed = true;
    _updateConnectionState(false);
    _registered = false;
    _updateConnectionStatus();
    _closeSocketSafely();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!_disposed) {
        closeCallback?.call(0, 'Client send disconnect');
      }
    });
  }

  /// Closes the socket connection, effectively logging the user out.
  void disconnect() {
    _invalidateConnectionGeneration();
    _invalidateGatewayResponseTimer();
    _resetGatewayCounters();
    _cancelPendingAnswerTimeout();
    _cancelReconnectionTimers();
    _cancelConnectivitySubscription();
    clearPushMetaData();
    GlobalLogger().i('disconnect()');
    // Explicit user disconnect/logout clears all persisted recovery data
    // (VSDK-418) and stops the signaling-health monitor (VSDK-416).
    _explicitDisconnectInProgress = true;
    _healthMonitor?.stop();
    _clearTokenExpiryTimer();
    unawaited(_clearPersistedRecovery(_recoveryEpoch));
    if (_closed) return;
    // Don't wait for the WebSocket 'close' event, do it now.
    _closed = true;
    _updateConnectionState(false);
    _registered = false;
    _updateConnectionStatus();
    _onClose(true, 0, 'Client send disconnect');
    _closeSocketSafely();
  }

  /// Releases resources owned by this client.
  void dispose() {
    if (_disposed) return;

    final shouldCloseSocket = !_closed;
    _disposed = true;
    _closed = true;
    _healthMonitor?.stop();
    _clearTokenExpiryTimer();
    _requestTimeoutTracker?.cancelAll();
    _invalidateConnectionGeneration();
    _invalidateGatewayResponseTimer();
    _resetGatewayCounters();
    _cancelPendingAnswerTimeout();
    _cancelReconnectionTimers();
    _cancelConnectivitySubscription();
    clearPushMetaData();
    _registered = false;
    _connected = false;
    _connectionStatus = ConnectionStatus.disconnected;
    if (shouldCloseSocket) {
      _closeSocketSafely();
    }
    _disposeLatencyTracker();
    if (_streamControllersInitialized) {
      _errorStreamController.close();
      _warningStreamController.close();
      _streamControllersInitialized = false;
    }
  }

  /// WebSocket Event Handlers
  void _onOpen() {
    GlobalLogger().i(
      'TelnyxClient._onOpen: WebSocket connected event triggered.',
    );
  }

  void _onClose(bool wasClean, int code, String reason) {
    if (_disposed) return;
    final connectionGeneration = _connectionGeneration;

    GlobalLogger().i('WebSocket closed');
    if (wasClean == false) {
      GlobalLogger().i('WebSocket abrupt disconnection');
      // Structured (non-fatal) WebSocket runtime error (VSDK-415).
      emitStructuredErrorCode(
        TelnyxErrorCodes.webSocketError,
        message: 'WebSocket closed unexpectedly [$code, $reason]',
      );

      // When auto-reconnect is disabled and this is not an intentional
      // disconnect, emit RECONNECTION_FAILED_WITH_NO_AUTO_RECONNECT (36005)
      // so the app knows the session won't recover automatically (VSDK-397).
      if (!_autoReconnectLogin && !_explicitDisconnectInProgress) {
        emitWarningCode(
          TelnyxWarningCodes.reconnectionFailedWithNoAutoReconnect,
          reason: 'auto_reconnect_disabled',
          source: 'socket_close',
        );
      }
    }

    // Handle region fallback if connection failed and fallback is enabled.
    // Uses a typed copy helper to preserve *every* Config option from the
    // current config, only changing the region to Region.auto. This prevents
    // silent option loss (e.g. enableStructuredErrors, ICE servers, timeouts)
    // that the prior hand-written constructors dropped (VSDK-415/416 B1).
    if (!wasClean &&
        _currentConfig != null &&
        _currentConfig!.region != Region.auto &&
        _currentConfig!.fallbackOnRegionFailure &&
        !_isRegionFallbackAttempt) {
      GlobalLogger().i(
        'Connection failed with region ${_currentConfig!.region.value}, attempting fallback to auto region',
      );
      _isRegionFallbackAttempt = true;

      // Capture the auto-region fallback config NOW, before scheduling, so the
      // timer callback does not dereference the mutable _currentConfig field
      // (which may be reassigned by a concurrent connect/disconnect before the
      // timer fires). A captured immutable copy is race-free (VSDK-415/416).
      final fallbackConfig = _copyConfigWithAutoRegion(_currentConfig!);

      // Retry connection with the auto-region copy after a short delay.
      _scheduleConnectionTimer(
        const Duration(milliseconds: 1000),
        () {
          if (fallbackConfig is TokenConfig) {
            connectWithToken(fallbackConfig);
          } else if (fallbackConfig is CredentialConfig) {
            connectWithCredential(fallbackConfig);
          }
        },
        generation: connectionGeneration,
      );
    }
  }

  /// Build a copy of [config] with the region changed to [Region.auto],
  /// preserving every other Config option exactly.
  ///
  /// Used by the region-fallback path in [_onClose] so no option is silently
  /// dropped. A single typed helper prevents omissions that a hand-written
  /// constructor list would be prone to (VSDK-415/416 B1).
  Config _copyConfigWithAutoRegion(Config config) {
    if (config is TokenConfig) {
      return _copyTokenConfigWithRegion(config, Region.auto);
    } else if (config is CredentialConfig) {
      return _copyCredentialConfigWithRegion(config, Region.auto);
    }
    // Unreachable for the two concrete Config subclasses in use; defensive.
    return config;
  }

  /// Copies a [TokenConfig] preserving every field except [region].
  TokenConfig _copyTokenConfigWithRegion(
    TokenConfig c,
    Region region,
  ) {
    return TokenConfig(
      sipToken: c.sipToken,
      sipCallerIDName: c.sipCallerIDName,
      sipCallerIDNumber: c.sipCallerIDNumber,
      notificationToken: c.notificationToken,
      autoReconnect: c.autoReconnect,
      logLevel: c.logLevel,
      debug: c.debug,
      ringTonePath: c.ringTonePath,
      ringbackPath: c.ringbackPath,
      customLogger: c.customLogger,
      reconnectionTimeout: c.reconnectionTimeout,
      pushAnswerTimeout: c.pushAnswerTimeout,
      region: region,
      fallbackOnRegionFailure: c.fallbackOnRegionFailure,
      forceRelayCandidate: c.forceRelayCandidate,
      iceServers: c.iceServers,
      serverConfiguration: c.serverConfiguration,
      callReportInterval: c.callReportInterval,
      callReportLogLevel: c.callReportLogLevel,
      callReportMaxLogEntries: c.callReportMaxLogEntries,
      enableCallReports: c.enableCallReports,
      debugOutput: c.debugOutput,
      debugLogLevel: c.debugLogLevel,
      debugLogMaxEntries: c.debugLogMaxEntries,
      callReportFlushInterval: c.callReportFlushInterval,
      prefetchIceCandidates: c.prefetchIceCandidates,
      autoRecoverCalls: c.autoRecoverCalls,
      hangupOnBeforeUnload: c.hangupOnBeforeUnload,
      maxReconnectAttempts: c.maxReconnectAttempts,
      enableStructuredErrors: c.enableStructuredErrors,
      enableSignalingHealthMonitor: c.enableSignalingHealthMonitor,
      mediaPermissionsRecovery: c.mediaPermissionsRecovery,
    );
  }

  CredentialConfig _copyCredentialConfigWithRegion(
    CredentialConfig c,
    Region region,
  ) {
    return CredentialConfig(
      sipUser: c.sipUser,
      sipPassword: c.sipPassword,
      sipCallerIDName: c.sipCallerIDName,
      sipCallerIDNumber: c.sipCallerIDNumber,
      notificationToken: c.notificationToken,
      autoReconnect: c.autoReconnect,
      logLevel: c.logLevel,
      debug: c.debug,
      ringTonePath: c.ringTonePath,
      ringbackPath: c.ringbackPath,
      customLogger: c.customLogger,
      reconnectionTimeout: c.reconnectionTimeout,
      pushAnswerTimeout: c.pushAnswerTimeout,
      region: region,
      fallbackOnRegionFailure: c.fallbackOnRegionFailure,
      forceRelayCandidate: c.forceRelayCandidate,
      iceServers: c.iceServers,
      serverConfiguration: c.serverConfiguration,
      callReportInterval: c.callReportInterval,
      callReportLogLevel: c.callReportLogLevel,
      callReportMaxLogEntries: c.callReportMaxLogEntries,
      enableCallReports: c.enableCallReports,
      debugOutput: c.debugOutput,
      debugLogLevel: c.debugLogLevel,
      debugLogMaxEntries: c.debugLogMaxEntries,
      callReportFlushInterval: c.callReportFlushInterval,
      prefetchIceCandidates: c.prefetchIceCandidates,
      autoRecoverCalls: c.autoRecoverCalls,
      hangupOnBeforeUnload: c.hangupOnBeforeUnload,
      maxReconnectAttempts: c.maxReconnectAttempts,
      enableStructuredErrors: c.enableStructuredErrors,
      enableSignalingHealthMonitor: c.enableSignalingHealthMonitor,
      mediaPermissionsRecovery: c.mediaPermissionsRecovery,
    );
  }

  void _onMessage(dynamic data) async {
    if (_isTornDown) return;

    // Every inbound WebSocket message is signaling-health activity (VSDK-416).
    _healthMonitor?.onSocketActivity();

    GlobalLogger().i(
      'TelnyxClient._onMessage: RAW WebSocket data received: ${data?.toString().trim()}',
    );

    if (data != null) {
      final messageString = data.toString().trim();
      if (messageString.isNotEmpty) {
        GlobalLogger().i('TxSocket :: $messageString');

        try {
          final Map<String, dynamic> messageJson = jsonDecode(messageString);

          if (messageJson.containsKey('error')) {
            final errorJson = jsonEncode(messageJson);
            _logger.log(
              LogLevel.info,
              'Received WebSocket message - Contains Error :: $errorJson',
            );
            final ReceivedResult errorResult = ReceivedResult.fromJson(
              messageJson,
            );
            // Resolve the in-flight signaling probe (if any) when the JSON-RPC
            // error matches the probe's request id. An error response still
            // proves the signaling path is alive (the server answered), even
            // if the ping itself was rejected — VSDK-416 Gap 1 hardening.
            _healthMonitor?.resolveProbe(errorResult.id);
            if (errorResult.id != null) {
              _requestTimeoutTracker?.resolve(errorResult.id!);
            }
            final TelnyxSocketError error = TelnyxSocketError(
              errorCode: errorResult.error?.errorCode ?? 0,
              errorMessage: errorResult.error?.errorMessage ?? 'Unknown error',
            );
            onSocketErrorReceived.call(error);
            // Structured error alongside the legacy callback (VSDK-415).
            _emitStructuredForSocketError(error);
          } else if (messageJson.containsKey('result')) {
            final paramJson = jsonEncode(messageJson);
            _logger.log(
              LogLevel.info,
              'Received WebSocket message - Contains Result :: $paramJson',
            );

            final ReceivedResult stateMessage = ReceivedResult.fromJson(
              messageJson,
            );
            // Resolve the in-flight signaling probe (if any) when the JSON-RPC
            // result matches the probe's request id. Unrelated inbound frames
            // MUST NOT release the probe — VSDK-416 Gap 1 hardening.
            _healthMonitor?.resolveProbe(stateMessage.id);
            // Resolve any pending request-timeout timer for this response.
            if (stateMessage.id != null) {
              _requestTimeoutTracker?.resolve(stateMessage.id!);
            }
            final mainMessage = ReceivedMessage(
              jsonrpc: stateMessage.jsonrpc,
              method: SocketMethod.gatewayState,
              stateParams: stateMessage.resultParams?.stateParams,
            );

            if (stateMessage.resultParams != null) {
              switch (stateMessage.resultParams?.stateParams?.state) {
                case GatewayState.reged:
                  {
                    if (!_registered) {
                      GlobalLogger().i(
                        'GATEWAY REGISTERED :: ${stateMessage.toString()}',
                      );
                      _invalidateGatewayResponseTimer();
                      _resetGatewayCounters();
                      gatewayState = GatewayState.reged;

                      // Complete registration latency tracking
                      latencyTracker.completeRegistrationTracking();

                      // Store call_report_id for call report authentication
                      callReportId =
                          stateMessage.resultParams?.stateParams?.callReportId;
                      if (callReportId != null) {
                        GlobalLogger().d(
                          'CallReportId received: $callReportId',
                        );
                      }
                      _waitingForReg = false;
                      // Capture the server-provided voice_sdk_id *before* the
                      // push-driven path clears _pushMetaData below, otherwise
                      // the reconnect token would be lost (VSDK-418).
                      final registeredVoiceSdkId = voiceSdkId;
                      final message = TelnyxMessage(
                        socketMethod: SocketMethod.clientReady,
                        message: mainMessage,
                      );
                      onSocketMessageReceived.call(message);
                      if (_isCallFromPush) {
                        //sending attach Call
                        final String platform =
                            defaultTargetPlatform == TargetPlatform.android
                                ? 'android'
                                : 'ios';
                        const String pushEnvironment =
                            kDebugMode ? 'development' : 'production';
                        final AttachCallMessage attachCallMessage =
                            AttachCallMessage(
                          method: SocketMethod.attachCall,
                          id: const Uuid().v4(),
                          params: Params(
                            userVariables: <dynamic, dynamic>{
                              'push_notification_environment': pushEnvironment,
                              'push_notification_provider': platform,
                            },
                          ),
                          jsonrpc: '2.0',
                        );
                        GlobalLogger().i(
                          'attachCallMessage :: ${attachCallMessage.toJson()}',
                        );
                        txSocket.send(jsonEncode(attachCallMessage));
                        _isCallFromPush = false;
                        _pushMetaData = null;
                        clearPushMetaData();
                      }
                      _registered = true;
                      _updateConnectionStatus();

                      // Persist reconnect session identifiers and attempt any
                      // pending startup reattachment (VSDK-418). The captured
                      // voice_sdk_id survives the push-path clear above.
                      unawaited(
                        _persistReconnectSession(
                          voiceSdkIdOverride: registeredVoiceSdkId,
                        ),
                      );
                      unawaited(_attemptPendingReattach());
                    }
                    break;
                  }
                case GatewayState.failed:
                  {
                    GlobalLogger().i(
                      'GATEWAY REGISTRATION FAILED :: ${stateMessage.toString()}',
                    );
                    gatewayState = GatewayState.failed;
                    _invalidateGatewayResponseTimer();

                    // Attempt reconnection if autoReconnect is enabled and retry limit not reached
                    if (_autoReconnectLogin &&
                        _connectRetryCounter < Constants.retryConnectTime) {
                      _connectRetryCounter++;
                      GlobalLogger().i(
                        'Attempting reconnection :: attempt $_connectRetryCounter / ${Constants.retryConnectTime}',
                      );
                      _attemptReconnection();
                    } else {
                      final error = TelnyxSocketError(
                        errorCode: TelnyxErrorConstants.gatewayFailedErrorCode,
                        errorMessage: TelnyxErrorConstants.gatewayFailedError,
                      );
                      onSocketErrorReceived(error);
                      // Structured error alongside legacy callback (VSDK-415).
                      emitStructuredErrorCode(
                        TelnyxErrorCodes.gatewayFailed,
                        message: TelnyxErrorConstants.gatewayFailedError,
                      );
                    }
                    break;
                  }
                case GatewayState.failWait:
                  {
                    GlobalLogger().i(
                      'GATEWAY FAIL_WAIT :: ${stateMessage.toString()}',
                    );
                    gatewayState = GatewayState.failWait;

                    // Attempt reconnection if autoReconnect is enabled and retry limit not reached
                    if (_autoReconnectLogin &&
                        _connectRetryCounter < Constants.retryConnectTime) {
                      _connectRetryCounter++;
                      GlobalLogger().i(
                        'Attempting reconnection :: attempt $_connectRetryCounter / ${Constants.retryConnectTime}',
                      );
                      _attemptReconnection();
                    } else {
                      _invalidateGatewayResponseTimer();
                      const failWaitMessage =
                          'Gateway registration has received fail wait response';
                      final error = TelnyxSocketError(
                        errorCode: TelnyxErrorConstants.gatewayFailedErrorCode,
                        errorMessage: failWaitMessage,
                      );
                      onSocketErrorReceived(error);
                      // Structured error alongside legacy callback (VSDK-415).
                      emitStructuredErrorCode(
                        TelnyxErrorCodes.gatewayFailed,
                        message: failWaitMessage,
                      );
                    }
                    break;
                  }
                case GatewayState.unreged:
                  {
                    GlobalLogger().i(
                      'GATEWAY UNREGED :: ${stateMessage.toString()}',
                    );
                    gatewayState = GatewayState.unreged;
                    break;
                  }
                case GatewayState.register:
                  {
                    _logger.log(
                      LogLevel.info,
                      'GATEWAY REGISTERING :: ${stateMessage.toString()}',
                    );
                    gatewayState = GatewayState.register;
                    break;
                  }
                case GatewayState.unregister:
                  {
                    GlobalLogger().i(
                      'GATEWAY UNREGISTERED :: ${stateMessage.toString()}',
                    );
                    gatewayState = GatewayState.unregister;
                    break;
                  }
                case GatewayState.attached:
                  {
                    GlobalLogger().i(
                      'GATEWAY ATTACHED :: ${stateMessage.toString()}',
                    );
                    break;
                  }
                default:
                  {
                    GlobalLogger().i('$stateMessage');
                  }
              }

              // Handle updateMedia response - check the raw JSON data directly
              try {
                final Map<String, dynamic> rawData = jsonDecode(
                  data.toString(),
                );
                if (rawData.containsKey('result') && rawData['result'] is Map) {
                  final resultMap = rawData['result'] as Map<String, dynamic>;
                  if (resultMap['action'] == 'updateMedia') {
                    GlobalLogger().i('Received updateMedia response');

                    final updateMediaResponse = UpdateMediaResponse.fromJson(
                      resultMap,
                    );

                    // Find the call and handle the response
                    final callId = updateMediaResponse.callID;
                    final call = calls[callId];
                    if (call?.peerConnection != null) {
                      await call!.peerConnection!.handleUpdateMediaResponse(
                        updateMediaResponse,
                      );
                    }
                  } else {
                    GlobalLogger().i('Not an updateMedia response');
                  }
                }
              } catch (e) {
                GlobalLogger().e('Error parsing updateMedia response: $e');
              }
            }
          } else if (messageJson.containsKey('method')) {
            //Received Telnyx Method Message
            final ReceivedMessage clientReadyMessage = ReceivedMessage.fromJson(
              messageJson,
            );
            if (clientReadyMessage.voiceSdkId != null) {
              GlobalLogger().i(
                'VoiceSdkID :: ${clientReadyMessage.voiceSdkId}',
              );
              _pushMetaData = PushMetaData(
                callerNumber: null,
                callerName: null,
                voiceSdkId: clientReadyMessage.voiceSdkId,
              );
            } else {
              GlobalLogger().e('VoiceSdkID not found');
            }
            GlobalLogger().i(
              'Received WebSocket message - Contains Method :: $messageJson',
            );
            switch (messageJson['method']) {
              case SocketMethod.ping:
                {
                  final result = Result(message: 'PONG', sessid: sessid);
                  final pongMessage = PongMessage(
                    jsonrpc: JsonRPCConstant.jsonrpc,
                    id: const Uuid().v4(),
                    result: result,
                  );
                  final String jsonPongMessage = jsonEncode(pongMessage);
                  txSocket.send(jsonPongMessage);
                  break;
                }
              case SocketMethod.clientReady:
                {
                  if (gatewayState != GatewayState.reged) {
                    GlobalLogger().i('Retrieving Gateway state...');
                    if (_waitingForReg) {
                      _requestGatewayStatus();
                      _gatewayResponseTimer = Timer(
                        Duration(milliseconds: Constants.gatewayResponseDelay),
                        () {
                          if (_isTornDown) return;

                          if (_registrationRetryCounter <
                              Constants.retryRegisterTime) {
                            if (_waitingForReg) {
                              _onMessage(data);
                            }
                            _registrationRetryCounter++;
                          } else {
                            GlobalLogger().i('GATEWAY REGISTRATION TIMEOUT');
                            final error = TelnyxSocketError(
                              errorCode:
                                  TelnyxErrorConstants.gatewayTimeoutErrorCode,
                              errorMessage:
                                  TelnyxErrorConstants.gatewayTimeoutError,
                            );
                            onSocketErrorReceived(error);
                          }
                        },
                      );
                    }
                  } else {
                    final message = TelnyxMessage(
                      socketMethod: SocketMethod.clientReady,
                      message: clientReadyMessage,
                    );
                    onSocketMessageReceived.call(message);
                  }
                  break;
                }
              case SocketMethod.invite:
                {
                  GlobalLogger().i('INCOMING INVITATION :: $messageJson');
                  final ReceivedMessage invite = ReceivedMessage.fromJson(
                    messageJson,
                  );
                  final message = TelnyxMessage(
                    socketMethod: SocketMethod.invite,
                    message: invite,
                  );

                  final Call offerCall = _createCall()
                    ..callId = invite.inviteParams?.callID;
                  updateCall(offerCall);

                  // Register the incoming call with CallManager so the app can
                  // query callManager.hasActiveCall to decide how to handle it.
                  callManager.registerCall(offerCall);

                  // Mark invite received for latency tracking
                  if (offerCall.callId != null) {
                    latencyTracker
                      ..startCallTracking(
                        offerCall.callId!,
                        isOutbound: false,
                      )
                      ..markInviteReceived(offerCall.callId!);
                  }

                  onSocketMessageReceived.call(message);

                  offerCall.callHandler.changeState(CallState.ringing);
                  if (!_pendingAnswerFromPush) {
                    offerCall.playRingtone(_ringtonePath);
                    offerCall.callHandler.changeState(CallState.ringing);
                  } else {
                    // Cancel the pending answer timeout since INVITE arrived
                    _cancelPendingAnswerTimeout();

                    // Auto-answer from push notification
                    if (callManager.hasActiveCall) {
                      callManager.holdCurrentAndAcceptIncoming(
                        offerCall.callId!,
                        (callId) => acceptCall(
                          invite.inviteParams!,
                          invite.inviteParams!.calleeIdName ?? '',
                          invite.inviteParams!.callerIdNumber ?? '',
                          'State',
                          answeredDeviceToken: _answeredDeviceToken,
                        ),
                      );
                    } else {
                      offerCall.acceptCall(
                        invite.inviteParams!,
                        invite.inviteParams!.calleeIdName ?? '',
                        invite.inviteParams!.callerIdNumber ?? '',
                        'State',
                        answeredDeviceToken: _answeredDeviceToken,
                      );
                    }
                    _pendingAnswerFromPush = false;
                    _answeredDeviceToken = null; // Clear after use
                    offerCall.callHandler.changeState(CallState.connecting);
                  }
                  if (_pendingDeclineFromPush) {
                    offerCall.endCall();
                    offerCall.callHandler.changeState(CallState.done);
                    _pendingDeclineFromPush = false;
                  }
                  break;
                }
              case SocketMethod.attach:
                {
                  GlobalLogger().i('ATTACH RECEIVED :: $messageJson');
                  final ReceivedMessage invite = ReceivedMessage.fromJson(
                    messageJson,
                  );
                  final message = TelnyxMessage(
                    socketMethod: SocketMethod.attach,
                    message: invite,
                  );

                  final attachCallId = invite.inviteParams?.callID;
                  // Preserve speakerphone state from existing call before reconnection
                  final existingCall = calls[attachCallId];
                  final bool wasSpeakerPhoneEnabled =
                      existingCall?.speakerPhone ?? false;
                  GlobalLogger().i(
                    'ATTACH :: Preserving speakerphone state: $wasSpeakerPhoneEnabled',
                  );

                  // If the SDK has active calls but this Attach's callID is
                  // not among them, the server is reattaching a session the
                  // client doesn't know about — emit warning (VSDK-397).
                  if (attachCallId != null &&
                      existingCall == null &&
                      calls.isNotEmpty) {
                    emitWarningCode(
                      TelnyxWarningCodes.unknownReattachedSession,
                      callId: attachCallId,
                      reason:
                          'Attach for callID $attachCallId does not match any active call (${calls.length} active)',
                      source: 'attach',
                    );
                  }

                  //play ringtone for web
                  final Call offerCall = _createCall()
                    ..callId = invite.inviteParams?.callID
                    ..speakerPhone =
                        wasSpeakerPhoneEnabled; // Preserve the state
                  updateCall(offerCall);

                  onSocketMessageReceived.call(message);

                  offerCall.acceptCall(
                    invite.inviteParams!,
                    invite.inviteParams!.calleeIdName ?? '',
                    invite.inviteParams!.callerIdNumber ?? '',
                    'State',
                    isAttach: true,
                  );
                  // Cancel the pending answer timeout since ATTACH arrived
                  _cancelPendingAnswerTimeout();
                  _pendingAnswerFromPush = false;
                  break;
                }
              case SocketMethod.media:
                {
                  GlobalLogger().i('MEDIA RECEIVED :: $messageJson');
                  final ReceivedMessage mediaReceived =
                      ReceivedMessage.fromJson(messageJson);
                  if (mediaReceived.inviteParams?.sdp != null) {
                    final Call? mediaCall =
                        calls[mediaReceived.inviteParams?.callID];
                    if (mediaCall == null) {
                      GlobalLogger().d(
                        'Error : Call  is null from Media Message',
                      );
                      _sendNoCallError();
                      return;
                    }
                    mediaCall.onRemoteSessionReceived(
                      mediaReceived.inviteParams?.sdp,
                    );
                    _earlySDP = true;
                  } else {
                    GlobalLogger().d('No SDP contained within Media Message');
                  }
                  break;
                }
              case SocketMethod.answer:
                {
                  GlobalLogger().i('INVITATION ANSWERED :: $messageJson');
                  final ReceivedMessage inviteAnswer = ReceivedMessage.fromJson(
                    messageJson,
                  );
                  final Call? answerCall =
                      calls[inviteAnswer.inviteParams?.callID];
                  if (answerCall == null) {
                    GlobalLogger().d(
                      'Error : Call  is null from Answer Message',
                    );
                    _sendNoCallError();
                    return;
                  }

                  // Extract and store the telnyx_call_control_id if present
                  if (inviteAnswer.inviteParams?.telnyxCallControlId != null) {
                    answerCall.telnyxCallControlId =
                        inviteAnswer.inviteParams?.telnyxCallControlId;
                    GlobalLogger().d(
                      'Telnyx Call Control ID :: ${answerCall.telnyxCallControlId}',
                    );
                  }

                  // Mark latency milestones for answer received
                  if (answerCall.callId != null) {
                    latencyTracker
                      ..markCallMilestone(
                        answerCall.callId!,
                        LatencyTracker.milestoneRemoteSdpReceived,
                      )
                      ..markCallAnsweredByRemote(answerCall.callId!);
                  }

                  final message = TelnyxMessage(
                    socketMethod: SocketMethod.answer,
                    message: inviteAnswer,
                  );
                  answerCall.callState = CallState.active;

                  updateCall(answerCall);

                  if (inviteAnswer.inviteParams?.sdp != null) {
                    answerCall.onRemoteSessionReceived(
                      inviteAnswer.inviteParams?.sdp,
                    );
                    onSocketMessageReceived(message);
                  } else if (_earlySDP) {
                    onSocketMessageReceived(message);
                  } else {
                    GlobalLogger().d(
                      'No SDP provided for Answer or Media, cannot initialize call',
                    );
                    answerCall.endCall();
                  }
                  _earlySDP = false;
                  answerCall.stopAudio();
                  break;
                }
              case SocketMethod.bye:
                {
                  GlobalLogger().i('BYE RECEIVED :: $messageJson');

                  // Parse the bye message to extract termination details
                  // Try to parse as ReceiveByeMessage first to get detailed termination info
                  ReceiveByeMessage? byeMessage;
                  CallTerminationReason? terminationReason;

                  try {
                    byeMessage = ReceiveByeMessage.fromJson(messageJson);

                    // Extract termination details if available
                    if (byeMessage.params != null) {
                      terminationReason = CallTerminationReason(
                        cause: byeMessage.params?.cause,
                        causeCode: byeMessage.params?.causeCode,
                        sipCode: byeMessage.params?.sipCode,
                        sipReason: byeMessage.params?.sipReason,
                      );

                      GlobalLogger().d(
                        'Call termination reason: $terminationReason',
                      );
                    }
                  } catch (e) {
                    GlobalLogger().e('Error parsing bye message: $e');
                  }

                  // Fall back to ReceivedMessage if ReceiveByeMessage parsing failed
                  final ReceivedMessage bye = ReceivedMessage.fromJson(
                    messageJson,
                  );
                  final String? callId =
                      byeMessage?.params?.callID ?? bye.inviteParams?.callID;

                  final Call? byeCall = calls[callId];
                  if (byeCall == null) {
                    GlobalLogger().d('Error: Call is null from Bye Message');
                    _sendNoCallError();
                    return;
                  }

                  final message = TelnyxMessage(
                    socketMethod: SocketMethod.bye,
                    message: bye,
                  );
                  onSocketMessageReceived(message);

                  byeCall.stopAudio();
                  byeCall.peerConnection?.closeSession();

                  // Update call state with termination reason
                  byeCall.callHandler.changeState(
                    CallState.done.withTerminationReason(terminationReason),
                  );

                  calls.remove(byeCall.callId);

                  // Cancel latency tracking for this call
                  if (byeCall.callId != null) {
                    latencyTracker.cancelCallTracking(byeCall.callId!);
                  }

                  // Let CallManager handle multi-call cleanup (auto-unhold held
                  // calls if this was the current active call).
                  if (byeCall.callId != null) {
                    callManager.onByeReceived(byeCall.callId!);
                  }
                  break;
                }
              case SocketMethod.ringing:
                {
                  GlobalLogger().i('RINGING RECEIVED :: $messageJson');
                  final ReceivedMessage ringing = ReceivedMessage.fromJson(
                    messageJson,
                  );
                  final Call? ringingCall = calls[ringing.inviteParams?.callID];
                  if (ringingCall == null) {
                    GlobalLogger().d(
                      'Error : Call  is null from Ringing Message',
                    );
                    _sendNoCallError();
                    return;
                  }

                  // Mark remote ringing for latency tracking (outbound calls)
                  if (ringingCall.callId != null) {
                    latencyTracker.markRemoteRinging(ringingCall.callId!);
                  }

                  // Send ringing acknowledgement
                  final ringingAckResult = RingingAckResult(
                    method: SocketMethod.ringing,
                  );
                  final ringingAckMessage = RingingAckMessage(
                    jsonrpc: JsonRPCConstant.jsonrpc,
                    id: ringing.id,
                    result: ringingAckResult,
                  );
                  final String jsonRingingAckMessage = jsonEncode(
                    ringingAckMessage,
                  );
                  GlobalLogger().i(
                    'Sending ringing acknowledgement: $jsonRingingAckMessage',
                  );
                  txSocket.send(jsonRingingAckMessage);

                  GlobalLogger().i(
                    'Telnyx Leg ID :: ${ringing.inviteParams?.telnyxLegId.toString()}',
                  );
                  final message = TelnyxMessage(
                    socketMethod: SocketMethod.ringing,
                    message: ringing,
                  );

                  // Process any queued ICE candidates after remote description is set (Android-style approach)
                  _processQueuedIceCandidates(ringing.inviteParams!.callID!);

                  onSocketMessageReceived(message);
                  break;
                }
              case SocketMethod.aiConversation:
                {
                  GlobalLogger().i('AI CONVERSATION RECEIVED :: $messageJson');
                  final ReceivedMessage aiConversation =
                      ReceivedMessage.fromJson(messageJson);

                  // Store widget settings if available
                  if (aiConversation.aiConversationParams?.widgetSettings !=
                      null) {
                    _currentWidgetSettings =
                        aiConversation.aiConversationParams!.widgetSettings;
                    GlobalLogger().i('Widget settings updated');
                  }

                  // Process message for transcript extraction
                  _processAiConversationForTranscript(
                    aiConversation.aiConversationParams,
                  );

                  final message = TelnyxMessage(
                    socketMethod: SocketMethod.aiConversation,
                    message: aiConversation,
                  );
                  onSocketMessageReceived(message);
                  break;
                }
              case SocketMethod.candidate:
                {
                  GlobalLogger().i(
                    'TRICKLE ICE CANDIDATE RECEIVED :: $messageJson',
                  );
                  final Map<String, dynamic> candidateData = jsonDecode(
                    data.toString(),
                  );

                  // Extract params from the candidate data
                  final Map<String, dynamic>? params = candidateData['params'];
                  if (params == null) {
                    GlobalLogger().w('Candidate message missing params');
                    break;
                  }

                  // Validate required fields
                  if (!CandidateUtils.hasRequiredCandidateFields(params)) {
                    GlobalLogger().w(
                      'Candidate message missing required fields (candidate, sdpMid, or sdpMLineIndex)',
                    );
                    break;
                  }

                  // Extract call ID using the utility method
                  final String? callId =
                      CandidateUtils.extractCallIdFromCandidate(params);
                  if (callId == null) {
                    GlobalLogger().w(
                      'Could not extract call ID from candidate message',
                    );
                    break;
                  }

                  // Normalize the candidate string to handle "a=" prefix issue
                  final String candidateStr = params['candidate'] as String;
                  final String normalizedCandidate =
                      CandidateUtils.normalizeCandidateString(candidateStr);

                  // Extract other required fields
                  final String sdpMid = params['sdpMid'] as String;
                  final int sdpMLineIndex = params['sdpMLineIndex'] as int;

                  // Process and queue the candidate (Android-style approach)
                  _processAndQueueCandidate(
                    callId,
                    sdpMid,
                    sdpMLineIndex,
                    normalizedCandidate,
                  );
                  break;
                }
              case SocketMethod.endOfCandidates:
                {
                  GlobalLogger().i(
                    'END OF CANDIDATES RECEIVED :: $messageJson',
                  );
                  final Map<String, dynamic> endData = jsonDecode(
                    data.toString(),
                  );

                  // Extract call ID
                  final String? callId =
                      endData['params']?['dialogParams']?['callID'];

                  if (callId != null) {
                    // Find the call and signal end of candidates
                    final Call? call = calls[callId];
                    if (call != null) {
                      GlobalLogger().i(
                        'End of candidates signaled for call: $callId',
                      );
                    } else {
                      GlobalLogger().w(
                        'Received endOfCandidates for unknown call: $callId',
                      );
                    }
                  }
                  break;
                }
            }
          } else {
            GlobalLogger().i('Received and ignored empty packet');
          }
        } catch (e) {
          GlobalLogger().e('Error parsing JSON: $e');
        }
      } else {
        GlobalLogger().i('Received and ignored empty packet');
      }
    }
  }

  /// Process AI conversation messages for transcript extraction
  void _processAiConversationForTranscript(AiConversationParams? params) {
    if (params?.type == null) return;

    switch (params!.type) {
      case 'conversation.item.created':
        _handleConversationItemCreated(params);
        break;
      case 'response.text.delta':
        _handleResponseTextDelta(params);
        break;
      default:
        // Other AI conversation message types are ignored for transcript
        break;
    }
  }

  /// Handle user speech transcript from conversation.item.created messages
  void _handleConversationItemCreated(AiConversationParams params) {
    if (params.item?.role != 'user' ||
        params.item?.status != 'completed' ||
        params.item?.content == null ||
        params.item?.id == null) {
      return; // Only handle completed user messages with content and an ID
    }

    final textParts = <String>[];
    final imageUrls = <String>[];

    for (final c in params.item!.content!) {
      final text = c.transcript ?? c.text;
      if (text != null && text.isNotEmpty) {
        textParts.add(text);
      }
      if (c.type == 'image_url') {
        final url = c.imageUrl?.url;
        if (url != null && url.isNotEmpty) {
          imageUrls.add(url);
        }
      }
    }

    final content = textParts.join(' ');
    final finalImageUrls = imageUrls.isNotEmpty ? imageUrls : null;

    if (content.isNotEmpty || finalImageUrls != null) {
      final transcriptItem = TranscriptItem(
        id: params.item!.id!,
        role: 'user',
        content: content,
        imageUrls: finalImageUrls,
        timestamp: DateTime.now(),
      );
      _transcript.add(transcriptItem);
      onTranscriptUpdate?.call(List.unmodifiable(_transcript));
    }
  }

  /// Handle AI response text deltas from response.text.delta messages
  void _handleResponseTextDelta(AiConversationParams params) {
    if (params.delta == null || params.itemId == null) return;

    final itemId = params.itemId!;
    final delta = params.delta!;

    // Initialize buffer for this response if not exists
    _assistantResponseBuffers.putIfAbsent(itemId, () => StringBuffer());
    _assistantResponseBuffers[itemId]!.write(delta);

    // Create or update transcript item for this response
    final existingIndex = _transcript.indexWhere((item) => item.id == itemId);
    final currentContent = _assistantResponseBuffers[itemId]!.toString();

    if (existingIndex >= 0) {
      // Update existing transcript item with accumulated content
      _transcript[existingIndex] = TranscriptItem(
        id: itemId,
        role: 'assistant',
        content: currentContent,
        timestamp: _transcript[existingIndex].timestamp,
      );
    } else {
      // Create new transcript item
      final transcriptItem = TranscriptItem(
        id: itemId,
        role: 'assistant',
        content: currentContent,
        timestamp: DateTime.now(),
      );
      _transcript.add(transcriptItem);
    }

    onTranscriptUpdate?.call(List.unmodifiable(_transcript));
  }

  void _sendNoCallError() {
    final error = TelnyxSocketError(
      errorCode: 404,
      errorMessage: TelnyxErrorConstants.callNotFound,
    );
    onSocketErrorReceived(error);
  }

  void _requestGatewayStatus() {
    if (_waitingForReg) {
      const uuid = Uuid();
      final gatewayRequestParams = GatewayRequestStateParams();
      final gatewayRequestMessage = GatewayRequestMessage(
        id: uuid.toString(),
        method: SocketMethod.gatewayState,
        params: gatewayRequestParams,
        jsonrpc: JsonRPCConstant.jsonrpc,
      );

      final String jsonGatewayRequestMessage = jsonEncode(
        gatewayRequestMessage,
      );

      txSocket.send(jsonGatewayRequestMessage);
    }
  }

  void _invalidateGatewayResponseTimer() {
    _gatewayResponseTimer?.cancel();
    _gatewayResponseTimer = null;
  }

  void _resetGatewayCounters() {
    _registrationRetryCounter = 0;
    _connectRetryCounter = 0;
    _waitingForReg = true;
    gatewayState = GatewayState.idle;
  }

  /// Attempts to reconnect to the socket using the stored configuration
  /// This method is called when gateway registration fails and autoReconnect is enabled
  /// It respects the _autoReconnectLogin setting and _connectRetryCounter limits
  void _attemptReconnection() {
    if (_isTornDown) return;
    final connectionGeneration = _connectionGeneration;

    // Set reconnecting status
    if (_connectionStatus != ConnectionStatus.reconnecting) {
      _connectionStatus = ConnectionStatus.reconnecting;
      onConnectionStateChanged?.call(_connectionStatus);
    }

    // Check if autoReconnect is enabled
    if (!_autoReconnectLogin) {
      GlobalLogger().i(
        'AutoReconnect is disabled, not attempting reconnection',
      );
      final error = TelnyxSocketError(
        errorCode: TelnyxErrorConstants.gatewayFailedErrorCode,
        errorMessage: 'AutoReconnect is disabled',
      );
      onSocketErrorReceived(error);
      return;
    }

    // Check if we've exceeded the retry limit
    if (_connectRetryCounter >= Constants.retryConnectTime) {
      GlobalLogger().e(
        'Maximum reconnection attempts reached ($_connectRetryCounter/${Constants.retryConnectTime})',
      );
      final error = TelnyxSocketError(
        errorCode: TelnyxErrorConstants.gatewayFailedErrorCode,
        errorMessage: 'Maximum reconnection attempts reached',
      );
      onSocketErrorReceived(error);
      // Structured error alongside legacy callback (VSDK-415).
      emitStructuredErrorCode(
        TelnyxErrorCodes.reconnectionExhausted,
        message: 'Maximum reconnection attempts reached',
      );
      return;
    }

    GlobalLogger().i(
      'Attempting reconnection $_connectRetryCounter/${Constants.retryConnectTime} (autoReconnect: $_autoReconnectLogin)',
    );

    // Add a small delay before attempting reconnection to avoid overwhelming the server
    // Use exponential backoff: base delay * (2 ^ retry_count)
    final delayMs =
        Constants.reconnectTimer * (1 << (_connectRetryCounter - 1));
    _scheduleConnectionTimer(
      Duration(milliseconds: delayMs),
      () {
        if (_storedCredentialConfig != null) {
          GlobalLogger().i(
            'Attempting reconnection with credential config (attempt $_connectRetryCounter)',
          );
          // Use the existing _reconnectToSocket method for consistency
          _reconnectToSocket();
        } else if (_storedTokenConfig != null) {
          GlobalLogger().i(
            'Attempting reconnection with token config (attempt $_connectRetryCounter)',
          );
          // Use the existing _reconnectToSocket method for consistency
          _reconnectToSocket();
        } else {
          GlobalLogger()
              .e('No stored configuration available for reconnection');
          final error = TelnyxSocketError(
            errorCode: TelnyxErrorConstants.gatewayFailedErrorCode,
            errorMessage: 'No stored configuration available for reconnection',
          );
          onSocketErrorReceived(error);
        }
      },
      generation: connectionGeneration,
    );
  }

  /// Gets the current socket connection metrics
  SocketConnectionMetrics getConnectionMetrics() {
    return txSocket.getConnectionMetrics();
  }
}

/// Production adapter that exposes a [TelnyxClient] to the
/// [SignalingHealthMonitor] via the [ISignalingHealthSession] interface
/// (VSDK-416). Owned by the client; delegates every call back to it.
class _TelnyxHealthSession implements ISignalingHealthSession {
  _TelnyxHealthSession(this._client);

  final TelnyxClient _client;

  @override
  bool? get isConnected => _client.isConnected();

  @override
  bool? hasActiveCall() => _client.activeCalls().isNotEmpty;

  @override
  void socketDisconnect() => _client._healthSocketDisconnect();

  @override
  TriggerIceRestartResult? triggerIceRestart(String? callId) =>
      _client._healthTriggerIceRestart(callId);

  @override
  void sendProbe() => _client._sendSignalingProbe();
}
