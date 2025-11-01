import 'package:telnyx_webrtc/utils/logging/global_logger.dart';
import 'package:uuid/uuid.dart';

/// Utility class for handling ICE candidate processing and validation.
/// This class contains helper methods extracted from TelnyxClient to reduce complexity
/// and improve code organization.
class CandidateUtils {
  /// Validates that the candidate message has all required fields.
  /// 
  /// [params] The JSON object containing candidate parameters
  /// Returns true if all required fields are present, false otherwise
  static bool hasRequiredCandidateFields(Map<String, dynamic> params) {
    return params.containsKey('candidate') && 
           params.containsKey('sdpMid') && 
           params.containsKey('sdpMLineIndex');
  }

  /// Normalizes the candidate string by ensuring proper prefix.
  /// Handles different formats that might be received from the server.
  /// 
  /// [candidateString] The original candidate string
  /// Returns the normalized candidate string with proper "candidate:" prefix
  static String normalizeCandidateString(String candidateString) {
    if (candidateString.startsWith('a=candidate:')) {
      // Only strip "a=" not "a=candidate:"
      final normalized = candidateString.substring(2);  // Remove "a="
      GlobalLogger().i('Stripped \'a=\' prefix from candidate string');
      return normalized;
    } else if (!candidateString.startsWith('candidate:')) {
      // If it doesn't start with "candidate:", add it
      final normalized = 'candidate:$candidateString';
      GlobalLogger().i('Added \'candidate:\' prefix to candidate string');
      return normalized;
    } else {
      return candidateString;
    }
  }

  /// Extracts call ID from the candidate message parameters.
  /// Supports both new server format (callID in params) and legacy format (callId in dialogParams).
  /// 
  /// [params] The JSON object containing candidate parameters
  /// Returns the extracted UUID if found, null otherwise
  static String? extractCallIdFromCandidate(Map<String, dynamic> params) {
    String? callId;
    
    // Try to get call ID from multiple possible locations
    
    // 1. Check directly in params for "callID" (new server format)
    if (params.containsKey('callID')) {
      try {
        callId = params['callID'] as String?;
        if (callId != null) {
          GlobalLogger().i('Found callID directly in params: $callId');
        }
      } catch (e) {
        GlobalLogger().e('Failed to parse callID from params: ${e.toString()}');
      }
    }
    
    // 2. Fallback to dialogParams for "callId" (legacy format) if not found yet
    if (callId == null && params.containsKey('dialogParams')) {
      final dialogParams = params['dialogParams'] as Map<String, dynamic>?;
      if (dialogParams != null && dialogParams.containsKey('callId')) {
        try {
          callId = dialogParams['callId'] as String?;
          if (callId != null) {
            GlobalLogger().i('Found callId in dialogParams: $callId');
          }
        } catch (e) {
          GlobalLogger().e('Failed to parse callId from dialogParams: ${e.toString()}');
        }
      }
    }
    
    return callId;
  }
}