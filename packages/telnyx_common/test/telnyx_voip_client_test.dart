import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_common/telnyx_common.dart';

void main() {
  group('TelnyxVoipClient', () {
    late TelnyxVoipClient client;
    
    setUp(() {
      client = TelnyxVoipClient();
    });
    
    tearDown(() {
      client.dispose();
    });
    
    test('should initialize with disconnected state', () {
      expect(client.currentConnectionState, isA<Disconnected>());
      expect(client.currentCalls, isEmpty);
      expect(client.currentActiveCall, isNull);
    });
    
    test('should expose connection state stream', () {
      expect(client.connectionState, isA<Stream<ConnectionState>>());
    });
    
    test('should expose calls stream', () {
      expect(client.calls, isA<Stream<List<Call>>>());
    });
    
    test('should expose active call stream', () {
      expect(client.activeCall, isA<Stream<Call?>>());
    });
    
    test('should throw when disposed', () {
      client.dispose();
      
      expect(
        () => client.login(const CredentialConfig(
          sipUser: 'test',
          sipPassword: 'test',
        )),
        throwsStateError,
      );
    });
    
    group('Configuration', () {
      test('should accept credential config', () {
        const config = CredentialConfig(
          sipUser: 'testuser',
          sipPassword: 'testpass',
          fcmToken: 'testtoken',
          debug: true,
        );
        
        expect(config.sipUser, equals('testuser'));
        expect(config.sipPassword, equals('testpass'));
        expect(config.fcmToken, equals('testtoken'));
        expect(config.debug, isTrue);
      });
      
      test('should accept token config', () {
        const config = TokenConfig(
          token: 'testtoken',
          fcmToken: 'fcmtoken',
          debug: false,
        );
        
        expect(config.token, equals('testtoken'));
        expect(config.fcmToken, equals('fcmtoken'));
        expect(config.debug, isFalse);
      });
    });
  });
  
  group('Call', () {
    test('should create call with required parameters', () {
      final call = Call(
        destination: '+1234567890',
        onAction: (callId, action, [params]) {},
      );
      
      expect(call.destination, equals('+1234567890'));
      expect(call.isIncoming, isFalse);
      expect(call.callId, isNotEmpty);
    });
    
    test('should create incoming call', () {
      final call = Call(
        callerName: 'John Doe',
        callerNumber: '+1234567890',
        isIncoming: true,
        onAction: (callId, action, [params]) {},
      );
      
      expect(call.callerName, equals('John Doe'));
      expect(call.callerNumber, equals('+1234567890'));
      expect(call.isIncoming, isTrue);
    });
    
    test('should expose state streams', () {
      final call = Call(
        destination: '+1234567890',
        onAction: (callId, action, [params]) {},
      );
      
      expect(call.callState, isA<Stream<CallState>>());
      expect(call.isMuted, isA<Stream<bool>>());
      expect(call.isHeld, isA<Stream<bool>>());
    });
    
    test('should update state and notify listeners', () async {
      final call = Call(
        destination: '+1234567890',
        onAction: (callId, action, [params]) {},
      );
      
      final states = <CallState>[];
      call.callState.listen(states.add);
      
      call.updateState(CallState.ringing);
      call.updateState(CallState.active);
      
      await Future.delayed(const Duration(milliseconds: 10));
      
      expect(states, equals([CallState.ringing, CallState.active]));
      
      call.dispose();
    });
  });
  
  group('CallState', () {
    test('should have correct state capabilities', () {
      expect(CallState.ringing.canAnswer, isTrue);
      expect(CallState.active.canAnswer, isFalse);
      
      expect(CallState.active.canHangup, isTrue);
      expect(CallState.ended.canHangup, isFalse);
      
      expect(CallState.active.canHold, isTrue);
      expect(CallState.held.canHold, isFalse);
      
      expect(CallState.held.canUnhold, isTrue);
      expect(CallState.active.canUnhold, isFalse);
      
      expect(CallState.active.canMute, isTrue);
      expect(CallState.ringing.canMute, isFalse);
      
      expect(CallState.active.isActive, isTrue);
      expect(CallState.held.isActive, isFalse);
      
      expect(CallState.ended.isTerminated, isTrue);
      expect(CallState.error.isTerminated, isTrue);
      expect(CallState.active.isTerminated, isFalse);
    });
  });
  
  group('ConnectionState', () {
    test('should create different connection states', () {
      const disconnected = Disconnected();
      const connecting = Connecting();
      const connected = Connected();
      
      expect(disconnected, isA<Disconnected>());
      expect(connecting, isA<Connecting>());
      expect(connected, isA<Connected>());
    });
    
    test('should handle equality correctly', () {
      const disconnected1 = Disconnected();
      const disconnected2 = Disconnected();
      const connecting = Connecting();
      
      expect(disconnected1, equals(disconnected2));
      expect(disconnected1, isNot(equals(connecting)));
    });
  });
}