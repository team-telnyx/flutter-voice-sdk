# Telnyx Flutter WebRTC SDK

Enable Telnyx real-time communication services on Flutter applications (Android / iOS / Web) :telephone_receiver: :fire:

## Features
TODO: List what your package can do. Maybe include images, gifs, or videos.

## Usage

### SIP Credentials
In order to start making and receiving calls using the TelnyxRTC SDK you will need to get SIP Credentials:

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
  
```




