import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telnyx_flutter_webrtc/file_logger.dart';
import 'package:telnyx_flutter_webrtc/model/call_history_entry.dart';
import 'package:telnyx_flutter_webrtc/service/call_history_service.dart';
import 'package:telnyx_flutter_webrtc/utils/background_detector.dart';
import 'package:telnyx_flutter_webrtc/utils/theme.dart';
import 'package:telnyx_flutter_webrtc/utils/config_helper.dart';

// telnyx_common imports
import 'package:telnyx_common/telnyx_common.dart' as telnyx;

// Legacy imports for compatibility
import 'package:telnyx_webrtc/model/call_termination_reason.dart';
import 'package:telnyx_webrtc/model/call_quality_metrics.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';

class TelnyxClientViewModel with ChangeNotifier {
  final logger = Logger();

  // Constructor - set up stream subscriptions immediately
  TelnyxClientViewModel() {
    logger.i(
        'TelnyxClientViewModel: Initializing and setting up stream subscriptions');
    _setupStreamSubscriptions();
  }

  // telnyx_common client - replaces direct TelnyxClient usage
  final telnyx.TelnyxVoipClient _telnyxVoipClient = telnyx.TelnyxVoipClient(
    enableNativeUI: true,
    enableBackgroundHandling: true,
    customTokenProvider: telnyx.DefaultPushTokenProvider(),
  );

  // Stream subscriptions for telnyx_common
  StreamSubscription<telnyx.ConnectionState>? _connectionSubscription;
  StreamSubscription<telnyx.Call?>? _activeCallSubscription;
  StreamSubscription<List<telnyx.Call>>? _callsSubscription;

  // Wrapped state from telnyx_common
  telnyx.ConnectionState? _connectionState;
  telnyx.Call? _activeCall;
  List<telnyx.Call> _calls = [];

  // UI-specific state
  bool _loggingIn = false;
  bool _speakerPhone = false;
  bool _isConnectingToCall = false; // New flag for connecting state

  CredentialConfig? _credentialConfig;
  TokenConfig? _tokenConfig;
  CallQualityMetrics? _callQualityMetrics;

  String _localName = '';
  String _localNumber = '';

  // Call history tracking
  String? _currentCallDestination;
  CallDirection? _currentCallDirection;

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

  // Provider wrapper getters - expose telnyx_common state directly
  telnyx.ConnectionState? get connectionState => _connectionState;

  telnyx.Call? get activeCall => _activeCall;

  List<telnyx.Call> get calls => _calls;

  // UI-specific getters
  bool get registered => _connectionState is telnyx.Connected;

  bool get loggingIn => _loggingIn;

  bool get isConnectingToCall => _isConnectingToCall;

  bool get speakerPhoneState {
    return _speakerPhone;
  }

  CallQualityMetrics? get callQualityMetrics {
    return _callQualityMetrics;
  }

  bool get muteState {
    return _activeCall?.currentIsMuted ?? false;
  }

  bool get holdState {
    return _activeCall?.currentIsHeld ?? false;
  }

  String get sessionId {
    return _telnyxVoipClient.sessionId;
  }

  String get localName => _localName;

  String get localNumber => _localNumber;

  // Legacy compatibility for current call access
  telnyx.Call? get currentCall {
    return _activeCall;
  }

  /// State flow for inbound audio levels list
  final List<double> _inboundAudioLevels = [];

  List<double> get inboundAudioLevels => List.unmodifiable(_inboundAudioLevels);

  /// State flow for outbound audio levels list
  final List<double> _outboundAudioLevels = [];

  List<double> get outboundAudioLevels =>
      List.unmodifiable(_outboundAudioLevels);

  /// Maximum number of audio levels to keep in memory
  static const int maxAudioLevels = 100;

  CallTerminationReason? get lastTerminationReason => _lastTerminationReason;

  /// Expose the TelnyxVoipClient for use with TelnyxVoiceApp
  telnyx.TelnyxVoipClient get telnyxVoipClient => _telnyxVoipClient;

  /// Initialize stream subscriptions to wrap telnyx_common streams with Provider
  void _setupStreamSubscriptions() {
    // Connection state changes
    _connectionSubscription = _telnyxVoipClient.connectionState.listen((state) {
      logger.i('TelnyxClientViewModel: Connection state changed to $state');
      _connectionState = state;
      _loggingIn = state is telnyx.Connecting;

      // If we disconnect, ensure connecting flag is reset
      if (state is telnyx.Disconnected || state is telnyx.ConnectionError) {
        if (_isConnectingToCall) {
          _isConnectingToCall = false;
        }
      }

      notifyListeners();
    });

    // Active call changes
    _activeCallSubscription = _telnyxVoipClient.activeCall.listen((call) {
      logger.i('TelnyxClientViewModel: Active call changed to ${call?.callId}');
      _activeCall = call;

      // When a call becomes active or ends, we are no longer "connecting"
      if (call != null &&
          (call.currentState.isTerminated || call.currentState.isStable)) {
        if (_isConnectingToCall) {
          _isConnectingToCall = false;
        }
      }

      if (call != null) {
        _setupCallQualityMonitoring(call);
      } else {
        // No active call, ensure connecting flag is reset
        if (_isConnectingToCall) {
          _isConnectingToCall = false;
        }
      }

      notifyListeners();
    });

    // All calls changes
    _callsSubscription = _telnyxVoipClient.calls.listen((callsList) {
      logger.i(
          'TelnyxClientViewModel: Calls list changed, count: ${callsList.length}');
      _calls = callsList;
      notifyListeners();
    });
  }

  /// Set up call quality monitoring for the active call
  void _setupCallQualityMonitoring(telnyx.Call call) {
    // Listen to call quality metrics from the telnyx_common Call
    call.callQualityMetrics.listen((metrics) {
      _callQualityMetrics = metrics;

      // Update audio level lists directly from metrics
      _inboundAudioLevels.add(metrics.inboundAudioLevel);
      while (_inboundAudioLevels.length > maxAudioLevels) {
        _inboundAudioLevels.removeAt(0);
      }

      _outboundAudioLevels.add(metrics.outboundAudioLevel);
      while (_outboundAudioLevels.length > maxAudioLevels) {
        _outboundAudioLevels.removeAt(0);
      }

      notifyListeners();
    });
  }

  void resetCallInfo() {
    logger.i('TxClientViewModel :: Reset Call Info');
    BackgroundDetector.ignore = false;
    _speakerPhone = false;
    _callQualityMetrics = null;
    _isConnectingToCall = false;

    // Clear audio level lists
    _inboundAudioLevels.clear();
    _outboundAudioLevels.clear();

    // Reset call history tracking
    _currentCallDestination = null;
    _currentCallDirection = null;

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

  void setConnectingToCall(bool connecting) {
    if (_isConnectingToCall != connecting) {
      _isConnectingToCall = connecting;
      notifyListeners();
    }
  }

  Future<void> _saveCredentialsForAutoLogin(Config config) async {
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
      await prefs.setString('notificationToken', config.notificationToken!);
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

  Future<void> disconnect() async {
    logger.i(
        'TelnyxClientViewModel.disconnect: Disconnecting from telnyx_common');
    await _telnyxVoipClient.logout();
    _loggingIn = false;
    // Connection state will be updated via stream
    notifyListeners();
  }

  void login(CredentialConfig credentialConfig) async {
    logger.i('TelnyxClientViewModel.login: Logging in with credentials');
    _loggingIn = true;
    notifyListeners();

    _localName = credentialConfig.sipCallerIDName;
    _localNumber = credentialConfig.sipCallerIDNumber;
    _credentialConfig = credentialConfig;

    try {
      await _telnyxVoipClient.login(credentialConfig);
      // Save credentials for auto-login
      await _saveCredentialsForAutoLogin(credentialConfig);
      // Connection state will be updated via stream
    } catch (e) {
      logger.e('TelnyxClientViewModel.login: Login failed: $e');
      _setErrorDialog('Login failed: $e');
      _loggingIn = false;
      notifyListeners();
    }
  }

  void loginWithToken(TokenConfig tokenConfig) async {
    logger.i('TelnyxClientViewModel.loginWithToken: Logging in with token');
    _loggingIn = true;
    notifyListeners();

    _localName = tokenConfig.sipCallerIDName;
    _localNumber = tokenConfig.sipCallerIDNumber;
    _tokenConfig = tokenConfig;

    try {
      await _telnyxVoipClient.loginWithToken(tokenConfig);
      // Save credentials for auto-login
      await _saveCredentialsForAutoLogin(tokenConfig);
      // Connection state will be updated via stream
    } catch (e) {
      logger.e('TelnyxClientViewModel.loginWithToken: Login failed: $e');
      _setErrorDialog('Login failed: $e');
      _loggingIn = false;
      notifyListeners();
    }
  }

  void call(String destination) async {
    logger.i('TelnyxClientViewModel.call: Initiating call to $destination');

    // Track outgoing call for history
    _currentCallDestination = destination;
    _currentCallDirection = CallDirection.outgoing;

    try {
      final call = await _telnyxVoipClient.newCall(destination: destination);
      logger.i(
          'TelnyxClientViewModel.call: Call initiated. Call ID: ${call.callId}');

      // The call state will be updated via stream subscriptions
      // Native UI is handled automatically by telnyx_common
    } catch (e) {
      logger.e('TelnyxClientViewModel.call: Failed to initiate call: $e');
      _setErrorDialog('Failed to initiate call: $e');
    }
  }

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
        'TelnyxClientViewModel.accept: Accepting call. acceptFromPush: $acceptFromPush');

    if (_activeCall == null) {
      logger.w('TelnyxClientViewModel.accept: No active call to accept');
      return;
    }

    try {
      await _activeCall!.answer();
      logger.i('TelnyxClientViewModel.accept: Call accepted successfully');

      // Track incoming call for history
      _currentCallDestination =
          _activeCall!.destination ?? _activeCall!.callerNumber ?? 'Unknown';
      _currentCallDirection = CallDirection.incoming;

      // State will be updated via stream subscriptions
      // Native UI is handled automatically by telnyx_common
    } catch (e) {
      logger.e('TelnyxClientViewModel.accept: Failed to accept call: $e');
      _setErrorDialog('Failed to accept call: $e');
    }
  }

  void endCall({bool endfromCallScreen = false}) async {
    logger.i(
        'TelnyxClientViewModel.endCall: Ending call. endfromCallScreen: $endfromCallScreen');

    if (_activeCall == null) {
      logger.w('TelnyxClientViewModel.endCall: No active call to end');
      return;
    }

    try {
      await _activeCall!.hangup();
      logger.i('TelnyxClientViewModel.endCall: Call ended successfully');

      // Save call to history
      if (_currentCallDestination != null && _currentCallDirection != null) {
        // A call is considered "answered" if it was in the 'active' state
        final wasAnswered = activeCall?.currentState == telnyx.CallState.active;
        await _addCallToHistory(
          destination: _currentCallDestination!,
          direction: _currentCallDirection!,
          wasAnswered: wasAnswered,
        );
      }

      // State will be updated via stream subscriptions
      // Native UI cleanup is handled automatically by telnyx_common
    } catch (e) {
      logger.e('TelnyxClientViewModel.endCall: Failed to end call: $e');
      _setErrorDialog('Failed to end call: $e');
    }
  }

  void dtmf(String tone) async {
    if (_activeCall == null) {
      logger.w('TelnyxClientViewModel.dtmf: No active call for DTMF');
      return;
    }

    try {
      await _activeCall!.dtmf(tone);
      logger.i('TelnyxClientViewModel.dtmf: Sent DTMF tone: $tone');
    } catch (e) {
      logger.e('TelnyxClientViewModel.dtmf: Failed to send DTMF: $e');
    }
  }

  void muteUnmute() async {
    if (_activeCall == null) {
      logger
          .w('TelnyxClientViewModel.muteUnmute: No active call to mute/unmute');
      return;
    }

    try {
      await _activeCall!.toggleMute();
      logger.i('TelnyxClientViewModel.muteUnmute: Toggled mute state');
      // State will be updated via stream subscriptions
    } catch (e) {
      logger.e('TelnyxClientViewModel.muteUnmute: Failed to toggle mute: $e');
    }
  }

  void holdUnhold() async {
    if (_activeCall == null) {
      logger
          .w('TelnyxClientViewModel.holdUnhold: No active call to hold/unhold');
      return;
    }

    try {
      await _activeCall!.toggleHold();
      logger.i('TelnyxClientViewModel.holdUnhold: Toggled hold state');
      // State will be updated via stream subscriptions
    } catch (e) {
      logger.e('TelnyxClientViewModel.holdUnhold: Failed to toggle hold: $e');
    }
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
    _activeCall?.enableSpeakerPhone(_speakerPhone);
    notifyListeners();
  }

  void exportLogs() async {
    final messageLogger = await FileLogger.getInstance();
    final logContents = await messageLogger.exportLogs();
    logger.i('Log Contents :: $logContents');
    //ToDo: Implement log export
  }

  void disablePushNotifications() async {
    logger.i(
        'TelnyxClientViewModel.disablePushNotifications: Disabling push notifications');
    try {
      _telnyxVoipClient.disablePushNotifications();
      logger.i(
          'TelnyxClientViewModel.disablePushNotifications: Push notifications disabled');
    } catch (e) {
      logger.e(
          'TelnyxClientViewModel.disablePushNotifications: Failed to disable push: $e');
    }
  }

  @override
  void dispose() {
    logger.i('TelnyxClientViewModel.dispose: Cleaning up stream subscriptions');
    _connectionSubscription?.cancel();
    _activeCallSubscription?.cancel();
    _callsSubscription?.cancel();
    super.dispose();
  }
}
