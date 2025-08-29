import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/model/network_reason.dart';

void main() {
  group('NetworkReason', () {
    test('should have all expected enum values', () {
      expect(NetworkReason.values, hasLength(4));
      expect(NetworkReason.values, contains(NetworkReason.networkSwitch));
      expect(NetworkReason.values, contains(NetworkReason.networkLost));
      expect(NetworkReason.values, contains(NetworkReason.airplaneMode));
      expect(NetworkReason.values, contains(NetworkReason.serverError));
    });

    test('should have correct messages for each enum value', () {
      expect(NetworkReason.networkSwitch.message, equals('Network switched'));
      expect(NetworkReason.networkLost.message, equals('Network lost'));
      expect(
        NetworkReason.airplaneMode.message,
        equals('Airplane mode enabled'),
      );
      expect(NetworkReason.serverError.message, equals('Server error'));
    });

    test('should be able to compare enum values', () {
      expect(NetworkReason.networkSwitch, equals(NetworkReason.networkSwitch));
      expect(NetworkReason.networkLost, equals(NetworkReason.networkLost));
      expect(NetworkReason.airplaneMode, equals(NetworkReason.airplaneMode));
      expect(NetworkReason.serverError, equals(NetworkReason.serverError));

      expect(
        NetworkReason.networkSwitch,
        isNot(equals(NetworkReason.networkLost)),
      );
      expect(
        NetworkReason.networkLost,
        isNot(equals(NetworkReason.airplaneMode)),
      );
      expect(
        NetworkReason.airplaneMode,
        isNot(equals(NetworkReason.serverError)),
      );
    });

    test('should have consistent toString behavior', () {
      expect(NetworkReason.networkSwitch.toString(), contains('networkSwitch'));
      expect(NetworkReason.networkLost.toString(), contains('networkLost'));
      expect(NetworkReason.airplaneMode.toString(), contains('airplaneMode'));
      expect(NetworkReason.serverError.toString(), contains('serverError'));
    });

    test('should be usable in switch statements', () {
      String getDescription(NetworkReason reason) {
        switch (reason) {
          case NetworkReason.networkSwitch:
            return 'The network connection has been switched';
          case NetworkReason.networkLost:
            return 'The network connection has been lost';
          case NetworkReason.airplaneMode:
            return 'Airplane mode has been enabled';
          case NetworkReason.serverError:
            return 'A server error has occurred';
        }
      }

      expect(
        getDescription(NetworkReason.networkSwitch),
        equals('The network connection has been switched'),
      );
      expect(
        getDescription(NetworkReason.networkLost),
        equals('The network connection has been lost'),
      );
      expect(
        getDescription(NetworkReason.airplaneMode),
        equals('Airplane mode has been enabled'),
      );
      expect(
        getDescription(NetworkReason.serverError),
        equals('A server error has occurred'),
      );
    });

    test('should be usable in collections', () {
      final reasons = <NetworkReason>[
        NetworkReason.networkSwitch,
        NetworkReason.networkLost,
        NetworkReason.airplaneMode,
        NetworkReason.serverError,
      ];

      expect(reasons, hasLength(4));
      expect(reasons, contains(NetworkReason.networkSwitch));
      expect(reasons, contains(NetworkReason.networkLost));
      expect(reasons, contains(NetworkReason.airplaneMode));
      expect(reasons, contains(NetworkReason.serverError));
    });

    test('should be usable as map keys', () {
      final reasonMap = <NetworkReason, String>{
        NetworkReason.networkSwitch: 'switch',
        NetworkReason.networkLost: 'lost',
        NetworkReason.airplaneMode: 'airplane',
        NetworkReason.serverError: 'error',
      };

      expect(reasonMap[NetworkReason.networkSwitch], equals('switch'));
      expect(reasonMap[NetworkReason.networkLost], equals('lost'));
      expect(reasonMap[NetworkReason.airplaneMode], equals('airplane'));
      expect(reasonMap[NetworkReason.serverError], equals('error'));
    });
  });
}
