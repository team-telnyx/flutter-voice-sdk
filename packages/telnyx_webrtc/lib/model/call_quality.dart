/// Represents the quality of a call based on Mean Opinion Score (MOS).
enum CallQuality {
  /// Excellent call quality (MOS > 4.2)
  excellent,

  /// Good call quality (4.1 <= MOS <= 4.2)
  good,

  /// Fair call quality (3.7 <= MOS <= 4.0)
  fair,

  /// Poor call quality (3.1 <= MOS <= 3.6)
  poor,

  /// Bad call quality (MOS <= 3.0)
  bad,

  /// Unable to calculate quality
  unknown;

  /// Returns a string representation of the call quality.
  @override
  String toString() {
    switch (this) {
      case CallQuality.excellent:
        return 'Excellent';
      case CallQuality.good:
        return 'Good';
      case CallQuality.fair:
        return 'Fair';
      case CallQuality.poor:
        return 'Poor';
      case CallQuality.bad:
        return 'Bad';
      case CallQuality.unknown:
        return 'Unknown';
    }
  }

  /// Determines the call quality based on a Mean Opinion Score (MOS).
  ///
  /// @param mos The Mean Opinion Score (1.0-5.0)
  /// @return The corresponding CallQuality
  static CallQuality fromMos(double mos) {
    if (mos > 4.2) {
      return CallQuality.excellent;
    } else if (mos >= 4.1) {
      return CallQuality.good;
    } else if (mos >= 3.7) {
      return CallQuality.fair;
    } else if (mos >= 3.1) {
      return CallQuality.poor;
    } else if (mos > 0) {
      return CallQuality.bad;
    } else {
      return CallQuality.unknown;
    }
  }
}