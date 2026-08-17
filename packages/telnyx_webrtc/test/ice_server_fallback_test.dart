import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/config.dart';
import 'package:telnyx_webrtc/model/tx_ice_server.dart';
import 'package:telnyx_webrtc/model/tx_server_configuration.dart';
import 'package:telnyx_webrtc/src/ice_server_resolver.dart';

/// Tests for the ICE server empty-URL fallback behaviour in
/// [resolveEffectiveIceServers].
///
/// These tests exercise the *actual* static method used by the SDK (not a
/// re-implementation) so they catch real regressions.
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

      test('empty-string urls field produces urls: [""]', () {
        final server = TxIceServer.fromJson({'urls': ''});
        expect(server.urls, ['']);
      });

      test('list with empty string produces urls: [""]', () {
        final server = TxIceServer.fromJson({
          'urls': [''],
        });
        expect(server.urls, ['']);
      });

      test('ignores non-string members in a urls list', () {
        final server = TxIceServer.fromJson({
          'urls': ['stun:valid.example.com:3478', 42, null],
        });
        expect(server.urls, ['stun:valid.example.com:3478']);
      });
    });

    group('resolveEffectiveIceServers — filtering of empty-URL ICE servers',
        () {
      test('empty-list servers are filtered out, valid ones remain', () {
        const servers = [
          TxIceServer(urls: ['stun:stun.example.com:3478']),
          TxIceServer(urls: []),
          TxIceServer(urls: ['turn:turn.example.com:3478?transport=tcp']),
        ];

        final result = resolveEffectiveIceServers(
          configIceServers: servers,
          defaultServerConfig: TxServerConfiguration.production(),
        );

        expect(result.length, 2);
        expect(result[0].urls, ['stun:stun.example.com:3478']);
        expect(result[1].urls, ['turn:turn.example.com:3478?transport=tcp']);
      });

      test('all-empty list filters to empty, falls back to defaults', () {
        const servers = [
          TxIceServer(urls: []),
          TxIceServer(urls: []),
        ];

        final result = resolveEffectiveIceServers(
          configIceServers: servers,
          defaultServerConfig: TxServerConfiguration.production(),
        );

        // Falls all the way through to defaults
        expect(result, equals(DefaultConfig.defaultProdIceServers));
      });

      test('TxIceServer with urls [""] is filtered out', () {
        const servers = [
          TxIceServer(urls: ['']),
          TxIceServer(urls: ['stun:stun.telnyx.com:3478']),
        ];

        final result = resolveEffectiveIceServers(
          configIceServers: servers,
          defaultServerConfig: TxServerConfiguration.production(),
        );

        expect(result.length, 1);
        expect(result[0].urls, ['stun:stun.telnyx.com:3478']);
      });

      test('TxIceServer.fromJson({"urls": ""}) is filtered out', () {
        final servers = [
          TxIceServer.fromJson({'urls': ''}),
          TxIceServer.fromJson({'urls': 'stun:stun.telnyx.com:3478'}),
        ];

        final result = resolveEffectiveIceServers(
          configIceServers: servers,
          defaultServerConfig: TxServerConfiguration.production(),
        );

        expect(result.length, 1);
        expect(result[0].urls, ['stun:stun.telnyx.com:3478']);
      });

      test('TxIceServer.fromJson({"urls": [""]}) is filtered out', () {
        final servers = [
          TxIceServer.fromJson({
            'urls': [''],
          }),
          TxIceServer.fromJson({
            'urls': ['stun:stun.telnyx.com:3478'],
          }),
        ];

        final result = resolveEffectiveIceServers(
          configIceServers: servers,
          defaultServerConfig: TxServerConfiguration.production(),
        );

        expect(result.length, 1);
        expect(result[0].urls, ['stun:stun.telnyx.com:3478']);
      });

      test(
          'invalid members are removed from a mixed URL list',
          () {
        const servers = [
          TxIceServer(urls: ['', 'stun:stun.telnyx.com:3478']),
        ];

        final result = resolveEffectiveIceServers(
          configIceServers: servers,
          defaultServerConfig: TxServerConfiguration.production(),
        );

        expect(result.length, 1);
        expect(result[0].urls, ['stun:stun.telnyx.com:3478']);
      });

      test('whitespace-only URLs are removed', () {
        const servers = [
          TxIceServer(urls: ['  ', '\n', 'stun:valid.example.com:3478']),
        ];

        final result = resolveEffectiveIceServers(
          configIceServers: servers,
          defaultServerConfig: TxServerConfiguration.production(),
        );

        expect(result.single.urls, ['stun:valid.example.com:3478']);
      });

      test(
          'mix of empty-list and empty-string servers: only valid ones returned',
          () {
        const servers = [
          TxIceServer(urls: []),
          TxIceServer(urls: ['']),
          TxIceServer(urls: ['', '']),
          TxIceServer(urls: ['stun:valid.example.com:3478']),
          TxIceServer(
            urls: ['turn:valid.example.com:3478?transport=udp'],
            username: 'u',
            credential: 'p',
          ),
        ];

        final result = resolveEffectiveIceServers(
          configIceServers: servers,
          defaultServerConfig: TxServerConfiguration.production(),
        );

        expect(result.length, 2);
        expect(result[0].urls, ['stun:valid.example.com:3478']);
        expect(result[1].urls, ['turn:valid.example.com:3478?transport=udp']);
      });
    });

    group(
      'fallback chain: custom iceServers -> serverConfiguration -> defaults',
      () {
        test(
          'normal non-empty custom iceServers pass through unchanged',
          () {
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
              defaultServerConfig: TxServerConfiguration.production(),
            );

            expect(result.length, 2);
            expect(result[0].urls, ['stun:custom.example.com:3478']);
            expect(
              result[1].urls,
              ['turn:custom.example.com:3478?transport=tcp'],
            );
            expect(result[1].username, 'user');
            expect(result[1].credential, 'pass');
          },
        );

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
              serverConfig: serverConfig,
              defaultServerConfig: TxServerConfiguration.production(),
            );

            expect(result.length, 2);
            expect(result[0].urls, ['stun:from-server-config:3478']);
            expect(
              result[1].urls,
              ['turn:from-server-config:3478?transport=tcp'],
            );
          },
        );

        test(
          'when both custom iceServers and serverConfiguration have empty URLs, falls back to client-level defaults',
          () {
            final emptyServers = [TxIceServer(urls: [])];

            final emptyServerConfig = TxServerConfiguration(
              webRTCIceServers: [
                TxIceServer(urls: ['']),
              ],
            );

            final clientDefault = TxServerConfiguration.production();

            final result = resolveEffectiveIceServers(
              configIceServers: emptyServers,
              serverConfig: emptyServerConfig,
              defaultServerConfig: clientDefault,
            );

            // Production includes both primary and secondary TURNS endpoints.
            expect(result.length, 6);
            expect(result, equals(DefaultConfig.defaultProdIceServers));
          },
        );

        test(
          'when no custom iceServers and no serverConfiguration, uses client-level defaults',
          () {
            final clientDefault = TxServerConfiguration.development();

            final result = resolveEffectiveIceServers(
              defaultServerConfig: clientDefault,
            );

            // Should be the development default ICE servers (5 servers)
            expect(result.length, 5);
            expect(result, equals(DefaultConfig.defaultDevIceServers));
          },
        );

        test('invalid client-level defaults fall back to SDK defaults', () {
          final invalidDefault = TxServerConfiguration(
            webRTCIceServers: const [
              TxIceServer(urls: []),
              TxIceServer(urls: ['  ']),
            ],
          );

          final result = resolveEffectiveIceServers(
            defaultServerConfig: invalidDefault,
          );

          expect(result, equals(DefaultConfig.defaultProdIceServers));
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
              defaultServerConfig: TxServerConfiguration.production(),
            );

            expect(result.length, 2);
            expect(result[0].urls, ['stun:valid.example.com:3478']);
            expect(
              result[1].urls,
              ['turn:valid.example.com:3478?transport=udp'],
            );
          },
        );

        test('serverConfiguration with mixed empty/valid: only valid used', () {
          final serverConfig = TxServerConfiguration(
            webRTCIceServers: [
              TxIceServer(urls: []),
              TxIceServer(urls: ['stun:mixed-valid:3478']),
              TxIceServer(urls: []),
            ],
          );

          final result = resolveEffectiveIceServers(
            serverConfig: serverConfig,
            defaultServerConfig: TxServerConfiguration.production(),
          );

          expect(result.length, 1);
          expect(result[0].urls, ['stun:mixed-valid:3478']);
        });

        test(
          'serverConfiguration with empty-string URLs: falls back to defaults',
          () {
            final serverConfig = TxServerConfiguration(
              webRTCIceServers: [
                TxIceServer(urls: ['']),
                TxIceServer(urls: ['', '']),
              ],
            );

            final result = resolveEffectiveIceServers(
              serverConfig: serverConfig,
              defaultServerConfig: TxServerConfiguration.production(),
            );

            expect(result, equals(DefaultConfig.defaultProdIceServers));
          },
        );
      },
    );

    group('default ICE server integrity', () {
      test('production defaults all have non-empty URLs', () {
        for (final server in DefaultConfig.defaultProdIceServers) {
          expect(
            server.urls,
            isNotEmpty,
            reason: 'Production default ICE server should have non-empty URLs',
          );
          for (final url in server.urls) {
            expect(
              url,
              isNotEmpty,
              reason: 'Production default ICE server URL should not be empty',
            );
          }
        }
      });

      test('development defaults all have non-empty URLs', () {
        for (final server in DefaultConfig.defaultDevIceServers) {
          expect(
            server.urls,
            isNotEmpty,
            reason: 'Development default ICE server should have non-empty URLs',
          );
          for (final url in server.urls) {
            expect(
              url,
              isNotEmpty,
              reason: 'Development default ICE server URL should not be empty',
            );
          }
        }
      });
    });
  });
}
