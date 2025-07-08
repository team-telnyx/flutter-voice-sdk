/// Represents the connection state to the Telnyx backend.
///
/// This sealed class provides a type-safe way to handle different connection
/// states in the application. Each state can carry additional information
/// relevant to that specific state.
sealed class ConnectionState {
  const ConnectionState();
}

/// The client is not connected to the Telnyx backend.
class Disconnected extends ConnectionState {
  const Disconnected();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Disconnected;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'Disconnected()';
}

/// The client is attempting to connect to the Telnyx backend.
class Connecting extends ConnectionState {
  const Connecting();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Connecting;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'Connecting()';
}

/// The client is successfully connected to the Telnyx backend.
class Connected extends ConnectionState {
  const Connected();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Connected;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'Connected()';
}

/// The connection to the Telnyx backend failed or encountered an error.
class ConnectionError extends ConnectionState {
  /// The error that caused the connection failure.
  final Object error;

  /// Optional stack trace associated with the error.
  final StackTrace? stackTrace;

  const ConnectionError(this.error, [this.stackTrace]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConnectionError && other.error == error);

  @override
  int get hashCode => Object.hash(runtimeType, error);

  @override
  String toString() => 'ConnectionError(error: $error)';
}
