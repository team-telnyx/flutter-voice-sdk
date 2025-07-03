import 'package:telnyx_webrtc/model/telnyx_socket_error.dart';

/// Represents the connection state to the Telnyx backend.
///
/// This enum provides a high-level abstraction of the underlying socket
/// connection status, making it easier for developers to handle connection
/// state changes in their UI.
sealed class ConnectionState {
  const ConnectionState();
}

/// The client is currently disconnected from the Telnyx backend.
class Disconnected extends ConnectionState {
  const Disconnected();
  
  @override
  String toString() => 'Disconnected';
  
  @override
  bool operator ==(Object other) => other is Disconnected;
  
  @override
  int get hashCode => 0;
}

/// The client is attempting to connect to the Telnyx backend.
class Connecting extends ConnectionState {
  const Connecting();
  
  @override
  String toString() => 'Connecting';
  
  @override
  bool operator ==(Object other) => other is Connecting;
  
  @override
  int get hashCode => 1;
}

/// The client is successfully connected to the Telnyx backend.
class Connected extends ConnectionState {
  const Connected();
  
  @override
  String toString() => 'Connected';
  
  @override
  bool operator ==(Object other) => other is Connected;
  
  @override
  int get hashCode => 2;
}

/// The client encountered an error while connecting or maintaining connection.
class ConnectionError extends ConnectionState {
  /// The error that occurred during connection.
  final TelnyxSocketError error;
  
  const ConnectionError(this.error);
  
  @override
  String toString() => 'ConnectionError(${error.toString()})';
  
  @override
  bool operator ==(Object other) => 
      other is ConnectionError && other.error == error;
  
  @override
  int get hashCode => error.hashCode;
}