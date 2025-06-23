import 'dart:io';
import 'package:telnyx_webrtc/model/region.dart';
import 'package:telnyx_webrtc/utils/logging/global_logger.dart';

/// Helper class for checking connectivity and resolving reachable hosts
class ConnectivityHelper {
  /// Check if a socket is reachable.
  /// If not, try to resolve the host by removing the region from the host.
  ///
  /// [host] the host to check
  /// [port] the port to connect to
  /// [timeoutMillis] timeout in milliseconds (default 1000ms)
  /// Returns the reachable host address
  static Future<String> resolveReachableHost(
    String host,
    int port, {
    int timeoutMillis = 1000,
  }) async {
    try {
      final socket = Socket();
      await socket.connect(host, port).timeout(
        Duration(milliseconds: timeoutMillis),
      );
      await socket.close();
      GlobalLogger().i('Host $host is reachable');
      return host;
    } catch (e) {
      GlobalLogger().e('Socket not reachable $host: $e');
      return _prepareHostFallback(host);
    }
  }

  /// Prepare host by removing the region from the host.
  /// 
  /// [host] the original host address
  /// Returns the host with region prefix removed
  static String _prepareHostFallback(String host) {
    // Extract the region part (everything before the first dot)
    final parts = host.split('.');
    if (parts.length > 1) {
      final regionValue = parts[0];
      final region = Region.fromValue(regionValue);
      
      if (region != null) {
        // Remove the region prefix and return the fallback host
        final fallbackHost = parts.sublist(1).join('.');
        GlobalLogger().i('Falling back from $host to $fallbackHost');
        return fallbackHost;
      }
    }
    
    // If no region found or parsing failed, return original host
    GlobalLogger().i('No region fallback available for $host');
    return host;
  }
}