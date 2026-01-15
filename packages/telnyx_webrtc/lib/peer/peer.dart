import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:telnyx_webrtc/call.dart';
import 'package:telnyx_webrtc/config.dart';
import 'package:telnyx_webrtc/model/socket_method.dart';
import 'package:telnyx_webrtc/model/verto/send/invite_answer_message_body.dart';
import 'package:telnyx_webrtc/model/verto/send/candidate_message_body.dart';
import 'package:telnyx_webrtc/model/verto/send/end_of_candidates_message_body.dart';
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
import 'package:telnyx_webrtc/utils/sdp_utils.dart';
import 'package:telnyx_webrtc/utils/version_utils.dart';
import 'package:uuid/uuid.dart';
import 'package:telnyx_webrtc/model/verto/receive/received_message_body.dart';
import 'package:telnyx_webrtc/model/verto/receive/update_media_response.dart';
import 'package:telnyx_webrtc/model/call_state.dart';
import 'package:telnyx_webrtc/model/jsonrpc.dart';
import 'package:telnyx_webrtc/model/audio_codec.dart';
import 'package:telnyx_webrtc/model/audio_constraints.dart';
import 'package:telnyx_webrtc/utils/call_timing_benchmark.dart';

/// Represents a peer in the WebRTC communication.
class Peer {
  /// The peer connection instance.
  RTCPeerConnection? peerConnection;

  /// The constructor for the Peer class.
  ///
  /// [_socket] The socket connection for signaling.
  /// [_debug] Whether debug mode is enabled.
  /// [_txClient] The TelnyxClient instance.
  /// [_forceRelayCandidate] Whether to force TURN relay candidates.
  /// [_useTrickleIce] Whether to use trickle ICE.
  /// [_audioConstraints] Optional audio constraints.
  /// [providedTurn] Optional custom TURN server URL. Defaults to production.
  /// [providedStun] Optional custom STUN server URL. Defaults to production.
  /// [initialMuteState] Whether to start the call muted.
  Peer(
    this._socket,
    this._debug,
    this._txClient,
    this._forceRelayCandidate,
    this._useTrickleIce, [
    this._audioConstraints,
    String? providedTurn,
    String? providedStun,
    bool initialMuteState = false,
  ])  : _providedTurn = providedTurn ?? DefaultConfig.defaultTurn,
        _providedStun = providedStun ?? DefaultConfig.defaultStun,
        _initialMuteState = initialMuteState;

  final String _selfId = randomNumeric(6);

  final TxSocket _socket;
  final TelnyxClient _txClient;
  final bool _debug;
  final bool _forceRelayCandidate;
  final bool _useTrickleIce;
  final AudioConstraints? _audioConstraints;
  final String _providedTurn;
  final String _providedStun;
  final bool _initialMuteState;
  WebRTCStatsReporter? _statsManager;

  // Add negotiation timer fields
  Timer? _negotiationTimer;
  DateTime? _lastCandidateTime;
  static const int _negotiationTimeout = 300; // 300ms timeout for negotiation
  Function()? _onNegotiationComplete;

  // Add trickle ICE end-of-candidates timer fields
  Timer? _trickleIceTimer;
  static const int _trickleIceTimeout = 500; // 500ms timeout for trickle ICE
  String? _currentTrickleCallId;
  bool _endOfCandidatesSent = false;

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

  Map<String, dynamic> get _iceServers => {
        'iceServers': [
          {
            'url': _providedStun,
            'username': DefaultConfig.username,
            'credential': DefaultConfig.password,
          },
          {
            'url': _providedTurn,
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

  /// Sets the microphone mute state to a specific value.
  ///
  /// [muted] True to mute the microphone, false to unmute.
  void setMuteState(bool muted) {
    if (_localStream != null) {
      _localStream!.getAudioTracks()[0].enabled = !muted;
      GlobalLogger().d('Peer :: Microphone mute state set to: $muted');
    } else {
      GlobalLogger().d('Peer :: No local stream :: Unable to set mute state');
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

      // With trickle ICE, create offer without waiting for ICE gathering
      if (_useTrickleIce) {
        // Create offer with proper constraints but don't wait for ICE candidate gathering
        final RTCSessionDescription s =
            await session.peerConnection!.createOffer(
          _dcConstraints,
        );
        CallTimingBenchmark.mark('offer_created');

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

        // For trickle ICE, we set the local description but don't wait for candidates
        await session.peerConnection!.setLocalDescription(
          RTCSessionDescription(sdpToUse, s.type),
        );
        CallTimingBenchmark.mark('local_offer_sdp_set');

        // Get the SDP immediately - it should not contain candidates yet
        String? sdpUsed = s.sdp;

        // Add trickle ICE capability to SDP
        sdpUsed =
            SdpUtils.addTrickleIceCapability(sdpUsed ?? '', _useTrickleIce);

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
          trickle: true, // Set trickle flag
        );
        final inviteMessage = InviteAnswerMessage(
          id: const Uuid().v4(),
          jsonrpc: JsonRPCConstant.jsonrpc,
          method: SocketMethod.invite,
          params: inviteParams,
        );

        final String jsonInviteMessage = jsonEncode(inviteMessage);
        GlobalLogger().i(
          'Peer :: Sending INVITE with trickle ICE enabled (no candidate gathering)',
        );
        _send(jsonInviteMessage);
        CallTimingBenchmark.mark('invite_sent');
      } else {
        // Traditional ICE gathering - use negotiation timer
        final RTCSessionDescription s =
            await session.peerConnection!.createOffer(
          _dcConstraints,
        );
        CallTimingBenchmark.mark('offer_created');
        await session.peerConnection!.setLocalDescription(s);
        CallTimingBenchmark.mark('local_offer_sdp_set');

        if (session.remoteCandidates.isNotEmpty) {
          for (var candidate in session.remoteCandidates) {
            if (candidate.candidate != null) {
              GlobalLogger().i('adding $candidate');
              await session.peerConnection?.addCandidate(candidate);
            }
          }
          session.remoteCandidates.clear();
        }

        _lastCandidateTime = DateTime.now();
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
            trickle: false, // Set trickle flag to false for traditional ICE
          );
          final inviteMessage = InviteAnswerMessage(
            id: const Uuid().v4(),
            jsonrpc: JsonRPCConstant.jsonrpc,
            method: SocketMethod.invite,
            params: inviteParams,
          );

          final String jsonInviteMessage = jsonEncode(inviteMessage);
          CallTimingBenchmark.mark('ice_gathering_complete');
          _send(jsonInviteMessage);
          CallTimingBenchmark.mark('invite_sent');
        });
      }
    } catch (e) {
      GlobalLogger().e('Peer :: $e');
    }
  }

  /// Sets the remote session description when an answer is received.
  ///
  /// [sdp] The SDP string of the remote description.
  void remoteSessionReceived(String sdp) async {
    CallTimingBenchmark.start(isOutbound: true);
    await _sessions[_selfId]?.peerConnection?.setRemoteDescription(
          RTCSessionDescription(sdp, 'answer'),
        );
    CallTimingBenchmark.mark('remote_answer_sdp_set');

    // Process any queued candidates after setting remote SDP
    final session = _sessions[_selfId];
    if (session != null && session.remoteCandidates.isNotEmpty) {
      GlobalLogger()
          .i('Peer :: Processing queued remote candidates after remote SDP');
      for (var candidate in session.remoteCandidates) {
        if (candidate.candidate != null) {
          GlobalLogger()
              .i('Peer :: Adding queued candidate: ${candidate.candidate}');
          await session.peerConnection?.addCandidate(candidate);
        }
      }
      session.remoteCandidates.clear();
      GlobalLogger().i('Peer :: Cleared queued candidates after processing');
    }
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
    CallTimingBenchmark.start();
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
    CallTimingBenchmark.mark('remote_sdp_set');

    // Process any queued candidates after setting remote SDP
    if (session.remoteCandidates.isNotEmpty) {
      GlobalLogger().i(
        'Peer :: Processing queued remote candidates after setting remote SDP in accept',
      );
      for (var candidate in session.remoteCandidates) {
        if (candidate.candidate != null) {
          GlobalLogger()
              .i('Peer :: Adding queued candidate: ${candidate.candidate}');
          await session.peerConnection?.addCandidate(candidate);
        }
      }
      session.remoteCandidates.clear();
      GlobalLogger()
          .i('Peer :: Cleared queued candidates after processing in accept');
    }

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
            if (_useTrickleIce) {
              // With trickle ICE, send all candidates immediately
              _sendTrickleCandidate(candidate, callId);
            } else {
              // Traditional ICE: filter and collect candidates
              final candidateString = candidate.candidate.toString();
              final isValidCandidate =
                  candidateString.contains('stun.telnyx.com') ||
                      candidateString.contains('turn.telnyx.com');

              if (isValidCandidate) {
                GlobalLogger()
                    .i('Peer :: Valid ICE candidate: $candidateString');
                // Only add valid candidates and reset timer
                await session.peerConnection?.addCandidate(candidate);
                _lastCandidateTime = DateTime.now();
              } else {
                GlobalLogger().i(
                  'Peer :: Ignoring non-STUN/TURN candidate: $candidateString',
                );
              }
            }
          } else if (_useTrickleIce) {
            // End of candidates signal for trickle ICE
            _sendEndOfCandidates(callId);
          }
        } else {
          // Still collect candidates if peerConnection is not ready yet
          session.remoteCandidates.add(candidate);
        }
      };

      if (_useTrickleIce) {
        // With trickle ICE, create answer without waiting for ICE gathering
        final RTCSessionDescription s =
            await session.peerConnection!.createAnswer(_dcConstraints);
        CallTimingBenchmark.mark('local_answer_created');

        // For trickle ICE, we set the local description but don't wait for candidates
        await session.peerConnection!.setLocalDescription(s);
        CallTimingBenchmark.mark('local_sdp_set');

        // Get the SDP immediately - it should not contain candidates yet
        String? sdpUsed = s.sdp;

        // Add trickle ICE capability to SDP
        sdpUsed =
            SdpUtils.addTrickleIceCapability(sdpUsed ?? '', _useTrickleIce);

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
          trickle: true, // Set trickle flag
        );
        final answerMessage = InviteAnswerMessage(
          id: const Uuid().v4(),
          jsonrpc: JsonRPCConstant.jsonrpc,
          method: isAttach ? SocketMethod.attach : SocketMethod.answer,
          params: inviteParams,
        );

        final String jsonAnswerMessage = jsonEncode(answerMessage);
        GlobalLogger()
            .i('Peer :: Sending ANSWER with trickle ICE enabled (immediate)');
        _send(jsonAnswerMessage);
        CallTimingBenchmark.mark('answer_sent');
      } else {
        // Traditional ICE gathering - wait for candidates
        final RTCSessionDescription s =
            await session.peerConnection!.createAnswer(_dcConstraints);
        await session.peerConnection!.setLocalDescription(s);

        _lastCandidateTime = DateTime.now();
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
            trickle: false, // Set trickle flag to false for traditional ICE
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
      }
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
      'audio': (_audioConstraints ?? AudioConstraints.enabled())
          .toMap(isAndroid: Platform.isAndroid),
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

    // Parallelize media stream and peer connection creation for faster setup
    if (media != 'data') {
      // Run both operations in parallel since they are independent
      final results = await Future.wait([
        createStream(media),
        createPeerConnection(
          {
            ..._buildIceConfiguration(),
            ...{'sdpSemantics': sdpSemantics},
          },
          _dcConstraints,
        ),
      ]);

      _localStream = results[0] as MediaStream;
      CallTimingBenchmark.mark('media_stream_acquired');

      peerConnection = results[1] as RTCPeerConnection;
      CallTimingBenchmark.mark('peer_connection_created');

      // Apply initial mute state if requested
      if (_initialMuteState && _localStream != null) {
        final audioTracks = _localStream!.getAudioTracks();
        if (audioTracks.isNotEmpty) {
          audioTracks[0].enabled = false;
          GlobalLogger()
              .d('Peer :: Applied initial mute state on stream creation');
        }
      }
    } else {
      // Data-only mode: just create peer connection
      peerConnection = await createPeerConnection(
        {
          ..._buildIceConfiguration(),
          ...{'sdpSemantics': sdpSemantics},
        },
        _dcConstraints,
      );
      CallTimingBenchmark.mark('peer_connection_created');
    }

    // Start stats asynchronously (non-blocking) to avoid delaying call setup
    unawaited(
      startStats(callId, peerId, onCallQualityChange: onCallQualityChange),
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
      if (candidate.candidate != null) {
        if (_useTrickleIce) {
          // With trickle ICE, send ALL candidates immediately (host, srflx, relay)
          GlobalLogger().i(
            'Peer :: Sending trickle ICE candidate: ${candidate.candidate}',
          );
          CallTimingBenchmark.markFirstCandidate();
          _sendTrickleCandidate(candidate, callId);

          // Reset the trickle ICE timer when a candidate is generated
          _startTrickleIceTimer(callId);
        } else {
          // Traditional ICE: filter and collect candidates
          final candidateString = candidate.candidate.toString();
          final isValidCandidate =
              candidateString.contains('stun.telnyx.com') ||
                  candidateString.contains('turn.telnyx.com');

          if (isValidCandidate) {
            GlobalLogger().i('Peer :: Valid ICE candidate: $candidateString');
            // Add valid candidates for traditional ICE gathering
            await peerConnection?.addCandidate(candidate);
          } else {
            GlobalLogger().i(
              'Peer :: Ignoring non-STUN/TURN candidate: $candidateString',
            );
          }
        }
      } else {
        GlobalLogger().i('Peer :: onIceCandidate: complete!');
        if (_useTrickleIce) {
          // Send end of candidates signal when gathering completes naturally
          _sendEndOfCandidatesAndCleanup(callId);
        }
      }
    };

    peerConnection?.onIceConnectionState = (state) {
      GlobalLogger().i('Peer :: ICE Connection State change :: $state');
      // Benchmark all ICE connection state transitions
      CallTimingBenchmark.mark('ice_state_${state.name}');
      _previousIceConnectionState = state;
      switch (state) {
        case RTCIceConnectionState.RTCIceConnectionStateConnected:
          CallTimingBenchmark.end();
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

    peerConnection?.onConnectionState = (state) {
      GlobalLogger().i('Peer :: Peer Connection State change :: $state');
      CallTimingBenchmark.mark('peer_state_${state.name}');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        final Call? currentCall = _txClient.calls[callId];
        currentCall?.callHandler.changeState(CallState.active);
        onCallStateChange?.call(newSession, CallState.active);
        CallTimingBenchmark.end();
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

    // Clean up trickle ICE timer when session is closed
    _stopTrickleIceTimer();
  }

  /// Sets a callback to be invoked when ICE negotiation is complete
  void _setOnNegotiationComplete(Function() callback) {
    _onNegotiationComplete = callback;
    _startNegotiationTimer();
  }

  /// Starts the negotiation timer that checks for ICE candidate timeout
  void _startNegotiationTimer() {
    _negotiationTimer?.cancel();
    _negotiationTimer = Timer.periodic(
      const Duration(milliseconds: _negotiationTimeout),
      (timer) {
        if (_lastCandidateTime == null) return;

        final timeSinceLastCandidate =
            DateTime.now().difference(_lastCandidateTime!).inMilliseconds;
        GlobalLogger().d(
          'Time since last candidate: ${timeSinceLastCandidate}ms',
        );

        if (timeSinceLastCandidate >= _negotiationTimeout) {
          GlobalLogger().d('Negotiation timeout reached');
          _onNegotiationComplete?.call();
          _stopNegotiationTimer();
        }
      },
    );
  }

  /// Stops and cleans up the negotiation timer
  void _stopNegotiationTimer() {
    _negotiationTimer?.cancel();
    _negotiationTimer = null;
  }

  /// Starts/resets the trickle ICE timer that sends endOfCandidates after inactivity
  /// Uses a single delayed timer instead of periodic polling for better efficiency.
  void _startTrickleIceTimer(String callId) {
    // If this is a new call, initialize the call ID and reset flags
    if (_currentTrickleCallId != callId) {
      _currentTrickleCallId = callId;
      _endOfCandidatesSent = false;
    }

    // Cancel existing timer and start a fresh one (resets on each candidate)
    _trickleIceTimer?.cancel();
    _trickleIceTimer = Timer(
      const Duration(milliseconds: _trickleIceTimeout),
      () {
        if (!_endOfCandidatesSent && _currentTrickleCallId != null) {
          GlobalLogger()
              .i('Trickle ICE timeout reached - sending end of candidates');
          _sendEndOfCandidatesAndCleanup(_currentTrickleCallId!);
        }
      },
    );
  }

  /// Stops and cleans up the trickle ICE timer
  void _stopTrickleIceTimer() {
    _trickleIceTimer?.cancel();
    _trickleIceTimer = null;
    _currentTrickleCallId = null;
    _endOfCandidatesSent = false;
  }

  /// Sends end of candidates signal and cleans up timer
  void _sendEndOfCandidatesAndCleanup(String callId) {
    if (!_endOfCandidatesSent) {
      CallTimingBenchmark.mark('ice_gathering_complete');
      _sendEndOfCandidates(callId);
      _endOfCandidatesSent = true;
      _stopTrickleIceTimer();
      GlobalLogger().i(
        'Peer :: End of candidates sent and timer cleaned up for call $callId',
      );
    }
  }

  /// Sends a trickle ICE candidate to the remote peer
  void _sendTrickleCandidate(RTCIceCandidate candidate, String callId) {
    try {
      // Ensure sdpMid and sdpMLineIndex are set correctly for audio m-line
      final candidateParams = CandidateParams(
        dialogParams: CandidateDialogParams(callID: callId),
        candidate: candidate.candidate,
        sdpMid: candidate.sdpMid ?? '0', // Default to '0' for audio m-line
        sdpMLineIndex:
            candidate.sdpMLineIndex ?? 0, // Default to 0 for audio m-line
      );

      final candidateMessage = CandidateMessage(
        id: const Uuid().v4(),
        jsonrpc: JsonRPCConstant.jsonrpc,
        method: SocketMethod.candidate,
        params: candidateParams,
      );

      final String jsonCandidateMessage = jsonEncode(candidateMessage);
      GlobalLogger().i(
        'Peer :: Sending trickle ICE candidate: ${candidate.candidate} (sdpMid: ${candidateParams.sdpMid}, sdpMLineIndex: ${candidateParams.sdpMLineIndex})',
      );
      _send(jsonCandidateMessage);
    } catch (e) {
      GlobalLogger().e('Peer :: Error sending trickle ICE candidate: $e');
    }
  }

  /// Sends end of candidates signal to the remote peer
  void _sendEndOfCandidates(String callId) {
    try {
      final endOfCandidatesParams = EndOfCandidatesParams(
        dialogParams: EndOfCandidatesDialogParams(callID: callId),
      );

      final endOfCandidatesMessage = EndOfCandidatesMessage(
        id: const Uuid().v4(),
        jsonrpc: JsonRPCConstant.jsonrpc,
        method: SocketMethod.endOfCandidates,
        params: endOfCandidatesParams,
      );

      final String jsonEndOfCandidatesMessage =
          jsonEncode(endOfCandidatesMessage);
      GlobalLogger().i('Peer :: Sending end of candidates signal');
      _send(jsonEndOfCandidatesMessage);
    } catch (e) {
      GlobalLogger().e('Peer :: Error sending end of candidates: $e');
    }
  }

  /// Handles a remote ICE candidate received via trickle ICE
  void handleRemoteCandidate(
    String callId,
    String candidateStr,
    String sdpMid,
    int sdpMLineIndex,
  ) {
    try {
      GlobalLogger().i(
        'Peer :: Handling remote candidate for call $callId: $candidateStr',
      );

      // Find the session for this call
      final Session? session = _sessions[_selfId];

      if (session != null && session.peerConnection != null) {
        // Create RTCIceCandidate from the received candidate string
        final candidate = RTCIceCandidate(
          candidateStr,
          sdpMid,
          sdpMLineIndex,
        );

        // Add the candidate to the peer connection
        session.peerConnection!.addCandidate(candidate).then((_) {
          GlobalLogger().i('Peer :: Successfully added remote candidate');
        }).catchError((error) {
          GlobalLogger().e('Peer :: Error adding remote candidate: $error');
        });
      } else {
        GlobalLogger().w(
          'Peer :: No session or peer connection available for call $callId',
        );
        // Store the candidate for later if session is not ready yet
        final Session? pendingSession = _sessions[_selfId];
        if (pendingSession != null) {
          pendingSession.remoteCandidates.add(
            RTCIceCandidate(
              candidateStr,
              sdpMid,
              sdpMLineIndex,
            ),
          );
          GlobalLogger()
              .i('Peer :: Stored remote candidate for later processing');
        }
      }
    } catch (e) {
      GlobalLogger().e('Peer :: Error handling remote candidate: $e');
    }
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

        // Start negotiation timer
        _startNegotiationTimer();
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
