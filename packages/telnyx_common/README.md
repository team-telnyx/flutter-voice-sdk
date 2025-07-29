
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

## What telnyx_common Handles For You

Without the `telnyx_common` module, developers using the lower-level `telnyx_webrtc` package would need to manually implement:

### 1. Background State Detection and Reconnection
- Monitor app lifecycle changes using `WidgetsBindingObserver`
- Detect when the app goes to background/foreground
- Manually disconnect WebSocket connections when backgrounded
- Store credentials securely for reconnection
- Implement reconnection logic with proper error handling
- Handle edge cases like calls during background transitions

### 2. Push Notification Call Handling
- Parse incoming push notification payloads
- Extract call metadata from various push formats
- Initialize WebRTC client in background isolate
- Connect to Telnyx servers from push notification
- Handle call state synchronization between isolates
- Manage the complex flow of answering/declining from notifications

### 3. Native Call UI Integration (CallKit/ConnectionService)
- Implement platform channels for iOS CallKit (or Flutter library equivalent)
- Implement platform channels for Android ConnectionService (or Flutter library equivalent)
- Handle all CallKit delegate methods
- Manage ConnectionService lifecycle
- Synchronize native UI actions with WebRTC state
- Handle audio session management
- Deal with platform-specific quirks and edge cases

### 4. Complex State Management
- Track connection states across app lifecycle
- Manage multiple simultaneous calls
- Handle state transitions during network changes
- Implement proper cleanup on errors
- Coordinate between push notifications and active sessions

### 5. Platform-Specific Push Token Management
- Implement Firebase Cloud Messaging for Android
- Implement PushKit for iOS VoIP notifications
- Handle token refresh and registration
- Manage different token types per platform
- Coordinate token updates with Telnyx backend

### 6. Error Recovery and Edge Cases
- Network disconnection during calls
- App termination during active calls
- Push notifications while app is already connected
- Race conditions between user actions and push events
- Memory management in background isolates

The `telnyx_common` module handles all of this complexity for you with a simple, unified API!

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
   
   Modify `ios/Runner/AppDelegate.swift` to handle VoIP push notifications and CallKit:
   ```swift
   import UIKit
   import AVFAudio
   import CallKit
   import PushKit
   import Flutter
   import flutter_callkit_incoming
   import WebRTC
   
   @main
   @objc class AppDelegate: FlutterAppDelegate, PKPushRegistryDelegate, CallkitIncomingAppDelegate {
     
     override func application(
       _ application: UIApplication,
       didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
     ) -> Bool {
       GeneratedPluginRegistrant.register(with: self)
       
       // Setup VoIP push notifications
       let mainQueue = DispatchQueue.main
       let voipRegistry: PKPushRegistry = PKPushRegistry(queue: mainQueue)
       voipRegistry.delegate = self
       voipRegistry.desiredPushTypes = [PKPushType.voIP]
       
       // Configure WebRTC audio session
       RTCAudioSession.sharedInstance().useManualAudio = true
       RTCAudioSession.sharedInstance().isAudioEnabled = false
       
       return super.application(application, didFinishLaunchingWithOptions: launchOptions)
     }
     
     // MARK: - PKPushRegistryDelegate for VoIP Push
     
     func pushRegistry(_ registry: PKPushRegistry, didUpdate credentials: PKPushCredentials, for type: PKPushType) {
       let deviceToken = credentials.token.map { String(format: "%02x", $0) }.joined()
       // Token is automatically passed to Flutter
       SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP(deviceToken)
     }
     
     func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
       guard type == .voIP else { return }
       
       // Parse Telnyx push notification
       if let metadata = payload.dictionaryPayload["metadata"] as? [String: Any] {
         let callID = (metadata["call_id"] as? String) ?? UUID().uuidString
         let callerName = (metadata["caller_name"] as? String) ?? ""
         let callerNumber = (metadata["caller_number"] as? String) ?? ""
         
         let data = flutter_callkit_incoming.Data(id: callID, nameCaller: callerName, handle: callerNumber, type: 0)
         data.extra = payload.dictionaryPayload as NSDictionary
         data.uuid = callID
         
         // Show CallKit UI
         SwiftFlutterCallkitIncomingPlugin.sharedInstance?.showCallkitIncoming(data, fromPushKit: true)
         
         completion()
       }
     }
     
     // MARK: - CallKit Audio Session Management
     
     func didActivateAudioSession(_ audioSession: AVAudioSession) {
       RTCAudioSession.sharedInstance().audioSessionDidActivate(audioSession)
       RTCAudioSession.sharedInstance().isAudioEnabled = true
     }
     
     func didDeactivateAudioSession(_ audioSession: AVAudioSession) {
       RTCAudioSession.sharedInstance().audioSessionDidDeactivate(audioSession)
       RTCAudioSession.sharedInstance().isAudioEnabled = false
     }
     
     // MARK: - CallKit Action Handlers (Required by CallkitIncomingAppDelegate)
     func onAccept(_ call: flutter_callkit_incoming.Call, _ action: CXAnswerCallAction) {
       action.fulfill()
     }
     
     func onDecline(_ call: flutter_callkit_incoming.Call, _ action: CXEndCallAction) {
       action.fulfill()
     }
     
     func onEnd(_ call: flutter_callkit_incoming.Call, _ action: CXEndCallAction) {
       action.fulfill()
     }
     
     func onTimeOut(_ call: flutter_callkit_incoming.Call) {
       // Handle timeout
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

**Important:** When using `TelnyxVoiceApp`, push notifications are handled automatically for you. You don't need to implement any custom push notification handling code - the SDK takes care of everything including:

- Processing incoming call notifications
- Displaying native call UI (CallKit on iOS, ConnectionService on Android)
- Handling call acceptance/rejection from the native UI
- Managing the app lifecycle when calls arrive

The only requirements are:

1. **Provide the push token** when logging in via the [CredentialConfig](#2-authentication) or [TokenConfig](#2-authentication):
   ```dart
   // For iOS (VoIP push token)
   final config = CredentialConfig(
     sipUser: 'your_user',
     sipPassword: 'your_password',
     sipCallerIDName: 'Your Name',
     sipCallerIDNumber: 'Your Number',
     pushDeviceToken: 'your_ios_voip_push_token',  // Required for push notifications
   );
   
   // For Android (FCM token)
   final config = CredentialConfig(
     sipUser: 'your_user',
     sipPassword: 'your_password',
     sipCallerIDName: 'Your Name',
     sipCallerIDNumber: 'Your Number',
     pushDeviceToken: 'your_fcm_token',  // Required for push notifications
   );
   ```

2. **For Android only:** Provide a background message handler when initializing the SDK with the `@pragma('vm:entry-point')` annotation:

```dart
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // TelnyxVoiceApp handles the actual processing
  await TelnyxVoiceApp.handleBackgroundPush(message);
}

void main() async {
  runApp(await TelnyxVoiceApp.initializeAndCreate(
    voipClient: myVoipClient,
    backgroundMessageHandler: _firebaseMessagingBackgroundHandler,
    child: MyApp(),
  ));
}
```

That's it! The SDK will automatically:
- Connect to Telnyx when a push notification arrives
- Display the incoming call UI
- Handle user actions (answer/decline)
- Manage the call state

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

##### initializeAndCreate()

This is the recommended way to initialize the Telnyx Voice SDK in your app. It handles all common SDK initialization boilerplate including Firebase setup, background handlers, and dependency configuration.

```dart
static Future<Widget> initializeAndCreate({
  required TelnyxVoipClient voipClient,
  required Widget child,
  Future<void> Function(RemoteMessage)? backgroundMessageHandler,
  FirebaseOptions? firebaseOptions,
  VoidCallback? onPushNotificationProcessingStarted,
  VoidCallback? onPushNotificationProcessingCompleted,
  void Function(AppLifecycleState state)? onAppLifecycleStateChanged,
  bool enableAutoReconnect = true,
  bool skipWebBackgroundDetection = true,
})
```

**Parameters:**

- **`voipClient`** *(required)*: The `TelnyxVoipClient` instance that will be managed by this widget. This should be created with your desired configuration before calling this method.

- **`child`** *(required)*: The main widget of your application (typically `MyApp()`). This will be wrapped by the `TelnyxVoiceApp` widget.

- **`backgroundMessageHandler`**: A top-level function that handles background push notifications when the app is terminated. This function must be annotated with `@pragma('vm:entry-point')` to work properly. If not provided, background push notifications won't be handled when the app is terminated.

- **`firebaseOptions`**: Optional Firebase configuration options. If not provided, the SDK will attempt to use the default Firebase options generated by the FlutterFire CLI (from `firebase_options.dart`).

- **`onPushNotificationProcessingStarted`**: Callback triggered when the SDK begins processing an initial push notification upon app launch. Useful for showing a loading state while the SDK connects and handles the incoming call.

- **`onPushNotificationProcessingCompleted`**: Callback triggered when the SDK completes processing an initial push notification. This is the recommended place to start listening to state changes in your app, as the SDK will be fully initialized.

- **`onAppLifecycleStateChanged`**: Optional callback for custom handling of app lifecycle state changes (foreground, background, etc.). Called in addition to the SDK's built-in lifecycle management.

- **`enableAutoReconnect`** *(default: true)*: When enabled, the SDK automatically reconnects to the Telnyx server when the app returns to the foreground. Disable this if you want to manage connections manually.

- **`skipWebBackgroundDetection`** *(default: true)*: Whether to skip background detection logic on web platforms, as web apps don't have the same background/foreground lifecycle as mobile apps.

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


## Support

For issues and questions:
- [GitHub Issues](https://github.com/team-telnyx/flutter-voice-sdk/issues)
- [Telnyx Documentation](https://developers.telnyx.com/)
- [Flutter Voice SDK Documentation](https://github.com/team-telnyx/flutter-voice-sdk)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
