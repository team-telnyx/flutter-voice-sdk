import 'package:flutter/foundation.dart';
import 'package:telnyx_webrtc/utils/logging/global_logger.dart';

/// Represents an ICE server configuration for WebRTC peer connections.
///
/// This class mirrors the RTCIceServer structure used in JS and iOS SDKs
/// to ensure cross-platform consistency for TURN/STUN server configuration.
///
/// Example usage:
/// ```dart
/// final iceServer = TxIceServer(
///   urls: ['turn:turn.example.com:3478?transport=tcp'],
///   username: 'user',
///   credential: 'password',
/// );
/// ```
class TxIceServer {
  /// Creates an ICE server configuration.
  ///
  /// [urls] is a list of STUN/TURN server URLs.
  /// [username] is optional and used for TURN server authentication.
  /// [credential] is optional and used for TURN server authentication.
  const TxIceServer({
    required this.urls,
    this.username,
    this.credential,
  });

  /// The list of STUN/TURN server URLs.
  ///
  /// URLs should be in the format:
  /// - STUN: `stun:hostname:port`
  /// - TURN: `turn:hostname:port?transport=tcp` or `turn:hostname:port?transport=udp`
  final List<String> urls;

  /// The username for TURN server authentication.
  ///
  /// Required for TURN servers, optional for STUN servers.
  final String? username;

  /// The credential (password) for TURN server authentication.
  ///
  /// Required for TURN servers, optional for STUN servers.
  final String? credential;

  /// Creates a TxIceServer from a single URL string.
  ///
  /// This is a convenience factory for creating an ICE server with a single URL.
  factory TxIceServer.fromUrl(
    String url, {
    String? username,
    String? credential,
  }) {
    return TxIceServer(
      urls: [url],
      username: username,
      credential: credential,
    );
  }

  /// Creates a TxIceServer from a JSON map.
  ///
  /// The map should contain:
  /// - `urls` or `url`: String or List<String> of server URLs
  /// - `username`: Optional String for authentication
  /// - `credential`: Optional String for authentication
  factory TxIceServer.fromJson(Map<String, dynamic> json) {
    final urlsValue = json['urls'] ?? json['url'];
    List<String> urls;

    if (urlsValue is String) {
      urls = [urlsValue];
    } else if (urlsValue is List) {
      urls = urlsValue.cast<String>();
    } else {
      GlobalLogger().w(
        'TxIceServer :: Invalid urls value type in ICE server config: ${urlsValue?.runtimeType}. Expected String or List<String>.',
      );
      urls = [];
    }

    return TxIceServer(
      urls: urls,
      username: json['username'] as String?,
      credential: json['credential'] as String?,
    );
  }

  /// Converts this ICE server to a JSON map.
  ///
  /// Returns a map compatible with the flutter_webrtc package's
  /// RTCPeerConnection configuration.
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'urls': urls,
    };

    if (username != null) {
      map['username'] = username;
    }

    if (credential != null) {
      map['credential'] = credential;
    }

    return map;
  }

  /// Converts this ICE server to a map format compatible with flutter_webrtc.
  ///
  /// This uses 'url' instead of 'urls' for compatibility with some
  /// WebRTC implementations that expect a single URL string.
  Map<String, dynamic> toWebRTCMap() {
    final map = <String, dynamic>{
      'urls': urls,
    };

    if (username != null) {
      map['username'] = username;
    }

    if (credential != null) {
      map['credential'] = credential;
    }

    return map;
  }

  @override
  String toString() {
    return 'TxIceServer(urls: $urls, username: ${username != null ? '***' : 'null'}, credential: ${credential != null ? '***' : 'null'})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TxIceServer) return false;

    return listEquals(urls, other.urls) &&
        username == other.username &&
        credential == other.credential;
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(urls),
        username,
        credential,
      );
}
