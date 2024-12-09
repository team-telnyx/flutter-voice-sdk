### Telnyx Client
TelnyxClient() is the core class of the SDK, and can be used to connect to our backend socket connection, create calls, check state and disconnect, etc.

Once an instance is created, you can call the .connect() method to connect to the socket with either a token or credentials (see below). An error will appear as a socket response if there is no network available:

```dart
    TelnyxClient _telnyxClient = TelnyxClient();
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

### Listening for events and reacting - Accepting a Call
In order to be able to accept a call, we first need to listen for invitations. We do this by getting the Telnyx Socket Response callbacks from our TelnyxClient:

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
            // Handle a successful login (via Token or Credentials) - Update UI or Navigate to new screen, etc. 
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
           // Handle a received call answer (ie. Someone has accepted your invite)- Update UI or Navigate to new screen, etc.
          break;
        }
        case SocketMethod.BYE:
        {
           // Handle a call rejection or ending (ie. You or someone else has ended the call) - Update UI or Navigate to new screen, etc.
           break;
      }
    }
};
```