### Call
The Call class is used to manage the call state and call actions. It is used to accept, decline, end, mute, hold, and send DTMF tones during a call.

### Accept Call

In order to accept a call, we simply retrieve the instance of the call and use the .acceptCall(callID) method:

```dart
    _telnyxClient.call.acceptCall(_incomingInvite?.callID);
```

### Decline / End Call

In order to end a call, we can get a stored instance of Call and call the .endCall(callID) method. To decline an incoming call we first create the call with the .createCall() method and then call the .endCall(callID) method:

```dart
    if (_ongoingCall) {
      _telnyxClient.call.endCall(_telnyxClient.call.callId);
    } else {
      _telnyxClient.createCall().endCall(_incomingInvite?.callID);
    }
```

### Handling Late Notifications
If notifcations arrive very late due to no internet connectivity, It is good to always flag it as a missed call. You can do that using the
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
