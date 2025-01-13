## Introduction

This document provides a guide on how to set up push notifications for incoming calls on the Telnyx Voice SDK Flutter Plugin. 

It is important to understand how push notifications work in general in relation to Telnyx services. When you connect to the TelnyxClient, you establish a socket connection that can receive and handle incoming calls. However, if your application is in the background or terminated, the socket connection closes and can no longer receive invitations.

To address this limitation, the Telnyx Voice SDK uses push notifications to inform the device of incoming calls. When you log in to the TelnyxClient and provide an APNS or FCM token, the SDK sends a push notification to your device whenever an incoming call is received. Note that this notification only indicates that an invitation is on the way.

Once you respond to a push notification—for example, by tapping “Accept”—you must handle the logic to launch and reconnect to the TelnyxClient. After reconnection, the socket connection is re-established, and the backend will send the actual invitation to your device. In this scenario, it may be helpful to store the fact that the push notification was accepted so that when the invitation arrives (as soon as the socket is connected), you can automatically accept the call.

The following sections provide more detail on how to implement these steps.

## Handling Foreground and Terminated Calls

When the app is in the foreground you do not need to use push notifications to receive calls, however it still might be beneficial to use CallKit to show native UI for the calls. When the app is terminated you will need to use push notifications to receive calls as described below.

## Android

The Android platform makes use of Firebase Cloud Messaging in order to deliver push notifications. To receive notifications when receiving calls on your Android mobile device you will have to enable Firebase Cloud Messaging within your application.

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
      // Show notifcation
      showNotification(message);
      
      // Listen to action from FlutterCallkitIncoming
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
   assert if the `IncomingInviteParams` is not null and only accept/decline if this is available.

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

##  iOS
The iOS Platform makes use of the Apple Push Notification Service (APNS) and Pushkit in order to deliver and receive push notifications
For a detailed tutorial, please visit our official [Push Notification Docs](https://developers.telnyx.com/docs/v2/webrtc/push-notifications?lang=ios)

## Native Swift Code Changes
For a full example please view the [Demo Application Example](https://github.com/team-telnyx/flutter-voice-sdk/blob/main/ios/Runner/AppDelegate.swift)

1. In AppDelegate.swift setup the ability to receive VOIP push notifications by adding these lines to your application function
```swift
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

      //Setup VOIP
      let mainQueue = DispatchQueue.main
      let voipRegistry: PKPushRegistry = PKPushRegistry(queue: mainQueue)
      voipRegistry.delegate = self
      voipRegistry.desiredPushTypes = [PKPushType.voIP]
      
      RTCAudioSession.sharedInstance().useManualAudio = true
      RTCAudioSession.sharedInstance().isAudioEnabled = false

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
```

Note: It is important to add the following lines to your `Info.plist` file to enable push notifications
```xml
<key>UIBackgroundModes</key>
<array>
    <string>processing</string>
    <string>remote-notification</string>
    <string>voip</string>
</array>
```

Also, as we are using WebRTC we need to add the following lines to avoid a bug where there is no audio on iOS when using it with CallKit. Add the following lines to your `AppDelegate.swift` file in the application function as demonstrated above
```swift
      RTCAudioSession.sharedInstance().useManualAudio = true
      RTCAudioSession.sharedInstance().isAudioEnabled = false
```

2. Implement the CallkitIncomingAppDelegate within AppDelegate so that you can action on calls that are received. Callin action.fulfill() will allows us to listen to the events and act on them in our dart code. 
```swift
@main
@objc class AppDelegate: FlutterAppDelegate, PKPushRegistryDelegate, CallkitIncomingAppDelegate {
    func onAccept(_ call: flutter_callkit_incoming.Call, _ action: CXAnswerCallAction) {
        NSLog("onRunner ::  Accept")
        action.fulfill()

    }

    func onDecline(_ call: flutter_callkit_incoming.Call, _ action: CXEndCallAction) {
        NSLog("onRunner  :: Decline")
        action.fulfill()
    }

    func onEnd(_ call: flutter_callkit_incoming.Call, _ action: CXEndCallAction) {
        NSLog("onRunner  :: onEnd")
        action.fulfill()
    }

    func onTimeOut(_ call: flutter_callkit_incoming.Call) {
        NSLog("onRunner  :: TimeOut")
    }

    func didActivateAudioSession(_ audioSession: AVAudioSession) {
        NSLog("onRunner  :: Activate Audio Session")
        RTCAudioSession.sharedInstance().audioSessionDidActivate(audioSession)
        RTCAudioSession.sharedInstance().isAudioEnabled = true
    }

    func didDeactivateAudioSession(_ audioSession: AVAudioSession) {
        NSLog(":: DeActivate Audio Session")
        RTCAudioSession.sharedInstance().audioSessionDidDeactivate(audioSession)
        RTCAudioSession.sharedInstance().isAudioEnabled = false
    }
    
    ....
  ```  

Note: Notice for didActivateAudioSession and didDeactivateAudioSession that we are handling WebRTC manually. This is to handle the before mentioned bug where there is no audio on iOS when using it with CallKit.

1. Register / Invalidate the push device token for iOS within AppDelegate.swift class
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
3. Listen for incoming calls in AppDelegate.swift class and grab the relevant metadata from the push payload to pass to showCallkitIncoming (eg. the callerName, callerNumber, callID, etc)
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
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    completion()
                }
            }
        }
```

Note: it is important to call completion() after showing the callkit incoming screen to avoid the app being terminated by the system. See the last line above. if you don't call completion() in pushRegistry(......, completion: @escaping () -> Void), there may be app crash by system when receiving voIP

## Dart / Flutter Code Changes

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

5. Sending an invitation on iOS when using Callkit. Because of the native changes we made in AppDelegate.swift related to WebRTC audio handling, we now need to start a callkit call whenever we send out an invitation so that we can have an active audio session. This simply means starting a callkit call whenever we send out an invitation. Your call() method could look something like:
```dart
void call(String destination) {
   _currentCall = telnyxClient.newInvite(
      _localName,
      _localNumber,
      destination,
      'State',
      customHeaders: {'X-Header-1': 'Value1', 'X-Header-2': 'Value2'},
   );
   
   var params = CallKitParams(
      id: _currentCall?.callId,
      nameCaller: _localName,
      appName: 'My Calling App',
      handle: destination,
   );
   
   FlutterCallkitIncoming.startCall(params);
}
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

## Handling Background Calls

Background calls are handled slightly differently than terminated calls as the application is not disconnected and in a fresh state. The application is in the background and the socket connection is still active - meaning we can receive an invite on the socket but not be notified about it.

We can get around this by listening to application lifecycle events and checking if the application is in the background, and if so disconnecting from the socket manually. This way we can listen to the push notification and reconnect to the socket when the user accepts the call.

You can do this by either manually creating a lifecycle state listener in dart using the [WidgetsBindingObserver](https://api.flutter.dev/flutter/widgets/WidgetsBindingObserver-class.html) or using a library like [flutter_fgbg](https://pub.dev/packages/flutter_fgbg) to listen to the application lifecycle events.

An implementation could look like this:

```dart
@pragma('vm:entry-point')
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!AppInitializer()._isInitialized) {
    await AppInitializer()
        .initialize(); // handle any initialization here (setting up listeners, etc)
  }

  runApp(
    FGBGNotifier(
        onEvent: (FGBGType type) =>
        switch (type) {
          FGBGType.foreground =>
          {
            print('App in the foreground (FGBGNotifier)'),
            // Check if we are in the foreground as a result of a push notification, if we are do nothing, reconnection will happen there in handlePush. Otherwise connect
            if (telnyxClient.callFromPush)
              {
                telnyxClient.connectWithCredential(getCredentialConfig)
              },
          },
          FGBGType.background =>
          {
            print('App in the background (FGBGNotifier)'),
            telnyxClient.disconnect(),
          }
        },
        child: const MyApp()),
  );
}
```

Note: Notice that in the foreground event we check if we are in the foreground as a result of a push notification, if we are do nothing, reconnection will happen there in handlePush. Otherwise connect. This is because handlePushNotification will be called when the user accepts the call from the push notification and we will reconnect to the socket there.

This also means however that when we are showing a notification, which on iOS can be full screen, we need to make sure that we don't disconnect when the notification is shown. We can do this with FGBG's ignoreWhile method like so:

```dart
  Future<void> showNotification(IncomingInviteParams message) async {
    // Temporarily ignore FGBG events while showing the CallKit notification
    FGBGEvents.ignoreWhile(() async {
      CallKitParams callKitParams = CallKitParams(
        id: message.callID,
        nameCaller: message.callerIdName,
        appName: 'Calling Vault',
        handle: message.callerIdNumber,
        type: 0,
        textAccept: 'Accept',
        textDecline: 'Decline',
        missedCallNotification: const NotificationParams(
          showNotification: false,
          isShowCallback: false,
          subtitle: 'Missed call',
        ),
        duration: 30000,
        extra: {},
        headers: <String, dynamic>{'platform': 'flutter'},
      );

      await FlutterCallkitIncoming.showCallkitIncoming(callKitParams);
    });
  }
```


#### Best Practices for Push Notifications on iOS
1. Push Notifications only work in foreground for apps that are run in `debug` mode (You will not receive push notifications when you terminate the app while running in debug mode). Make sure you are in `release` mode. Preferably test using Testfight or Appstore.
   To test if push notifications are working, disconnect the telnyx client (while app is in foreground) and make a call to the device. You should receive a push notification.

   


