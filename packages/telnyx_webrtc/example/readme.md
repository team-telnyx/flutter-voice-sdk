![Pub Version](https://img.shields.io/pub/v/telnyx_webrtc?color=blue&logo=telnyx)
[![Flutter Test](https://github.com/team-telnyx/telnyx-webrtc-flutter/actions/workflows/unit_tests.yml/badge.svg)](https://github.com/team-telnyx/telnyx-webrtc-flutter/actions/workflows/unit_tests.yml)

For the example app implementation please visit this [root repository](https://github.com/team-telnyx/telnyx-webrtc-flutter)

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

### Telnyx Client
TelnyxClient() is the core class of the SDK, and can be used to connect to our backend socket connection, create calls, check state and disconnect, etc.

Once an instance is created, you can call the .connect() method to connect to the socket. An error will appear as a socket response if there is no network available:

```dart
    TelnyxClient _telnyxClient = TelnyxClient();
    _telnyxClient.connect();
```

### Logging into Telnyx Client
To log into the Telnyx WebRTC client, you'll need to authenticate using a Telnyx SIP Connection. Follow our [quickstart guide](https://developers.telnyx.com/docs/v2/webrtc/quickstart) to create **JWTs** (JSON Web Tokens) to authenticate. To log in with a token we use the tokinLogin() method. You can also authenticate directly with the SIP Connection `username` and `password` with the credentialLogin() method:

 ```dart
    _telnyxClient.tokenLogin(tokenConfig)
                     //OR
    _telnyxClient.credentialLogin(credentialConfig)             
 ```

**Note:** **tokenConfig** and **credentialConfig** are simple classes that represent login settings for the client to use. They look like this:

 ```dart
 /// Creates an instance of CredentialConfig which can be used to log in
///
/// Uses the [sipUser] and [sipPassword] fields to log in
/// [sipCallerIDName] and [sipCallerIDNumber] will be the Name and Number associated
/// [notificationToken] is the token used to register the device for notifications if required (FCM or APNS)
/// The [autoReconnect] flag decided whether or not to attempt a reconnect (3 attempts) in the case of a login failure with
/// legitimate credentials
class CredentialConfig {
  CredentialConfig(this.sipUser, this.sipPassword, this.sipCallerIDName,
      this.sipCallerIDNumber, this.notificationToken, this.autoReconnect);

  final String sipUser;
  final String sipPassword;
  final String sipCallerIDName;
  final String sipCallerIDNumber;
  final String? notificationToken;
  final bool? autoReconnect;
}

/// Creates an instance of TokenConfig which can be used to log in
///
/// Uses the [sipToken] field to log in
/// [sipCallerIDName] and [sipCallerIDNumber] will be the Name and Number associated
/// [notificationToken] is the token used to register the device for notifications if required (FCM or APNS)
/// The [autoReconnect] flag decided whether or not to attempt a reconnect (3 attempts) in the case of a login failure with
/// a legitimate token
class TokenConfig {
  TokenConfig(this.sipToken, this.sipCallerIDName, this.sipCallerIDNumber,
      this.notificationToken, this.autoReconnect);

  final String sipToken;
  final String sipCallerIDName;
  final String sipCallerIDNumber;
  final String? notificationToken;
  final bool? autoReconnect;
}
 ```

####  Adding push notifications - Android platform
The Android platform makes use of Firebase Cloud Messaging in order to deliver push notifications. If you would like to receive notifications when receiving calls on your Android mobile device you will have to enable Firebase Cloud Messaging within your application.

For a detailed tutorial, please visit our official [Push Notification Docs](https://developers.telnyx.com/docs/v2/webrtc/push-notifications?type=Android)

####  Adding push notifications - iOS platform
The iOS Platform makes use of the Apple Push Notification Service (APNS) and Pushkit in order to deliver and receive push notifications

For a detailed tutorial, please visit our official [Push Notification Docs](https://developers.telnyx.com/docs/v2/webrtc/push-notifications?lang=ios)

### Creating a call invitation
In order to make a call invitation, we first create an instance of the Call class with the .createCall() method. This creates a Call class which can be used to interact with calls (invite, accept, decline, etc).
To then send an invite, we can use the .newInvite() method which requires you to provide your callerName, callerNumber, the destinationNumber (or SIP credential), and your clientState (any String value).

```dart
    _telnyxClient
        .createCall()
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
            _incomingInvite = message.message.inviteParams;
            _telnyxClient.createCall().acceptCall(
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
    notifyListeners();
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

Questions? Comments? Building something rad? [Join our Slack channel](https://joinslack.telnyx.com/) and share.

## License

[`MIT Licence`](./LICENSE) © [Telnyx](https://github.com/team-telnyx)










