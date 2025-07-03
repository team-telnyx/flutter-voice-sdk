import 'dart:async';
import 'dart:io';
import 'package:telnyx_common/telnyx_common.dart';

/// A minimal, "headless" example application for Phase 1 testing.
///
/// This example demonstrates the core functionality of the telnyx_common
/// module without any UI dependencies. It uses simple console input/output
/// to interact with the user and logs all state changes to the console.
///
/// Usage:
/// ```
/// dart run example/headless_example.dart
/// ```
class HeadlessExample {
  late final TelnyxVoipClient _client;
  late final StreamSubscription _connectionSubscription;
  late final StreamSubscription _callsSubscription;
  late final StreamSubscription _activeCallSubscription;
  
  bool _isLoggedIn = false;
  
  HeadlessExample() {
    _client = TelnyxVoipClient(enableNativeUI: false);
    _setupListeners();
  }
  
  /// Sets up stream listeners for state changes.
  void _setupListeners() {
    // Listen to connection state changes
    _connectionSubscription = _client.connectionState.listen((state) {
      print('📡 Connection State: $state');
      
      if (state is Connected) {
        _isLoggedIn = true;
        print('✅ Successfully connected to Telnyx!');
      } else if (state is Disconnected) {
        _isLoggedIn = false;
        print('❌ Disconnected from Telnyx');
      } else if (state is ConnectionError) {
        _isLoggedIn = false;
        print('🚨 Connection Error: ${state.error}');
      }
    });
    
    // Listen to all calls
    _callsSubscription = _client.calls.listen((calls) {
      print('📞 Active Calls (${calls.length}):');
      for (final call in calls) {
        print('  - $call');
      }
    });
    
    // Listen to active call changes
    _activeCallSubscription = _client.activeCall.listen((call) {
      if (call != null) {
        print('🔥 Active Call: $call');
        _setupCallListeners(call);
      } else {
        print('📵 No active call');
      }
    });
  }
  
  /// Sets up listeners for a specific call.
  void _setupCallListeners(Call call) {
    call.callState.listen((state) {
      print('📱 Call ${call.callId} State: $state');
    });
    
    call.isMuted.listen((muted) {
      print('🔇 Call ${call.callId} Muted: $muted');
    });
    
    call.isHeld.listen((held) {
      print('⏸️ Call ${call.callId} Held: $held');
    });
  }
  
  /// Runs the interactive example.
  Future<void> run() async {
    print('🚀 Telnyx Common Module - Headless Example');
    print('==========================================');
    print('');
    
    while (true) {
      _showMenu();
      final input = stdin.readLineSync()?.trim() ?? '';
      
      try {
        await _handleInput(input);
      } catch (error) {
        print('❌ Error: $error');
      }
      
      print('');
    }
  }
  
  /// Shows the interactive menu.
  void _showMenu() {
    print('Available Commands:');
    if (!_isLoggedIn) {
      print('  1. Login with credentials');
      print('  2. Login with token');
    } else {
      print('  3. Make a call');
      print('  4. Logout');
      
      final activeCall = _client.currentActiveCall;
      if (activeCall != null) {
        if (activeCall.currentState.canAnswer) {
          print('  5. Answer call');
        }
        if (activeCall.currentState.canHangup) {
          print('  6. Hang up call');
        }
        if (activeCall.currentState.canMute) {
          print('  7. Toggle mute');
        }
        if (activeCall.currentState.canHold || activeCall.currentState.canUnhold) {
          print('  8. Toggle hold');
        }
        if (activeCall.currentState.isActive) {
          print('  9. Send DTMF tone');
        }
      }
    }
    print('  0. Exit');
    print('');
    stdout.write('Enter command: ');
  }
  
  /// Handles user input.
  Future<void> _handleInput(String input) async {
    switch (input) {
      case '1':
        await _loginWithCredentials();
        break;
      case '2':
        await _loginWithToken();
        break;
      case '3':
        await _makeCall();
        break;
      case '4':
        await _logout();
        break;
      case '5':
        await _answerCall();
        break;
      case '6':
        await _hangupCall();
        break;
      case '7':
        await _toggleMute();
        break;
      case '8':
        await _toggleHold();
        break;
      case '9':
        await _sendDtmf();
        break;
      case '0':
        await _exit();
        break;
      default:
        print('❌ Invalid command: $input');
    }
  }
  
  /// Logs in with credentials.
  Future<void> _loginWithCredentials() async {
    stdout.write('Enter SIP username: ');
    final username = stdin.readLineSync() ?? '';
    
    stdout.write('Enter SIP password: ');
    final password = stdin.readLineSync() ?? '';
    
    stdout.write('Enter FCM token (optional): ');
    final fcmToken = stdin.readLineSync();
    
    final config = CredentialConfig(
      sipUser: username,
      sipPassword: password,
      fcmToken: fcmToken?.isNotEmpty == true ? fcmToken : null,
      debug: true,
    );
    
    print('🔐 Logging in with credentials...');
    await _client.login(config);
  }
  
  /// Logs in with token.
  Future<void> _loginWithToken() async {
    stdout.write('Enter authentication token: ');
    final token = stdin.readLineSync() ?? '';
    
    stdout.write('Enter FCM token (optional): ');
    final fcmToken = stdin.readLineSync();
    
    final config = TokenConfig(
      token: token,
      fcmToken: fcmToken?.isNotEmpty == true ? fcmToken : null,
      debug: true,
    );
    
    print('🔐 Logging in with token...');
    await _client.loginWithToken(config);
  }
  
  /// Makes a new call.
  Future<void> _makeCall() async {
    if (!_isLoggedIn) {
      print('❌ Please login first');
      return;
    }
    
    stdout.write('Enter destination number: ');
    final destination = stdin.readLineSync() ?? '';
    
    if (destination.isEmpty) {
      print('❌ Destination cannot be empty');
      return;
    }
    
    print('📞 Making call to $destination...');
    final call = await _client.newCall(destination: destination);
    print('✅ Call initiated: ${call.callId}');
  }
  
  /// Logs out.
  Future<void> _logout() async {
    print('👋 Logging out...');
    await _client.logout();
  }
  
  /// Answers the current call.
  Future<void> _answerCall() async {
    final call = _client.currentActiveCall;
    if (call != null && call.currentState.canAnswer) {
      print('✅ Answering call...');
      await call.answer();
    } else {
      print('❌ No call to answer');
    }
  }
  
  /// Hangs up the current call.
  Future<void> _hangupCall() async {
    final call = _client.currentActiveCall;
    if (call != null && call.currentState.canHangup) {
      print('📴 Hanging up call...');
      await call.hangup();
    } else {
      print('❌ No call to hang up');
    }
  }
  
  /// Toggles mute on the current call.
  Future<void> _toggleMute() async {
    final call = _client.currentActiveCall;
    if (call != null && call.currentState.canMute) {
      print('🔇 Toggling mute...');
      await call.toggleMute();
    } else {
      print('❌ Cannot mute current call');
    }
  }
  
  /// Toggles hold on the current call.
  Future<void> _toggleHold() async {
    final call = _client.currentActiveCall;
    if (call != null && (call.currentState.canHold || call.currentState.canUnhold)) {
      print('⏸️ Toggling hold...');
      await call.toggleHold();
    } else {
      print('❌ Cannot toggle hold on current call');
    }
  }
  
  /// Sends a DTMF tone.
  Future<void> _sendDtmf() async {
    final call = _client.currentActiveCall;
    if (call != null && call.currentState.isActive) {
      stdout.write('Enter DTMF tone (0-9, *, #): ');
      final tone = stdin.readLineSync() ?? '';
      
      if (tone.isNotEmpty) {
        print('📱 Sending DTMF tone: $tone');
        await call.dtmf(tone);
      }
    } else {
      print('❌ No active call for DTMF');
    }
  }
  
  /// Exits the application.
  Future<void> _exit() async {
    print('👋 Goodbye!');
    await _cleanup();
    exit(0);
  }
  
  /// Cleans up resources.
  Future<void> _cleanup() async {
    await _connectionSubscription.cancel();
    await _callsSubscription.cancel();
    await _activeCallSubscription.cancel();
    _client.dispose();
  }
}

/// Entry point for the headless example.
void main() async {
  final example = HeadlessExample();
  
  // Handle Ctrl+C gracefully
  ProcessSignal.sigint.watch().listen((_) async {
    print('\n🛑 Received interrupt signal, cleaning up...');
    await example._cleanup();
    exit(0);
  });
  
  try {
    await example.run();
  } catch (error) {
    print('💥 Fatal error: $error');
    await example._cleanup();
    exit(1);
  }
}