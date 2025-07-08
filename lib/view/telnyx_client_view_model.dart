import 'dart:async';
import 'dart:io';
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
import 'package:telnyx_common/telnyx_common.dart';

/// Simplified TelnyxClientViewModel using the telnyx_common module.
/// 
/// This replaces the previous 863-line implementation with a much cleaner
/// approach that leverages the telnyx_common module for session management,
/// call state handling, push notifications, and CallKit integration.
class TelnyxClientViewModel with ChangeNotifier {
  final logger = Logger();
  late final TelnyxVoipClient _telnyxVoipClient;

  // Stream subscriptions for cleanup
  final List<StreamSubscription> _subscriptions = [];

  // Current state (derived from telnyx_common streams)
  ConnectionState _connectionState = const Disconnected();
  List<Call> _calls = [];
  Call? _activeCall;
  bool _speakerPhone = false;

  // Call history tracking
  String? _currentCallDestination;
  CallDirection? _currentCallDirection;
  DateTime? _currentCallStartTime;

  // Error handling
  String? _errorDialogMessage;
  String? get errorDialogMessage => _errorDialogMessage;

  // Legacy compatibility properties
  bool callFromPush = false;
  bool _loggingIn = false;

  TelnyxClientViewModel() {
    _initializeTelnyxClient();
    _setupStateListeners();
  }

  /// Initialize the TelnyxVoipClient with native UI and push notification support
  void _initializeTelnyxClient() {
    _telnyxVoipClient = TelnyxVoipClient(
      enableNativeUI: !kIsWeb, // Enable native UI on mobile platforms
      enableBackgroundHandling: true,
      notificationConfig: const NotificationConfig(
        channelId: 'telnyx_calls',
        channelName: 'Telnyx Calls',
        channelDescription: 'Incoming call notifications',
      ),
      customTokenProvider: DefaultPushTokenProvider(), // Use default Firebase token provider
    );
  }

  /// Set up listeners for telnyx_common streams
  void _setupStateListeners() {
    // Listen to connection state changes
    _subscriptions.add(
      _telnyxVoipClient.connectionState.listen((state) {
        _connectionState = state;
        _loggingIn = state is Connecting;
        
        logger.i('Connection state changed: $state');
        notifyListeners();
      }),
    );

    // Listen to calls list changes
    _subscriptions.add(
      _telnyxVoipClient.calls.listen((calls) {
        _calls = calls;
        logger.i('Calls updated: ${calls.length} active calls');
        notifyListeners();
      }),
    );

    // Listen to active call changes
    _subscriptions.add(
      _telnyxVoipClient.activeCall.listen((call) {
        final previousCall = _activeCall;
        _activeCall = call;

        if (call != null && previousCall?.callId != call.callId) {
          _setupCallListeners(call);
          logger.i('Active call changed: ${call.callId}');
        } else if (call == null && previousCall != null) {
          logger.i('Active call ended');
          _handleCallEnded(previousCall);
        }

        notifyListeners();
      }),
    );
  }

  /// Set up listeners for individual call state changes
  void _setupCallListeners(Call call) {
    // Listen to call state changes
    _subscriptions.add(
      call.callState.listen((state) {
        logger.i('Call ${call.callId} state changed: $state');
        
        switch (state) {
          case CallState.ringing:
            if (call.isIncoming) {
              // Track incoming call for history
              _currentCallDestination = call.callerNumber ?? 'Unknown';
              _currentCallDirection = CallDirection.incoming;
              _currentCallStartTime = DateTime.now();
            }
            break;
          case CallState.active:
            logger.i('Call ${call.callId} is now active');
            break;
          case CallState.ended:
            logger.i('Call ${call.callId} ended');
            _handleCallEnded(call);
            break;
          default:
            break;
        }
        
        notifyListeners();
      }),
    );

    // Listen to mute state changes
    _subscriptions.add(
      call.isMuted.listen((muted) {
        logger.i('Call ${call.callId} mute state: $muted');
        notifyListeners();
      }),
    );

    // Listen to hold state changes
    _subscriptions.add(
      call.isHeld.listen((held) {
        logger.i('Call ${call.callId} hold state: $held');
        notifyListeners();
      }),
    );
  }

  /// Handle call ended - save to history and cleanup
  void _handleCallEnded(Call call) {
    // Save call to history
    if (_currentCallDestination != null && _currentCallDirection != null) {
      final wasAnswered = call.currentState == CallState.active;
      _addCallToHistory(
        destination: _currentCallDestination!,
        direction: _currentCallDirection!,
        wasAnswered: wasAnswered,
      );
    }

    // Reset call tracking
    _currentCallDestination = null;
    _currentCallDirection = null;
    _currentCallStartTime = null;

    // Reset UI state
    BackgroundDetector.ignore = false;
    _speakerPhone = false;
    setPushCallStatus(false);
  }

  // Getters for UI compatibility
  bool get registered => _connectionState is Connected;
  bool get loggingIn => _loggingIn;
  bool get speakerPhoneState => _speakerPhone;
  bool get muteState => _activeCall?.currentIsMuted ?? false;
  bool get holdState => _activeCall?.currentIsHeld ?? false;
  String get sessionId => ''; // Not directly available in telnyx_common
  Call? get currentCall => _activeCall;

  /// Legacy call state enum for UI compatibility
  CallStateStatus get callState {
    if (_connectionState is Disconnected) return CallStateStatus.disconnected;
    if (_connectionState is! Connected) return CallStateStatus.disconnected;
    
    if (_activeCall == null) return CallStateStatus.idle;
    
    switch (_activeCall!.currentState) {
      case CallState.ringing:
        return _activeCall!.isIncoming 
            ? CallStateStatus.ongoingInvitation 
            : CallStateStatus.ringing;
      case CallState.connecting:
        return CallStateStatus.connectingToCall;
      case CallState.active:
        return CallStateStatus.ongoingCall;
      default:
        return CallStateStatus.idle;
    }
  }

  /// Login with credentials
  Future<void> connectWithCredentials({
    required String sipUser,
    required String sipPassword,
    required String sipCallerIDName,
    required String sipCallerIDNumber,
    String? notificationToken,
  }) async {
    try {
      _setErrorDialog(null);
      
      final config = CredentialConfig(
        sipUser: sipUser,
        sipPassword: sipPassword,
        sipCallerIDName: sipCallerIDName,
        sipCallerIDNumber: sipCallerIDNumber,
        notificationToken: notificationToken,
        logLevel: LogLevel.info,
        debug: true,
      );

      await _telnyxVoipClient.login(config);
      await _saveCredentialsForAutoLogin(config);
      
    } catch (error) {
      logger.e('Login failed: $error');
      _setErrorDialog('Login failed: $error');
    }
  }

  /// Login with token
  Future<void> connectWithToken({
    required String sipToken,
    required String sipCallerIDName,
    required String sipCallerIDNumber,
    String? notificationToken,
  }) async {
    try {
      _setErrorDialog(null);
      
      final config = TokenConfig(
        sipToken: sipToken,
        sipCallerIDName: sipCallerIDName,
        sipCallerIDNumber: sipCallerIDNumber,
        notificationToken: notificationToken,
        logLevel: LogLevel.info,
        debug: true,
      );

      await _telnyxVoipClient.loginWithToken(config);
      await _saveCredentialsForAutoLogin(config);
      
    } catch (error) {
      logger.e('Token login failed: $error');
      _setErrorDialog('Token login failed: $error');
    }
  }

  /// Disconnect from Telnyx
  Future<void> disconnect() async {
    try {
      await _telnyxVoipClient.logout();
      await _clearConfigForAutoLogin();
    } catch (error) {
      logger.e('Disconnect failed: $error');
      _setErrorDialog('Disconnect failed: $error');
    }
  }

  /// Make a new call
  Future<void> newCall(String destination) async {
    try {
      _setErrorDialog(null);
      
      // Track outgoing call for history
      _currentCallDestination = destination;
      _currentCallDirection = CallDirection.outgoing;
      _currentCallStartTime = DateTime.now();

      final call = await _telnyxVoipClient.newCall(destination: destination);
      logger.i('New call initiated: ${call.callId} to $destination');
      
    } catch (error) {
      logger.e('Failed to make call: $error');
      _setErrorDialog('Failed to make call: $error');
    }
  }

  /// Answer incoming call
  Future<void> acceptCall() async {
    try {
      final incomingCall = _calls
          .where((call) => call.isIncoming && call.currentState == CallState.ringing)
          .firstOrNull;
          
      if (incomingCall != null) {
        await incomingCall.answer();
        logger.i('Answered call: ${incomingCall.callId}');
      }
    } catch (error) {
      logger.e('Failed to answer call: $error');
      _setErrorDialog('Failed to answer call: $error');
    }
  }

  /// End current call
  Future<void> endCall() async {
    try {
      if (_activeCall != null) {
        await _activeCall!.hangup();
        logger.i('Ended call: ${_activeCall!.callId}');
      }
    } catch (error) {
      logger.e('Failed to end call: $error');
      _setErrorDialog('Failed to end call: $error');
    }
  }

  /// Toggle mute
  Future<void> toggleMute() async {
    try {
      if (_activeCall != null) {
        await _activeCall!.toggleMute();
        logger.i('Toggled mute for call: ${_activeCall!.callId}');
      }
    } catch (error) {
      logger.e('Failed to toggle mute: $error');
      _setErrorDialog('Failed to toggle mute: $error');
    }
  }

  /// Toggle hold
  Future<void> toggleHold() async {
    try {
      if (_activeCall != null) {
        await _activeCall!.toggleHold();
        logger.i('Toggled hold for call: ${_activeCall!.callId}');
      }
    } catch (error) {
      logger.e('Failed to toggle hold: $error');
      _setErrorDialog('Failed to toggle hold: $error');
    }
  }

  /// Send DTMF tone
  Future<void> sendDTMF(String tone) async {
    try {
      if (_activeCall != null) {
        await _activeCall!.dtmf(tone);
        logger.i('Sent DTMF tone "$tone" for call: ${_activeCall!.callId}');
      }
    } catch (error) {
      logger.e('Failed to send DTMF: $error');
      _setErrorDialog('Failed to send DTMF: $error');
    }
  }

  /// Toggle speaker phone (local state only)
  void toggleSpeakerPhone() {
    _speakerPhone = !_speakerPhone;
    logger.i('Speaker phone: $_speakerPhone');
    notifyListeners();
  }

  /// Handle push notification
  Future<void> handlePushNotification(Map<String, dynamic> payload) async {
    try {
      await _telnyxVoipClient.handlePushNotification(payload);
      setPushCallStatus(true);
    } catch (error) {
      logger.e('Failed to handle push notification: $error');
      _setErrorDialog('Failed to handle push notification: $error');
    }
  }

  /// Set push call status (legacy compatibility)
  void setPushCallStatus(bool isFromPush) {
    callFromPush = isFromPush;
    if (isFromPush) {
      logger.i('Entering push call context.');
    } else {
      logger.i('Exiting push call context / Resetting state.');
    }
    notifyListeners();
  }

  /// Error dialog management
  void _setErrorDialog(String? message) {
    _errorDialogMessage = message;
    notifyListeners();
  }

  void clearErrorDialog() {
    _errorDialogMessage = null;
    notifyListeners();
  }

  /// Save credentials for auto-login
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

  /// Clear saved credentials
  Future<void> _clearConfigForAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sipUser');
    await prefs.remove('sipPassword');
    await prefs.remove('token');
    await prefs.remove('sipName');
    await prefs.remove('sipNumber');
    await prefs.remove('notificationToken');
  }

  /// Add call to history
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

  /// Get current profile ID for call history
  String? _getCurrentProfileId() {
    // This is a simplified approach - in a real app you might want to
    // store the current config and derive the profile ID from it
    return 'current_user';
  }

  /// Export logs (legacy compatibility)
  Future<void> exportLogs() async {
    try {
      final messageLogger = await FileLogger.getInstance();
      final logContents = await messageLogger.exportLogs();
      logger.i('Log Contents :: $logContents');
      // TODO: Implement log export UI
    } catch (error) {
      logger.e('Failed to export logs: $error');
    }
  }

  /// Disable push notifications (legacy compatibility)
  void disablePushNotifications() {
    // The telnyx_common module handles push notifications internally
    // This is kept for UI compatibility but doesn't need implementation
    logger.i('Push notifications are managed by telnyx_common module');
  }

  /// Legacy method names for UI compatibility
  void muteUnmute() => toggleMute();
  void holdUnhold() => toggleHold();
  void dtmf(String tone) => sendDTMF(tone);
  
  /// Accept call (legacy compatibility)
  Future<void> accept({
    bool acceptFromPush = false,
    Map<String, dynamic>? pushData,
  }) async {
    await acceptCall();
  }

  /// End call (legacy compatibility - sync version)
  void endCallSync({bool endfromCallScreen = false}) {
    endCall(); // Call the async version without awaiting
  }

  @override
  void dispose() {
    // Cancel all stream subscriptions
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();

    // Dispose the TelnyxVoipClient
    _telnyxVoipClient.dispose();

    super.dispose();
  }
}

/// Legacy enum for UI compatibility
enum CallStateStatus {
  disconnected,
  idle,
  ringing,
  ongoingInvitation,
  connectingToCall,
  ongoingCall,
}