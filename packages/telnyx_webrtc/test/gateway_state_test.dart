import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/model/gateway_state.dart';

void main() {
  group('GatewayState', () {
    test('should have all expected state constants', () {
      expect(GatewayState.unreged, equals('UNREGED'));
      expect(GatewayState.trying, equals('TRYING'));
      expect(GatewayState.register, equals('REGISTER'));
      expect(GatewayState.reged, equals('REGED'));
      expect(GatewayState.unregister, equals('UNREGISTER'));
      expect(GatewayState.attached, equals('ATTACHED'));
      expect(GatewayState.failed, equals('FAILED'));
      expect(GatewayState.failWait, equals('FAIL_WAIT'));
      expect(GatewayState.expired, equals('EXPIRED'));
      expect(GatewayState.noreg, equals('NOREG'));
      expect(GatewayState.idle, equals('IDLE'));
    });

    test('should be usable in switch statements', () {
      String getStateDescription(String state) {
        switch (state) {
          case GatewayState.unreged:
            return 'Gateway is unregistered';
          case GatewayState.trying:
            return 'Gateway is trying to register';
          case GatewayState.register:
            return 'Gateway is registering';
          case GatewayState.reged:
            return 'Gateway is registered';
          case GatewayState.unregister:
            return 'Gateway is unregistering';
          case GatewayState.attached:
            return 'Gateway is attached';
          case GatewayState.failed:
            return 'Gateway registration failed';
          case GatewayState.failWait:
            return 'Gateway is waiting after failure';
          case GatewayState.expired:
            return 'Gateway registration expired';
          case GatewayState.noreg:
            return 'Gateway has no registration';
          case GatewayState.idle:
            return 'Gateway is idle';
          default:
            return 'Unknown gateway state';
        }
      }

      expect(
        getStateDescription(GatewayState.unreged),
        equals('Gateway is unregistered'),
      );
      expect(
        getStateDescription(GatewayState.trying),
        equals('Gateway is trying to register'),
      );
      expect(
        getStateDescription(GatewayState.register),
        equals('Gateway is registering'),
      );
      expect(
        getStateDescription(GatewayState.reged),
        equals('Gateway is registered'),
      );
      expect(
        getStateDescription(GatewayState.unregister),
        equals('Gateway is unregistering'),
      );
      expect(
        getStateDescription(GatewayState.attached),
        equals('Gateway is attached'),
      );
      expect(
        getStateDescription(GatewayState.failed),
        equals('Gateway registration failed'),
      );
      expect(
        getStateDescription(GatewayState.failWait),
        equals('Gateway is waiting after failure'),
      );
      expect(
        getStateDescription(GatewayState.expired),
        equals('Gateway registration expired'),
      );
      expect(
        getStateDescription(GatewayState.noreg),
        equals('Gateway has no registration'),
      );
      expect(getStateDescription(GatewayState.idle), equals('Gateway is idle'));
      expect(getStateDescription('UNKNOWN'), equals('Unknown gateway state'));
    });

    test('should be usable in collections', () {
      final allStates = [
        GatewayState.unreged,
        GatewayState.trying,
        GatewayState.register,
        GatewayState.reged,
        GatewayState.unregister,
        GatewayState.attached,
        GatewayState.failed,
        GatewayState.failWait,
        GatewayState.expired,
        GatewayState.noreg,
        GatewayState.idle,
      ];

      expect(allStates, hasLength(11));
      expect(allStates, contains(GatewayState.unreged));
      expect(allStates, contains(GatewayState.trying));
      expect(allStates, contains(GatewayState.register));
      expect(allStates, contains(GatewayState.reged));
      expect(allStates, contains(GatewayState.unregister));
      expect(allStates, contains(GatewayState.attached));
      expect(allStates, contains(GatewayState.failed));
      expect(allStates, contains(GatewayState.failWait));
      expect(allStates, contains(GatewayState.expired));
      expect(allStates, contains(GatewayState.noreg));
      expect(allStates, contains(GatewayState.idle));
    });

    test('should be usable as map keys', () {
      final stateMap = <String, bool>{
        GatewayState.unreged: false,
        GatewayState.trying: false,
        GatewayState.register: false,
        GatewayState.reged: true,
        GatewayState.unregister: false,
        GatewayState.attached: true,
        GatewayState.failed: false,
        GatewayState.failWait: false,
        GatewayState.expired: false,
        GatewayState.noreg: false,
        GatewayState.idle: false,
      };

      expect(stateMap[GatewayState.unreged], isFalse);
      expect(stateMap[GatewayState.trying], isFalse);
      expect(stateMap[GatewayState.register], isFalse);
      expect(stateMap[GatewayState.reged], isTrue);
      expect(stateMap[GatewayState.unregister], isFalse);
      expect(stateMap[GatewayState.attached], isTrue);
      expect(stateMap[GatewayState.failed], isFalse);
      expect(stateMap[GatewayState.failWait], isFalse);
      expect(stateMap[GatewayState.expired], isFalse);
      expect(stateMap[GatewayState.noreg], isFalse);
      expect(stateMap[GatewayState.idle], isFalse);
    });

    test('should identify successful states', () {
      final successfulStates = [GatewayState.reged, GatewayState.attached];
      final failureStates = [
        GatewayState.unreged,
        GatewayState.failed,
        GatewayState.expired,
        GatewayState.failWait,
      ];

      for (final state in successfulStates) {
        expect(
          state == GatewayState.reged || state == GatewayState.attached,
          isTrue,
        );
      }

      for (final state in failureStates) {
        expect(
          state == GatewayState.reged || state == GatewayState.attached,
          isFalse,
        );
      }
    });

    test('should identify transitional states', () {
      final transitionalStates = [
        GatewayState.trying,
        GatewayState.register,
        GatewayState.unregister,
      ];

      for (final state in transitionalStates) {
        expect(
          [
            GatewayState.trying,
            GatewayState.register,
            GatewayState.unregister,
          ].contains(state),
          isTrue,
        );
      }
    });
  });
}
