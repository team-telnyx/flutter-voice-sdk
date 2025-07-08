import 'dart:async';
import 'dart:io';
import 'package:telnyx_webrtc/config/telnyx_config.dart';

import '../lib/telnyx_common.dart';

/// A minimal, headless example application that demonstrates the core functionality
/// of the telnyx_common module without any UI dependencies.
///
/// This example shows how to:
/// - Connect to the Telnyx platform
/// - Monitor connection state changes
/// - Make outgoing calls
/// - Handle incoming calls
/// - Monitor call state changes
/// - Perform call actions (mute, hold, DTMF, hangup)
///
/// All state changes are printed to the console, making it easy to verify
/// that the core logic is working correctly.
void main() async {
  print('🚀 Starting Telnyx Common Module Headless Example');
  print('=' * 50);

  // Create the TelnyxVoipClient instance (headless mode - no native UI)
  final telnyxClient = TelnyxVoipClient(enableNativeUI: false);

  // Set up state monitoring
  _setupStateMonitoring(telnyxClient);

  // Interactive command loop
  await _runInteractiveLoop(telnyxClient);

  // Cleanup
  telnyxClient.dispose();
  print('👋 Example completed');
}

/// Sets up monitoring for connection and call state changes.
void _setupStateMonitoring(TelnyxVoipClient client) {
  // Monitor connection state
  client.connectionState.listen((state) {
    print('🔗 Connection State: $state');
  });

  // Monitor all calls
  client.calls.listen((calls) {
    print('📞 Active Calls (${calls.length}):');
    for (final call in calls) {
      print('  - ${call.callId}: ${call.currentState} '
          '${call.isIncoming ? '(incoming)' : '(outgoing)'} '
          '${call.destination ?? call.callerNumber ?? 'Unknown'}');
    }
    if (calls.isEmpty) {
      print('  - No active calls');
    }
  });

  // Monitor active call
  client.activeCall.listen((call) {
    if (call != null) {
      print('🎯 Active Call: ${call.callId} (${call.currentState})');

      // Monitor call state changes
      call.callState.listen((state) {
        print('📱 Call ${call.callId} state: $state');
      });

      // Monitor mute state
      call.isMuted.listen((muted) {
        print('🔇 Call ${call.callId} muted: $muted');
      });

      // Monitor hold state
      call.isHeld.listen((held) {
        print('⏸️ Call ${call.callId} held: $held');
      });
    } else {
      print('🎯 Active Call: None');
    }
  });
}

/// Runs an interactive command loop for testing the client.
Future<void> _runInteractiveLoop(TelnyxVoipClient client) async {
  print('\n📋 Available Commands:');
  print('  login <sipUser> <sipPassword> - Login with credentials');
  print('  token <token> - Login with token');
  print('  call <destination> - Make a call');
  print('  answer - Answer incoming call');
  print('  hangup - Hang up active call');
  print('  mute - Toggle mute');
  print('  hold - Toggle hold');
  print('  dtmf <tone> - Send DTMF tone');
  print('  status - Show current status');
  print('  help - Show this help');
  print('  quit - Exit');
  print('');

  while (true) {
    stdout.write('telnyx> ');
    final input = stdin.readLineSync()?.trim() ?? '';

    if (input.isEmpty) continue;

    final parts = input.split(' ');
    final command = parts[0].toLowerCase();

    try {
      switch (command) {
        case 'login':
          if (parts.length < 3) {
            print('❌ Usage: login <sipUser> <sipPassword>');
            break;
          }
          await _handleLogin(client, parts[1], parts[2]);
          break;

        case 'token':
          if (parts.length < 2) {
            print('❌ Usage: token <token>');
            break;
          }
          await _handleTokenLogin(client, parts[1]);
          break;

        case 'call':
          if (parts.length < 2) {
            print('❌ Usage: call <destination>');
            break;
          }
          await _handleCall(client, parts[1]);
          break;

        case 'answer':
          await _handleAnswer(client);
          break;

        case 'hangup':
          await _handleHangup(client);
          break;

        case 'mute':
          await _handleMute(client);
          break;

        case 'hold':
          await _handleHold(client);
          break;

        case 'dtmf':
          if (parts.length < 2) {
            print('❌ Usage: dtmf <tone>');
            break;
          }
          await _handleDtmf(client, parts[1]);
          break;

        case 'status':
          _showStatus(client);
          break;

        case 'help':
          print('\n📋 Available Commands:');
          print('  login <sipUser> <sipPassword> - Login with credentials');
          print('  token <token> - Login with token');
          print('  call <destination> - Make a call');
          print('  answer - Answer incoming call');
          print('  hangup - Hang up active call');
          print('  mute - Toggle mute');
          print('  hold - Toggle hold');
          print('  dtmf <tone> - Send DTMF tone');
          print('  status - Show current status');
          print('  help - Show this help');
          print('  quit - Exit');
          break;

        case 'quit':
        case 'exit':
          return;

        default:
          print(
              '❌ Unknown command: $command. Type "help" for available commands.');
      }
    } catch (error) {
      print('❌ Error executing command: $error');
    }
  }
}

/// Handles credential-based login.
Future<void> _handleLogin(
    TelnyxVoipClient client, String sipUser, String sipPassword) async {
  print('🔐 Logging in with credentials...');

  final config = CredentialConfig(
    sipUser: sipUser,
    sipPassword: sipPassword,
    sipCallerIDName: sipUser, // Use sipUser as caller ID name
    sipCallerIDNumber: sipUser, // Use sipUser as caller ID number
    logLevel: LogLevel.info,
    debug: true,
  );

  await client.login(config);
  print('✅ Login initiated. Monitor connection state for result.');
}

/// Handles token-based login.
Future<void> _handleTokenLogin(TelnyxVoipClient client, String token) async {
  print('🔐 Logging in with token...');

  final config = TokenConfig(
    sipToken: token,
    sipCallerIDName: 'User', // Default caller ID name for token auth
    sipCallerIDNumber: 'Unknown', // Default caller ID number for token auth
    logLevel: LogLevel.info,
    debug: true,
  );

  await client.loginWithToken(config);
  print('✅ Token login initiated. Monitor connection state for result.');
}

/// Handles making a call.
Future<void> _handleCall(TelnyxVoipClient client, String destination) async {
  if (client.currentConnectionState is! Connected) {
    print('❌ Not connected. Please login first.');
    return;
  }

  print('📞 Making call to $destination...');
  final call = await client.newCall(destination: destination);
  print('✅ Call initiated: ${call.callId}');
}

/// Handles answering an incoming call.
Future<void> _handleAnswer(TelnyxVoipClient client) async {
  final incomingCall = client.currentCalls
      .where(
          (call) => call.isIncoming && call.currentState == CallState.ringing)
      .firstOrNull;

  if (incomingCall == null) {
    print('❌ No incoming call to answer.');
    return;
  }

  print('📞 Answering call ${incomingCall.callId}...');
  await incomingCall.answer();
  print('✅ Call answered.');
}

/// Handles hanging up the active call.
Future<void> _handleHangup(TelnyxVoipClient client) async {
  final activeCall = client.currentActiveCall;
  if (activeCall == null) {
    print('❌ No active call to hang up.');
    return;
  }

  print('📞 Hanging up call ${activeCall.callId}...');
  await activeCall.hangup();
  print('✅ Call hung up.');
}

/// Handles toggling mute.
Future<void> _handleMute(TelnyxVoipClient client) async {
  final activeCall = client.currentActiveCall;
  if (activeCall == null) {
    print('❌ No active call to mute.');
    return;
  }

  print('🔇 Toggling mute for call ${activeCall.callId}...');
  await activeCall.toggleMute();
  print('✅ Mute toggled.');
}

/// Handles toggling hold.
Future<void> _handleHold(TelnyxVoipClient client) async {
  final activeCall = client.currentActiveCall;
  if (activeCall == null) {
    print('❌ No active call to hold.');
    return;
  }

  print('⏸️ Toggling hold for call ${activeCall.callId}...');
  await activeCall.toggleHold();
  print('✅ Hold toggled.');
}

/// Handles sending DTMF.
Future<void> _handleDtmf(TelnyxVoipClient client, String tone) async {
  final activeCall = client.currentActiveCall;
  if (activeCall == null) {
    print('❌ No active call to send DTMF.');
    return;
  }

  print('🔢 Sending DTMF tone "$tone" for call ${activeCall.callId}...');
  await activeCall.dtmf(tone);
  print('✅ DTMF sent.');
}

/// Shows the current status.
void _showStatus(TelnyxVoipClient client) {
  print('\n📊 Current Status:');
  print('  Connection: ${client.currentConnectionState}');
  print('  Total Calls: ${client.currentCalls.length}');
  print('  Active Call: ${client.currentActiveCall?.callId ?? 'None'}');

  if (client.currentCalls.isNotEmpty) {
    print('  Call Details:');
    for (final call in client.currentCalls) {
      print('    - ${call.callId}: ${call.currentState} '
          '${call.isIncoming ? '(incoming)' : '(outgoing)'} '
          '${call.destination ?? call.callerNumber ?? 'Unknown'}');
    }
  }
  print('');
}
