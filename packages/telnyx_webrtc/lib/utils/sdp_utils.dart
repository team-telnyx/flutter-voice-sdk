import 'package:telnyx_webrtc/utils/logging/global_logger.dart';

/// Utility class for Session Description Protocol (SDP) manipulation.
class SdpUtils {
  
  /// Adds trickle ICE capability to an SDP if not already present.
  /// This adds "a=ice-options:trickle" at the session level after the origin (o=) line.
  /// 
  /// [sdp] The original SDP string
  /// [useTrickleIce] Whether trickle ICE is enabled
  /// @return The modified SDP with ice-options:trickle added, or original if no modification needed
  static String addTrickleIceCapability(String sdp, bool useTrickleIce) {
    if (!useTrickleIce) {
      return sdp;
    }

    final lines = sdp.split('\r\n').toList();
    var result = _handleTrickleIceModification(lines);
    
    if (result != null) {
      GlobalLogger().i('SdpUtils :: Modified SDP with trickle ICE capability');
      return result;
    } else {
      GlobalLogger().i('SdpUtils :: SDP already contains trickle ICE or no modification needed');
      return sdp;
    }
  }

  /// Handles trickle ICE modification by checking existing ice-options and adding if needed
  static String? _handleTrickleIceModification(List<String> lines) {
    // Check if there's an existing ice-options line that needs modification
    final existingIceOptionsIndex = _findExistingIceOptionsIndex(lines);
    if (existingIceOptionsIndex != -1) {
      return _handleExistingIceOptions(lines, existingIceOptionsIndex);
    }

    // If no existing ice-options line was found, try to add a new one
    return _addNewIceOptions(lines);
  }

  /// Finds the index of an existing ice-options line
  static int _findExistingIceOptionsIndex(List<String> lines) {
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].startsWith('a=ice-options:')) {
        return i;
      }
    }
    return -1;
  }

  /// Handles an existing ice-options line
  static String? _handleExistingIceOptions(List<String> lines, int index) {
    final currentOptions = lines[index];
    
    if (currentOptions == 'a=ice-options:trickle') {
      // Already has exactly what we want
      return null;
    } else {
      // Replace any ice-options line with just trickle
      // This handles cases like "a=ice-options:trickle renomination"
      lines[index] = 'a=ice-options:trickle';
      GlobalLogger().i('SdpUtils :: Replaced ice-options line from \'$currentOptions\' to \'a=ice-options:trickle\'');
      return lines.join('\r\n');
    }
  }

  /// Adds a new ice-options line to the SDP
  static String? _addNewIceOptions(List<String> lines) {
    final insertIndex = _findOriginLineInsertIndex(lines);
    
    if (insertIndex != -1) {
      // Insert ice-options:trickle at session level (after origin line)
      lines.insert(insertIndex, 'a=ice-options:trickle');
      GlobalLogger().i('SdpUtils :: Added a=ice-options:trickle to SDP at index $insertIndex');
      return lines.join('\r\n');
    } else {
      GlobalLogger().w('SdpUtils :: Could not find origin line in SDP, returning original');
      return null;
    }
  }

  /// Finds the index where the ice-options line should be inserted (after origin line)
  static int _findOriginLineInsertIndex(List<String> lines) {
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].startsWith('o=')) {
        return i + 1;
      }
    }
    return -1;
  }

  /// Checks if an SDP contains trickle ICE capability.
  /// 
  /// [sdp] The SDP string to check
  /// @return true if the SDP advertises trickle ICE support
  static bool hasTrickleIceCapability(String sdp) {
    return sdp.contains("a=ice-options:trickle");
  }

  /// Removes ICE candidates from SDP for trickle ICE
  /// 
  /// [sdp] The SDP string to process
  /// @return The SDP with ICE candidates removed
  static String removeIceCandidatesFromSdp(String sdp) {
    final lines = sdp.split('\r\n');
    final modifiedLines = <String>[];

    for (final line in lines) {
      // Remove candidate lines (a=candidate:)
      if (!line.startsWith('a=candidate:')) {
        modifiedLines.add(line);
      }
    }

    final modifiedSdp = modifiedLines.join('\r\n');
    GlobalLogger().i('SdpUtils :: Removed ICE candidates from SDP for trickle ICE');
    return modifiedSdp;
  }
}