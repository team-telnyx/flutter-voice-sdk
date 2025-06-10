/// Represents the possible states of a WebRTC signaling connection.
enum SignalingState {
  /// The connection is open and ready to send and receive messages.
  connectionOpen,

  /// The connection is closed and no longer active.
  connectionClosed,

  /// The connection is in an error state and cannot be used.
  connectionError,
}
