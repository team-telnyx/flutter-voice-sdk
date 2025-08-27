/// Represents the different connection states of the Telnyx client
enum ConnectionStatus {
  /// Client is disconnected from the server
  disconnected,

  /// Client is connected to the server but not registered
  connected,

  /// Client is attempting to reconnect to the server
  reconnecting,

  /// Client is connected and registered, ready to make calls
  clientReady,
}
