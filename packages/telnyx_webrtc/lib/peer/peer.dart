import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:telnyx_webrtc/call.dart';
import 'package:telnyx_webrtc/config.dart';
import 'package:telnyx_webrtc/model/socket_method.dart';
import 'package:telnyx_webrtc/model/verto/send/invite_answer_message_body.dart';
import 'package:telnyx_webrtc/model/verto/send/modify_message_body.dart';
import 'package:telnyx_webrtc/peer/session.dart';
import 'package:telnyx_webrtc/peer/signaling_state.dart';
import 'package:telnyx_webrtc/telnyx_client.dart';
import 'package:telnyx_webrtc/tx_socket.dart'
    if (dart.library.js) 'package:telnyx_webrtc/tx_socket_web.dart';
import 'package:telnyx_webrtc/utils/codec_utils.dart';
import 'package:telnyx_webrtc/utils/logging/global_logger.dart';
import 'package:telnyx_webrtc/utils/stats/webrtc_stats_reporter.dart';
import 'package:telnyx_webrtc/utils/string_utils.dart';
import 'package:telnyx_webrtc/utils/version_utils.dart';
import 'package:uuid/uuid.dart';
import 'package:telnyx_webrtc/model/verto/receive/received_message_body.dart';
import 'package:telnyx_webrtc/model/verto/receive/update_media_response.dart';
import 'package:telnyx_webrtc/model/call_state.dart';
import 'package:telnyx_webrtc/model/jsonrpc.dart';
import 'package:telnyx_webrtc/model/audio_codec.dart';

/// Represents a peer in the WebRTC communication.
class Peer {
  /// The peer connection instance.
  RTCPeerConnection? peerConnection;

  /// The constructor for the Peer class.
  Peer(this._socket, this._debug, this._txClient, this._forceRelayCandidate);

  final String _selfId = randomNumeric(6);

  final TxSocket _socket;
  final TelnyxClient _txClient;
  final bool _debug;
  final bool _forceRelayCandidate;
  WebRTCStatsReporter? _statsManager;

  // Add negotiation timer fields
  Timer? _negotiationTimer;

  static const int _negotiationTimeout = 300; // 300ms timeout for negotiation
  Function()? _onNegotiationComplete;

  final Map<String, Session> _sessions = {};

  /// Current active session
  Session? currentSession;
  MediaStream? _localStream;
  final List<MediaStream> _remoteStreams = <MediaStream>[];

  /// Track previous ICE connection state for renegotiation logic
  RTCIceConnectionState? _previousIceConnectionState;

  /// Callback for when the signaling state changes.
  Function(SignalingState state)? onSignalingStateChange;

  /// Callback for when the call state changes.
  Function(Session session, CallState state)? onCallStateChange;

  /// Callback for when the local media stream is available.
  Function(MediaStream stream)? onLocalStream;

  /// Callback for when a remote media stream is added.
  Function(Session session, MediaStream stream)? onAddRemoteStream;

  /// Callback for when a remote media stream is removed.
  Function(Session session, MediaStream stream)? onRemoveRemoteStream;

  /// Callback for when peer updates occur.
  Function(dynamic event)? onPeersUpdate;

  /// Callback for when a data channel message is received.
  Function(Session session, RTCDataChannel dc, RTCDataChannelMessage data)?
      onDataChannelMessage;

  /// Callback for when a data channel is available.
  Function(Session session, RTCDataChannel dc)? onDataChannel;

  /// Callback for call quality metrics updates.
  CallQualityCallback? onCallQualityChange;

  /// Gets the SDP semantics based on the platform.
  /// Returns 'plan-b' for Windows and 'unified-plan' for other platforms.
  String get sdpSemantics =>
      WebRTC.platformIsWindows ? 'plan-b' : 'unified-plan';

  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {
        'url': DefaultConfig.defaultStun,
        'username': DefaultConfig.username,
        'credential': DefaultConfig.password,
      },
      {
        'url': DefaultConfig.defaultTurn,
        'username': DefaultConfig.username,
        'credential': DefaultConfig.password,
      },
    ],
  };

  /// Builds the ICE configuration based on the forceRelayCandidate setting
  Map<String, dynamic> _buildIceConfiguration() {
    final config = Map<String, dynamic>.from(_iceServers);

    if (_forceRelayCandidate) {
      // When forceRelayCandidate is enabled, only use TURN relay candidates
      config['iceTransportPolicy'] = 'relay';
      GlobalLogger().i(
        'Peer :: Force relay candidate enabled - using TURN relay only',
      );
    }

    return config;
  }

  final Map<String, dynamic> _dcConstraints = {
    'mandatory': {'OfferToReceiveAudio': true, 'OfferToReceiveVideo': false},
    'optional': [
      {'DtlsSrtpKeyAgreement': true},
    ],
  };

  /// Closes the peer connection and cleans up sessions.
  void close() async {
    await _cleanSessions();
  }

  /// Mutes or unmutes the microphone.
  void muteUnmuteMic() {
    if (_localStream != null) {
      final bool enabled = _localStream!.getAudioTracks()[0].enabled;
      _localStream!.getAudioTracks()[0].enabled = !enabled;
    } else {
      GlobalLogger().d('Peer :: No local stream :: Unable to Mute / Unmute');
    }
  }

  /// Enables or disables the speakerphone.
  ///
  /// [enable] True to enable speakerphone, false to disable.
  void enableSpeakerPhone(bool enable) {
    if (_localStream != null) {
      _localStream!.getAudioTracks()[0].enableSpeakerphone(enable);
    } else {
      GlobalLogger().d(
        'Peer :: No local stream :: Unable to toggle speaker mode',
      );
    }
  }

  /// Initiates a call.
  ///
  /// [callerName] The name of the caller.
  /// [callerNumber] The number of the caller.
  /// [destinationNumber] The number to call.
  /// [clientState] The client state.
  /// [callId] The unique ID of the call.
  /// [telnyxSessionId] The Telnyx session ID.
  /// [customHeaders] Custom headers to include in the invite.
  /// [preferredCodecs] Optional list of preferred audio codecs.
  void invite(
    String callerName,
    String callerNumber,
    String destinationNumber,
    String clientState,
    String callId,
    String telnyxSessionId,
    Map<String, String> customHeaders, {
    List<Map<String, dynamic>>? preferredCodecs,
  }) async {
    final sessionId = _selfId;

    final Session session = await _createSession(
      null,
      peerId: Uuid().v4(),
      sessionId: sessionId,
      callId: callId,
      media: 'audio',
    );

    _sessions[sessionId] = session;

    await _createOffer(
      session,
      'audio',
      callerName,
      callerNumber,
      destinationNumber,
      clientState,
      callId,
      telnyxSessionId,
      customHeaders,
      preferredCodecs,
    );

    // Start stats collection now that local description is set
    await startStats(
      callId,
      session.pid,
      onCallQualityChange: onCallQualityChange,
    );

    onCallStateChange?.call(session, CallState.newCall);
  }

  Future<void> _createOffer(
    Session session,
    String media,
    String callerName,
    String callerNumber,
    String destinationNumber,
    String clientState,
    String callId,
    String sessionId,
    Map<String, String> customHeaders,
    List<Map<String, dynamic>>? preferredCodecs,
  ) async {
    try {
      // For iOS/Web: Apply codec preferences before creating offer
      // For Android: We'll modify SDP after creation (setCodecPreferences doesn't work)
      if (preferredCodecs != null &&
          preferredCodecs.isNotEmpty &&
          !Platform.isAndroid) {
        GlobalLogger().d(
          'Peer :: Applying codec preferences via setCodecPreferences (iOS/Web)',
        );
        await applyAudioCodecPreferences(
          session.peerConnection!,
          preferredCodecs,
        );
      }

      // Set up ICE candidate handler to track candidates and update timer
      session.peerConnection?.onIceCandidate = (candidate) async {
        if (session.peerConnection != null) {
          GlobalLogger().i(
            'Peer :: onIceCandidate in _createOffer received: ${candidate.candidate}',
          );
          if (candidate.candidate != null) {
            // Restart timer for all candidates to keep gathering active
            _restartNegotiationTimer();
          }
        } else {
          // Still collect candidates if peerConnection is not ready yet
          session.remoteCandidates.add(candidate);
        }
      };

      final RTCSessionDescription s = await session.peerConnection!.createOffer(
        _dcConstraints,
      );

      // For Android: Modify SDP to filter codecs
      String? sdpToUse = s.sdp;
      if (preferredCodecs != null &&
          preferredCodecs.isNotEmpty &&
          Platform.isAndroid) {
        GlobalLogger().d(
          'Peer :: Filtering SDP codecs for Android (setCodecPreferences not supported)',
        );
        final audioCodecs =
            preferredCodecs.map((m) => AudioCodec.fromJson(m)).toList();
        sdpToUse = CodecUtils.filterSdpCodecs(s.sdp!, audioCodecs);
      }

      await session.peerConnection!.setLocalDescription(
        RTCSessionDescription(sdpToUse, s.type),
      );

      if (session.remoteCandidates.isNotEmpty) {
        for (var candidate in session.remoteCandidates) {
          if (candidate.candidate != null) {
            GlobalLogger().i('adding $candidate');
            await session.peerConnection?.addCandidate(candidate);
          }
        }
        session.remoteCandidates.clear();
      }

      // Start ICE candidate gathering and wait for negotiation to complete
      _setOnNegotiationComplete(() async {
        String? sdpUsed = '';
        await session.peerConnection?.getLocalDescription().then(
              (value) => sdpUsed = value?.sdp.toString(),
            );

        final userAgent = VersionUtils.getUserAgent();
        final dialogParams = DialogParams(
          attach: false,
          audio: true,
          callID: callId,
          callerIdName: callerName,
          callerIdNumber: callerNumber,
          clientState: clientState,
          destinationNumber: destinationNumber,
          remoteCallerIdName: '',
          screenShare: false,
          useStereo: false,
          userVariables: [],
          video: false,
          customHeaders: customHeaders,
          preferredCodecs: preferredCodecs,
        );
        final inviteParams = InviteParams(
          dialogParams: dialogParams,
          sdp: sdpUsed,
          sessid: sessionId,
          userAgent: userAgent,
        );
        final inviteMessage = InviteAnswerMessage(
          id: const Uuid().v4(),
          jsonrpc: JsonRPCConstant.jsonrpc,
          method: SocketMethod.invite,
          params: inviteParams,
        );

        final String jsonInviteMessage = jsonEncode(inviteMessage);

        _send(jsonInviteMessage);
      });
    } catch (e) {
      GlobalLogger().e('Peer :: $e');
    }
  }

  /// Sets the remote session description when an answer is received.
  ///
  /// [sdp] The SDP string of the remote description.
  void remoteSessionReceived(String sdp) async {
    await _sessions[_selfId]?.peerConnection?.setRemoteDescription(
          RTCSessionDescription(sdp, 'answer'),
        );
  }

  /// Accepts an incoming call.
  ///
  /// [callerName] The name of the caller.
  /// [callerNumber] The number of the caller.
  /// [destinationNumber] The destination number (usually the current user's number).
  /// [clientState] The client state.
  /// [callId] The unique ID of the call.
  /// [invite] The incoming invite parameters.
  /// [customHeaders] Custom headers to include in the answer.
  /// [isAttach] Whether this is an attach call.
  void accept(
    String callerName,
    String callerNumber,
    String destinationNumber,
    String clientState,
    String callId,
    IncomingInviteParams invite,
    Map<String, String> customHeaders,
    bool isAttach,
  ) async {
    final sessionId = _selfId;
    final Session session = await _createSession(
      null,
      peerId: Uuid().v4(),
      sessionId: sessionId,
      callId: callId,
      media: 'audio',
    );
    _sessions[sessionId] = session;

    await session.peerConnection?.setRemoteDescription(
      RTCSessionDescription(invite.sdp, 'offer'),
    );

    await _createAnswer(
      session,
      'audio',
      callerName,
      callerNumber,
      destinationNumber,
      clientState,
      callId,
      customHeaders,
      isAttach,
    );

    // Start stats collection now that descriptions are set
    await startStats(
      callId,
      session.pid,
      onCallQualityChange: onCallQualityChange,
    );

    onCallStateChange?.call(session, CallState.active);
  }

  Future<void> _createAnswer(
    Session session,
    String media,
    String callerName,
    String callerNumber,
    String destinationNumber,
    String clientState,
    String callId,
    Map<String, String> customHeaders,
    bool isAttach,
  ) async {
    try {
      session.peerConnection?.onIceCandidate = (candidate) async {
        if (session.peerConnection != null) {
          GlobalLogger().i(
            'Peer :: onIceCandidate in _createAnswer received: ${candidate.candidate}',
          );
          if (candidate.candidate != null) {
            // Restart timer for all candidates to keep gathering active
            _restartNegotiationTimer();
          }
        } else {
          // Still collect candidates if peerConnection is not ready yet
          session.remoteCandidates.add(candidate);
        }
      };

      final RTCSessionDescription s =
          await session.peerConnection!.createAnswer(_dcConstraints);

      await session.peerConnection!.setLocalDescription(s);

      // Start ICE candidate gathering and wait for negotiation to complete
      _setOnNegotiationComplete(() async {
        String? sdpUsed = '';
        await session.peerConnection?.getLocalDescription().then(
              (value) => sdpUsed = value?.sdp.toString(),
            );

        final userAgent = VersionUtils.getUserAgent();
        final dialogParams = DialogParams(
          attach: false,
          audio: true,
          callID: callId,
          callerIdName: callerNumber,
          callerIdNumber: callerNumber,
          clientState: clientState,
          destinationNumber: destinationNumber,
          remoteCallerIdName: '',
          screenShare: false,
          useStereo: false,
          userVariables: [],
          video: false,
          customHeaders: customHeaders,
        );
        final inviteParams = InviteParams(
          dialogParams: dialogParams,
          sdp: sdpUsed,
          sessid: session.sid,
          userAgent: userAgent,
        );
        final answerMessage = InviteAnswerMessage(
          id: const Uuid().v4(),
          jsonrpc: JsonRPCConstant.jsonrpc,
          method: isAttach ? SocketMethod.attach : SocketMethod.answer,
          params: inviteParams,
        );

        final String jsonAnswerMessage = jsonEncode(answerMessage);
        _send(jsonAnswerMessage);
      });
    } catch (e) {
      GlobalLogger().e('Peer :: $e');
    }
  }

  /// Closes the current session.
  void closeSession() {
    final sess = _sessions[_selfId];
    if (sess != null) {
      GlobalLogger().i('Session end success');
      _closeSession(sess);
    } else {
      GlobalLogger().d('Session end failed');
    }
  }

  /// Creates a local media stream.
  ///
  /// [media] The type of media to create (e.g., 'audio').
  /// Returns a [Future] that completes with the [MediaStream].
  Future<MediaStream> createStream(String media) async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': false,
    };

    final MediaStream stream = await navigator.mediaDevices.getUserMedia(
      mediaConstraints,
    );

    onLocalStream?.call(stream);
    return stream;
  }

  Future<Session> _createSession(
    Session? session, {
    required String peerId,
    required String sessionId,
    required String callId,
    required String media,
  }) async {
    final newSession = session ?? Session(sid: sessionId, pid: peerId);
    currentSession = newSession;
    if (media != 'data') _localStream = await createStream(media);

    peerConnection = await createPeerConnection(
      {
        ..._buildIceConfiguration(),
        ...{'sdpSemantics': sdpSemantics},
      },
      _dcConstraints,
    );

    if (media != 'data') {
      switch (sdpSemantics) {
        case 'plan-b':
          peerConnection?.onAddStream = (MediaStream stream) {
            onAddRemoteStream?.call(newSession, stream);
            _remoteStreams.add(stream);
          };
          await peerConnection?.addStream(_localStream!);
          break;
        case 'unified-plan':
          // Unified-Plan
          peerConnection?.onTrack = (event) {
            if (event.track.kind == 'video') {
              onAddRemoteStream?.call(newSession, event.streams[0]);
            } else if (event.track.kind == 'audio') {
              onAddRemoteStream?.call(newSession, event.streams[0]);
            }
          };
          _localStream!.getTracks().forEach((track) {
            peerConnection?.addTrack(track, _localStream!);
          });
          break;
      }
    }

    peerConnection?.onIceCandidate = (candidate) async {
      GlobalLogger().i(
        'Peer :: onIceCandidate in _createSession received: ${candidate.candidate}',
      );
    };

    peerConnection?.onIceConnectionState = (state) {
      GlobalLogger().i('Peer :: ICE Connection State change :: $state');
      _previousIceConnectionState = state;
      switch (state) {
        case RTCIceConnectionState.RTCIceConnectionStateConnected:
          final Call? currentCall = _txClient.calls[callId];
          currentCall?.callHandler.changeState(CallState.active);
          onCallStateChange?.call(newSession, CallState.active);

          // Handle speakerphone state after ICE connection is established
          if (Platform.isAndroid) {
            Future.delayed(const Duration(milliseconds: 100), () {
              if (currentCall?.isReconnection == true) {
                // This is a reconnection - restore previous speakerphone state
                final bool shouldEnableSpeaker =
                    currentCall?.speakerPhone ?? false;
                currentCall?.enableSpeakerPhone(shouldEnableSpeaker);
                GlobalLogger().i(
                  'Peer :: Restored speakerphone state for Android reconnection: $shouldEnableSpeaker',
                );
              } else {
                // This is initial connection - always disable to fix Android bug
                // where speakerphone is enabled by default
                currentCall?.enableSpeakerPhone(false);
                GlobalLogger().i(
                  'Peer :: Automatically disabled speaker phone for Android call (initial connection)',
                );
              }
            });
          } else {
            // For iOS and other platforms, restore if enabled during reconnection
            final bool shouldEnableSpeaker = currentCall?.speakerPhone ?? false;
            if (shouldEnableSpeaker) {
              Future.delayed(const Duration(milliseconds: 100), () {
                currentCall?.enableSpeakerPhone(true);
                GlobalLogger().i(
                  'Peer :: Restored speakerphone state: enabled',
                );
              });
            }
          }

          // Cancel any reconnection timer for this call
          _txClient.onCallStateChangedToActive(callId);
        case RTCIceConnectionState.RTCIceConnectionStateFailed:
          if (_previousIceConnectionState ==
              RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
            GlobalLogger()
                .i('Peer :: ICE connection failed, starting renegotiation...');
            startIceRenegotiation(callId, newSession.sid);
            break;
          } else {
            GlobalLogger().d(
              'Peer :: ICE connection failed without prior disconnection, not renegotiating',
            );
            break;
          }
        case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
          _statsManager?.stopStatsReporting();
          return;
        default:
          return;
      }
    };

    peerConnection?.onRemoveStream = (stream) {
      onRemoveRemoteStream?.call(newSession, stream);
      _remoteStreams.removeWhere((it) {
        return (it.id == stream.id);
      });
    };

    peerConnection?.onDataChannel = (channel) {
      _addDataChannel(newSession, channel);
    };

    newSession.peerConnection = peerConnection;
    return newSession;
  }

  void _addDataChannel(Session session, RTCDataChannel channel) {
    channel
      ..onDataChannelState = (e) {}
      ..onMessage = (RTCDataChannelMessage data) {
        onDataChannelMessage?.call(session, channel, data);
      };
    session.dc = channel;
    onDataChannel?.call(session, channel);
  }

  /// Starts reporting WebRTC statistics.
  ///
  /// [callId] The ID of the call.
  /// [peerId] The ID of the peer.
  /// [onCallQualityChange] Callback for call quality updates.
  /// Returns a [Future] that completes with true if stats reporting started successfully, false otherwise.
  Future<bool> startStats(
    String callId,
    String peerId, {
    CallQualityCallback? onCallQualityChange,
  }) async {
    if (_debug == false) {
      GlobalLogger().d(
        'Peer :: Stats manager will not start. Debug mode not enabled on config',
      );
      return false;
    }

    if (peerConnection == null) {
      GlobalLogger().d('Peer connection null');
      return false;
    }

    _statsManager = WebRTCStatsReporter(
      _socket,
      peerConnection!,
      callId,
      peerId,
      _txClient.isDebug(),
      onCallQualityChange: onCallQualityChange,
    );
    await _statsManager?.startStatsReporting();

    return true;
  }

  /// Stops reporting WebRTC statistics for a specific call.
  ///
  /// [callId] The ID of the call to stop stats for.
  void stopStats(String callId) {
    if (_debug == false) {
      return;
    }
    _statsManager?.stopStatsReporting();
    GlobalLogger().i('Peer :: Stats Manager stopped for $callId');
  }

  void _send(event) {
    _socket.send(event);
  }

  Future<void> _cleanSessions() async {
    if (_localStream != null) {
      _localStream!.getTracks().forEach((element) async {
        await element.stop();
      });
      await _localStream!.dispose();
      _localStream = null;
    }
    _sessions
      ..forEach((key, sess) async {
        await sess.peerConnection?.close();
        await sess.dc?.close();
      })
      ..clear();
  }

  Future<void> _closeSession(Session session) async {
    _localStream?.getTracks().forEach((element) async {
      await element.stop();
    });
    await _localStream?.dispose();
    _localStream = null;
    stopStats(session.sid);
    await session.peerConnection?.close();
    await session.peerConnection?.dispose();
    await session.dc?.close();
  }

  /// Sets a callback to be invoked when ICE negotiation is complete
  void _setOnNegotiationComplete(Function() callback) {
    _onNegotiationComplete = callback;
    _restartNegotiationTimer();
  }

  /// Restarts the negotiation timer (Debounce pattern)
  void _restartNegotiationTimer() {
    _negotiationTimer?.cancel();
    _negotiationTimer = Timer(
      const Duration(milliseconds: _negotiationTimeout),
      () {
        GlobalLogger().d('Negotiation timeout reached');
        final callback = _onNegotiationComplete;
        _onNegotiationComplete = null; // Clear to prevent duplicate calls
        callback?.call();
        _negotiationTimer = null;
      },
    );
  }

  /// Starts ICE renegotiation process when ICE connection fails
  Future<void> startIceRenegotiation(String callId, String sessionId) async {
    try {
      GlobalLogger().i('Peer :: Starting ICE renegotiation for call: $callId');
      if (_sessions[sessionId] != null) {
        onCallStateChange?.call(_sessions[sessionId]!, CallState.renegotiation);
        final peerConnection = _sessions[sessionId]?.peerConnection;
        if (peerConnection == null) {
          GlobalLogger()
              .e('Peer :: No peer connection found for session: $sessionId');
          return;
        }

        // Create constraints with IceRestart flag to force ICE restart
        final constraints = {
          'mandatory': {'IceRestart': true},
          'optional': [],
        };

        // Create new offer with ICE restart enabled
        final offer = await peerConnection.createOffer(constraints);

        // Set the local description with the new local SDP
        await peerConnection.setLocalDescription(offer);

        GlobalLogger().i(
          'Peer :: Created new offer with ICE restart, waiting for ICE candidates...',
        );

        // Set up callback for when negotiation is complete
        _setOnNegotiationComplete(() async {
          // Get the complete SDP with ICE candidates from the peer connection
          final localDescription = await peerConnection.getLocalDescription();
          if (localDescription != null && localDescription.sdp != null) {
            _sendUpdateMediaMessage(callId, sessionId, localDescription.sdp!);
          } else {
            GlobalLogger()
                .e('Peer :: No local description found with ICE candidates');
          }
        });
      } else {
        GlobalLogger().e('Peer :: No session found for ID: $sessionId');
      }
    } catch (e) {
      GlobalLogger().e('Peer :: Error during ICE renegotiation: $e');
    }
  }

  /// Sends the updateMedia modify message with the new SDP
  void _sendUpdateMediaMessage(String callId, String sessionId, String sdp) {
    try {
      GlobalLogger().i('Peer :: Sending updateMedia message for call: $callId');

      // Create dialog params with required callID field
      final dialogParams = DialogParams(
        callID: callId,
        customHeaders: {}, // Empty custom headers as required
      );

      final modifyMessage = ModifyMessage(
        id: const Uuid().v4(),
        jsonrpc: '2.0',
        method: 'telnyx_rtc.modify',
        params: ModifyParams(
          action: 'updateMedia',
          sessid: sessionId,
          dialogParams: dialogParams,
          sdp: sdp,
        ),
      );

      final jsonMessage = jsonEncode(modifyMessage.toJson());
      GlobalLogger().i('Peer :: Sending modify message: $jsonMessage');

      _socket.send(jsonMessage);
    } catch (e) {
      GlobalLogger().e('Peer :: Error sending updateMedia message: $e');
    }
  }

  /// Handles the updateMedia response from the server
  Future<void> handleUpdateMediaResponse(UpdateMediaResponse response) async {
    try {
      if (response.action != 'updateMedia') {
        GlobalLogger()
            .w('Peer :: Unexpected action in response: ${response.action}');
        return;
      }

      if (response.sdp.isEmpty) {
        GlobalLogger().e('Peer :: No SDP in updateMedia response');
        return;
      }

      final callId = response.callID;
      GlobalLogger()
          .i('Peer :: Received updateMedia response for call: $callId');

      final session = _sessions[_selfId];
      if (session == null) {
        GlobalLogger().e('Peer :: No session found for ID: $_selfId');
        return;
      }

      // Set the remote description to complete renegotiation
      final remoteDescription = RTCSessionDescription(response.sdp, 'answer');
      await session.peerConnection?.setRemoteDescription(remoteDescription);

      GlobalLogger().i(
        'Peer :: ICE renegotiation completed successfully for call: $callId',
      );
    } catch (e) {
      GlobalLogger().e('Peer :: Error handling updateMedia response: $e');
    }
  }

  /// Applies audio codec preferences to the peer connection's audio transceiver.
  /// This method must be called before creating an offer or answer to ensure the
  /// preferred codecs are negotiated in the correct order.
  ///
  /// [peerConnection] The RTCPeerConnection instance to apply preferences to
  /// [preferredCodecs] List of preferred audio codec maps in order of preference
  Future<void> applyAudioCodecPreferences(
    RTCPeerConnection peerConnection,
    List<Map<String, dynamic>>? preferredCodecs,
  ) async {
    if (preferredCodecs == null || preferredCodecs.isEmpty) {
      GlobalLogger().d(
        'Peer :: ApplyPreferredCodec :: No codec preferences provided, using defaults',
      );
      return;
    }

    try {
      GlobalLogger().d(
        'Peer :: ApplyPreferredCodec :: Attempting to apply ${preferredCodecs.length} codec preferences',
      );

      // Use CodecUtils to find the audio transceiver
      final audioTransceiver =
          await CodecUtils.findAudioTransceiver(peerConnection);

      if (audioTransceiver == null) {
        GlobalLogger().w(
          'Peer :: ApplyPreferredCodec :: No audio transceiver found, cannot apply codec preferences',
        );
        return;
      }

      GlobalLogger().d(
        'Peer :: ApplyPreferredCodec :: Audio transceiver found, converting codec maps to capabilities',
      );

      // Convert codec maps to capabilities
      final codecCapabilities =
          CodecUtils.convertAudioCodecMapsToCapabilities(preferredCodecs);

      if (codecCapabilities.isEmpty) {
        GlobalLogger().w(
          'Peer :: No valid codec capabilities created, using defaults',
        );
        return;
      }

      GlobalLogger().d(
        'Peer :: ApplyPreferredCodec :: Applying ${codecCapabilities.length} codec capabilities to transceiver',
      );

      // Apply codec preferences to transceiver
      await audioTransceiver.setCodecPreferences(codecCapabilities);

      GlobalLogger().d(
        'Peer :: Successfully applied codec preferences. Order: ${codecCapabilities.map((c) => c.mimeType).toList()}',
      );
    } catch (e) {
      GlobalLogger().e(
        'Peer :: Error applying codec preferences: $e',
      );
    }
  }
}
