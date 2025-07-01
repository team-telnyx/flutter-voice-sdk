/// Utility functions for WebSocket connection handling
class WebSocketUtils {
  /// Determines if a WebSocket close was clean based on close code and reason.
  ///
  /// This function adheres more strictly to WebSocket protocol close codes
  /// and provides more accurate classifications for common scenarios.
  static bool isCleanClose(int closeCode, String? closeReason) {
    // Normalize closeReason to handle null and case insensitivity
    final normalizedReason = closeReason?.toLowerCase() ?? '';

    // --- 1. Explicitly Unclean Close Codes (Protocol-defined errors) ---
    // These codes explicitly indicate an error or an abnormal termination.
    switch (closeCode) {
      case 1006: // Abnormal closure (no close frame, e.g., network error)
      case 1007: // Invalid frame payload data
      case 1008: // Policy Violation
      case 1009: // Message too big
      case 1010: // Missing a required extension
      case 1011: // Internal Error
      case 1015: // TLS Handshake (failure to complete TLS handshake)
        return false;
    }

    // --- 2. Lower-level/Network-related Unclean Closures ---
    // These often indicate a connection failure before or during the handshake,
    // or a system-level error.
    if (closeCode ==
            500 || // Custom/Non-standard HTTP-like error, treat as unclean
        normalizedReason.contains('failed host lookup') ||
        normalizedReason.contains('socketexception') ||
        normalizedReason.contains('connection refused') ||
        normalizedReason.contains(
          'connection reset by peer',
        ) || // Common network error
        normalizedReason.contains('network is unreachable')) {
      return false;
    }

    // --- 3. Standard Clean Close Codes ---
    // These are standard WebSocket codes that typically indicate a graceful or expected closure.
    // We've excluded the error codes handled above.
    if (closeCode == 1000 || // Normal Closure
        closeCode ==
            1001 || // Going Away (e.g., server shutting down, browser navigating)
        closeCode ==
            1002 || // Protocol error (could be clean if client understands/expects it, but safer to treat as potentially unclean if not explicit) - DECISION: For this version, keeping it here for simplicity of standard codes.
        closeCode == 1003 ||
        closeCode ==
            1005) // No status provided, generally sent when manually disconnected
    {
      // Unacceptable Data
      return true;
    }

    // --- 4. Application-Defined Close Codes (3000-4999) ---
    // These codes are application-specific. By default, we treat them as UNCLEAN
    // unless you have a specific list of "clean" application codes.
    // Example: if (closeCode == 3001 && normalizedReason == 'user logged out') return true;
    if (closeCode >= 3000 && closeCode <= 4999) {
      // You would need to add specific logic here if you define custom CLEAN codes.
      // For now, by default, we'll assume they're NOT clean unless explicitly handled.
      return false;
    }

    // --- 5. Fallback / Everything Else ---
    // Any other close code not explicitly handled, or a non-standard code,
    // is generally treated as an unclean closure. This includes:
    // - Reserved codes (1016-2999)
    // - Codes outside the standard WebSocket range that aren't specifically handled (e.g., 5000+)
    // - Custom codes not explicitly marked as clean.
    return false;
  }
}
