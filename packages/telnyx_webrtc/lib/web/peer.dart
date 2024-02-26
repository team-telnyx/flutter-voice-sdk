import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:telnyx_webrtc/config.dart';
import 'package:telnyx_webrtc/model/socket_method.dart';
import 'package:telnyx_webrtc/model/verto/send/invite_answer_message_body.dart';
import 'package:telnyx_webrtc/tx_socket.dart'
    if (dart.library.js) 'package:telnyx_webrtc/tx_socket_web.dart';
import 'package:uuid/uuid.dart';
import 'package:logger/logger.dart';

import 'package:telnyx_webrtc/model/verto/receive/received_message_body.dart';

import '../model/jsonrpc.dart';

enum SignalingState {
  ConnectionOpen,
  ConnectionClosed,
  ConnectionError,
}

enum CallState {
  CallStateNew,
  CallStateRinging,
  CallStateInvite,
  CallStateConnected,
  CallStateBye,
}

class Session {
  Session({required this.sid, required this.pid});

  String pid;
  String sid;
  RTCPeerConnection? peerConnection;
  RTCDataChannel? dc;
  List<RTCIceCandidate> remoteCandidates = [];
}

class Peer {
  Peer(this._socket);

  final _logger = Logger();

  final String _selfId = randomNumeric(6);

  final TxSocket _socket;
  final Map<String, Session> _sessions = {};
  MediaStream? _localStream;
  final List<MediaStream> _remoteStreams = <MediaStream>[];

  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  Function(SignalingState state)? onSignalingStateChange;
  Function(Session session, CallState state)? onCallStateChange;
  Function(MediaStream stream)? onLocalStream;
  Function(Session session, MediaStream stream)? onAddRemoteStream;
  Function(Session session, MediaStream stream)? onRemoveRemoteStream;
  Function(dynamic event)? onPeersUpdate;
  Function(Session session, RTCDataChannel dc, RTCDataChannelMessage data)?
      onDataChannelMessage;
  Function(Session session, RTCDataChannel dc)? onDataChannel;

  String get sdpSemantics =>
      WebRTC.platformIsWindows ? 'plan-b' : 'unified-plan';

  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {
        'url': DefaultConfig.defaultStun,
        'username': DefaultConfig.username,
        'credential': DefaultConfig.password
      },
      {
        'url': DefaultConfig.defaultTurn,
        'username': DefaultConfig.username,
        'credential': DefaultConfig.password
      },
    ]
  };

  final Map<String, dynamic> _dcConstraints = {
    'mandatory': {
      'OfferToReceiveAudio': true,
      'OfferToReceiveVideo': false,
    },
    'optional': [
      {'DtlsSrtpKeyAgreement': true},
    ],
  };

  close() async {
    await _cleanSessions();
    _socket.close();
  }

  void muteUnmuteMic() {
    if (_localStream != null) {
      bool enabled = _localStream!.getAudioTracks()[0].enabled;
      _localStream!.getAudioTracks()[0].enabled = !enabled;
    } else {
      _logger.d("Peer :: No local stream :: Unable to Mute / Unmute");
    }
  }


  void enableSpeakerPhone(bool enable) {
    if (kIsWeb) {
      _logger.d("Peer :: Speaker Enabled :: $enable");
      _localStream!.getAudioTracks().first.enableSpeakerphone(enable);
      return;
    }
    if (_localStream != null) {
      _localStream!.getAudioTracks()[0].enableSpeakerphone(enable);
      _logger.d("Peer :: Speaker Enabled :: $enable");
    } else {
      _logger.d("Peer :: No local stream :: Unable to toggle speaker mode");
    }
  }

  void invite(
      String callerName,
      String callerNumber,
      String destinationNumber,
      String clientState,
      String callId,
      String telnyxSessionId,
      Map<String, String> customHeaders) async {
    var sessionId = _selfId;

    Session session = await _createSession(null,
        peerId: "0", sessionId: sessionId, media: "audio");

    _sessions[sessionId] = session;

    _createOffer(session, "audio", callerName, callerNumber, destinationNumber,
        clientState, callId, telnyxSessionId, customHeaders);
    onCallStateChange?.call(session, CallState.CallStateInvite);
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
      Map<String, String> customHeaders) async {
    try {
      RTCSessionDescription s =
          await session.peerConnection!.createOffer(_dcConstraints);
      await session.peerConnection!.setLocalDescription(s);

      if (session.remoteCandidates.isNotEmpty) {
        for (var candidate in session.remoteCandidates) {
          if (candidate.candidate != null) {
            _logger.i("adding $candidate");
            await session.peerConnection?.addCandidate(candidate);
          }
        }
        session.remoteCandidates.clear();
      }

      await Future.delayed(const Duration(milliseconds: 500));

      String? sdpUsed = "";
      session.peerConnection
          ?.getLocalDescription()
          .then((value) => sdpUsed = value?.sdp.toString());

      Timer(const Duration(milliseconds: 500), () {
        var dialogParams = DialogParams(
            attach: false,
            audio: true,
            callID: callId,
            callerIdName: callerName,
            callerIdNumber: callerNumber,
            clientState: clientState,
            destinationNumber: destinationNumber,
            remoteCallerIdName: "",
            screenShare: false,
            useStereo: false,
            userVariables: [],
            video: false,
            customHeaders: customHeaders);
        var inviteParams = InviteParams(
            dialogParams: dialogParams,
            sdp: sdpUsed,
            sessid: sessionId,
            userAgent: "Flutter-1.0");
        var inviteMessage = InviteAnswerMessage(
            id: const Uuid().v4(),
            jsonrpc: JsonRPCConstant.jsonrpc,
            method: SocketMethod.INVITE,
            params: inviteParams);

        String jsonInviteMessage = jsonEncode(inviteMessage);

        _send(jsonInviteMessage);
      });
    } catch (e) {
      _logger.e("Peer :: $e");
    }
  }

  void remoteSessionReceived(String sdp) async {
    await _sessions[_selfId]
        ?.peerConnection
        ?.setRemoteDescription(RTCSessionDescription(sdp, "answer"));
  }

  void accept(
      String callerName,
      String callerNumber,
      String destinationNumber,
      String clientState,
      String callId,
      IncomingInviteParams invite,
      Map<String, String> customHeaders) async {
    var sessionId = _selfId;
    Session session = await _createSession(null,
        peerId: "0", sessionId: sessionId, media: "audio");
    _sessions[sessionId] = session;

    await session.peerConnection
        ?.setRemoteDescription(RTCSessionDescription(invite.sdp, "offer"));

    _createAnswer(session, "audio", callerName, callerNumber, destinationNumber,
        clientState, callId, customHeaders);

    onCallStateChange?.call(session, CallState.CallStateNew);
  }

  Future<void> _createAnswer(
      Session session,
      String media,
      String callerName,
      String callerNumber,
      String destinationNumber,
      String clientState,
      String callId,
      Map<String, String> customHeaders) async {
    try {
      session.peerConnection?.onIceCandidate = (candidate) async {
        if (session.peerConnection != null) {
          _logger.i("Peer :: Add Ice Candidate!");
          if (candidate.candidate != null) {
            await session.peerConnection?.addCandidate(candidate);
          }
        } else {
          session.remoteCandidates.add(candidate);
        }
      };

      RTCSessionDescription s =
          await session.peerConnection!.createAnswer(_dcConstraints);
      await session.peerConnection!.setLocalDescription(s);

      await Future.delayed(const Duration(milliseconds: 500));

      String? sdpUsed = "";
      session.peerConnection
          ?.getLocalDescription()
          .then((value) => sdpUsed = value?.sdp.toString());

      Timer(const Duration(milliseconds: 500), () {
        var dialogParams = DialogParams(
            attach: false,
            audio: true,
            callID: callId,
            callerIdName: callerNumber,
            callerIdNumber: callerNumber,
            clientState: clientState,
            destinationNumber: destinationNumber,
            remoteCallerIdName: "",
            screenShare: false,
            useStereo: false,
            userVariables: [],
            video: false,
            customHeaders: customHeaders);
        var inviteParams = InviteParams(
            dialogParams: dialogParams,
            sdp: sdpUsed,
            sessid: session.sid,
            userAgent: "Flutter-1.0");
        var answerMessage = InviteAnswerMessage(
            id: const Uuid().v4(),
            jsonrpc: JsonRPCConstant.jsonrpc,
            method: SocketMethod.ANSWER,
            params: inviteParams);

        String jsonAnswerMessage = jsonEncode(answerMessage);
        _send(jsonAnswerMessage);
      });
    } catch (e) {
      _logger.e("Peer :: $e");
    }
  }

  void closeSession(String sessionId) {
    var sess = _sessions[sessionId];
    if (sess != null) {
      _closeSession(sess);
    }
  }

  Future<MediaStream> createStream(String media) async {
    _logger.i("Peer :: Creating stream");
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': false
    };

    MediaStream stream =
        await navigator.mediaDevices.getUserMedia(mediaConstraints);
    onLocalStream?.call(stream);
    return stream;
  }

  Future<void> initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  Future<Session> _createSession(Session? session,
      {required String peerId,
      required String sessionId,
      required String media}) async {
    _logger.i('Web is running');

    var newSession = session ?? Session(sid: sessionId, pid: peerId);
    if (media != 'data') _localStream = await createStream(media);
    _localRenderer.srcObject = _localStream;
    initRenderers();
    RTCPeerConnection peerConnection = await createPeerConnection({
      ..._iceServers,
      ...{'sdpSemantics': sdpSemantics}
    });
    peerConnection.onTrack = (event) {
      if (event.track.kind == 'video') {
        _remoteRenderer.srcObject = event.streams[0];
      } else if (event.track.kind == 'audio') {
        _logger.i("Peer :: onTrack: audio");
        _remoteRenderer.srcObject = event.streams[0];
      }
    };

    _localStream?.getTracks().forEach((track) async {
      await peerConnection.addTrack(track, _localStream!);
      _logger.i('track.settings ${track.getSettings()}');
    });

    peerConnection.onIceCandidate = (candidate) async {
      if (!candidate.candidate.toString().contains("127.0.0.1")) {
        _logger.i("Peer :: Adding ICE candidate :: ${candidate.toString()}");
        peerConnection.addCandidate(candidate);
      } else {
        _logger.i("Peer :: Local candidate skipped!");
      }
      if (candidate.candidate == null) {
        _logger.i("Peer :: onIceCandidate: complete!");
        return;
      }
    };

    peerConnection.onIceConnectionState = (state) {
      _logger.i("Peer :: ICE Connection State change :: $state");
      switch (state) {
        case RTCIceConnectionState.RTCIceConnectionStateFailed:
          peerConnection.restartIce();
          return;
        default:
          return;
      }
    };

    peerConnection.onRemoveStream = (stream) {
      onRemoveRemoteStream?.call(newSession, stream);
      _remoteStreams.removeWhere((it) {
        return (it.id == stream.id);
      });
    };

    onAddRemoteStream = (newSession, stream) {
      _remoteStreams.add(stream);
      _logger.i("Peer  :: Remote stream added");
    };

    peerConnection.onDataChannel = (channel) {
      _addDataChannel(newSession, channel);
    };

    newSession.peerConnection = peerConnection;
    return newSession;
  }

  void _addDataChannel(Session session, RTCDataChannel channel) {
    channel.onDataChannelState = (e) {};
    channel.onMessage = (RTCDataChannelMessage data) {
      onDataChannelMessage?.call(session, channel, data);
    };
    session.dc = channel;
    onDataChannel?.call(session, channel);
  }

  /*Future<void> _createDataChannel(Session session,
      {label = 'fileTransfer'}) async {
    RTCDataChannelInit dataChannelDict = RTCDataChannelInit()
      ..maxRetransmits = 30;
    RTCDataChannel channel =
        await session.peerConnection!.createDataChannel(label, dataChannelDict);
    _addDataChannel(session, channel);
  }*/

  _send(event) {
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
    _sessions.forEach((key, sess) async {
      await sess.peerConnection?.close();
      await sess.dc?.close();
    });
    _sessions.clear();
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
    await session.dc?.close();
  }
}

int randomBetween(int from, int to) {
  if (from > to) throw Exception('$from cannot be > $to');
  var rand = Random();
  return ((to - from) * rand.nextDouble()).toInt() + from;
}

String randomString(int length, {int from = 33, int to = 126}) {
  return String.fromCharCodes(
      List.generate(length, (index) => randomBetween(from, to)));
}

String randomNumeric(int length) => randomString(length, from: 48, to: 57);
