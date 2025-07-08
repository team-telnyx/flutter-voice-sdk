import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telnyx_common/telnyx_common.dart';
import 'package:telnyx_flutter_webrtc/model/call_history_entry.dart' show CallDirection;
import 'package:telnyx_flutter_webrtc/service/call_history_service.dart';
import 'package:telnyx_flutter_webrtc/utils/background_detector.dart';
import 'package:telnyx_webrtc/model/call_quality_metrics.dart';
import 'package:telnyx_webrtc/model/call_termination_reason.dart';

/// Provider that wraps telnyx_common for state management using Provider pattern.
/// 
/// This provider handles:
/// - Session management (login/logout)
/// - Call state management
/// - Push notification handling
/// - CallKit integration
/// - Call history tracking
/// - Audio level monitoring
class TelnyxCommonProvider with ChangeNotifier {
  final Logger logger = Logger();
  late final TelnyxVoipClient _telnyxClient;
  
  // Subscriptions for reactive streams
  StreamSubscription<ConnectionState>? _connectionStateSubscription;
  StreamSubscription<List<Call>>? _callsSubscription;
  StreamSubscription<Call?>? _activeCallSubscription;
  
  // State variables
  bool _loggingIn = false;
  bool _speakerPhone = false;
  bool _mute = false;
  bool _hold = false;
  bool callFromPush = false;
  
  // Current configurations
  CredentialConfig? _credentialConfig;
  TokenConfig? _tokenConfig;
  
  // Call tracking for history
  String? _currentCallDestination;
  CallDirection? _currentCallDirection;
  DateTime? _currentCallStartTime;
  
  // Call quality metrics (not handled by telnyx_common)
  CallQualityMetrics? _callQualityMetrics;
  
  // Audio level tracking (not handled by telnyx_common)
  final List<double> _inboundAudioLevels = [];
  final List<double> _outboundAudioLevels = [];
  static const int maxAudioLevels = 100;
  
  // Error handling
  String? _errorDialogMessage;
  
  // Call termination reason tracking
  CallTerminationReason? _lastTerminationReason;
  
  // Current state from telnyx_common
  ConnectionState _connectionState = ConnectionState.disconnected;
  List<Call> _calls = [];
  Call? _activeCall;
  
  TelnyxCommonProvider() {
    _initializeTelnyxClient();
  }
  
  // Getters
  bool get registered => _connectionState == ConnectionState.connected;
  bool get loggingIn => _loggingIn;
  bool get speakerPhoneState => _speakerPhone;
  bool get muteState => _mute;
  bool get holdState => _hold;
  String? get errorDialogMessage => _errorDialogMessage;
  CallQualityMetrics? get callQualityMetrics => _callQualityMetrics;
  List<double> get inboundAudioLevels => List.unmodifiable(_inboundAudioLevels);
  List<double> get outboundAudioLevels => List.unmodifiable(_outboundAudioLevels);
  CallTerminationReason? get lastTerminationReason => _lastTerminationReason;
  
  // Connection state
  ConnectionState get connectionState => _connectionState;
  
  // Call state
  List<Call> get calls => _calls;
  Call? get activeCall => _activeCall;
  
  // Legacy compatibility - map telnyx_common CallState to legacy CallStateStatus
  CallStateStatus get callState {
    if (_activeCall == null) {
      if (_connectionState == ConnectionState.connected) {
        return CallStateStatus.idle;
      } else {
        return CallStateStatus.disconnected;
      }
    }
    
    switch (_activeCall!.currentState) {
      case CallState.ringing:
        return _activeCall!.isIncoming ? CallStateStatus.ongoingInvitation : CallStateStatus.ringing;
      case CallState.initiating:
        return CallStateStatus.connectingToCall;
      case CallState.active:
        return CallStateStatus.ongoingCall;
      case CallState.held:
        return CallStateStatus.ongoingCall; // Still ongoing, just held
      case CallState.ended:
      case CallState.error:
        return CallStateStatus.idle;
      case CallState.reconnecting:
        return CallStateStatus.connectingToCall;
      default:
        return CallStateStatus.idle;
    }
  }
  
  // Session ID for compatibility
  String get sessionId => _activeCall?.callId ?? '';
  
  void _initializeTelnyxClient() {
    // Initialize with native UI and background handling enabled
    _telnyxClient = TelnyxVoipClient(
      enableNativeUI: !kIsWeb && (Platform.isIOS || Platform.isAndroid),
      enableBackgroundHandling: true,
      customTokenProvider: DefaultPushTokenProvider(),
    );
    
    _setupStreamSubscriptions();
  }
  
  void _setupStreamSubscriptions() {
    // Listen to connection state changes
    _connectionStateSubscription = _telnyxClient.connectionState.listen((state) {
      _connectionState = state;
      logger.i('Connection state changed to: $state');
      notifyListeners();
    });
    
    // Listen to calls list changes
    _callsSubscription = _telnyxClient.calls.listen((calls) {
      _calls = calls;
      logger.i('Calls list updated: ${calls.length} calls');
      notifyListeners();
    });
    
    // Listen to active call changes
    _activeCallSubscription = _telnyxClient.activeCall.listen((call) {
      final previousCall = _activeCall;
      _activeCall = call;
      
      if (call != null && previousCall?.callId != call.callId) {
        _setupCallObservation(call);
      }
      
      if (call == null && previousCall != null) {
        _handleCallEnded();
      }
      
      logger.i('Active call changed: ${call?.callId}');
      notifyListeners();
    });
  }
  
  void _setupCallObservation(Call call) {
    logger.i('Setting up call observation for: ${call.callId}');
    
    // Track call for history
    _currentCallDestination = call.destination ?? call.callerNumber ?? 'Unknown';
    _currentCallDirection = call.isIncoming ? CallDirection.incoming : CallDirection.outgoing;
    _currentCallStartTime = DateTime.now();
    
    // Listen to call state changes
    call.callState.listen((state) {
      logger.i('Call ${call.callId} state changed to: $state');
      
      if (state == CallState.ended || state == CallState.error) {
        _handleCallTermination(call);
      }
      
      notifyListeners();
    });
    
    // Set up call quality monitoring if available
    // Note: This would need to be implemented by accessing the underlying
    // telnyx_webrtc Call object through telnyx_common
    _setupCallQualityMonitoring(call);
  }
  
  void _setupCallQualityMonitoring(Call call) {
    // TODO: Implement call quality monitoring
    // This would require exposing the underlying telnyx_webrtc Call object
    // through the telnyx_common Call wrapper, or implementing quality
    // monitoring directly in telnyx_common
    logger.i('Call quality monitoring setup for: ${call.callId}');
  }
  
  void _handleCallEnded() {
    logger.i('Call ended, resetting state');
    BackgroundDetector.ignore = false;
    _speakerPhone = false;
    _mute = false;
    _hold = false;
    _callQualityMetrics = null;
    setPushCallStatus(false);
    
    // Clear audio level lists
    _inboundAudioLevels.clear();
    _outboundAudioLevels.clear();
    
    // Reset call history tracking
    _currentCallDestination = null;
    _currentCallDirection = null;
    _currentCallStartTime = null;
    
    // Reset termination reason after a delay
    Timer(const Duration(seconds: 5), () {
      _lastTerminationReason = null;
      notifyListeners();
    });
  }
  
  void _handleCallTermination(Call call) {
    logger.i('Handling call termination for: ${call.callId}');
    
    // Save call to history
    if (_currentCallDestination != null && _currentCallDirection != null) {
      final wasAnswered = call.currentState == CallState.active;
      _addCallToHistory(
        destination: _currentCallDestination!,
        direction: _currentCallDirection!,
        wasAnswered: wasAnswered,
      );
    }
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
    }
    notifyListeners();
  }
  
  void _setErrorDialog(String message) {
    _errorDialogMessage = message;
    notifyListeners();
  }
  
  void clearErrorDialog() {
    _errorDialogMessage = null;
    notifyListeners();
  }
  
  // Authentication methods
  Future<void> connectWithCredentials(CredentialConfig config) async {
    _loggingIn = true;
    _credentialConfig = config;
    notifyListeners();
    
    try {
      await _telnyxClient.login(config);
      await _saveCredentialsForAutoLogin(config);
    } catch (e) {
      logger.e('Failed to connect with credentials: $e');
      _setErrorDialog('Failed to connect: $e');
    } finally {
      _loggingIn = false;
      notifyListeners();
    }
  }
  
  Future<void> connectWithToken(TokenConfig config) async {
    _loggingIn = true;
    _tokenConfig = config;
    notifyListeners();
    
    try {
      await _telnyxClient.loginWithToken(config);
      await _saveCredentialsForAutoLogin(config);
    } catch (e) {
      logger.e('Failed to connect with token: $e');
      _setErrorDialog('Failed to connect: $e');
    } finally {
      _loggingIn = false;
      notifyListeners();
    }
  }
  
  Future<void> disconnect() async {
    try {
      await _telnyxClient.logout();
      await _clearConfigForAutoLogin();
      _credentialConfig = null;
      _tokenConfig = null;
    } catch (e) {
      logger.e('Failed to disconnect: $e');
      _setErrorDialog('Failed to disconnect: $e');
    }
  }
  
  // Call control methods
  Future<void> newCall(String destination) async {
    try {
      final call = await _telnyxClient.newCall(destination: destination);
      logger.i('New call initiated: ${call.callId}');
    } catch (e) {
      logger.e('Failed to initiate call: $e');
      _setErrorDialog('Failed to initiate call: $e');
    }
  }
  
  Future<void> acceptCall() async {
    if (_activeCall != null) {
      try {
        await _activeCall!.accept();
        logger.i('Call accepted: ${_activeCall!.callId}');
      } catch (e) {
        logger.e('Failed to accept call: $e');
        _setErrorDialog('Failed to accept call: $e');
      }
    }
  }
  
  Future<void> endCall() async {
    if (_activeCall != null) {
      try {
        await _activeCall!.hangup();
        logger.i('Call ended: ${_activeCall!.callId}');
      } catch (e) {
        logger.e('Failed to end call: $e');
        _setErrorDialog('Failed to end call: $e');
      }
    }
  }
  
  Future<void> muteCall() async {
    if (_activeCall != null) {
      try {
        await _activeCall!.mute();
        _mute = true;
        logger.i('Call muted: ${_activeCall!.callId}');
        notifyListeners();
      } catch (e) {
        logger.e('Failed to mute call: $e');
        _setErrorDialog('Failed to mute call: $e');
      }
    }
  }
  
  Future<void> unmuteCall() async {
    if (_activeCall != null) {
      try {
        await _activeCall!.unmute();
        _mute = false;
        logger.i('Call unmuted: ${_activeCall!.callId}');
        notifyListeners();
      } catch (e) {
        logger.e('Failed to unmute call: $e');
        _setErrorDialog('Failed to unmute call: $e');
      }
    }
  }
  
  Future<void> holdCall() async {
    if (_activeCall != null) {
      try {
        await _activeCall!.hold();
        _hold = true;
        logger.i('Call held: ${_activeCall!.callId}');
        notifyListeners();
      } catch (e) {
        logger.e('Failed to hold call: $e');
        _setErrorDialog('Failed to hold call: $e');
      }
    }
  }
  
  Future<void> unholdCall() async {
    if (_activeCall != null) {
      try {
        await _activeCall!.unhold();
        _hold = false;
        logger.i('Call unheld: ${_activeCall!.callId}');
        notifyListeners();
      } catch (e) {
        logger.e('Failed to unhold call: $e');
        _setErrorDialog('Failed to unhold call: $e');
      }
    }
  }
  
  Future<void> sendDTMF(String tone) async {
    if (_activeCall != null) {
      try {
        await _activeCall!.dtmf(tone);
        logger.i('DTMF sent: $tone for call ${_activeCall!.callId}');
      } catch (e) {
        logger.e('Failed to send DTMF: $e');
        _setErrorDialog('Failed to send DTMF: $e');
      }
    }
  }
  
  // Speaker phone control (platform-specific implementation needed)
  void toggleSpeakerPhone() {
    _speakerPhone = !_speakerPhone;
    // TODO: Implement actual speaker phone toggle
    // This would need to be implemented in telnyx_common or
    // through platform-specific code
    logger.i('Speaker phone toggled: $_speakerPhone');
    notifyListeners();
  }
  
  // Push notification handling
  Future<void> handlePushNotification(Map<String, dynamic> payload) async {
    try {
      await _telnyxClient.handlePushNotification(payload);
      setPushCallStatus(true);
      logger.i('Push notification handled');
    } catch (e) {
      logger.e('Failed to handle push notification: $e');
      _setErrorDialog('Failed to handle push notification: $e');
    }
  }
  
  // Auto-login support
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
  
  @override
  void dispose() {
    _connectionStateSubscription?.cancel();
    _callsSubscription?.cancel();
    _activeCallSubscription?.cancel();
    super.dispose();
  }
}

// Legacy enum for compatibility
enum CallStateStatus {
  disconnected,
  idle,
  ringing,
  ongoingInvitation,
  connectingToCall,
  ongoingCall,
}