
# Telnyx Common

A high-level, state-agnostic, drop-in module for the Telnyx Flutter SDK that simplifies WebRTC voice calling integration. This package provides a streamlined interface for handling background state management, push notifications, native call UI, and call state management, eliminating the most complex parts of implementing the Telnyx Voice SDK.

## Features

- **🚀 Drop-in Integration**: Simple, high-level API that abstracts away WebRTC complexity
- **📱 Native Call UI**: Automatic integration with iOS CallKit and Android ConnectionService
- **🔔 Push Notifications**: Comprehensive push notification handling for incoming calls
- **🔄 State Management Agnostic**: Uses Dart Streams, works with any state management solution
- **🌐 Background Handling**: Automatic background/foreground lifecycle management
- **📞 Multiple Call Support**: Handle multiple simultaneous calls with ease
- **🎛️ Call Controls**: Mute, hold, DTMF, and call transfer capabilities

## Installation

Add `telnyx_common` to your `pubspec.yaml`:

```yaml
dependencies:
  telnyx_common: ^0.1.0
```

## Quick Start

### 1. Basic Setup

```dart
import 'package:telnyx_common/telnyx_common.dart';

// Create a TelnyxVoipClient instance
final voipClient = TelnyxVoipClient(
  enableNativeUI: true,  // Enable CallKit/ConnectionService
  enableBackgroundHandling: true,  // Handle background state
);

// Listen to connection state changes
voipClient.connectionState.listen((state) {
  print('Connection state: $state');
});

// Listen to call state changes
voipClient.calls.listen((calls) {
  print('Active calls: ${calls.length}');
});
```

### 2. Authentication

```dart
// Using SIP credentials
final credentialConfig = CredentialConfig(
  sipUser: 'your_sip_user',
  sipPassword: 'your_sip_password',
  sipCallerIDName: 'Your Name',
  sipCallerIDNumber: 'Your Number',
);

await voipClient.login(credentialConfig);

// Or using a token
final tokenConfig = TokenConfig(
  sipToken: 'your_sip_token',
  sipCallerIDName: 'Your Name',
  sipCallerIDNumber: 'Your Number',
);

await voipClient.loginWithToken(tokenConfig);
```

### 3. Making Calls

```dart
// Make an outgoing call
final call = await voipClient.newCall(destination: '+1234567890');

// Listen to call state changes
call.callState.listen((state) {
  switch (state) {
    case CallState.ringing:
      print('Call is ringing...');
      break;
    case CallState.active:
      print('Call is active');
      break;
    case CallState.ended:
      print('Call ended');
      break;
  }
});
```

### 4. Handling Incoming Calls

```dart
// Incoming calls automatically appear in the calls stream
voipClient.calls.listen((calls) {
  for (final call in calls) {
    if (call.isIncoming && call.currentState == CallState.ringing) {
      // Show your custom UI or let native UI handle it
      print('Incoming call from: ${call.callerNumber}');
      
      // Answer the call
      await call.answer();
      
      // Or decline the call
      await call.decline();
    }
  }
});
```

## Advanced Usage with TelnyxVoiceApp

For complete lifecycle management, use the `TelnyxVoiceApp` wrapper widget:

```dart
import 'package:flutter/material.dart';
import 'package:telnyx_common/telnyx_common.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Create your VoIP client
  final voipClient = TelnyxVoipClient(
    enableNativeUI: true,
    enableBackgroundHandling: true,
  );
  
  // Initialize and run the app with TelnyxVoiceApp
  runApp(await TelnyxVoiceApp.initializeAndCreate(
    voipClient: voipClient,
    backgroundMessageHandler: _backgroundHandler,
    child: MyApp(),
  ));
}

// Background push notification handler
@pragma('vm:entry-point')
Future<void> _backgroundHandler(RemoteMessage message) async {
  await TelnyxVoiceApp.handleBackgroundPush(message);
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Voice App',
      home: MyHomePage(),
    );
  }
}
```

## Platform Setup

### Android Setup

1. **Add Firebase Configuration**
   
   Add your `google-services.json` file to `android/app/`:
   ```
   android/
     app/
       google-services.json  # Add this file
   ```

2. **Update AndroidManifest.xml**
   
   Add the following permissions and services to `android/app/src/main/AndroidManifest.xml`:
   ```xml
   <uses-permission android:name="android.permission.RECORD_AUDIO" />
   <uses-permission android:name="android.permission.INTERNET" />
   <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
   <uses-permission android:name="android.permission.WAKE_LOCK" />
   <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
   <uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT" />
   
   <!-- Inside <application> tag -->
   <service
       android:name="com.hiennv.flutter_callkit_incoming.CallkitIncomingBroadcastReceiver"
       android:enabled="true"
       android:exported="true" />
   ```

### iOS Setup

1. **Update Info.plist**
   
   Add the following to `ios/Runner/Info.plist`:
   ```xml
   <key>NSMicrophoneUsageDescription</key>
   <string>This app needs microphone access to make voice calls</string>
   
   <key>UIBackgroundModes</key>
   <array>
       <string>audio</string>
       <string>voip</string>
   </array>
   ```

2. **Update AppDelegate**
   
   Modify `ios/Runner/AppDelegate.swift` to handle CallKit events:
   ```swift
   import UIKit
   import Flutter
   import flutter_callkit_incoming
   
   @UIApplicationMain
   @objc class AppDelegate: FlutterAppDelegate {
     override func application(
       _ application: UIApplication,
       didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
     ) -> Bool {
       GeneratedPluginRegistrant.register(with: self)
       return super.application(application, didFinishLaunchingWithOptions: launchOptions)
     }
     
     override func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
         guard let handle = userActivity.startCallHandle else {
             return false
         }
         
         guard let uuid = UUID(uuidString: userActivity.uuid) else {
             return false
         }
         
         FlutterCallkitIncomingPlugin.sharedInstance?.startCall(uuid, handle: handle, localizedCallerName: userActivity.localizedCallerName)
         
         return super.application(application, continue: userActivity, restorationHandler: restorationHandler)
     }
   }
   ```

3. **Add Entitlements**
   
   Create or update `ios/Runner/Runner.entitlements`:
   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
   <plist version="1.0">
   <dict>
       <key>com.apple.developer.pushkit.unrestricted-voip</key>
       <true/>
   </dict>
   </plist>
   ```

## Common Usage Patterns

### State Management Integration

The package works with any state management solution:

```dart
// With Provider
class CallProvider extends ChangeNotifier {
  final TelnyxVoipClient _voipClient;
  List<Call> _calls = [];
  
  CallProvider(this._voipClient) {
    _voipClient.calls.listen((calls) {
      _calls = calls;
      notifyListeners();
    });
  }
  
  List<Call> get calls => _calls;
}

// With BLoC
class CallBloc extends Bloc<CallEvent, CallState> {
  final TelnyxVoipClient voipClient;
  
  CallBloc(this.voipClient) : super(CallInitial()) {
    voipClient.calls.listen((calls) {
      add(CallsUpdated(calls));
    });
  }
}

// With Riverpod
final voipClientProvider = Provider<TelnyxVoipClient>((ref) {
  return TelnyxVoipClient(enableNativeUI: true);
});

final callsProvider = StreamProvider<List<Call>>((ref) {
  final client = ref.watch(voipClientProvider);
  return client.calls;
});
```

### Call Controls

```dart
// Get the active call
final activeCall = voipClient.currentActiveCall;

if (activeCall != null) {
  // Mute/unmute
  await activeCall.toggleMute();
  
  // Hold/unhold
  await activeCall.toggleHold();
  
  // Send DTMF tones
  await activeCall.dtmf('1');
  
  // Hang up
  await activeCall.hangup();
  
  // Listen to call properties
  activeCall.isMuted.listen((muted) {
    print('Call muted: $muted');
  });
  
  activeCall.isHeld.listen((held) {
    print('Call held: $held');
  });
}
```

### Push Notification Handling

```dart
// In your main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(_backgroundHandler);
  
  runApp(MyApp());
}

@pragma('vm:entry-point')
Future<void> _backgroundHandler(RemoteMessage message) async {
  // Handle background push notifications
  await TelnyxVoiceApp.handleBackgroundPush(message);
}

// In your app
class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late TelnyxVoipClient voipClient;
  
  @override
  void initState() {
    super.initState();
    voipClient = TelnyxVoipClient(enableNativeUI: true);
    
    // Handle foreground push notifications
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      voipClient.handlePushNotification(message.data);
    });
  }
}
```

## API Reference

### TelnyxVoipClient

The main interface for the telnyx_common module.

#### Constructor
```dart
TelnyxVoipClient({
  bool enableNativeUI = true,
  bool enableBackgroundHandling = true,
  PushTokenProvider? customTokenProvider,
  bool isBackgroundClient = false,
})
```

#### Methods
- `Future<void> login(CredentialConfig config)` - Login with SIP credentials
- `Future<void> loginWithToken(TokenConfig config)` - Login with SIP token
- `Future<Call> newCall({required String destination})` - Make a new call
- `Future<void> handlePushNotification(Map<String, dynamic> payload)` - Handle push notification
- `Future<void> logout()` - Logout and disconnect
- `void dispose()` - Clean up resources

#### Streams
- `Stream<ConnectionState> connectionState` - Connection state changes
- `Stream<List<Call>> calls` - All active calls
- `Stream<Call?> activeCall` - Currently active call

### TelnyxVoiceApp

A wrapper widget that handles complete SDK lifecycle management.

#### Static Methods
```dart
static Future<Widget> initializeAndCreate({
  required TelnyxVoipClient voipClient,
  required Widget child,
  Future<void> Function(RemoteMessage)? backgroundMessageHandler,
  FirebaseOptions? firebaseOptions,
  // ... other optional parameters
})
```

### Call

Represents an individual call with reactive state management.

#### Properties
- `String callId` - Unique call identifier
- `bool isIncoming` - Whether this is an incoming call
- `String? destination` - Call destination (for outgoing calls)
- `String? callerNumber` - Caller number (for incoming calls)
- `CallState currentState` - Current call state

#### Streams
- `Stream<CallState> callState` - Call state changes
- `Stream<bool> isMuted` - Mute state changes
- `Stream<bool> isHeld` - Hold state changes

#### Methods
- `Future<void> answer()` - Answer the call
- `Future<void> decline()` - Decline the call
- `Future<void> hangup()` - Hang up the call
- `Future<void> toggleMute()` - Toggle mute state
- `Future<void> toggleHold()` - Toggle hold state
- `Future<void> dtmf(String tone)` - Send DTMF tone

## Troubleshooting

### Common Issues

1. **Calls not connecting**
   - Verify your SIP credentials or token
   - Check network connectivity
   - Ensure proper Firebase configuration

2. **Push notifications not working**
   - Verify `google-services.json` is properly added
   - Check Firebase project configuration
   - Ensure background message handler is registered

3. **Native UI not showing**
   - Verify CallKit entitlements on iOS
   - Check AndroidManifest.xml permissions on Android
   - Ensure `enableNativeUI: true` in TelnyxVoipClient

4. **Background calls failing**
   - Verify background modes in Info.plist (iOS)
   - Check foreground service permissions (Android)
   - Ensure `enableBackgroundHandling: true`

### Debug Logging

Enable verbose logging for debugging:

```dart
final voipClient = TelnyxVoipClient(
  enableNativeUI: true,
  // Add debug configuration
);

// Enable debug logging in your config
final config = CredentialConfig(
  sipUser: 'your_user',
  sipPassword: 'your_password',
  sipCallerIDName: 'Your Name',
  sipCallerIDNumber: 'Your Number',
  debug: true,  // Enable debug logging
  logLevel: LogLevel.debug,
);
```

## Examples

Check out the [example directory](example/) for complete implementation examples:

- **Headless Example**: Basic usage without UI dependencies
- **Full App Example**: Complete app with native UI integration

## Support

For issues and questions:
- [GitHub Issues](https://github.com/team-telnyx/flutter-voice-sdk/issues)
- [Telnyx Documentation](https://developers.telnyx.com/)
- [Flutter Voice SDK Documentation](https://github.com/team-telnyx/flutter-voice-sdk)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
