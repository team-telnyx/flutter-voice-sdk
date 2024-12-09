# `CallState`

`CallState` represents the state of the call

```dart
enum CallState {
  newCall,
  connecting,
  ringing,
  active,
  held,
  done,
  error,
}

```
## Cases
### `NEW`

```dart
newCall
```

New call has been created in the client.

### `CONNECTING`

```dart
connecting
```

The outbound call is being sent to the server.

### `RINGING`

```dart
ringing
```

Call is pending to be answered. Someone is attempting to call you.

### `ACTIVE`

```dart
active
```

Call is active when two clients are fully connected.

### `HELD`

```dart
held
```

Call has been held.

### `DONE`

```dart
done
```

Call has ended.

### `error`

```dart
error
```

An error has occured