import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/config.dart';

void main() {
  group('DefaultConfig ICE server constants', () {
    test('defaultTurns443 uses TLS on port 443 for prod', () {
      expect(
        DefaultConfig.defaultTurns443,
        equals('turns:turn.telnyx.com:443'),
      );
    });

    test('devTurns443 uses TLS on port 443 for dev', () {
      expect(
        DefaultConfig.devTurns443,
        equals('turns:turndev.telnyx.com:443'),
      );
    });
  });

  group('DefaultConfig.defaultProdIceServers', () {
    final servers = DefaultConfig.defaultProdIceServers;

    test('contains 6 entries including both production TURNS endpoints', () {
      expect(servers.length, equals(6));
    });

    test('preserves ordering with primary and secondary TURNS last',
        () {
      expect(servers[0].urls, equals([DefaultConfig.defaultStun]));
      expect(servers[1].urls, equals([DefaultConfig.googleStun]));
      expect(servers[2].urls, equals([DefaultConfig.defaultTurnUdp]));
      expect(servers[3].urls, equals([DefaultConfig.defaultTurn]));
      expect(servers[4].urls, equals([DefaultConfig.defaultTurns443]));
      expect(servers[5].urls, equals([DefaultConfig.secondaryTurns443]));
    });

    test('secondary TURNS 443 entry has correct credentials', () {
      final turns443 = servers[5];
      expect(turns443.urls, equals([DefaultConfig.secondaryTurns443]));
      expect(turns443.username, equals(DefaultConfig.username));
      expect(turns443.credential, equals(DefaultConfig.password));
    });

    test('TURNS 443 entry (5th) has correct URL and credentials', () {
      final turns443 = servers[4];
      expect(turns443.urls, equals([DefaultConfig.defaultTurns443]));
      expect(turns443.username, equals(DefaultConfig.username));
      expect(turns443.credential, equals(DefaultConfig.password));
    });

    test('existing TURN entries keep their credentials', () {
      expect(servers[2].username, equals(DefaultConfig.username));
      expect(servers[2].credential, equals(DefaultConfig.password));
      expect(servers[3].username, equals(DefaultConfig.username));
      expect(servers[3].credential, equals(DefaultConfig.password));
    });
  });

  group('DefaultConfig.defaultDevIceServers', () {
    final servers = DefaultConfig.defaultDevIceServers;

    test('contains 5 entries (dev TURNS 443 added as 5th)', () {
      expect(servers.length, equals(5));
    });

    test(
        'preserves ordering: dev STUN, Google STUN, dev TURN UDP, dev TURN TCP, dev TURNS 443',
        () {
      expect(servers[0].urls, equals([DefaultConfig.devStun]));
      expect(servers[1].urls, equals([DefaultConfig.googleStun]));
      expect(servers[2].urls, equals([DefaultConfig.devTurnUdp]));
      expect(servers[3].urls, equals([DefaultConfig.devTurn]));
      expect(servers[4].urls, equals([DefaultConfig.devTurns443]));
    });

    test('dev TURNS 443 entry (5th) has correct URL and credentials', () {
      final turns443 = servers[4];
      expect(turns443.urls, equals([DefaultConfig.devTurns443]));
      expect(turns443.username, equals(DefaultConfig.username));
      expect(turns443.credential, equals(DefaultConfig.password));
    });
  });

  group('DefaultConfig ICE server ordering invariants', () {
    test('secondary prod TURNS and dev TURNS are last', () {
      expect(
        DefaultConfig.defaultProdIceServers.last.urls,
        equals([DefaultConfig.secondaryTurns443]),
      );
      expect(
        DefaultConfig.defaultDevIceServers.last.urls,
        equals([DefaultConfig.devTurns443]),
      );
    });

    test('lower-latency UDP/TCP TURN entries precede TURNS 443 in prod', () {
      final urls =
          DefaultConfig.defaultProdIceServers.expand((s) => s.urls).toList();
      final udpIdx = urls.indexOf(DefaultConfig.defaultTurnUdp);
      final tcpIdx = urls.indexOf(DefaultConfig.defaultTurn);
      final turns443Idx = urls.indexOf(DefaultConfig.defaultTurns443);
      final secondaryTurns443Idx =
          urls.indexOf(DefaultConfig.secondaryTurns443);
      expect(udpIdx, isNonNegative);
      expect(tcpIdx, isNonNegative);
      expect(turns443Idx, isNonNegative);
      expect(secondaryTurns443Idx, isNonNegative);
      expect(udpIdx, lessThan(turns443Idx));
      expect(tcpIdx, lessThan(turns443Idx));
      expect(turns443Idx, lessThan(secondaryTurns443Idx));
    });

    test('lower-latency UDP/TCP TURN entries precede TURNS 443 in dev', () {
      final urls =
          DefaultConfig.defaultDevIceServers.expand((s) => s.urls).toList();
      final udpIdx = urls.indexOf(DefaultConfig.devTurnUdp);
      final tcpIdx = urls.indexOf(DefaultConfig.devTurn);
      final turns443Idx = urls.indexOf(DefaultConfig.devTurns443);
      expect(udpIdx, isNonNegative);
      expect(tcpIdx, isNonNegative);
      expect(turns443Idx, isNonNegative);
      expect(udpIdx, lessThan(turns443Idx));
      expect(tcpIdx, lessThan(turns443Idx));
    });
  });
}
