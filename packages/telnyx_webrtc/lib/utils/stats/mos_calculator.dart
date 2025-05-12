/// Utility class for calculating Mean Opinion Score (MOS) from WebRTC statistics.
class MosCalculator {
  /// Calculates the Mean Opinion Score (MOS) based on network metrics.
  ///
  /// This implementation uses the ITU-T G.107 E-Model to estimate MOS.
  /// The formula is simplified for WebRTC audio calls.
  ///
  /// @param rtt Round-trip time in seconds
  /// @param jitter Jitter in seconds
  /// @param packetLoss Packet loss ratio (0.0-1.0)
  /// @return Estimated MOS value between 1.0 and 4.5
  static double calculateMos({
    required double rtt,
    required double jitter,
    double packetLoss = 0.0,
  }) {
    // Convert to milliseconds for calculation
    final rttMs = rtt * 1000;
    final jitterMs = jitter * 1000;
    
    // Clamp values to reasonable ranges
    final effectiveRtt = _clamp(rttMs, 0, 500);
    final effectiveJitter = _clamp(jitterMs, 0, 100);
    final effectivePacketLoss = _clamp(packetLoss, 0.0, 1.0) * 100; // Convert to percentage
    
    // Calculate R-factor based on ITU-T G.107 E-Model (simplified)
    // R = 93.2 - Id - Ie
    // where:
    // - Id is the delay impairment factor
    // - Ie is the equipment impairment factor (affected by packet loss and codec)
    
    // Delay impairment (Id)
    final delayImpairment = 0.024 * effectiveRtt + 0.11 * (effectiveRtt - 177.3) * (effectiveRtt > 177.3 ? 1 : 0);
    
    // Equipment impairment (Ie)
    // For G.711 codec: Ie = 0 + 30 * packetLoss / (packetLoss + 10)
    // We add jitter impact as well
    final jitterImpairment = effectiveJitter * 0.05;
    final packetLossImpairment = 30 * effectivePacketLoss / (effectivePacketLoss + 10);
    final equipmentImpairment = jitterImpairment + packetLossImpairment;
    
    // Calculate R-factor
    final rFactor = 93.2 - delayImpairment - equipmentImpairment;
    final clampedRFactor = _clamp(rFactor, 0, 100);
    
    // Convert R-factor to MOS using the standard formula
    // For R < 0: MOS = 1
    // For 0 <= R <= 100: MOS = 1 + 0.035*R + R*(R-60)*(100-R)*7*10^-6
    // For R > 100: MOS = 4.5
    
    double mos;
    if (clampedRFactor < 0) {
      mos = 1.0;
    } else if (clampedRFactor > 100) {
      mos = 4.5;
    } else {
      mos = 1 + 0.035 * clampedRFactor + 
          clampedRFactor * (clampedRFactor - 60) * (100 - clampedRFactor) * 7 * 1e-6;
    }
    
    // Ensure MOS is between 1.0 and 4.5
    return _clamp(mos, 1.0, 4.5);
  }
  
  /// Clamps a value between a minimum and maximum.
  static T _clamp<T extends num>(T value, T min, T max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }
}