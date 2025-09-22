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
import 'package:telnyx_webrtc/peer/session.dart';
import 'package:telnyx_webrtc/peer/signaling_state.dart';
import 'package:telnyx_webrtc/telnyx_client.dart';
import 'package:telnyx_webrtc/utils/logging/global_logger.dart';
import 'package:telnyx_webrtc/utils/stats/webrtc_stats_reporter.dart';
import 'package:telnyx_webrtc/utils/version_utils.dart';
import 'package:telnyx_webrtc/tx_socket.dart'
    if (dart.library.js) 'package:telnyx_webrtc/tx_socket_web.dart';
import 'package:telnyx_webrtc/utils/string_utils.dart';
import 'package:uuid/uuid.dart';
import 'package:telnyx_webrtc/model/verto/receive/received_message_body.dart';
import 'package:telnyx_webrtc/model/call_state.dart';
import 'package:telnyx_webrtc/model/jsonrpc.dart';

/// Represents a peer in the WebRTC communication.
class Peer {
  /// The peer connection instance.
  RTCPeerConnection? peerConnection;

  /// The constructor for the Peer class.
  Peer(
    this._socket,
    this._debug,
    this._txClient,
    this._forceRelayCandidate,
    this._useTrickleIce,
  );

  final String _selfId = randomNumeric(6);

  final TxSocket _socket;
  final TelnyxClient _txClient;
  final bool _debug;
  final bool _forceRelayCandidate;
  final bool _useTrickleIce;
  WebRTCStatsReporter? _statsManager;

  // Add negotiation timer fields
  Timer? _negotiationTimer;
  DateTime? _lastCandidateTime;
  static const int _negotiationTimeout = 500; // 500ms timeout for negotiation
  Function()? _onNegotiationComplete;

  // Add trickle ICE end-of-candidates timer fields
  Timer? _trickleIceTimer;
  DateTime? _lastTrickleCandidateTime;
  static const int _trickleIceTimeout =
      3000; // 3 seconds timeout for trickle ICE
  String? _currentTrickleCallId;
  bool _endOfCandidatesSent = false;

  final Map<String, Session> _sessions = {};
  MediaStream? _localStream;
  final List<MediaStream> _remoteStreams = <MediaStream>[];

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
      final RTCSessionDescription s = await session.peerConnection!.createOffer(
        _dcConstraints,
      );
      await session.peerConnection!.setLocalDescription(s);

      if (session.remoteCandidates.isNotEmpty) {
        for (var candidate in session.remoteCandidates) {
          if (candidate.candidate != null) {
            GlobalLogger().i('adding $candidate');
            await session.peerConnection?.addCandidate(candidate);
          }
        }
        session.remoteCandidates.clear();
      }

      // With trickle ICE, send offer immediately without waiting for candidates
      if (_useTrickleIce) {
        String? sdpUsed = '';
        await session.peerConnection?.getLocalDescription().then(
              (value) => sdpUsed = value?.sdp.toString(),
            );

        // Add trickle ICE capability to SDP
        sdpUsed = _addTrickleIceToSdp(sdpUsed ?? '');

        final userAgent = await VersionUtils.getUserAgent();
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
        GlobalLogger()
            .i('Peer :: Sending INVITE with trickle ICE enabled (immediate)');
        _send(jsonInviteMessage);
      } else {
        // Traditional ICE gathering - wait for candidates
        await Future.delayed(const Duration(milliseconds: 500));

        String? sdpUsed = '';
        await session.peerConnection?.getLocalDescription().then(
              (value) => sdpUsed = value?.sdp.toString(),
            );

        Timer(const Duration(milliseconds: 500), () async {
          final userAgent = await VersionUtils.getUserAgent();
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

          _send(jsonInviteMessage);
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
    await _sessions[_selfId]?.peerConnection?.setRemoteDescription(
          RTCSessionDescription(sdp, 'answer'),
        );

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
    bool isAttach, {
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

    await session.peerConnection?.setRemoteDescription(
      RTCSessionDescription(invite.sdp, 'offer'),
    );

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
      preferredCodecs,
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
    List<Map<String, dynamic>>? preferredCodecs,
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

      final RTCSessionDescription s =
          await session.peerConnection!.createAnswer(_dcConstraints);
      await session.peerConnection!.setLocalDescription(s);

      if (_useTrickleIce) {
        // With trickle ICE, send answer immediately without waiting for candidates
        String? sdpUsed = '';
        await session.peerConnection?.getLocalDescription().then(
              (value) => sdpUsed = value?.sdp.toString(),
            );

        // Add trickle ICE capability to SDP
        sdpUsed = _addTrickleIceToSdp(sdpUsed ?? '');

        final userAgent = await VersionUtils.getUserAgent();
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
          preferredCodecs: preferredCodecs,
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
      } else {
        // Traditional ICE gathering - wait for candidates
        _lastCandidateTime = DateTime.now();
        _setOnNegotiationComplete(() async {
          String? sdpUsed = '';
          await session.peerConnection?.getLocalDescription().then(
                (value) => sdpUsed = value?.sdp.toString(),
              );

          final userAgent = await VersionUtils.getUserAgent();
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
            preferredCodecs: preferredCodecs,
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
    if (media != 'data') _localStream = await createStream(media);

    peerConnection = await createPeerConnection(
      {
        ..._buildIceConfiguration(),
        ...{'sdpSemantics': sdpSemantics},
      },
      _dcConstraints,
    );

    await startStats(callId, peerId, onCallQualityChange: onCallQualityChange);

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
      switch (state) {
        case RTCIceConnectionState.RTCIceConnectionStateConnected:
          final Call? currentCall = _txClient.calls[callId];
          currentCall?.callHandler.changeState(CallState.active);
          onCallStateChange?.call(newSession, CallState.active);

          // Automatically disable speaker phone to fix Android default behavior
          // This ensures calls start with earpiece audio routing by default on Android
          if (Platform.isAndroid) {
            Future.delayed(const Duration(milliseconds: 100), () {
              currentCall?.enableSpeakerPhone(false);
              GlobalLogger().i(
                'Peer :: Automatically disabled speaker phone for Android call',
              );
            });
          }

          // Cancel any reconnection timer for this call
          _txClient.onCallStateChangedToActive(callId);
        case RTCIceConnectionState.RTCIceConnectionStateFailed:
          peerConnection?.restartIce();
          return;
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

  /*void _closeSessionByPeerId(String peerId) {
    Session? session;
    _sessions.removeWhere((String key, Session sess) {
      var ids = key.split('-');
      session = sess;
      return peerId == ids[0] || peerId == ids[1];
    });
    if (session != null) {
      _closeSession(session!);
      onCallStateChange?.call(session!, CallState.CallStateBye);
    }
  }*/

  Future<void> _closeSession(Session session) async {
    _localStream?.getTracks().forEach((element) async {
      await element.stop();
    });
    await _localStream?.dispose();
    _localStream = null;
    await session.peerConnection?.close();
    await session.peerConnection?.dispose();
    await session.dc?.close();
    stopStats(session.sid);

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

  /// Starts the trickle ICE timer that sends endOfCandidates after 3 seconds of inactivity
  void _startTrickleIceTimer(String callId) {
    // If this is a new call or timer is not running, start it
    if (_currentTrickleCallId != callId || _trickleIceTimer == null) {
      _stopTrickleIceTimer(); // Clean up any existing timer
      _currentTrickleCallId = callId;
      _endOfCandidatesSent = false;
    }

    _lastTrickleCandidateTime = DateTime.now();

    // Start timer if not already running
    _trickleIceTimer ??= Timer.periodic(
      const Duration(milliseconds: 500), // Check every 500ms
      (timer) {
        if (_lastTrickleCandidateTime == null) return;

        final timeSinceLastCandidate = DateTime.now()
            .difference(_lastTrickleCandidateTime!)
            .inMilliseconds;
        GlobalLogger().d(
          'Time since last trickle candidate: ${timeSinceLastCandidate}ms',
        );

        if (timeSinceLastCandidate >= _trickleIceTimeout &&
            !_endOfCandidatesSent) {
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
    _lastTrickleCandidateTime = null;
    _currentTrickleCallId = null;
    _endOfCandidatesSent = false;
  }

  /// Sends end of candidates signal and cleans up timer
  void _sendEndOfCandidatesAndCleanup(String callId) {
    if (!_endOfCandidatesSent) {
      _sendEndOfCandidates(callId);
      _endOfCandidatesSent = true;
      _stopTrickleIceTimer();
      GlobalLogger().i(
        'Peer :: End of candidates sent and timer cleaned up for call $callId',
      );
    }
  }

  /// Adds trickle ICE capability to the SDP
  String _addTrickleIceToSdp(String sdp) {
    if (!_useTrickleIce) {
      return sdp;
    }

    // Check if ice-options:trickle already exists
    if (sdp.contains('a=ice-options:trickle')) {
      return sdp;
    }

    // Find the first media line (m=) and add ice-options after it
    final lines = sdp.split('\r\n');
    final modifiedLines = <String>[];
    bool addedTrickleIce = false;

    for (int i = 0; i < lines.length; i++) {
      modifiedLines.add(lines[i]);

      // Add ice-options:trickle after the first m= line
      if (!addedTrickleIce && lines[i].startsWith('m=')) {
        // Look for the next line that starts with 'a=' and add before it
        // or add immediately after the m= line
        int insertIndex = i + 1;
        while (
            insertIndex < lines.length && lines[insertIndex].startsWith('c=')) {
          modifiedLines.add(lines[insertIndex]);
          insertIndex++;
          i++;
        }
        modifiedLines.add('a=ice-options:trickle');
        addedTrickleIce = true;
      }
    }

    final modifiedSdp = modifiedLines.join('\r\n');
    GlobalLogger().i('Peer :: Added trickle ICE to SDP');
    return modifiedSdp;
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
}
