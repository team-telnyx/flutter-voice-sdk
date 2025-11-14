import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/model/call_state.dart';
import 'package:telnyx_webrtc/model/network_reason.dart';
import 'package:telnyx_webrtc/model/call_termination_reason.dart';

void main() {
  group('CallState', () {
    test('should have all expected enum values', () {
      expect(CallState.values, hasLength(10));
      expect(CallState.values, contains(CallState.newCall));
      expect(CallState.values, contains(CallState.connecting));
      expect(CallState.values, contains(CallState.ringing));
      expect(CallState.values, contains(CallState.active));
      expect(CallState.values, contains(CallState.held));
      expect(CallState.values, contains(CallState.reconnecting));
      expect(CallState.values, contains(CallState.renegotiation));
      expect(CallState.values, contains(CallState.dropped));
      expect(CallState.values, contains(CallState.done));
      expect(CallState.values, contains(CallState.error));
    });

    test('should correctly identify active state', () {
      expect(CallState.active.isActive, isTrue);
      expect(CallState.newCall.isActive, isFalse);
      expect(CallState.connecting.isActive, isFalse);
      expect(CallState.ringing.isActive, isFalse);
      expect(CallState.held.isActive, isFalse);
      expect(CallState.reconnecting.isActive, isFalse);
      expect(CallState.renegotiation.isActive, isFalse);
      expect(CallState.dropped.isActive, isFalse);
      expect(CallState.done.isActive, isFalse);
      expect(CallState.error.isActive, isFalse);
    });

    test('should correctly identify reconnecting state', () {
      expect(CallState.reconnecting.isReconnecting, isTrue);
      expect(CallState.newCall.isReconnecting, isFalse);
      expect(CallState.connecting.isReconnecting, isFalse);
      expect(CallState.ringing.isReconnecting, isFalse);
      expect(CallState.active.isReconnecting, isFalse);
      expect(CallState.held.isReconnecting, isFalse);
      expect(CallState.renegotiation.isReconnecting, isFalse);
      expect(CallState.dropped.isReconnecting, isFalse);
      expect(CallState.done.isReconnecting, isFalse);
      expect(CallState.error.isReconnecting, isFalse);
    });

    test('should correctly identify dropped state', () {
      expect(CallState.dropped.isDropped, isTrue);
      expect(CallState.newCall.isDropped, isFalse);
      expect(CallState.connecting.isDropped, isFalse);
      expect(CallState.ringing.isDropped, isFalse);
      expect(CallState.active.isDropped, isFalse);
      expect(CallState.held.isDropped, isFalse);
      expect(CallState.reconnecting.isDropped, isFalse);
      expect(CallState.renegotiation.isDropped, isFalse);
      expect(CallState.done.isDropped, isFalse);
      expect(CallState.error.isDropped, isFalse);
    });

    test('should correctly identify done state', () {
      expect(CallState.done.isDone, isTrue);
      expect(CallState.newCall.isDone, isFalse);
      expect(CallState.connecting.isDone, isFalse);
      expect(CallState.ringing.isDone, isFalse);
      expect(CallState.active.isDone, isFalse);
      expect(CallState.held.isDone, isFalse);
      expect(CallState.reconnecting.isDone, isFalse);
      expect(CallState.renegotiation.isDone, isFalse);
      expect(CallState.dropped.isDone, isFalse);
      expect(CallState.error.isDone, isFalse);
    });

    group('withNetworkReason', () {
      test('should set network reason for reconnecting state', () {
        final state = CallState.reconnecting.withNetworkReason(
          NetworkReason.networkSwitch,
        );
        expect(state.networkReason, equals(NetworkReason.networkSwitch));
      });

      test('should set network reason for dropped state', () {
        final state = CallState.dropped.withNetworkReason(
          NetworkReason.networkLost,
        );
        expect(state.networkReason, equals(NetworkReason.networkLost));
      });

      test('should throw StateError for invalid states', () {
        expect(
          () =>
              CallState.newCall.withNetworkReason(NetworkReason.networkSwitch),
          throwsStateError,
        );
        expect(
          () => CallState.connecting.withNetworkReason(
            NetworkReason.networkSwitch,
          ),
          throwsStateError,
        );
        expect(
          () =>
              CallState.ringing.withNetworkReason(NetworkReason.networkSwitch),
          throwsStateError,
        );
        expect(
          () => CallState.active.withNetworkReason(NetworkReason.networkSwitch),
          throwsStateError,
        );
        expect(
          () => CallState.held.withNetworkReason(NetworkReason.networkSwitch),
          throwsStateError,
        );
        expect(
          () => CallState.renegotiation
              .withNetworkReason(NetworkReason.networkSwitch),
          throwsStateError,
        );
        expect(
          () => CallState.done.withNetworkReason(NetworkReason.networkSwitch),
          throwsStateError,
        );
        expect(
          () => CallState.error.withNetworkReason(NetworkReason.networkSwitch),
          throwsStateError,
        );
      });
    });

    group('withTerminationReason', () {
      test('should set termination reason for done state', () {
        const reason = CallTerminationReason(cause: 'USER_BUSY', sipCode: 486);
        final state = CallState.done.withTerminationReason(reason);
        expect(state.terminationReason, equals(reason));
      });

      test('should set null termination reason for done state', () {
        final state = CallState.done.withTerminationReason(null);
        expect(state.terminationReason, isNull);
      });

      test('should throw StateError for invalid states', () {
        const reason = CallTerminationReason(cause: 'USER_BUSY', sipCode: 486);
        expect(
          () => CallState.newCall.withTerminationReason(reason),
          throwsStateError,
        );
        expect(
          () => CallState.connecting.withTerminationReason(reason),
          throwsStateError,
        );
        expect(
          () => CallState.ringing.withTerminationReason(reason),
          throwsStateError,
        );
        expect(
          () => CallState.active.withTerminationReason(reason),
          throwsStateError,
        );
        expect(
          () => CallState.held.withTerminationReason(reason),
          throwsStateError,
        );
        expect(
          () => CallState.reconnecting.withTerminationReason(reason),
          throwsStateError,
        );
        expect(
          () => CallState.renegotiation.withTerminationReason(reason),
          throwsStateError,
        );
        expect(
          () => CallState.dropped.withTerminationReason(reason),
          throwsStateError,
        );
        expect(
          () => CallState.error.withTerminationReason(reason),
          throwsStateError,
        );
      });
    });

    test('should return null network reason for states without reason', () {
      expect(CallState.newCall.networkReason, isNull);
      expect(CallState.connecting.networkReason, isNull);
      expect(CallState.ringing.networkReason, isNull);
      expect(CallState.active.networkReason, isNull);
      expect(CallState.held.networkReason, isNull);
      expect(CallState.renegotiation.networkReason, isNull);
      expect(CallState.done.networkReason, isNull);
      expect(CallState.error.networkReason, isNull);
    });

    test('should return null termination reason for states without reason', () {
      expect(CallState.newCall.terminationReason, isNull);
      expect(CallState.connecting.terminationReason, isNull);
      expect(CallState.ringing.terminationReason, isNull);
      expect(CallState.active.terminationReason, isNull);
      expect(CallState.held.terminationReason, isNull);
      expect(CallState.reconnecting.terminationReason, isNull);
      expect(CallState.renegotiation.terminationReason, isNull);
      expect(CallState.dropped.terminationReason, isNull);
      expect(CallState.error.terminationReason, isNull);
    });
  });
}
