enum NetworkReason {
  networkSwitch('Network switched'),
  networkLost('Network lost'),
  airplaneMode('Airplane mode enabled');

  final String message;
  const NetworkReason(this.message);
}
