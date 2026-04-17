# Migration Guide: v3.x to v4.0.0

This guide covers the migration from Telnyx Flutter Voice SDK v3.x to v4.0.0.

## Overview

Version 4.0.0 introduces improved push notification handling, specifically for missed call scenarios. The main enhancement is:

- **Missed call notification handling** — Automatically dismiss CallKit when a call is missed or rejected remotely

## ⚠️ Breaking Changes

### Missed Call Notification Handling (Required for iOS)

**Action Required:** v4.0.0 requires you to update your iOS `AppDelegate.swift` to handle missed call VoIP push notifications.

**Why This is Critical:**

Per Apple's PushKit policy, apps receiving VoIP push notifications **must report all incoming calls to CallKit**. Starting in v4.0.0, Telnyx servers send "Missed call!" push notifications when calls are rejected remotely or missed.

**Failure to handle these notifications can result in:**
- ⚠️ Apple stopping push notifications to that device as they are not handled
- ⚠️ Stale CallKit UI showing for calls that no longer exist
- ⚠️ Users attempting to answer calls that have already ended
- ⚠️ Poor user experience

## Migration Steps

### iOS: Update AppDelegate.swift

In your `AppDelegate.swift`, update the `pushRegistry(_:didReceiveIncomingPushWith:for:completion:)` method to detect and handle missed call notifications:

```swift
func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
    guard type == .voIP else { return }
    
    // Check for missed call notification (SDK 4.0.0+)
    if let aps = payload.dictionaryPayload["aps"] as? [String: Any],
       let alert = aps["alert"] as? String,
       alert == "Missed call!" {
        print("Received missed call notification, dismissing CallKit")
        
        if let metadata = payload.dictionaryPayload["metadata"] as? [String: Any] {
            var callID = UUID().uuidString
            if let newCallId = metadata["call_id"] as? String, !newCallId.isEmpty {
                callID = newCallId
            }
            
            // End the call to dismiss CallKit UI
            let data = flutter_callkit_incoming.Data(id: callID, nameCaller: "", handle: "", type: 0)
            data.uuid = callID
            SwiftFlutterCallkitIncomingPlugin.sharedInstance?.endCall(data)
        }
        
        completion()
        return
    }
    
    // Handle regular incoming call notification as before
    // ... your existing code
}
```

### Android: No Changes Required

Android already handles missed call notifications via FCM. No changes are needed for Android.

## How It Works

### Server-Side Behavior (v4.0.0+)

1. User A calls User B
2. User B's device receives VoIP push notification → CallKit UI appears
3. User A hangs up before User B answers
4. Telnyx server sends "Missed call!" push notification to User B
5. User B's app detects the missed call notification
6. CallKit UI is dismissed automatically

### Push Notification Payload Format

Missed call notifications have this structure:

```json
{
  "aps": {
    "alert": "Missed call!"
  },
  "metadata": {
    "call_id": "uuid-of-the-call",
    "caller_name": "...",
    "caller_number": "..."
  }
}
```

Your app detects the `"Missed call!"` alert string to differentiate from regular incoming call notifications.

## Testing

To verify the implementation:

1. Have someone call your test device
2. Have the caller hang up before you answer
3. Verify the CallKit UI dismisses automatically
4. Check logs for: `"Received missed call notification, dismissing CallKit"`

## Implementation Reference

See the example app's [`AppDelegate.swift`](../../ios/Runner/AppDelegate.swift) for a complete implementation.

## Summary

v4.0.0 introduces missed call notification handling to provide a better user experience. The change is minimal — just add the missed call detection logic to your existing push notification handler.
