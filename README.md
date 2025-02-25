[![Pub Version](https://img.shields.io/pub/v/telnyx_webrtc?color=blue&logo=telnyx)](https://pub.dev/packages/telnyx_webrtc)
[![Flutter Test](https://github.com/team-telnyx/telnyx-webrtc-flutter/actions/workflows/unit_tests.yml/badge.svg)](https://github.com/team-telnyx/telnyx-webrtc-flutter/actions/workflows/unit_tests.yml)

# Telnyx Flutter Voice SDK

Enable Telnyx real-time communication services on Flutter applications (Android / iOS / Web) :telephone_receiver: :fire:

## Features
- [x] Create / Receive calls
- [x] Hold calls
- [x] Mute calls
- [x] Dual Tone Multi Frequency

## Usage

### SIP Credentials
In order to start making and receiving calls using the TelnyxRTC SDK you will need to get SIP Credentials:

![Screenshot 2022-07-15 at 13 51 45](https://user-images.githubusercontent.com/9112652/179226614-f0477f38-6131-4cef-9c7a-3366f23a89b6.png)

1. Access to https://portal.telnyx.com/
2. Sign up for a Telnyx Account.
3. Create a Credential Connection to configure how you connect your calls.
4. Create an Outbound Voice Profile to configure your outbound call settings and assign it to your Credential Connection.

For more information on how to generate SIP credentials check the [Telnyx WebRTC quickstart guide](https://developers.telnyx.com/docs/v2/webrtc/quickstart).

### Platform Specific Configuration

## Android
If you are implementing the SDK into an Android application it is important to remember to add the following permissions to your AndroidManifest in order to allow Audio and Internet permissions:

```xml
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
```

## iOS
on the iOS platform, you need to add the microphone permission to your Info.plist file:

```xml
    <key>NSMicrophoneUsageDescription</key>
    <string>$(PRODUCT_NAME) Microphone Usage!</string>
```

## Basic Usage

### Telnyx Client
TelnyxClient() is the core class of the SDK, and can be used to connect to our backend socket connection, create calls, check state and disconnect, etc.

Once an instance is created, you can call the .connect() method to connect to the socket with either a token or credentials (see below). An error will appear as a socket response if there is no network available:

```dart
    TelnyxClient _telnyxClient = TelnyxClient();
```

### Logging Configuration
The SDK provides a flexible logging system that allows you to control the verbosity of logs and even implement your own custom logging solution. There are two main aspects to configure:

1. **Log Level**
The `LogLevel` enum determines which types of logs are displayed:
```dart
enum LogLevel {
  none,    // Disable all logs (default)
  error,   // Print error logs only
  warning, // Print warning logs only
  debug,   // Print debug logs only
  info,    // Print info logs only
  verto,   // Print verto protocol messages
  all      // Print all logs
}
```

2. **Custom Logger**
You can implement your own logging solution by extending the `CustomLogger` abstract class:
```dart
class MyCustomLogger extends CustomLogger {
  @override
  void e(String message) => print('ERROR: $message');
  
  @override
  void w(String message) => print('WARNING: $message');
  
  @override
  void d(String message) => print('DEBUG: $message');
  
  @override
  void i(String message) => print('INFO: $message');
  
  @override
  void v(String message) => print('VERTO: $message');
}
```

Both the log level and custom logger can be configured in the `Config` class:
```dart
var config = CredentialConfig(
  sipUser: 'username',
  sipPassword: 'password',
  sipCallerIDName: 'Caller Name',
  sipCallerIDNumber: '1234567890',
  debug: true,  // Enable debug mode which allows you to track call metrics and download them from the portal - this is different to the log level and custom logger
  logLevel: LogLevel.debug,  // Set log level
  customLogger: MyCustomLogger(),  // Optional: provide custom logger
);
```

### Logging into Telnyx Client
To log into the Telnyx WebRTC client, you'll need to authenticate using a Telnyx SIP Connection. Follow our [quickstart guide](https://developers.telnyx.com/docs/v2/webrtc/quickstart) to create **JWTs** (JSON Web Tokens) to authenticate. To log in with a token we use the connectWithToken() method. You can also authenticate directly with the SIP Connection `username` and `password` with the connectWithCredential() method:

 ```dart
    _telnyxClient.connectWithToken(tokenConfig)
                     //OR
    _telnyxClient.connectWithCredential(credentialConfig)             
 ```

**Note:** **tokenConfig** and **credentialConfig** are simple classes that represent login settings for the client to use they extend a base Config class with shared properties. They look like this:

 ```dart
/// Creates an instance of CredentialConfig which can be used to log in
///
/// Uses the [sipUser] and [sipPassword] fields to log in
/// [sipCallerIDName] and [sipCallerIDNumber] will be the Name and Number associated
/// [notificationToken] is the token used to register the device for notifications if required (FCM or APNS)
/// The [autoReconnect] flag decided whether or not to attempt a reconnect (3 attempts) in the case of a login failure with
/// legitimate credentials
class CredentialConfig extends Config {
   CredentialConfig({
      required this.sipUser,
      required this.sipPassword,
      required super.sipCallerIDName,
      required super.sipCallerIDNumber,
      super.notificationToken,
      super.autoReconnect,
      required super.debug,
      super.ringTonePath,
      super.ringbackPath,
   });

   final String sipUser;
   final String sipPassword;
}

/// Creates an instance of TokenConfig which can be used to log in
///
/// Uses the [sipToken] field to log in
/// [sipCallerIDName] and [sipCallerIDNumber] will be the Name and Number associated
/// [notificationToken] is the token used to register the device for notifications if required (FCM or APNS)
/// The [autoReconnect] flag decided whether or not to attempt a reconnect (3 attempts) in the case of a login failure with
/// a legitimate token
class TokenConfig extends Config {
   TokenConfig({
      required this.sipToken,
      required super.sipCallerIDName,
      required super.sipCallerIDNumber,
      super.notificationToken,
      super.autoReconnect,
      required super.debug,
      super.ringTonePath,
      super.ringbackPath,
   });

   final String sipToken;
}
 ```

### Creating a call invitation
In order to make a call invitation, we first create an instance of the Call class with the .call instance. This creates a Call class which can be used to interact with calls (invite, accept, decline, etc).
To then send an invite, we can use the .newInvite() method which requires you to provide your callerName, callerNumber, the destinationNumber (or SIP credential), and your clientState (any String value).

```dart
    _telnyxClient
        .call
        .newInvite("callerName", "000000000", destination, "State");
```

### Accepting a call
In order to be able to accept a call, we first need to listen for invitations. We do this by getting the Telnyx Socket Response callbacks:

```dart
 // Observe Socket Messages Received
_telnyxClient.onSocketMessageReceived = (TelnyxMessage message) {
  switch (message.socketMethod) {
        case SocketMethod.CLIENT_READY:
        {
           // Fires once client has correctly been setup and logged into, you can now make calls. 
           break;
        }
        case SocketMethod.LOGIN:
        {
            // Handle a successful login - Update UI or Navigate to new screen, etc. 
            break;
        }
        case SocketMethod.INVITE:
        {
            // Handle an invitation Update UI or Navigate to new screen, etc. 
            // Then, through an answer button of some kind we can accept the call with:
            // This will return an instance of the Call class which can be used to interact with the call or monitor it's state.
            _incomingInvite = message.message.inviteParams;
            _call = _telnyxClient.acceptCall(
                _incomingInvite, "callerName", "000000000", "State");
            break;
        }
        case SocketMethod.ANSWER:
        {
           // Handle a received call answer - Update UI or Navigate to new screen, etc.
          break;
        }
        case SocketMethod.BYE:
        {
           // Handle a call rejection or ending - Update UI or Navigate to new screen, etc.
           break;
      }
    }
};
```

We can then use this method to create a listener that listens for an invitation and, in this case, answers it straight away. A real implementation would be more suited to show some UI and allow manual accept / decline operations. 

### Decline / End Call

In order to end a call, we can get a stored instance of Call and call the .endCall(callID) method. To decline an incoming call we first create the call with the .createCall() method and then call the .endCall(callID) method:

```dart
    if (_ongoingCall) {
      _telnyxClient.call.endCall(_telnyxClient.call.callId);
    } else {
      _telnyxClient.createCall().endCall(_incomingInvite?.callID);
    }
```

### DTMF (Dual Tone Multi Frequency)

In order to send a DTMF message while on a call you can call the .dtmf(callID, tone), method where tone is a String value of the character you would like pressed:

```dart
    _telnyxClient.call.dtmf(_telnyxClient.call.callId, tone);
```

### Mute a call

To mute a call, you can simply call the .onMuteUnmutePressed() method:

```dart
    _telnyxClient.call.onMuteUnmutePressed();
```

### Toggle loud speaker

To toggle loud speaker, you can simply call .enableSpeakerPhone(bool):

```dart
    _telnyxClient.call.enableSpeakerPhone(true);
```

### Put a call on hold

To put a call on hold, you can simply call the .onHoldUnholdPressed() method:

```dart
    _telnyxClient.call.onHoldUnholdPressed();
```

## Advanced Usage - Push Notifications

###  Adding push notifications - Android platform
The Android platform makes use of Firebase Cloud Messaging in order to deliver push notifications. To receive notifications when receiving calls on your Android mobile device you will have to enable Firebase Cloud Messaging within your application.
For a detailed tutorial, please visit our official [Push Notification Docs](https://developers.telnyx.com/docs/v2/webrtc/push-notifications?type=Android).

Note: for flutter, an easy way to add the firebase configuration after setting up the firebase project is to simply run the `flutterfire configure` command in the terminal. For example, if your firebase project is called `myproject` you would run `flutterfire configure myproject`. This will generate all the required files and configurations for your project.

The Demo app uses the [FlutterCallkitIncoming](https://pub.dev/packages/flutter_callkit_incoming) plugin to show incoming calls. To show a notification when receiving a call, you can follow the steps below:
1. Listen for Background Push Notifications, Implement the `FirebaseMessaging.onBackgroundMessage` method in your `main` method
```dart

@pragma('vm:entry-point')
Future<void> main() async {
    WidgetsFlutterBinding.ensureInitialized();

    if (defaultTargetPlatform == TargetPlatform.android) {
      // Android Only - Push Notifications
        await Firebase.initializeApp();
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      
        await FirebaseMessaging.instance
                .setForegroundNotificationPresentationOptions(
         alert: true,
         badge: true,
         sound: true,
      );
    }
      runApp(const MyApp());
}
```

2. Optionally Add the `metadata` to CallKitParams `extra` field
```dart

    static Future showNotification(RemoteMessage message)  {
      CallKitParams callKitParams = CallKitParams(
        android:...,
          ios:...,
          extra: message.data,
      )
      await FlutterCallkitIncoming.showCallkitIncoming(callKitParams);
    }
```


3. Handle the push notification in the `_firebaseMessagingBackgroundHandler` method
```dart

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
      //show notifcation
      showNotification(message);
      
      //Listen to action from FlutterCallkitIncoming
      FlutterCallkitIncoming.onEvent.listen((CallEvent? event) async {
       switch (event!.event) {
        case Event.actionCallAccept:
         // Set the telnyx metadata for access when the app comes to foreground
         TelnyxClient.setPushMetaData(
                 message.data, isAnswer: true, isDecline: false);
         break;
        case Event.actionCallDecline:
        /*
        * When the user declines the call from the push notification, the app will no longer be visible, and we have to
        * handle the endCall user here.
        * Login to the TelnyxClient and end the call
        * */
          ...
       }});
}


```

4. Use the `TelnyxClient.getPushMetaData()` method to retrieve the metadata when the app comes to the foreground. This data is only available on 1st access and becomes `null` afterward.
```dart
    Future<void> _handlePushNotification() async {
       final  data = await TelnyxClient.getPushMetaData();
       PushMetaData? pushMetaData = PushMetaData.fromJson(data);
      if (pushMetaData != null) {
        _telnyxClient.handlePushNotification(pushMetaData, credentialConfig, tokenConfig);
      }
    }
```

5. To Handle push calls on foreground, Listen for Call Events and invoke the `handlePushNotification` method
```dart
FlutterCallkitIncoming.onEvent.listen((CallEvent? event) {
   switch (event!.event) {
   case Event.actionCallIncoming:
   // retrieve the push metadata from extras
   final data = await TelnyxClient.getPushData();
   ...
  _telnyxClient.handlePushNotification(pushMetaData, credentialConfig, tokenConfig);
    break;
   case Event.actionCallStart:
    ....
   break;
   case Event.actionCallAccept:
     ...
   logger.i('Call Accepted Attach Call');
   break;
   });
```

#### Best Practices for Push Notifications on Android
1. Request for Notification Permissions for android 13+ devices to show push notifications. More information can be found [here](https://developer.android.com/develop/ui/views/notifications/notification-permission)
2. Push Notifications only work in foreground for apps that are run in `debug` mode (You will not receive push notifications when you terminate the app while running in debug mode).
3. On Foreground calls, you can use the `FirebaseMessaging.onMessage.listen` method to listen for incoming calls and show a notification.
```dart
 FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        TelnyxClient.setPushMetaData(message.data);
        NotificationService.showNotification(message);
        mainViewModel.callFromPush = true;
      });
```
4. To handle push notifications on the background,  use the `FirebaseMessaging.onBackgroundMessage` method to listen for incoming calls and show a notification and make sure to set the ` TelnyxClient.setPushMetaData` when user answers the call.
```dart 
 TelnyxClient.setPushMetaData(
                 message.data, isAnswer: true, isDecline: false);
```
5. When you call the `telnyxClient.handlePushNotification` it connects to the `telnyxClient`, make sure not to call the `telnyxClient.connect()` method after this. e.g an Edge case might be if you call `telnyxClient.connect()` on Widget `init` method it
   will always call the `connect` method


6. Early Answer/Decline : Users may answer/decline the call too early before a socket connection is established. To handle this situation,
   assert if the `IncomingInviteParams` is not null and only accept/decline if this is availalble.
```dart
bool waitingForInvite = false;

void accept() {

if (_incomingInvite != null) {
  // accept the call if the incomingInvite arrives on time 
      _currentCall = _telnyxClient.acceptCall(
          _incomingInvite!, _localName, _localNumber, "State");
    } else {
      // set waitingForInvite to true if we have an early accept
      waitingForInvite = true;
    }
}


 _telnyxClient.onSocketMessageReceived = (TelnyxMessage message) {
      switch (message.socketMethod) {
        ...
        case SocketMethod.INVITE:
          {
            if (callFromPush) {
              // For early accept of call
              if (waitingForInvite) {
                //accept the call
                accept();
                waitingForInvite = false;
              }
              callFromPush = false;
            }

          }
        ...
      }
 }
```



### Adding push notifications - iOS platform
The iOS Platform makes use of the Apple Push Notification Service (APNS) and Pushkit in order to deliver and receive push notifications
For a detailed tutorial, please visit our official [Push Notification Docs](https://developers.telnyx.com/docs/v2/webrtc/push-notifications?lang=ios)
1. Register/Invalidate the push device token for iOS
```swift
        func pushRegistry(_ registry: PKPushRegistry, didUpdate credentials: PKPushCredentials, for type: PKPushType) {
            print(credentials.token)
            let deviceToken = credentials.token.map { String(format: "%02x", $0) }.joined()
            //Save deviceToken to your server
            SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP(deviceToken)
        }
        
        func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
            SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP("")
        }
```

2. For foreground calls to work, you need to register with callkit on the restorationHandler delegate function. You can also choose to register with callkit using iOS official documentation on
   [CallKit](https://developer.apple.com/documentation/callkit/).
```swift
  override func application(_ application: UIApplication,
                                  continue userActivity: NSUserActivity,
                                  restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
                                  
            let nameCaller = handleObj.getDecryptHandle()["nameCaller"] as? String ?? ""
            let handle = handleObj.getDecryptHandle()["handle"] as? String ?? ""
            let data = flutter_callkit_incoming.Data(id: UUID().uuidString, nameCaller: nameCaller, handle: handle, type: isVideo ? 1 : 0)
            //set more data...
            data.nameCaller = "dummy"
            SwiftFlutterCallkitIncomingPlugin.sharedInstance?.startCall(data, fromPushKit: true)
         
         }                         
```
3. Listen for incoming calls in AppDelegate.swift class
```swift 
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
            print("didReceiveIncomingPushWith")
            guard type == .voIP else { return }
            
            if let metadata = payload.dictionaryPayload["metadata"] as? [String: Any] {
                var callID = UUID.init().uuidString
                if let newCallId = (metadata["call_id"] as? String),
                   !newCallId.isEmpty {
                    callID = newCallId
                }
                let callerName = (metadata["caller_name"] as? String) ?? ""
                let callerNumber = (metadata["caller_number"] as? String) ?? ""
                
                let id = payload.dictionaryPayload["call_id"] as? String ??  UUID().uuidString
                
                let data = flutter_callkit_incoming.Data(id: id, nameCaller: callerName, handle: callerNumber, type: isVideo ? 1 : 0)
                data.extra = payload.dictionaryPayload as NSDictionary
                data.normalHandle = 1              
                
                let caller = callerName.isEmpty ? (callerNumber.isEmpty ? "Unknown" : callerNumber) : callerName
                let uuid = UUID(uuidString: callID)
                
                data.uuid = uuid!.uuidString
                data.nameCaller = caller
                
                SwiftFlutterCallkitIncomingPlugin.sharedInstance?.showCallkitIncoming(data, fromPushKit: true)
            }
        }
```

4. Listen for Call Events and invoke the `handlePushNotification` method
```dart
   FlutterCallkitIncoming.onEvent.listen((CallEvent? event) {
   switch (event!.event) {
   case Event.actionCallIncoming:
   // retrieve the push metadata from extras
    PushMetaData? pushMetaData = PushMetaData.fromJson(event.body['extra']['metadata']);
    _telnyxClient.handlePushNotification(pushMetaData, credentialConfig, tokenConfig);
    break;
   case Event.actionCallStart:
    ....
   break;
   case Event.actionCallAccept:
     ...
   logger.i('Call Accepted Attach Call');
   break;
   });
```

### Handling Late Notifications
If notifications arrive very late due to no internet connectivity, It is good to always flag it as a missed call. You can do that using the
code snippet below :

```dart
const CALL_MISSED_TIMEOUT = 60;

 DateTime nowTime = DateTime.now();
 Duration? difference = nowTime?.difference(message.sentTime!);

 if (difference.inSeconds > CALL_MISSED_TIMEOUT) {
    NotificationService.showMissedCallNotification(message);
    return;
}
```

#### Best Practices for Push Notifications on iOS
1. Push Notifications only work in foreground for apps that are run in `debug` mode (You will not receive push notifications when you terminate the app while running in debug mode). Make sure you are in `release` mode. Preferably test using Testfight or Appstore.
   To test if push notifications are working, disconnect the telnyx client (while app is in foreground) and make a call to the device. You should receive a push notification.

   
Questions? Comments? Building something rad? [Join our Slack channel](https://joinslack.telnyx.com/) and share.

## License

[`MIT Licence`](./LICENSE) © [Telnyx](https://github.com/team-telnyx)
