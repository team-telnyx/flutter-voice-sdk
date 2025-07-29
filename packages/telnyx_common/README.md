
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

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.ve UI Display:** The gateway commands the \_CallKitAdapter to invoke FlutterCallkitIncoming.showCallkitIncoming(...).5 The native OS call UI is displayed (CallKit on iOS, a full-screen activity on Android), and the device begins ringing. The application now waits for user input.
5. **Path A: User Accepts the Call**
    * The \_CallKitAdapter's onAccept event listener, provided by flutter\_callkit\_incoming, fires.
    * The adapter notifies the \_CallStateController of the accepted call's UUID.
    * Crucially, it then triggers the \_SessionManager to connect to the Telnyx socket. When connecting, it provides the push metadata via a method equivalent to setPushMetaData.7
    * The \_SessionManager connects and logs in. The Telnyx backend, seeing the push metadata, sends the corresponding INVITE message for the call.1
    * The \_CallStateController receives the INVITE, matches it to the existing call UUID, and invokes the low-level telnyxClient.call.acceptCall(...).3
    * The call's state transitions to active, the \_callkit is used to register a call and keep the call active (even when in the background )is started, and the audio session is established.
6. **Path B: User Rejects the Call**
    * The \_CallKitAdapter's onDecline event listener fires.
    * It notifies the \_CallStateController to mark the call as ended.
    * For efficiency, it triggers the \_SessionManager to connect to the Telnyx socket. However, upon login, it includes a special parameter, decline\_push: true, as documented in the core SDK best practices.7
    * This parameter instructs the Telnyx backend to automatically terminate the call leg on the server side without ever sending an INVITE. This avoids the overhead of a full call setup-and-teardown cycle, providing a highly optimized rejection flow.

### **Sequence 3: In-Call State Transitions (Mute/Hold)**

1. **UI Action:** The user taps the "Mute" button in the call UI. This calls a method on the Call object exposed by the activeCall stream, for example, activeCall.toggleMute().
2. **Core SDK Action:** The Call object, managed by the \_CallStateController, directly invokes the corresponding low-level method from the core SDK, such as currentCall.onMuteUnmutePressed().3
3. **Reactive State Update:** The \_CallStateController simultaneously updates the isMuted boolean property on the Call object. Since the UI is listening to the stream that emits this object, it will automatically rebuild to reflect the new state (e.g., changing the button icon). The flow for hold is identical.

### **Sequence 4: Error and Network State Handling**

1. **Network Failure:** The device loses its internet connection.
2. **Low-Level Detection:** The core TelnyxClient's underlying WebSocket detects the connection loss and emits an error or disconnected event.
3. **Session Management:** The \_SessionManager catches this low-level event. Based on the user's configuration, it may attempt to reconnect. If reconnection fails, it translates the low-level issue into a high-level ConnectionState.error(TelnyxSocketError) and emits it on its state stream.8
4. **Centralized State Teardown:** The \_CallStateController listens to the \_SessionManager's state. Upon receiving an unrecoverable error state, it iterates through all calls in its active list and transitions their state to ended with a specific reason, such as networkLost, mirroring the logic from the core client's \_handleNetworkLost method.8
5. **UI and Service Cleanup:** The controller then commands the \_CallKitAdapter to dismiss all native call UIs.

## **V. Public API Specification and Developer Experience**

The public API is the contract between the telnyx\_common module and the developer. Its design is guided by a philosophy of simplicity, predictability, and adherence to Flutter best practices.

### **API Philosophy**

The API will be entirely asynchronous and reactive. Methods that perform a discrete action and then complete (e.g., login, newCall) will return a Future. Properties that represent an ongoing state that can change over time (e.g., connection status, the active call) will be exposed as a Stream. This Future/Stream-based design is the key to enabling state management agnosticism, as it allows any consumer to await actions and listen to state changes without being tied to a specific framework.

### **Table: TelnyxVoipClient \- Public Properties and Streams**

This table outlines the reactive state streams that developers can subscribe to for building their UI.

| Property Name | Type | Description |
| :---- | :---- | :---- |
| connectionState | Stream\<ConnectionState\> | Emits the current status of the connection to the Telnyx backend. Values include connecting, connected, disconnected, and error(TelnyxSocketError). Listen to this to show connection indicators. |
| activeCall | Stream\<Call?\> | A convenience stream that emits the currently active Call object. It emits null when no call is in progress. Ideal for applications that only handle a single call at a time. |
| calls | Stream\<List\<Call\>\> | Emits a list of all current Call objects. Use this for applications that need to support multiple simultaneous calls (e.g., call waiting, conference calls). |

### **Table: TelnyxVoipClient \- Public Methods**

This table defines the actions a developer can perform using the module.

| Method Signature | Return Type | Description |
| :---- | :---- | :---- |
| login(Config config) | Future\<void\> | Connects to the Telnyx platform and authenticates the user. The config parameter can be either a CredentialConfig or a TokenConfig object, mirroring the core SDK's authentication options.4 |
| logout() | Future\<void\> | Disconnects from the Telnyx platform, terminates any active sessions, and cleans up all related resources. |
| newCall({required String destination}) | Future\<Call\> | Initiates a new outgoing call to the specified destination number or SIP URI. Returns a Future that completes with the Call object once the invitation has been sent. |
| handlePushNotification(Map\<String, dynamic\> payload) | Future\<void\> | Processes a remote push notification payload. This method must be called from the application's background push handler to initiate the incoming call flow.7 |

### **The Call Object API**

When a developer gets a Call object from the activeCall or calls stream, it will have its own set of properties and methods for managing that specific call.

* **Properties:** callId (UUID), callState (Stream\<CallState\>), isMuted (Stream\<bool\>), isHeld (Stream\<bool\>), callerName (String), callerNumber (String).
* **Methods:** answer(), hangup(), toggleMute(), toggleHold(), dtmf(String tone).

### **Usage Examples**

To validate the state management agnosticism, the documentation will provide concrete examples for multiple popular frameworks.

#### **BLoC/Cubit Example**

Dart

class CallCubit extends Cubit\<CallState\> {  
final TelnyxVoipClient \_telnyxVoipClient;  
StreamSubscription? \_callSubscription;

CallCubit(this.\_telnyxVoipClient) : super(NoCallState()) {  
\_callSubscription \= \_telnyxVoipClient.activeCall.listen((call) {  
if (call\!= null) {  
emit(InCallState(call));  
} else {  
emit(NoCallState());  
}  
});  
}

@override  
Future\<void\> close() {  
\_callSubscription?.cancel();  
return super.close();  
}  
}

#### **Provider/Riverpod Example**

Dart

// In your list of providers  
final telnyxVoipClientProvider \= Provider((ref) \=\> TelnyxVoipClient());

final activeCallProvider \= StreamProvider\<Call?\>((ref) {  
final client \= ref.watch(telnyxVoipClientProvider);  
return client.activeCall;  
});

// In your widget  
class CallScreen extends ConsumerWidget {  
@override  
Widget build(BuildContext context, WidgetRef ref) {  
final activeCall \= ref.watch(activeCallProvider);  
return activeCall.when(  
data: (call) \=\> call\!= null? InCallUI(call: call) : NoCallUI(),  
loading: () \=\> CircularProgressIndicator(),  
error: (err, stack) \=\> Text('Error: $err'),  
);  
}  
}

## **VI. Phased Development and Testing Roadmap**

The project will be executed in four distinct, iterative phases. This approach de-risks development by ensuring that a functional, testable core is built first, with complexity layered on progressively. Each phase corresponds to approximately two development sprints (four weeks).

### **Phase 1: Core Engine & Headless Operation (2 Sprints)**

* **Goal:** To build and validate the internal logic of the module without any UI dependency. The objective is to prove that calls can be programmatically initiated, received, and managed.
* **Tasks:**
    * Implement the \_SessionManager to wrap the core TelnyxClient and manage its connection lifecycle.4
    * Implement the \_CallStateController as the central state machine.
    * Develop a comprehensive suite of unit tests to verify that raw socket messages (INVITE, ANSWER, BYE) 3 correctly transition the state machine's internal state.
    * Create a minimal, "headless" example application that uses simple buttons to log in and make a call, printing all state changes to the console log.
* **Deliverable:** A functional but non-UI core library that can establish and manage a call's state programmatically.

### **Phase 2: Native UI Integration (2 Sprints)**

* **Goal:** To integrate the flutter\_callkit\_incoming package and bring the full native call experience to the screen for both incoming and outgoing calls.
* **Tasks:**
    * Implement the \_CallKitAdapter, encapsulating all interactions with the flutter\_callkit\_incoming plugin.
    * Connect the adapter to the \_CallStateController, allowing the state machine to drive the UI and the UI to drive the state machine.
    * Implement the full interaction sequences for outgoing calls and incoming push-initiated calls.5
    * Conduct rigorous testing on both iOS and Android devices, paying special attention to the onAccept/onDecline flows and ensuring a smooth handoff to the WebRTC audio session, mitigating known issues.6
* **Deliverable:** A module capable of displaying and managing the complete native call UI lifecycle on both platforms.

### **Phase 3: Robustness & Background Processing (2 Sprints)**

* **Goal:** To ensure that calls are stable, persist when the application is backgrounded, and handle network interruptions gracefully.
* **Tasks:**
    * Implement comprehensive error handling pathways based on the TelnyxSocketError class and other exceptions from the core SDK.8
    * Perform extensive stress testing, including scenarios like network loss/recovery during a call, rejecting a call from a terminated app state, and maintaining long-duration calls while the app is in the background.
* **Deliverable:** A production-ready, robust, and stable module that can be relied upon in real-world conditions.

### **Phase 4: Documentation & Finalization (1 Sprint)**

* **Goal:** To create the public-facing documentation and assets required for a successful developer-facing launch.
* **Tasks:**
    * Author a comprehensive quickstart guide. The structure and content will be heavily based on the successful Android telnyx\_common quickstart guide.1
    * Ensure all public classes, methods, and properties are fully documented with Dart doc comments, and generate a complete API reference library.
    * Clean, polish, and thoroughly comment the sample application to ensure it serves as a canonical, best-practice example for developers.
    * Prepare the package for publication and release it on pub.dev.
* **Deliverable:** The final, publicly available telnyx\_common package, its documentation, and the polished sample application.

## **VII. Documentation Plan**

High-quality documentation is as critical as the code itself for driving adoption. The primary user-facing document will be a quickstart guide designed to take a developer from zero to a functioning call in the shortest possible time. Its structure will be modeled on the clear and effective Android quickstart guide.1

### **Guide Structure**

1. **Introduction:** A brief overview of what telnyx\_common is, its benefits, and how it simplifies Telnyx integration in Flutter.
2. **Setup & Configuration:**
    * Instructions for adding telnyx\_common and firebase\_messaging to pubspec.yaml.
    * Detailed steps for configuring native project files: AndroidManifest.xml (permissions, services) and Info.plist (background modes, permissions).5
    * A critical section on setting up the top-level or background push handler function, which is the entry point for incoming calls.
3. **Authentication:**
    * Code examples for instantiating the TelnyxVoipClient.
    * Step-by-step instructions for logging in using both CredentialConfig and TokenConfig.4
    * A UI example showing how to listen to the connectionState stream to display a "Connected" or "Disconnected" status.
4. **Making a Call:**
    * A complete, copy-pasteable example of using the newCall() method.
    * Guidance on building a basic call screen that subscribes to the activeCall stream to display call duration, caller info, and state-based controls (e.g., show a "Hangup" button when the call is active).
5. **Receiving a Call:**
    * A clear explanation of the end-to-end flow: how to configure the background handler, the single call to handlePushNotification(), and an explanation that the module manages the native UI display automatically.
6. **API Reference:** A prominent link to the auto-generated API documentation for TelnyxVoipClient, the Call object, and all configuration and state enums.
7. **Troubleshooting:** A FAQ-style section addressing common problems, directly mirroring known issues from similar platforms 1:
    * "My call disconnects when the app is minimized on Android." (Solution: Ensure the foreground service permissions and configuration are correct).
    * "I'm not receiving incoming call notifications." (Solution: Double-check FCM/APNS setup, notification permissions, and ensure push credentials are correctly assigned in the Telnyx portal).

## **VIII. Conclusion and Strategic Recommendations**

### **Summary of Plan**

This document presents a robust and detailed plan for the creation of the telnyx\_common Flutter module. The proposed architecture, centered on a public Façade (TelnyxVoipClient), a central \_CallStateController, and an isolated \_CallKitAdapter, provides a powerful yet simple interface for developers. This design directly addresses the core requirements of state management agnosticism, push notification handling, and native UI integration. The phased development roadmap ensures a structured, iterative process that prioritizes a stable core and mitigates risk by layering complexity incrementally.

### **Confidence Assessment**

Confidence in the success of this project is high. This confidence is not based on theoreticals, but on two key factors. First, the proposed architecture is not novel; it is a direct translation and enhancement of the patterns proven to be successful and reliable in the existing Android telnyx\_common module.1 Second, the plan proactively identifies and mitigates key risks, such as the volatility of third-party UI dependencies, by employing established software design patterns like the Adapter pattern to ensure long-term maintainability.6

### **Strategic Recommendation**

The development of the telnyx\_common module is more than a technical task; it is a strategic imperative for expanding the reach and adoption of the Telnyx platform. By significantly lowering the barrier to entry for the large and growing community of Flutter developers, Telnyx can capture new market segments and solidify its position as a leader in developer-friendly real-time communications.

It is therefore formally recommended that this project be approved and allocated the necessary engineering resources to begin development immediately. The successful execution of this plan will result in a high-value asset that enhances the Telnyx developer experience and drives platform growth. Commencement of Phase 1 should be prioritized to build foundational momentum and deliver value as quickly as possible.

#### **Works cited**

1. WebRTC Android Quickstart \- Telnyx's Developer Documentation, accessed July 2, 2025, [https://developers.telnyx.com/docs/voice/webrtc/android-sdk/quickstart](https://developers.telnyx.com/docs/voice/webrtc/android-sdk/quickstart)
2. WebRTC using Dart · Issue \#11 · team-telnyx/webrtc \- GitHub, accessed July 2, 2025, [https://github.com/team-telnyx/webrtc/issues/11](https://github.com/team-telnyx/webrtc/issues/11)
3. team-telnyx/telnyx-webrtc-android: Telnyx Android WebRTC SDK \- Enable real-time communication with WebRTC and Telnyx \- GitHub, accessed July 2, 2025, [https://github.com/team-telnyx/telnyx-webrtc-android](https://github.com/team-telnyx/telnyx-webrtc-android)
4. WebRTC Flutter Client \- Telnyx's Developer Documentation, accessed July 2, 2025, [https://developers.telnyx.com/docs/voice/webrtc/flutter-sdk/classes/txclient](https://developers.telnyx.com/docs/voice/webrtc/flutter-sdk/classes/txclient)
5. flutter\_callkit\_incoming | Flutter package \- Pub.dev, accessed July 2, 2025, [https://pub.dev/packages/flutter\_callkit\_incoming](https://pub.dev/packages/flutter_callkit_incoming)
6. flutter\_callkit\_incoming changelog | Flutter package \- Pub.dev, accessed July 2, 2025, [https://pub.dev/packages/flutter\_callkit\_incoming/changelog](https://pub.dev/packages/flutter_callkit_incoming/changelog)
7. team-telnyx/flutter-voice-sdk: Telnyx Flutter WebRTC SDK \- Enable real-time communication with WebRTC and Telnyx \- GitHub, accessed July 2, 2025, [https://github.com/team-telnyx/flutter-voice-sdk](https://github.com/team-telnyx/flutter-voice-sdk)
8. WebRTC Flutter SDK Error Handling \- Telnyx's Developer Documentation, accessed July 2, 2025, [https://developers.telnyx.com/docs/voice/webrtc/flutter-sdk/error-handling](https://developers.telnyx.com/docs/voice/webrtc/flutter-sdk/error-handling)
