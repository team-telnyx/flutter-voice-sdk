import 'dart:convert';
import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:telnyx_flutter_webrtc/telnyx_webrtc/config.dart';
import 'package:telnyx_flutter_webrtc/telnyx_webrtc/model/verto/receive/incoming_invitation_body.dart';
import 'package:telnyx_flutter_webrtc/telnyx_webrtc/model/verto/send/invite_message_body.dart';
import 'package:telnyx_flutter_webrtc/telnyx_webrtc/tx_socket.dart'
    if (dart.library.js) 'package:telnyx_flutter_webrtc/telnyx_webrtc/tx_socket_web.dart';
import 'package:uuid/uuid.dart';

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

  final JsonEncoder _encoder = const JsonEncoder();
  final JsonDecoder _decoder = const JsonDecoder();

  // String _selfId = randomNumeric(6);
  final String _selfId = "123456";

  //SimpleWebSocket? _socket;
  final TxSocket _socket;

  //final _host;
  final _port = 8086;
  var _turnCredential;
  final Map<String, Session> _sessions = {};
  MediaStream? _localStream;
  final List<MediaStream> _remoteStreams = <MediaStream>[];

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

  final Map<String, dynamic> _config = {
    'mandatory': {},
    'optional': [
      {'DtlsSrtpKeyAgreement': true},
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
    }
  }

  void invite(
      String peerId,
      String media,
      String callerName,
      String callerNumber,
      String destinationNumber,
      String clientState,
      String callId,
      String telnyxSessionId) async {
    var sessionId = _selfId + '-' + peerId;

    Session session = await _createSession(null,
        peerId: peerId, sessionId: sessionId, media: media);

    _sessions[sessionId] = session;
    if (media == 'data') {
      _createDataChannel(session);
    }

    _createOffer(session, media, callerName, callerNumber, destinationNumber,
        clientState, callId, telnyxSessionId);
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
      String sessionId) async {
    try {
      RTCSessionDescription s =
          await session.peerConnection!.createOffer(_dcConstraints);
      await session.peerConnection!.setLocalDescription(s);
      String? sdpUsed = "";
      session.peerConnection
          ?.getLocalDescription()
          .then((value) => sdpUsed = value?.sdp.toString());
      Timer(const Duration(seconds: 1), () {
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
            video: false);
        var inviteParams = InviteParams(
            dialogParams: dialogParams,
            sdp: sdpUsed,
            sessionId: sessionId,
            userAgent: "Flutter-1.0");
        var inviteMessage = InviteMessage(
            id: const Uuid().toString(),
            jsonrpc: "2.0",
            method: "telnyx_rtc.invite",
            params: inviteParams);

        String jsonInviteMessage = jsonEncode(inviteMessage);

        _send(jsonInviteMessage);
      });
    } catch (e) {
      print(e.toString());
    }
  }

  void accept(
      String peerId,
      String media,
      String callerName,
      String callerNumber,
      String destinationNumber,
      String clientState,
      String callId, IncomingInvitation invite) async {
    var sessionId = _selfId + '-' + peerId;
    Session session = await _createSession(null,
        peerId: peerId, sessionId: sessionId, media: media);
    _sessions[sessionId] = session;

   await session.peerConnection?.setRemoteDescription(
        RTCSessionDescription(invite.params?.sdp, "offer"));

    session.peerConnection?.onSignalingState = (state) {
      print("New state $state");
      if (state == RTCSignalingState.RTCSignalingStateHaveRemoteOffer) {
        // answer here
        print("Answer here");
      }
    };

    _createAnswer(session, media, callerName, callerNumber, destinationNumber,
        clientState, callId);

    if (session.remoteCandidates.length > 0) {
      session.remoteCandidates.forEach((candidate) async {
        await session.peerConnection?.addCandidate(candidate);
      });
      session.remoteCandidates.clear();
    }

    onCallStateChange?.call(session, CallState.CallStateNew);
  }

  Future<void> _createAnswer(
      Session session,
      String media,
      String callerName,
      String callerNumber,
      String destinationNumber,
      String clientState,
      String callId) async {
    try {
      RTCSessionDescription s =
          await session.peerConnection!.createAnswer(_dcConstraints);
      await session.peerConnection!.setLocalDescription(s);

      String? sdpUsed = "";
      session.peerConnection
          ?.getLocalDescription()
          .then((value) => sdpUsed = value?.sdp.toString());

      Timer(const Duration(seconds: 1), () {
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
            video: false);
        var inviteParams = InviteParams(
            dialogParams: dialogParams,
            sdp: sdpUsed,
            sessionId: session.sid,
            userAgent: "Flutter-1.0");
        var answerMessage = InviteMessage(
            id: const Uuid().toString(),
            jsonrpc: "2.0",
            method: "telnyx_rtc.answer",
            params: inviteParams);

        String jsonAnswerMessage = jsonEncode(answerMessage);
        _send(jsonAnswerMessage);
      });
    } catch (e) {
      print(e.toString());
    }
  }

  void bye(String sessionId) {
    /* _send('bye', {
      'session_id': sessionId,
      'from': _selfId,
    });*/
    var sess = _sessions[sessionId];
    if (sess != null) {
      _closeSession(sess);
    }
  }

  /*void onMessage(message) async {
    Map<String, dynamic> mapData = message;
    var data = mapData['data'];

    switch (mapData['type']) {
      case 'peers':
        {
          List<dynamic> peers = data;
          if (onPeersUpdate != null) {
            Map<String, dynamic> event = Map<String, dynamic>();
            event['self'] = _selfId;
            event['peers'] = peers;
            onPeersUpdate?.call(event);
          }
        }
        break;
      case 'offer':
        {
          var peerId = data['from'];
          var description = data['description'];
          var media = data['media'];
          var sessionId = data['session_id'];
          var session = _sessions[sessionId];
          var newSession = await _createSession(session,
              peerId: peerId, sessionId: sessionId, media: media);
          _sessions[sessionId] = newSession;
          await newSession.pc?.setRemoteDescription(
              RTCSessionDescription(description['sdp'], description['type']));
          //await _createAnswer(newSession, media);
          if (newSession.remoteCandidates.isNotEmpty) {
            newSession.remoteCandidates.forEach((candidate) async {
              await newSession.pc?.addCandidate(candidate);
            });
            newSession.remoteCandidates.clear();
          }
          onCallStateChange?.call(newSession, CallState.CallStateNew);
        }
        break;
      case 'answer':
        {
          var description = data['description'];
          var sessionId = data['session_id'];
          var session = _sessions[sessionId];
          session?.pc?.setRemoteDescription(
              RTCSessionDescription(description['sdp'], description['type']));
        }
        break;
      case 'candidate':
        {
          var peerId = data['from'];
          var candidateMap = data['candidate'];
          var sessionId = data['session_id'];
          var session = _sessions[sessionId];
          RTCIceCandidate candidate = RTCIceCandidate(candidateMap['candidate'],
              candidateMap['sdpMid'], candidateMap['sdpMLineIndex']);

          if (session != null) {
            if (session.pc != null) {
              await session.pc?.addCandidate(candidate);
            } else {
              session.remoteCandidates.add(candidate);
            }
          } else {
            _sessions[sessionId] = Session(pid: peerId, sid: sessionId)
              ..remoteCandidates.add(candidate);
          }
        }
        break;
      case 'leave':
        {
          var peerId = data as String;
          _closeSessionByPeerId(peerId);
        }
        break;
      case 'bye':
        {
          var sessionId = data['session_id'];
          print('bye: ' + sessionId);
          var session = _sessions.remove(sessionId);
          if (session != null) {
            onCallStateChange?.call(session, CallState.CallStateBye);
            _closeSession(session);
          }
        }
        break;
      case 'keepalive':
        {
          print('keepalive response!');
        }
        break;
      default:
        break;
    }
  }*/

  Future<MediaStream> createStream(String media) async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': false
    };

    MediaStream stream =
        await navigator.mediaDevices.getUserMedia(mediaConstraints);
    onLocalStream?.call(stream);
    return stream;
  }

  /*Future<MediaStream> createStream(String media, bool userScreen) async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': userScreen ? false : true,
      'video': userScreen
          ? true
          : {
        'mandatory': {
          'minWidth':
          '640', // Provide your own width, height and frame rate here
          'minHeight': '480',
          'minFrameRate': '30',
        },
        'facingMode': 'user',
        'optional': [],
      }
    };

    MediaStream stream = userScreen
        ? await navigator.mediaDevices.getDisplayMedia(mediaConstraints)
        : await navigator.mediaDevices.getUserMedia(mediaConstraints);
    onLocalStream?.call(stream);
    return stream;
  }*/

  Future<Session> _createSession(Session? session,
      {required String peerId,
      required String sessionId,
      required String media}) async {
    var newSession = session ?? Session(sid: sessionId, pid: peerId);
    if (media != 'data') _localStream = await createStream(media);
    print(_iceServers);

    RTCPeerConnection peerConnection = await createPeerConnection({
      ..._iceServers,
      ...{'sdpSemantics': sdpSemantics}
    }, _dcConstraints);
    if (media != 'data') {
      switch (sdpSemantics) {
        case 'plan-b':
          peerConnection.onAddStream = (MediaStream stream) {
            onAddRemoteStream?.call(newSession, stream);
            _remoteStreams.add(stream);
          };
          await peerConnection.addStream(_localStream!);
          break;
        case 'unified-plan':
          // Unified-Plan
          peerConnection.onTrack = (event) {
            if (event.track.kind == 'video') {
              onAddRemoteStream?.call(newSession, event.streams[0]);
            } else if (event.track.kind == 'audio') {
              onAddRemoteStream?.call(newSession, event.streams[0]);
            }
          };
          _localStream!.getTracks().forEach((track) {
            peerConnection.addTrack(track, _localStream!);
          });
          break;
      }
    }
    peerConnection.onIceCandidate = (candidate) async {
      peerConnection.addCandidate(candidate);
      print("Adding Candidate!");
      if (candidate == null) {
        print('onIceCandidate: complete!');
        return;
      }
    };

    peerConnection.onIceConnectionState = (state) {
      print("ICE Connection State change :: $state");
    };

   /*peerConnection.onSignalingState = (state) {
      print("ICE Signalling state weeeeee :: $state");
      if (state == RTCSignalingState.RTCSignalingStateHaveRemoteOffer) {
        print("ICE Signalling state weeeeee :: $state");
        // answer here
      }
    };*/

    peerConnection.onRemoveStream = (stream) {
      onRemoveRemoteStream?.call(newSession, stream);
      _remoteStreams.removeWhere((it) {
        return (it.id == stream.id);
      });
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

  Future<void> _createDataChannel(Session session,
      {label: 'fileTransfer'}) async {
    RTCDataChannelInit dataChannelDict = RTCDataChannelInit()
      ..maxRetransmits = 30;
    RTCDataChannel channel =
        await session.peerConnection!.createDataChannel(label, dataChannelDict);
    _addDataChannel(session, channel);
  }

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

  void _closeSessionByPeerId(String peerId) {
    var session;
    _sessions.removeWhere((String key, Session sess) {
      var ids = key.split('-');
      session = sess;
      return peerId == ids[0] || peerId == ids[1];
    });
    if (session != null) {
      _closeSession(session);
      onCallStateChange?.call(session, CallState.CallStateBye);
    }
  }

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
