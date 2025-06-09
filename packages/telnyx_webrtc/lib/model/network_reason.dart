/// Enum representing the reason for a network change event.
enum NetworkReason {
  /// The network has been switched.
  networkSwitch('Network switched'),

  /// The network has been lost.
  networkLost('Network lost'),

  /// The network has adjusted due to Airplane mode.
  airplaneMode('Airplane mode enabled'),
  
  /// A server error occurred.
  serverError('Server error');

  /// The message associated with the network reason.
  final String message;

  const NetworkReason(this.message);
}
