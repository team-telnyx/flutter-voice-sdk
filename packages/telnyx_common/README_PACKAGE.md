# telnyx_common

A high-level, state-agnostic, drop-in module for the Telnyx Flutter SDK that simplifies WebRTC integration.

## Overview

The `telnyx_common` package provides a simplified interface for integrating Telnyx WebRTC capabilities into Flutter applications. It handles session management, call state transitions, push notification processing, and native call UI integration, allowing developers to focus on their application logic rather than the complexities of real-time communication.

## Features

### Phase 1: Core Engine & Headless Operation ✅
- **SessionManager**: Manages TelnyxClient connection lifecycle
- **CallStateController**: Central state machine for call management
- **TelnyxVoipClient**: Public facade with state-agnostic API
- **Comprehensive Testing**: Unit tests for core functionality
- **Headless Example**: Console-based example application

### Phase 2: Native UI Integration (In Development)
- **CallKitAdapter**: Native call UI integration
- **Push Notification Gateway**: Unified push handling
- **Full Native Experience**: iOS CallKit and Android call screens

### Phase 3: Robustness & Background Processing (Planned)
- **Error Handling**: Comprehensive error recovery
- **Background Execution**: Stable calls when app is backgrounded
- **Network Resilience**: Graceful handling of network interruptions

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  telnyx_common:
    path: ../telnyx_common  # Adjust path as needed
```

## Quick Start

### 1. Initialize the Client

```dart
import 'package:telnyx_common/telnyx_common.dart';

// Create client instance
final telnyxClient = TelnyxVoipClient();

// For native UI integration (Phase 2)
final telnyxClient = TelnyxVoipClient(enableNativeUI: true);
```

### 2. Connect to Telnyx

```dart
// Using credentials
await telnyxClient.login(CredentialConfig(
  sipUser: 'your_sip_user',
  sipPassword: 'your_sip_password',
  fcmToken: 'your_fcm_token', // Optional
));

// Using token
await telnyxClient.loginWithToken(TokenConfig(
  token: 'your_auth_token',
  fcmToken: 'your_fcm_token', // Optional
));
```

### 3. Monitor Connection State

```dart
telnyxClient.connectionState.listen((state) {
  switch (state.runtimeType) {
    case Connecting:
      print('Connecting to Telnyx...');
      break;
    case Connected:
      print('Connected to Telnyx!');
      break;
    case Disconnected:
      print('Disconnected from Telnyx');
      break;
    case ConnectionError:
      print('Connection error: ${(state as ConnectionError).error}');
      break;
  }
});
```

### 4. Make a Call

```dart
final call = await telnyxClient.newCall(destination: '+1234567890');

// Monitor call state
call.callState.listen((state) {
  print('Call state: $state');
});

// Monitor mute state
call.isMuted.listen((muted) {
  print('Call muted: $muted');
});
```

### 5. Handle Incoming Calls

```dart
// Listen for incoming calls
telnyxClient.calls.listen((calls) {
  for (final call in calls) {
    if (call.isIncoming && call.currentState == CallState.ringing) {
      // Show incoming call UI
      showIncomingCallDialog(call);
    }
  }
});

// Answer a call
await call.answer();

// Decline a call
await call.hangup();
```

### 6. Call Control

```dart
// Mute/unmute
await call.toggleMute();

// Hold/unhold
await call.toggleHold();

// Send DTMF
await call.dtmf('1');

// End call
await call.hangup();
```

## State Management Integration

The `telnyx_common` package is designed to be state-management agnostic. Here are examples for popular frameworks:

### BLoC/Cubit

```dart
class CallCubit extends Cubit<CallState> {
  final TelnyxVoipClient _telnyxClient;
  StreamSubscription? _callSubscription;

  CallCubit(this._telnyxClient) : super(NoCallState()) {
    _callSubscription = _telnyxClient.activeCall.listen((call) {
      if (call != null) {
        emit(InCallState(call));
      } else {
        emit(NoCallState());
      }
    });
  }

  @override
  Future<void> close() {
    _callSubscription?.cancel();
    return super.close();
  }
}
```

### Provider/Riverpod

```dart
// Provider
final telnyxClientProvider = Provider((ref) => TelnyxVoipClient());

final activeCallProvider = StreamProvider<Call?>((ref) {
  final client = ref.watch(telnyxClientProvider);
  return client.activeCall;
});

// Widget
class CallScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCall = ref.watch(activeCallProvider);
    return activeCall.when(
      data: (call) => call != null ? InCallUI(call: call) : NoCallUI(),
      loading: () => CircularProgressIndicator(),
      error: (err, stack) => Text('Error: $err'),
    );
  }
}
```

### GetX

```dart
class CallController extends GetxController {
  final TelnyxVoipClient _telnyxClient = TelnyxVoipClient();
  final Rx<Call?> activeCall = Rx<Call?>(null);

  @override
  void onInit() {
    super.onInit();
    _telnyxClient.activeCall.listen((call) {
      activeCall.value = call;
    });
  }

  @override
  void onClose() {
    _telnyxClient.dispose();
    super.onClose();
  }
}
```

## Push Notifications (Phase 2)

For handling incoming calls via push notifications:

```dart
// In your FirebaseMessaging background handler
FirebaseMessaging.onBackgroundMessage((RemoteMessage message) async {
  await telnyxClient.handlePushNotification(message.data);
});

// In your foreground message handler
FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
  await telnyxClient.handlePushNotification(message.data);
});
```

## Testing

Run the headless example to test core functionality:

```bash
cd packages/telnyx_common
dart run example/headless_example.dart
```

Run unit tests:

```bash
flutter test
```

## API Reference

### TelnyxVoipClient

The main public interface for the telnyx_common module.

#### Properties

- `connectionState`: Stream<ConnectionState> - Connection status
- `calls`: Stream<List<Call>> - All active calls
- `activeCall`: Stream<Call?> - Currently active call

#### Methods

- `login(CredentialConfig)`: Connect with credentials
- `loginWithToken(TokenConfig)`: Connect with token
- `logout()`: Disconnect from Telnyx
- `newCall({required String destination})`: Initiate outgoing call
- `handlePushNotification(Map<String, dynamic>)`: Process push notification
- `dispose()`: Clean up resources

### Call

Represents an individual call with state management and control methods.

#### Properties

- `callId`: Unique identifier
- `destination`: Destination number (outgoing calls)
- `callerName`: Caller name (incoming calls)
- `callerNumber`: Caller number (incoming calls)
- `isIncoming`: Whether this is an incoming call
- `callState`: Stream<CallState> - Call state changes
- `isMuted`: Stream<bool> - Mute state changes
- `isHeld`: Stream<bool> - Hold state changes

#### Methods

- `answer()`: Answer incoming call
- `hangup()`: End the call
- `toggleMute()`: Toggle mute state
- `toggleHold()`: Toggle hold state
- `dtmf(String tone)`: Send DTMF tone

### CallState

Enum representing call states:
- `initiating`: Call is being initiated
- `ringing`: Call is ringing
- `active`: Call is connected and active
- `held`: Call is on hold
- `ended`: Call has ended
- `error`: Call is in error state
- `reconnecting`: Call is reconnecting

### ConnectionState

Sealed class representing connection states:
- `Disconnected`: Not connected
- `Connecting`: Attempting to connect
- `Connected`: Successfully connected
- `ConnectionError`: Connection failed

## Development Status

- ✅ **Phase 1**: Core Engine & Headless Operation (Complete)
- 🚧 **Phase 2**: Native UI Integration (In Progress)
- 📋 **Phase 3**: Robustness & Background Processing (Planned)

## Contributing

This package is part of the Telnyx Flutter SDK. Please refer to the main repository for contribution guidelines.

## License

This project is licensed under the MIT License - see the LICENSE file for details.