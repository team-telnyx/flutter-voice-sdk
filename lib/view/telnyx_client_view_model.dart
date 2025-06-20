import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telnyx_flutter_webrtc/file_logger.dart';
import 'package:telnyx_flutter_webrtc/model/call_history_entry.dart';
import 'package:telnyx_flutter_webrtc/service/call_history_service.dart';
import 'package:telnyx_flutter_webrtc/utils/background_detector.dart';
import 'package:telnyx_flutter_webrtc/utils/theme.dart';
import 'package:telnyx_webrtc/call.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';
import 'package:telnyx_webrtc/model/call_termination_reason.dart';
import 'package:telnyx_webrtc/model/socket_method.dart';
import 'package:telnyx_webrtc/model/telnyx_message.dart';
import 'package:telnyx_webrtc/model/telnyx_socket_error.dart';
import 'package:telnyx_webrtc/model/verto/receive/received_message_body.dart';
import 'package:telnyx_webrtc/telnyx_client.dart';
import 'package:telnyx_webrtc/model/push_notification.dart';
import 'package:telnyx_webrtc/model/call_state.dart';
import 'package:telnyx_webrtc/model/call_quality_metrics.dart';
import 'package:telnyx_flutter_webrtc/utils/config_helper.dart';
import 'package:telnyx_flutter_webrtc/service/notification_service.dart';

enum CallStateStatus {
  disconnected,
  idle,
  ringing,
  ongoingInvitation,
  connectingToCall,
  ongoingCall,
}

class TelnyxClientViewModel with ChangeNotifier {
  final logger = Logger();
  final TelnyxClient _telnyxClient = TelnyxClient();

  bool _registered = false;
  bool _loggingIn = false;
  bool callFromPush = false;
  bool _speakerPhone = true;
  bool _mute = false;
  bool _hold = false;

  CredentialConfig? _credentialConfig;
  TokenConfig? _tokenConfig;
  IncomingInviteParams? _incomingInvite;
  CallQualityMetrics? _callQualityMetrics;

  String _localName = '';
  String _localNumber = '';

  // Call history tracking
  String? _currentCallDestination;
  CallDirection? _currentCallDirection;
  DateTime? _currentCallStartTime;

  // Call termination reason tracking
  CallTerminationReason? _lastTerminationReason;

  String? _errorDialogMessage;
  String? get errorDialogMessage => _errorDialogMessage;

  void _setErrorDialog(String message) {
    _errorDialogMessage = message;
    notifyListeners();
  }

  void clearErrorDialog() {
    _errorDialogMessage = null;
    notifyListeners();
  }

  bool get registered {
    return _registered;
  }

  bool get loggingIn {
    return _loggingIn;
  }

  bool get speakerPhoneState {
    return _speakerPhone;
  }

  CallQualityMetrics? get callQualityMetrics {
    return _callQualityMetrics;
  }

  bool get muteState {
    return _mute;
  }

  bool get holdState {
    return _hold;
  }

  String get sessionId {
    return _telnyxClient.sessid;
  }

  CallStateStatus _callState = CallStateStatus.disconnected;

  CallStateStatus get callState => _callState;

  set callState(CallStateStatus newState) {
    _callState = newState;
    notifyListeners();
  }

  Call? _currentCall;

  Call? get currentCall {
    return _telnyxClient.calls.values.firstOrNull;
  }

  IncomingInviteParams? get incomingInvitation {
    return _incomingInvite;
  }


  /// State flow for inbound audio levels list
  final List<double> _inboundAudioLevels = [];
  List<double> get inboundAudioLevels => List.unmodifiable(_inboundAudioLevels);

  /// State flow for outbound audio levels list  
  final List<double> _outboundAudioLevels = [];
  List<double> get outboundAudioLevels => List.unmodifiable(_outboundAudioLevels);

  /// Maximum number of audio levels to keep in memory
  static const int maxAudioLevels = 100;

  CallTerminationReason? get lastTerminationReason => _lastTerminationReason;

  void resetCallInfo() {
    logger.i('TxClientViewModel :: Reset Call Info');
    BackgroundDetector.ignore = false;
    _incomingInvite = null;
    _currentCall = null;
    _speakerPhone = false;
    _mute = false;
    _hold = false;
    callState = CallStateStatus.idle;
    _callQualityMetrics = null;
    setPushCallStatus(false);
    
    // Clear audio level lists
    _inboundAudioLevels.clear();
    _outboundAudioLevels.clear();
    
    // Reset call history tracking
    _currentCallDestination = null;
    _currentCallDirection = null;
    _currentCallStartTime = null;
    
    // Reset termination reason after a delay to allow UI to show it
    Timer(const Duration(seconds: 5), () {
      _lastTerminationReason = null;
      notifyListeners();
    });
    
    notifyListeners();
  }

  String? _getCurrentProfileId() {
    if (_credentialConfig != null) {
      return 'sip_${_credentialConfig!.sipUser.hashCode}';
    } else if (_tokenConfig != null) {
      return 'token_${_tokenConfig!.sipToken.hashCode}';
    }
    return null;
  }

  Future<void> _addCallToHistory({
    required String destination,
    required CallDirection direction,
    bool wasAnswered = false,
  }) async {
    final profileId = _getCurrentProfileId();
    if (profileId == null) return;

    final entry = CallHistoryEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      destination: destination,
      direction: direction,
      timestamp: DateTime.now(),
      wasAnswered: wasAnswered,
    );

    await CallHistoryService.addCallHistoryEntry(
      profileId: profileId,
      entry: entry,
    );
  }

  void setPushCallStatus(bool isFromPush) {
    callFromPush = isFromPush;

    if (isFromPush) {
      logger.i('Entering push call context.');
    } else {
      logger.i('Exiting push call context / Resetting state.');
      callState = CallStateStatus.idle;
    }
    notifyListeners();
  }

  void observeCurrentCall() {
    logger.i('TelnyxClientViewModel.observeCurrentCall: Setting up call observation for callId: ${currentCall?.callId}');
    
    // Set up call quality callback to receive metrics every 100ms
    currentCall?.onCallQualityChange = (metrics) {
      _callQualityMetrics = metrics;
      
      // Update audio level lists directly from metrics (now coming every 100ms)
      _inboundAudioLevels.add(metrics.inboundAudioLevel);
      while (_inboundAudioLevels.length > maxAudioLevels) {
        _inboundAudioLevels.removeAt(0);
      }

      _outboundAudioLevels.add(metrics.outboundAudioLevel);
      while (_outboundAudioLevels.length > maxAudioLevels) {
        _outboundAudioLevels.removeAt(0);
      }

      notifyListeners();
    };
    
    currentCall?.callHandler.onCallStateChanged = (CallState state) {
      logger.i(
        'TelnyxClientViewModel.observeCurrentCall: Call State changed to :: $state for callId: ${currentCall?.callId}',
      );
      switch (state) {
        case CallState.newCall:
          logger.i('New Call');
          break;
        case CallState.connecting:
          logger.i('Connecting');
          _callState = CallStateStatus.connectingToCall;
          notifyListeners();
          break;
        case CallState.ringing:
          if (_callState == CallStateStatus.connectingToCall) {
            // Ringing state as a result of an invitation after a push notification reaction - ignore invitation as we should be connecting and auto answering
            return;
          }
          _callState = CallStateStatus.ongoingInvitation;
          notifyListeners();
          break;
        case CallState.active:
          logger.i(
            'TelnyxClientViewModel.observeCurrentCall: Current call is Active. Call ID: ${currentCall?.callId}',
          );
          if (!kIsWeb && Platform.isIOS) {
            final String? callKitKnownUuid =
                _incomingInvite?.callID ?? currentCall?.callId;
            if (callKitKnownUuid != null && callKitKnownUuid.isNotEmpty) {
              logger.i(
                'TelnyxClientViewModel.observeCurrentCall: Calling FlutterCallkitIncoming.setCallConnected for UUID: $callKitKnownUuid',
              );
              FlutterCallkitIncoming.setCallConnected(callKitKnownUuid);
            } else {
              logger.w(
                'TelnyxClientViewModel.observeCurrentCall: Could not determine CallKit UUID to setCallConnected.',
              );
            }
          }

          _callState = CallStateStatus.ongoingCall;
          notifyListeners();
          break;
        case CallState.held:
          logger.i('Held');
          break;
        case CallState.done:
          logger.i('Call done : ${state.terminationReason}');
          
          // Store the termination reason for display
          _lastTerminationReason = state.terminationReason;
          
          // Save call to history
          if (_currentCallDestination != null && _currentCallDirection != null) {
            final wasAnswered = _callState == CallStateStatus.ongoingCall;
            _addCallToHistory(
              destination: _currentCallDestination!,
              direction: _currentCallDirection!,
              wasAnswered: wasAnswered,
            );
          }
          
          if (!kIsWeb) {
            if (currentCall?.callId != null || _incomingInvite != null) {
              FlutterCallkitIncoming.endCall(
                currentCall?.callId ?? _incomingInvite?.callID! ?? '',
              );
            }
          }
          break;
        case CallState.error:
          logger.i('error');
          _setErrorDialog(
            'An error occurred during the call: ${state.networkReason?.message}',
          );
          break;
        case CallState.reconnecting:
          logger.i('reconnecting - ${state.networkReason?.message}');
          break;
        case CallState.dropped:
          logger.i('dropped - ${state.networkReason?.message}');
          break;
      }
    };
  }

  Future<void> _saveCredentialsForAutoLogin(
    Config config,
  ) async {
    await _clearConfigForAutoLogin();
    final prefs = await SharedPreferences.getInstance();
    if (config is TokenConfig) {
      await prefs.setString('token', config.sipToken);
    } else if (config is CredentialConfig) {
      await prefs.setString('sipUser', config.sipUser);
      await prefs.setString('sipPassword', config.sipPassword);
    }
    await prefs.setString('sipName', config.sipCallerIDName);
    await prefs.setString('sipNumber', config.sipCallerIDNumber);
    if (config.notificationToken != null) {
      await prefs.setString(
        'notificationToken',
        config.notificationToken!,
      );
    }
  }

  Future<void> _clearConfigForAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sipUser');
    await prefs.remove('sipPassword');
    await prefs.remove('token');
    await prefs.remove('sipName');
    await prefs.remove('sipNumber');
    await prefs.remove('notificationToken');
  }

  void observeResponses() {
    // Observe Socket Messages Received
    _telnyxClient
      ..onSocketMessageReceived = (TelnyxMessage message) async {
        logger.i(
          'TxClientViewModel :: observeResponses :: Socket :: ${message.message}',
        );
        switch (message.socketMethod) {
          case SocketMethod.clientReady:
            {
              if (_credentialConfig != null) {
                await _saveCredentialsForAutoLogin(_credentialConfig!);
              } else if (_tokenConfig != null) {
                await _saveCredentialsForAutoLogin(_tokenConfig!);
              }

              _registered = true;
              logger.i(
                'TxClientViewModel :: observeResponses : Registered :: $_registered',
              );
              if (callState != CallStateStatus.connectingToCall) {
                callState = CallStateStatus.idle;
              }
              break;
            }
          case SocketMethod.invite:
            {
              logger.i(
                'ObserveResponses :: Received INVITE. callFromPush: $callFromPush, waitingForInvite: $waitingForInvite',
              );
              _incomingInvite = message.message.inviteParams;

              // Track incoming call for history
              if (_incomingInvite != null) {
                _currentCallDestination = _incomingInvite!.callerIdNumber ?? 'Unknown';
                _currentCallDirection = CallDirection.incoming;
                _currentCallStartTime = DateTime.now();
              }

              if (waitingForInvite) {
                logger.i(
                  'ObserveResponses :: Invite received while waiting, calling _performAccept.',
                );
                await _performAccept(_incomingInvite!);
              } else if (!callFromPush) {
                logger.i(
                  'ObserveResponses :: Invite - Not from push, showing notification.',
                );
                callState = CallStateStatus.ongoingInvitation;
                observeCurrentCall();
                await NotificationService.showIncomingCallUi(
                  callId: _incomingInvite!.callID!,
                  callerName: _incomingInvite!.callerIdName ?? 'Unknown Caller',
                  callerNumber:
                      _incomingInvite!.callerIdNumber ?? 'Unknown Number',
                );
                notifyListeners();
              } else {
                // Invite received, was from push, but we weren't explicitly waiting.
                // Monitor state, but don't auto-accept here unless the SDK failed.
                logger.i(
                  'ObserveResponses :: Invite received, was from push but NOT waiting. Monitoring state.',
                );
                callState = CallStateStatus.ongoingInvitation;
                observeCurrentCall();
                notifyListeners();
              }

              logger.i(
                'customheaders :: ${message.message.dialogParams?.customHeaders}',
              );
              break;
            }
          case SocketMethod.answer:
            {
              callState = CallStateStatus.ongoingCall;
              notifyListeners();
              break;
            }
          case SocketMethod.ringing:
            {
              callState = CallStateStatus.ringing;
              notifyListeners();
              break;
            }
          case SocketMethod.bye:
            {
              logger.i(
                'TxClientViewModel :: observeResponses :: Received BYE message: ${message.message}',
              );
              
              // Extract termination reason from BYE message if available
              CallTerminationReason? terminationReason;
              if (message.message.byeParams != null) {
                final byeParams = message.message.byeParams!;
                if (byeParams.cause != null || byeParams.sipCode != null) {
                  terminationReason = CallTerminationReason(
                    cause: byeParams.cause,
                    causeCode: byeParams.causeCode,
                    sipCode: byeParams.sipCode,
                    sipReason: byeParams.sipReason,
                  );
                  
                  // Store the termination reason for display
                  _lastTerminationReason = terminationReason;
                  
                  logger.i(
                    'TxClientViewModel :: observeResponses :: Extracted termination reason from BYE: $terminationReason',
                  );
                }
              }
              
              // Save call to history before resetting call info
              if (_currentCallDestination != null && _currentCallDirection != null) {
                final wasAnswered = _callState == CallStateStatus.ongoingCall;
                _addCallToHistory(
                  destination: _currentCallDestination!,
                  direction: _currentCallDirection!,
                  wasAnswered: wasAnswered,
                );
              }
              
              callState = CallStateStatus.idle;

              // Handle CallKit cleanup
              if (!kIsWeb && Platform.isIOS) {
                if (callFromPush) {
                  // For iOS push calls, handle CallKit cleanup but avoid double resetCallInfo()
                  FlutterCallkitIncoming.endCall(
                    currentCall?.callId ?? _incomingInvite!.callID!,
                  );
                  if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
                    _telnyxClient.disconnect();
                  }
                }
              }

              // End Call via Flutter Callkit Incoming regardless of Platform:
              if (currentCall?.callId != null || _incomingInvite != null) {
                // end Call for Callkit on iOS
                await FlutterCallkitIncoming.endCall(
                  currentCall?.callId ?? _incomingInvite?.callID! ?? '',
                );
              } else {
                final numCalls = await FlutterCallkitIncoming.activeCalls();
                if (numCalls.isNotEmpty) {
                  final String? callKitId = numCalls.first['id'] as String?;
                  if (callKitId != null && callKitId.isNotEmpty) {
                    await FlutterCallkitIncoming.endCall(callKitId);
                  } else {
                    logger.w(
                      'Could not find call ID in active CallKit calls map.',
                    );
                  }
                }
              }
              
              // Call resetCallInfo() once at the end, after termination reason is set
              resetCallInfo();
              break;
            }
        }
        notifyListeners();

        if (!kIsWeb) {
          final messageLogger = await FileLogger.getInstance();
          await messageLogger.writeLog(message.toString());
        }
      }

      // Observe Socket Error Messages
      ..onSocketErrorReceived = (TelnyxSocketError error) {
        _setErrorDialog(
            formatSignalingErrorMessage(error.errorCode, error.errorMessage));

        switch (error.errorCode) {
          //ToDo Error handling here depends on the requirement of the SDK implementor and the use case
          case -32000:
            {
              //Todo handle token error (try again, sign user out and move to login screen, etc)
              logger.i(
                '${error.errorMessage} :: The token is invalid or expired',
              );
              _loggingIn = false;
              break;
            }
          case -32001:
            {
              //Todo handle credential error (try again, sign user out and move to login screen, etc)
              _loggingIn = false;
              logger.i('${error.errorMessage} :: The Credential is invalid');
              break;
            }
          case -32002:
            {
              //Todo handle codec error (end call and show error message, call back, etc)
              logger.i(
                '${error.errorMessage} :: There was an issue with the SDP Handshake, likely due to invalid ICE Candidates',
              );
              break;
            }
          case -32003:
            {
              //Todo handle gateway timeout error (try again, check network connection, etc)
              logger.i(
                '${error.errorMessage} :: It is taking too long to register with the gateway',
              );
              break;
            }
          case -32004:
            {
              //ToDo hande gateway failure error (try again, check network connection, etc)
              logger.i(
                '${error.errorMessage} :: Registration with the gateway has failed',
              );
              break;
            }
        }
        notifyListeners();
      };
  }

  String formatSignalingErrorMessage(int causeCode, String message) {
    switch (causeCode) {
      case -32000:
        return 'Token registration error: $message';
      case -32001:
        return 'Credential registration error: $message';
      case -32002:
        return 'Codec error: $message';
      case -32003:
        return 'Gateway registration timeout: $message';
      case -32004:
        return 'Gateway registration failed: $message';
      default:
        if (message.contains('Call not found')) {
          return 'Call not found: The specified call cannot be found';
        }
        return message;
    }
  }

  void _endCallFromPush(bool fromBye) {
    if (!kIsWeb && Platform.isIOS) {
      // end Call for Callkit on iOS
      FlutterCallkitIncoming.endCall(
        currentCall?.callId ?? _incomingInvite!.callID!,
      );
      if (!fromBye) {
        _telnyxClient.calls.values.firstOrNull?.endCall();
      }
      // Attempt to end the call if still present and disconnect from the socket to logout - this enables us to receive further push notifications after
      if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        _telnyxClient.disconnect();
      }
    }
    resetCallInfo();
  }

  void handlePushNotification(
    PushMetaData pushMetaData,
    CredentialConfig? credentialConfig,
    TokenConfig? tokenConfig,
  ) {
    logger.i(
      'TelnyxClientViewModel.handlePushNotification: Called with PushMetaData: ${pushMetaData.toJson()}',
    );
    _telnyxClient.handlePushNotification(
      pushMetaData,
      credentialConfig,
      tokenConfig,
    );
  }

  void disconnect() {
    TelnyxClient.clearPushMetaData();
    _telnyxClient.disconnect();
    callState = CallStateStatus.disconnected;
    _loggingIn = false;
    _registered = false;
    notifyListeners();
  }

  void login(CredentialConfig credentialConfig) async {
    _loggingIn = true;
    notifyListeners();

    _localName = credentialConfig.sipCallerIDName;
    _localNumber = credentialConfig.sipCallerIDNumber;
    _credentialConfig = credentialConfig;
    _telnyxClient.connectWithCredential(credentialConfig);
    observeResponses();
  }

  void loginWithToken(TokenConfig tokenConfig) {
    _loggingIn = true;
    notifyListeners();

    _localName = tokenConfig.sipCallerIDName;
    _localNumber = tokenConfig.sipCallerIDNumber;
    _tokenConfig = tokenConfig;
    _telnyxClient.connectWithToken(tokenConfig);
    observeResponses();
  }

  void call(String destination) {
    _currentCall = _telnyxClient.newInvite(
      _localName,
      _localNumber,
      destination,
      'Fake State',
      customHeaders: {'X-Header-1': 'Value1', 'X-Header-2': 'Value2'},
      debug: true,
    );

    logger.i(
      'TelnyxClientViewModel.call: Call initiated to $destination. Call ID: ${_currentCall?.callId}',
    );

    // Track outgoing call for history
    _currentCallDestination = destination;
    _currentCallDirection = CallDirection.outgoing;
    _currentCallStartTime = DateTime.now();

    // Call NotificationService to handle the CallKit UI for outgoing call
    if (_currentCall?.callId != null) {
      NotificationService.startOutgoingCallNotification(
        callId: _currentCall!.callId!,
        callerName: _localName, // Or however the caller should be represented
        handle: destination,
        // extra: {} // Optionally pass any extra data if needed
      );
    }

    observeCurrentCall();
  }

  bool waitingForInvite = false;

  /// Returns the stored CredentialConfig or TokenConfig, preferring Credential.
  /// Uses [ConfigHelper] for retrieval.
  Future<Object?> getConfig() async {
    logger.i('[TelnyxClientViewModel] getConfig: Using ConfigHelper...');
    return ConfigHelper.getTelnyxConfigFromPrefs();
  }

  Future<void> accept({
    bool acceptFromPush = false,
    Map<dynamic, dynamic>? pushData,
  }) async {
    logger.i(
      'TelnyxClientViewModel.accept: Called. acceptFromPush: $acceptFromPush, _incomingInvite exists: ${_incomingInvite != null}, callState: $callState. pushData: $pushData',
    );
    await FlutterCallkitIncoming.activeCalls().then((value) {
      logger.i(
        'TelnyxClientViewModel.accept: ${value.length} Active CallKit calls before accept $value',
      );
    });

    // Prevent processing if already connecting or ongoing
    // Note: connectingToCall check is important to prevent re-entry
    if (callState == CallStateStatus.connectingToCall ||
        callState == CallStateStatus.ongoingCall) {
      logger.i(
        'Accept :: Already connecting or in a call, ignoring request :: $callState',
      );
      return;
    }

    // --- Main Acceptance Logic ---
    if (_incomingInvite != null) {
      // Invite is ready NOW. Perform the acceptance actions.
      await _performAccept(_incomingInvite!);
    } else if (acceptFromPush) {
      // Accept intent came from push, but invite hasn't arrived. Set up waiting state.
      logger.i(
        'Accept :: Invite not present yet (from push), setting waiting state.',
      );
      waitingForInvite = true;
      callState = CallStateStatus.connectingToCall;
      notifyListeners();
    } else {
      // Accept was called unexpectedly without an invite and not from a push trigger.
      logger.w(
        'Accept :: Called without an incoming invite and not from push context. State: $callState',
      );
    }
  }

  // Private helper to contain the actual acceptance steps
  Future<void> _performAccept(IncomingInviteParams invite) async {
    logger.i(
      'TelnyxClientViewModel._performAccept: Performing accept actions for call ${invite.callID}, caller: ${invite.callerIdName}/${invite.callerIdNumber}',
    );
    // Set state definitively before async gaps
    callState = CallStateStatus.connectingToCall;
    waitingForInvite = false; // Ensure this is reset
    notifyListeners();

    try {
      _currentCall = _telnyxClient.acceptCall(
        invite,
        _localName,
        _localNumber,
        'State',
        customHeaders: {},
        debug: true,
      );
      observeCurrentCall();

      if (!kIsWeb) {
        if (Platform.isIOS) {
          logger.i(
            'TelnyxClientViewModel._performAccept: Call acceptance initiated with SDK. Waiting for CallState.active to confirm connection with CallKit.',
          );
        } else if (Platform.isAndroid) {
          final CallKitParams callKitParams = CallKitParams(
            id: invite.callID,
            nameCaller: invite.callerIdName,
            handle: invite.callerIdNumber,
            appName: 'Telnyx Flutter Voice',
            type: 0,
          );
          try {
            await FlutterCallkitIncoming.hideCallkitIncoming(callKitParams);
            logger.i(
              'Accept :: Android hideCallkitIncoming for ${invite.callID}',
            );
          } catch (e) {
            logger.e('Accept :: Error hiding CallKit UI: $e');
          }
        }
      }
    } catch (e) {
      logger.e('Error during _performAccept: $e');
      callState = CallStateStatus.idle;
      waitingForInvite = false;
      notifyListeners();
    }
  }

  void endCall({bool endfromCallScreen = false}) {
    logger.i(' Platform ::: endfromCallScreen :: $endfromCallScreen');
    if (currentCall == null) {
      logger.i('Current Call is null');
    } else {
      logger.i('Current Call is not null');
    }

    if (!kIsWeb && Platform.isIOS) {
      /* when end call from CallScreen we need to tell Callkit to end the call as well
       */
      if (endfromCallScreen && callFromPush) {
        // end Call for Callkit on iOS
        _endCallFromPush(false);
        logger.i('end Call: Call from Push $callFromPush');
      } else {
        logger.i('end Call: Call from CallScreen $callFromPush');
        // end Call normally on iOS
        currentCall?.endCall();
      }
    } else if (kIsWeb || Platform.isAndroid) {
      currentCall?.endCall();
    }

    _callState = CallStateStatus.idle;
    notifyListeners();
  }

  void dtmf(String tone) {
    currentCall?.dtmf(tone);
  }

  void muteUnmute() {
    _mute = !_mute;
    _currentCall?.onMuteUnmutePressed();
    notifyListeners();
  }

  void holdUnhold() {
    _hold = !_hold;
    currentCall?.onHoldUnholdPressed();
    notifyListeners();
  }

  void toggleSpeakerPhone() {
    if (kIsWeb) {
      Fluttertoast.showToast(
        msg: 'Toggling loud speaker is disabled on the web client',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: telnyx_green,
        textColor: Colors.white,
      );
      return;
    }
    _speakerPhone = !_speakerPhone;
    currentCall?.enableSpeakerPhone(_speakerPhone);
    notifyListeners();
  }

  void exportLogs() async {
    final messageLogger = await FileLogger.getInstance();
    final logContents = await messageLogger.exportLogs();
    logger.i('Log Contents :: $logContents');
    //ToDo: Implement log export
  }

  void disablePushNotifications() {
    _telnyxClient.disablePushNotifications();
  }
}
