import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/config.dart';
import 'package:telnyx_webrtc/model/tx_ice_server.dart';
import 'package:telnyx_webrtc/model/tx_server_configuration.dart';

/// Tests for the ICE server empty-URL fallback behaviour in _getEffectiveIceServers().
///
/// These tests verify that:
/// 1. TxIceServer with empty urls are filtered out from custom iceServers
/// 2. When all custom iceServers have empty URLs, falls back to serverConfiguration
/// 3. When serverConfiguration.webRTCIceServers also has empty URLs, falls back
///    to client-level defaults
/// 4. Normal (non-empty) ICE servers pass through unchanged
void main() {
  group('ICE server empty-URL fallback', () {
    group('TxIceServer.fromJson empty-URL handling', () {
      test('returns empty urls list when urls is null', () {
        final server = TxIceServer.fromJson({'urls': null});
        expect(server.urls, isEmpty);
      });

      test('returns empty urls list when urls key is missing', () {
        final server = TxIceServer.fromJson({});
        expect(server.urls, isEmpty);
      });

      test('returns empty urls list when urls is wrong type', () {
        final server = TxIceServer.fromJson({'urls': 42});
        expect(server.urls, isEmpty);
      });
    });

    group('filtering of empty-URL ICE servers', () {
      test('empty-URL servers are filtered out, valid ones remain', () {
        const servers = [
          TxIceServer(urls: ['stun:stun.example.com:3478']),
          TxIceServer(urls: []),
          TxIceServer(urls: ['turn:turn.example.com:3478?transport=tcp']),
        ];

        final valid = servers.where((s) => s.urls.isNotEmpty).toList();

        expect(valid.length, 2);
        expect(valid[0].urls, ['stun:stun.example.com:3478']);
        expect(valid[1].urls, ['turn:turn.example.com:3478?transport=tcp']);
      });

      test('all-empty list filters to empty', () {
        const servers = [
          TxIceServer(urls: []),
          TxIceServer(urls: []),
        ];

        final valid = servers.where((s) => s.urls.isNotEmpty).toList();

        expect(valid, isEmpty);
      });
    });

    group(
        'fallback chain: custom iceServers -> serverConfiguration -> defaults',
        () {
      // Simulate the _getEffectiveIceServers logic in isolation.
      // We extract the logic into a testable function that mirrors the
      // priority order in telnyx_client.dart.
      List<TxIceServer> resolveEffectiveIceServers({
        List<TxIceServer>? configIceServers,
        TxServerConfiguration? configServerConfig,
        required TxServerConfiguration clientDefault,
      }) {
        // First priority: custom ICE servers from Config
        if (configIceServers != null && configIceServers.isNotEmpty) {
          final valid =
              configIceServers.where((s) => s.urls.isNotEmpty).toList();
          if (valid.isNotEmpty) return valid;
        }

        // Second priority: ICE servers from serverConfiguration in Config
        if (configServerConfig != null) {
          final valid = configServerConfig.webRTCIceServers
              .where((s) => s.urls.isNotEmpty)
              .toList();
          if (valid.isNotEmpty) return valid;
        }

        // Third priority: client-level default serverConfiguration
        return clientDefault.webRTCIceServers;
      }

      test('normal non-empty custom iceServers pass through unchanged', () {
        final customServers = [
          TxIceServer(urls: ['stun:custom.example.com:3478']),
          TxIceServer(
            urls: ['turn:custom.example.com:3478?transport=tcp'],
            username: 'user',
            credential: 'pass',
          ),
        ];

        final result = resolveEffectiveIceServers(
          configIceServers: customServers,
          clientDefault: TxServerConfiguration.production(),
        );

        expect(result.length, 2);
        expect(result[0].urls, ['stun:custom.example.com:3478']);
        expect(result[1].urls, ['turn:custom.example.com:3478?transport=tcp']);
        expect(result[1].username, 'user');
        expect(result[1].credential, 'pass');
      });

      test(
          'when all custom iceServers have empty URLs, falls back to serverConfiguration',
          () {
        final emptyServers = [
          TxIceServer(urls: []),
          TxIceServer(urls: []),
        ];

        final serverConfig = TxServerConfiguration(
          webRTCIceServers: [
            TxIceServer(urls: ['stun:from-server-config:3478']),
            TxIceServer(
              urls: ['turn:from-server-config:3478?transport=tcp'],
              username: 'srvuser',
              credential: 'srvpass',
            ),
          ],
        );

        final result = resolveEffectiveIceServers(
          configIceServers: emptyServers,
          configServerConfig: serverConfig,
          clientDefault: TxServerConfiguration.production(),
        );

        expect(result.length, 2);
        expect(result[0].urls, ['stun:from-server-config:3478']);
        expect(result[1].urls, ['turn:from-server-config:3478?transport=tcp']);
      });

      test(
          'when both custom iceServers and serverConfiguration have empty URLs, falls back to client-level defaults',
          () {
        final emptyServers = [TxIceServer(urls: [])];

        final emptyServerConfig = TxServerConfiguration(
          webRTCIceServers: [TxIceServer(urls: [])],
        );

        final clientDefault = TxServerConfiguration.production();

        final result = resolveEffectiveIceServers(
          configIceServers: emptyServers,
          configServerConfig: emptyServerConfig,
          clientDefault: clientDefault,
        );

        // Should be the production default ICE servers (5 servers)
        expect(result.length, 5);
        expect(result, equals(DefaultConfig.defaultProdIceServers));
      });

      test(
          'when no custom iceServers and no serverConfiguration, uses client-level defaults',
          () {
        final clientDefault = TxServerConfiguration.development();

        final result = resolveEffectiveIceServers(
          clientDefault: clientDefault,
        );

        // Should be the development default ICE servers (5 servers)
        expect(result.length, 5);
        expect(result, equals(DefaultConfig.defaultDevIceServers));
      });

      test(
          'mixed empty and valid servers in custom iceServers: only valid ones are used',
          () {
        final mixedServers = [
          TxIceServer(urls: []),
          TxIceServer(urls: ['stun:valid.example.com:3478']),
          TxIceServer(urls: []),
          TxIceServer(
            urls: ['turn:valid.example.com:3478?transport=udp'],
            username: 'u',
            credential: 'p',
          ),
        ];

        final result = resolveEffectiveIceServers(
          configIceServers: mixedServers,
          clientDefault: TxServerConfiguration.production(),
        );

        expect(result.length, 2);
        expect(result[0].urls, ['stun:valid.example.com:3478']);
        expect(result[1].urls, ['turn:valid.example.com:3478?transport=udp']);
      });

      test('serverConfiguration with mixed empty/valid: only valid used', () {
        final serverConfig = TxServerConfiguration(
          webRTCIceServers: [
            TxIceServer(urls: []),
            TxIceServer(urls: ['stun:mixed-valid:3478']),
            TxIceServer(urls: []),
          ],
        );

        final result = resolveEffectiveIceServers(
          configServerConfig: serverConfig,
          clientDefault: TxServerConfiguration.production(),
        );

        expect(result.length, 1);
        expect(result[0].urls, ['stun:mixed-valid:3478']);
      });
    });

    group('default ICE server integrity', () {
      test('production defaults all have non-empty URLs', () {
        for (final server in DefaultConfig.defaultProdIceServers) {
          expect(server.urls, isNotEmpty,
              reason:
                  'Production default ICE server should have non-empty URLs');
        }
      });

      test('development defaults all have non-empty URLs', () {
        for (final server in DefaultConfig.defaultDevIceServers) {
          expect(server.urls, isNotEmpty,
              reason:
                  'Development default ICE server should have non-empty URLs');
        }
      });
    });
  });
}
