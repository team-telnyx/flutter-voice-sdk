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

### Restart ICE

The SDK recovers active calls automatically. When ICE or the peer connection fails (or stays disconnected for 3 seconds), it restarts ICE on the same peer connection if signaling is healthy, probes signaling first if it is stale, and falls back to a single reconnect / reattach if media does not resume within 5 seconds. Recovery is enabled by default and controlled by `enableSignalingHealthMonitor` on `CredentialConfig` / `TokenConfig`.

To restart ICE yourself on an active call, for example from a "Restart ICE" debug action, call `.iceRestart()`:

```dart
    final started = _telnyxClient.call.iceRestart();
    if (!started) {
      // The call is not active, signaling is down, there is no peer
      // connection, or a recovery is already running.
    }
```

`true` means the restart was accepted; with recovery enabled (the default) it uses the same timeout, media verification and reattach fallback as automatic recovery. With `enableSignalingHealthMonitor: false`, `iceRestart()` uses the legacy direct ICE renegotiation instead: it sends the offer and applies the answer, without the timeout, media verification or reattach fallback. If a reattach replaced the call, the request is forwarded to the replacement call. `restartIce()` is deprecated in favor of `iceRestart()`.
