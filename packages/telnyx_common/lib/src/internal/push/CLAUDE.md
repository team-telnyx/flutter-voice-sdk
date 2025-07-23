# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with push notifications in the `telnyx_common` package. It outlines the architecture and flow of handling incoming call notifications, ensuring a clear understanding of the design principles and implementation details.

# Push Notification Handling in the Telnyx Common Module

This document outlines the architecture and step-by-step flow of handling push notifications for incoming calls within the `telnyx_common` module. The design prioritizes abstracting complexity away from the implementing developer, ensuring a robust and seamless user experience on both Android and iOS.

## Overview

The entire process is orchestrated by the `TelnyxVoiceApp` widget, which serves as a wrapper around the main application. It manages the lifecycle, initialization, and communication between different application states (foreground, background, terminated).

The core principle is a **separation of concerns** between two Dart isolates:

1.  **Background Isolate**: Triggered by a push notification when the app is not in the foreground. Its sole responsibilities are to display the native incoming call UI and persist the user's action (accept/decline) to local storage.
2.  **Foreground (UI) Isolate**: This is the main application thread. When launched after a user accepts a call, it reads the persisted action from storage, connects to the Telnyx backend, and manages the active call state.

This separation prevents the need to run a full-headless version of the app in the background, making the process lightweight and reliable across platforms.

## Key Components

-   **`TelnyxVoiceApp`**: A stateful widget that automates the initialization of Firebase/APNs, registers background handlers, and manages the `TelnyxVoipClient` lifecycle.
-   **`TelnyxVoipClient`**: The primary facade for all SDK interactions, used temporarily in the background and as a singleton in the foreground.
-   **`PushNotificationManager`**: A specialized class that acts as a bridge to the `flutter_callkit_incoming` library. **This is a key abstraction layer**, translating a single Dart command into the appropriate native UI for either platform.
-   **`SharedPreferences` (`TelnyxClient.setPushMetaData`)**: The platform-agnostic communication channel between the background and foreground isolates. It's used to store the push payload and the user's action.
-   **`CallStateController`**: The internal state machine for calls, translating low-level socket messages into high-level `Call` objects for UI consumption.

## Platform-Specific Entry Points

While the Dart logic is shared, the initial trigger for a push notification is platform-specific.

### iOS

-   **Push Service**: Uses **APNs (Apple Push Notification service)** with **PushKit**. PushKit notifications are high-priority and are designed specifically for VoIP apps, allowing the app to be woken up reliably from a terminated state to handle a call.
-   **Native Entry Point**: The `didReceiveIncomingPushWith` method in the project's `AppDelegate.swift` file is the first to receive the push. It then forwards the payload to the Dart side for processing.
-   **Native UI**: `PushNotificationManager` uses `flutter_callkit_incoming` to interact with **CallKit**, the native iOS calling framework. This presents the familiar, standard iOS incoming call screen, providing a deeply integrated user experience.

### Android

-   **Push Service**: Uses **FCM (Firebase Cloud Messaging)**.
-   **Native Entry Point**: The `FirebaseMessaging.onBackgroundMessage` callback, registered by `TelnyxVoiceApp`, is triggered.
-   **Native UI**: `PushNotificationManager` uses `flutter_callkit_incoming` to create a high-priority notification channel, display a heads-up notification, and manage the Android `ConnectionService` and `Telecom` framework.

**From this point forward, the flow is identical for both platforms.**

## Step-by-Step Flow

1.  **Initialization**: `TelnyxVoiceApp.initializeAndCreate` sets up the appropriate push listeners for the platform it's running on.

2.  **Receiving a Push (App in Background/Terminated)**: The platform-specific entry point (APNs/PushKit for iOS, FCM for Android) is triggered, and the payload is passed to a Dart background isolate. A temporary `TelnyxVoipClient` is created.

3.  **Displaying Native UI**: The temporary client's `handlePushNotification` method calls `PushNotificationManager`, which displays the appropriate native UI (**CallKit** on iOS, a heads-up notification on Android).

4.  **User Interaction with Native UI**:

    #### Path A: User Accepts
    1.  `PushNotificationManager` receives the `actionCallAccept` event from `flutter_callkit_incoming` (which gets it from CallKit on iOS).
    2.  It invokes the `_onPushNotificationAccepted` callback in the temporary `TelnyxVoipClient`.
    3.  This callback calls `TelnyxClient.setPushMetaData`, saving the push payload and `isAnswer: true` to `SharedPreferences`.
    4.  The temporary background client is disposed of.

    #### Path B: User Declines
    1.  `PushNotificationManager` receives the `actionCallDecline` event.
    2.  It invokes the `_onPushNotificationDeclined` callback.
    3.  The temporary client performs the "fire-and-forget" decline by connecting, sending the decline message, and disconnecting.

5.  **App Launch & Connection (Post-Acceptance)**:
    1.  The main application launches.
    2.  `TelnyxVoiceApp`'s `initState` logic reads the `isAnswer: true` flag from `SharedPreferences`.
    3.  It calls `handlePushNotification` on the **main `TelnyxVoipClient` instance**, which sees the flag and knows to connect to Telnyx immediately.

6.  **Call State Synchronization**:
    1.  Once connected, the `INVITE` is received from the Telnyx backend.
    2The UI updates directly to the active call screen, providing a seamless transition for the user on both iOS and Android.