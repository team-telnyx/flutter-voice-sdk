import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/config.dart';
import 'package:telnyx_webrtc/model/tx_ice_server.dart';
import 'package:telnyx_webrtc/model/tx_server_configuration.dart';

void main() {
  group('TxServerConfiguration', () {
    group('constructor', () {
      test('creates instance with default values', () {
        final config = TxServerConfiguration();

        expect(config.host, DefaultConfig.telnyxProdHostAddress);
        expect(config.port, DefaultConfig.telnyxPort);
        expect(config.turn, DefaultConfig.defaultTurn);
        expect(config.stun, DefaultConfig.defaultStun);
        expect(config.environment, WebRTCEnvironment.production);
        expect(config.webRTCIceServers, isNotEmpty);
      });

      test('creates instance with custom values', () {
        final customIceServers = [
          TxIceServer(urls: ['stun:custom.stun.com:3478']),
        ];

        final config = TxServerConfiguration(
          host: 'custom.host.com',
          port: 8080,
          turn: 'turn:custom.turn.com:3478',
          stun: 'stun:custom.stun.com:3478',
          webRTCIceServers: customIceServers,
          environment: WebRTCEnvironment.development,
        );

        expect(config.host, 'custom.host.com');
        expect(config.port, 8080);
        expect(config.turn, 'turn:custom.turn.com:3478');
        expect(config.stun, 'stun:custom.stun.com:3478');
        expect(config.webRTCIceServers, customIceServers);
        expect(config.environment, WebRTCEnvironment.development);
      });
    });

    group('production factory', () {
      test('creates production configuration', () {
        final config = TxServerConfiguration.production();

        expect(config.host, DefaultConfig.telnyxProdHostAddress);
        expect(config.port, DefaultConfig.telnyxPort);
        expect(config.turn, DefaultConfig.defaultTurn);
        expect(config.stun, DefaultConfig.defaultStun);
        expect(config.environment, WebRTCEnvironment.production);
      });

      test('uses default production ICE servers', () {
        final config = TxServerConfiguration.production();

        expect(config.webRTCIceServers, isNotEmpty);
        // Should contain STUN and TURN servers
        final urls = config.webRTCIceServers
            .expand((server) => server.urls)
            .toList();
        expect(urls.any((url) => url.contains('stun:')), isTrue);
        expect(urls.any((url) => url.contains('turn:')), isTrue);
      });

      test('accepts custom ICE servers', () {
        final customIceServers = [
          TxIceServer(urls: ['stun:custom.stun.com:3478']),
        ];

        final config = TxServerConfiguration.production(
          webRTCIceServers: customIceServers,
        );

        expect(config.webRTCIceServers, customIceServers);
      });
    });

    group('development factory', () {
      test('creates development configuration', () {
        final config = TxServerConfiguration.development();

        expect(config.host, DefaultConfig.telnyxDevHostAddress);
        expect(config.port, DefaultConfig.telnyxPort);
        expect(config.turn, DefaultConfig.devTurn);
        expect(config.stun, DefaultConfig.devStun);
        expect(config.environment, WebRTCEnvironment.development);
      });

      test('uses default development ICE servers', () {
        final config = TxServerConfiguration.development();

        expect(config.webRTCIceServers, isNotEmpty);
        // Should contain dev STUN and TURN servers
        final urls = config.webRTCIceServers
            .expand((server) => server.urls)
            .toList();
        expect(urls.any((url) => url.contains('stundev') || url.contains('stun')), isTrue);
        expect(urls.any((url) => url.contains('turndev') || url.contains('turn')), isTrue);
      });

      test('accepts custom ICE servers', () {
        final customIceServers = [
          TxIceServer(urls: ['stun:custom.stun.com:3478']),
        ];

        final config = TxServerConfiguration.development(
          webRTCIceServers: customIceServers,
        );

        expect(config.webRTCIceServers, customIceServers);
      });
    });

    group('socketUrl', () {
      test('returns correct WebSocket URL', () {
        final config = TxServerConfiguration(
          host: 'example.com',
          port: 443,
        );

        expect(config.socketUrl, 'wss://example.com:443');
      });

      test('returns correct URL for production', () {
        final config = TxServerConfiguration.production();

        expect(
          config.socketUrl,
          'wss://${DefaultConfig.telnyxProdHostAddress}:${DefaultConfig.telnyxPort}',
        );
      });

      test('returns correct URL for development', () {
        final config = TxServerConfiguration.development();

        expect(
          config.socketUrl,
          'wss://${DefaultConfig.telnyxDevHostAddress}:${DefaultConfig.telnyxPort}',
        );
      });
    });

    group('copyWith', () {
      test('creates copy with updated host', () {
        final original = TxServerConfiguration.production();
        final copy = original.copyWith(host: 'new.host.com');

        expect(copy.host, 'new.host.com');
        expect(copy.port, original.port);
        expect(copy.turn, original.turn);
        expect(copy.stun, original.stun);
      });

      test('creates copy with updated ICE servers', () {
        final original = TxServerConfiguration.production();
        final newIceServers = [
          TxIceServer(urls: ['stun:new.stun.com:3478']),
        ];
        final copy = original.copyWith(webRTCIceServers: newIceServers);

        expect(copy.webRTCIceServers, newIceServers);
        expect(copy.host, original.host);
      });

      test('creates copy with updated environment', () {
        final original = TxServerConfiguration.production();
        final copy = original.copyWith(environment: WebRTCEnvironment.development);

        expect(copy.environment, WebRTCEnvironment.development);
      });
    });

    group('toString', () {
      test('returns readable string representation', () {
        final config = TxServerConfiguration.production();
        final str = config.toString();

        expect(str.contains('TxServerConfiguration'), isTrue);
        expect(str.contains(config.host), isTrue);
        expect(str.contains('production'), isTrue);
      });
    });
  });

  group('WebRTCEnvironment', () {
    test('has development value', () {
      expect(WebRTCEnvironment.development, isNotNull);
    });

    test('has production value', () {
      expect(WebRTCEnvironment.production, isNotNull);
    });
  });

  group('DefaultConfig ICE servers', () {
    test('defaultProdIceServers contains expected servers', () {
      final servers = DefaultConfig.defaultProdIceServers;

      expect(servers, isNotEmpty);
      expect(servers.length, greaterThanOrEqualTo(2));

      // Check for STUN server
      final stunServers = servers.where(
        (s) => s.urls.any((url) => url.startsWith('stun:')),
      );
      expect(stunServers, isNotEmpty);

      // Check for TURN server
      final turnServers = servers.where(
        (s) => s.urls.any((url) => url.startsWith('turn:')),
      );
      expect(turnServers, isNotEmpty);
    });

    test('defaultDevIceServers contains expected servers', () {
      final servers = DefaultConfig.defaultDevIceServers;

      expect(servers, isNotEmpty);
      expect(servers.length, greaterThanOrEqualTo(2));

      // Check for STUN server
      final stunServers = servers.where(
        (s) => s.urls.any((url) => url.startsWith('stun:')),
      );
      expect(stunServers, isNotEmpty);

      // Check for TURN server
      final turnServers = servers.where(
        (s) => s.urls.any((url) => url.startsWith('turn:')),
      );
      expect(turnServers, isNotEmpty);
    });

    test('includes Google STUN server as fallback', () {
      final prodServers = DefaultConfig.defaultProdIceServers;
      final devServers = DefaultConfig.defaultDevIceServers;

      final prodHasGoogle = prodServers.any(
        (s) => s.urls.any((url) => url.contains('google')),
      );
      final devHasGoogle = devServers.any(
        (s) => s.urls.any((url) => url.contains('google')),
      );

      expect(prodHasGoogle, isTrue);
      expect(devHasGoogle, isTrue);
    });

    test('includes UDP TURN servers', () {
      final prodServers = DefaultConfig.defaultProdIceServers;
      final devServers = DefaultConfig.defaultDevIceServers;

      final prodHasUdp = prodServers.any(
        (s) => s.urls.any((url) => url.contains('transport=udp')),
      );
      final devHasUdp = devServers.any(
        (s) => s.urls.any((url) => url.contains('transport=udp')),
      );

      expect(prodHasUdp, isTrue);
      expect(devHasUdp, isTrue);
    });

    test('includes TCP TURN servers', () {
      final prodServers = DefaultConfig.defaultProdIceServers;
      final devServers = DefaultConfig.defaultDevIceServers;

      final prodHasTcp = prodServers.any(
        (s) => s.urls.any((url) => url.contains('transport=tcp')),
      );
      final devHasTcp = devServers.any(
        (s) => s.urls.any((url) => url.contains('transport=tcp')),
      );

      expect(prodHasTcp, isTrue);
      expect(devHasTcp, isTrue);
    });
  });
}
