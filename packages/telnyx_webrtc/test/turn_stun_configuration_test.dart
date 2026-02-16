import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/config.dart';
import 'package:telnyx_webrtc/model/tx_server_configuration.dart';

void main() {
  group('TURN/STUN Server Configuration Tests', () {
    group('DefaultConfig', () {
      test('should have UDP TURN server for production', () {
        expect(
          DefaultConfig.defaultTurnUdp,
          'turn:turn.telnyx.com:3478?transport=udp',
        );
      });

      test('should have TCP TURN server for production', () {
        expect(
          DefaultConfig.defaultTurnTcp,
          'turn:turn.telnyx.com:3478?transport=tcp',
        );
      });

      test('should have UDP TURN server for development', () {
        expect(
          DefaultConfig.devTurnUdp,
          'turn:turndev.telnyx.com:3478?transport=udp',
        );
      });

      test('should have TCP TURN server for development', () {
        expect(
          DefaultConfig.devTurnTcp,
          'turn:turndev.telnyx.com:3478?transport=tcp',
        );
      });

      test('should have Google STUN server for redundancy', () {
        expect(DefaultConfig.googleStun, 'stun:stun.l.google.com:19302');
      });

      test('should have Telnyx STUN server for production', () {
        expect(DefaultConfig.defaultStun, 'stun:stun.telnyx.com:3478');
      });

      test('should have Telnyx STUN server for development', () {
        expect(DefaultConfig.devStun, 'stun:stundev.telnyx.com:3478');
      });

      test('legacy defaultTurn should point to UDP', () {
        // ignore: deprecated_member_use_from_same_package
        expect(DefaultConfig.defaultTurn, DefaultConfig.defaultTurnUdp);
      });

      test('legacy devTurn should point to UDP', () {
        // ignore: deprecated_member_use_from_same_package
        expect(DefaultConfig.devTurn, DefaultConfig.devTurnUdp);
      });
    });

    group('TxServerConfiguration.production()', () {
      late TxServerConfiguration config;

      setUp(() {
        config = TxServerConfiguration.production();
      });

      test('should use production host', () {
        expect(config.host, DefaultConfig.telnyxProdHostAddress);
      });

      test('should use production TURN UDP server', () {
        expect(config.turnUdp, DefaultConfig.defaultTurnUdp);
      });

      test('should use production TURN TCP server', () {
        expect(config.turnTcp, DefaultConfig.defaultTurnTcp);
      });

      test('should use production STUN server', () {
        expect(config.stun, DefaultConfig.defaultStun);
      });

      test('should include Google STUN server', () {
        expect(config.googleStun, DefaultConfig.googleStun);
      });

      test('legacy turn getter should return UDP server', () {
        // ignore: deprecated_member_use_from_same_package
        expect(config.turn, config.turnUdp);
      });
    });

    group('TxServerConfiguration.development()', () {
      late TxServerConfiguration config;

      setUp(() {
        config = TxServerConfiguration.development();
      });

      test('should use development host', () {
        expect(config.host, DefaultConfig.telnyxDevHostAddress);
      });

      test('should use development TURN UDP server', () {
        expect(config.turnUdp, DefaultConfig.devTurnUdp);
      });

      test('should use development TURN TCP server', () {
        expect(config.turnTcp, DefaultConfig.devTurnTcp);
      });

      test('should use development STUN server', () {
        expect(config.stun, DefaultConfig.devStun);
      });

      test('should include Google STUN server', () {
        expect(config.googleStun, DefaultConfig.googleStun);
      });
    });

    group('TxServerConfiguration custom', () {
      test('should allow custom TURN/STUN servers', () {
        const customTurnUdp = 'turn:custom.example.com:3478?transport=udp';
        const customTurnTcp = 'turn:custom.example.com:3478?transport=tcp';
        const customStun = 'stun:custom.example.com:3478';
        const customGoogleStun = 'stun:custom-google.example.com:19302';

        final config = TxServerConfiguration(
          turnUdp: customTurnUdp,
          turnTcp: customTurnTcp,
          stun: customStun,
          googleStun: customGoogleStun,
        );

        expect(config.turnUdp, customTurnUdp);
        expect(config.turnTcp, customTurnTcp);
        expect(config.stun, customStun);
        expect(config.googleStun, customGoogleStun);
      });

      test('should use default values when not specified', () {
        const config = TxServerConfiguration();

        expect(config.turnUdp, DefaultConfig.defaultTurnUdp);
        expect(config.turnTcp, DefaultConfig.defaultTurnTcp);
        expect(config.stun, DefaultConfig.defaultStun);
        expect(config.googleStun, DefaultConfig.googleStun);
      });
    });

    group('TxServerConfiguration toString', () {
      test('should include all server URLs in toString', () {
        final config = TxServerConfiguration.production();
        final str = config.toString();

        expect(str, contains('turnUdp:'));
        expect(str, contains('turnTcp:'));
        expect(str, contains('stun:'));
        expect(str, contains('googleStun:'));
      });
    });
  });
}
