import 'package:telnyx_webrtc/config.dart';
import 'package:telnyx_webrtc/model/tx_ice_server.dart';
import 'package:telnyx_webrtc/model/tx_server_configuration.dart';
import 'package:telnyx_webrtc/utils/logging/global_logger.dart';

List<TxIceServer> resolveEffectiveIceServers({
  List<TxIceServer>? configIceServers,
  TxServerConfiguration? serverConfig,
  required TxServerConfiguration defaultServerConfig,
}) {
  final custom = _sanitize(configIceServers, 'Config');
  if (custom.isNotEmpty) return custom;

  final server = _sanitize(
    serverConfig?.webRTCIceServers,
    'serverConfiguration',
  );
  if (server.isNotEmpty) return server;

  final clientDefaults = _sanitize(
    defaultServerConfig.webRTCIceServers,
    'default serverConfiguration',
  );
  if (clientDefaults.isNotEmpty) return clientDefaults;

  GlobalLogger().w(
    'TelnyxClient :: Default serverConfiguration has no valid ICE URLs; using SDK defaults',
  );
  return defaultServerConfig.environment == WebRTCEnvironment.development
      ? DefaultConfig.defaultDevIceServers
      : DefaultConfig.defaultProdIceServers;
}

List<TxIceServer> _sanitize(List<TxIceServer>? servers, String source) {
  if (servers == null || servers.isEmpty) return const [];

  final sanitized = <TxIceServer>[];
  var removedUrls = 0;
  for (final server in servers) {
    final urls = server.urls.where((url) => url.trim().isNotEmpty).toList();
    removedUrls += server.urls.length - urls.length;
    if (urls.isNotEmpty) {
      sanitized.add(TxIceServer(
        urls: urls,
        username: server.username,
        credential: server.credential,
      ));
    }
  }

  final removedServers = servers.length - sanitized.length;
  if (removedServers > 0 || removedUrls > 0) {
    GlobalLogger().w(
      'TelnyxClient :: Filtered $removedServers invalid ICE server(s) and $removedUrls empty URL(s) from $source',
    );
  }
  if (sanitized.isNotEmpty) {
    GlobalLogger().i(
      'TelnyxClient :: Using ICE servers from $source (${sanitized.length} servers)',
    );
  }
  return sanitized;
}
