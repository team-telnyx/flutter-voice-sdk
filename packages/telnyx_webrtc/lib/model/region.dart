/// Enum representing the available regions for Telnyx WebRTC connections.
enum Region {
  /// Automatically select the best region
  auto('AUTO', 'auto'),

  /// European region
  eu('EU', 'eu'),

  /// US Central region
  usCentral('US-CENTRAL', 'us-central'),

  /// US East region
  usEast('US-EAST', 'us-east'),

  /// US West region
  usWest('US-WEST', 'us-west'),

  /// Canada Central region
  caCentral('CA-CENTRAL', 'ca-central'),

  /// Asia Pacific region
  apac('APAC', 'apac');

  const Region(this.displayName, this.value);

  /// The display name of the region
  final String displayName;

  /// The value used for connection
  final String value;

  /// Find a region by its display name
  static Region? fromDisplayName(String displayName) {
    for (Region region in Region.values) {
      if (region.displayName == displayName) {
        return region;
      }
    }
    return null;
  }

  /// Find a region by its value
  static Region? fromValue(String value) {
    for (Region region in Region.values) {
      if (region.value == value) {
        return region;
      }
    }
    return null;
  }

  @override
  String toString() => displayName;
}
