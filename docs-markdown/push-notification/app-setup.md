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

##  iOS
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

   


