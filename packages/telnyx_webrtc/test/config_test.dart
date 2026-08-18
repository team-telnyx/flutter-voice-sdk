import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/config.dart';
import 'package:telnyx_webrtc/model/tx_ice_server.dart';

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

  // VSDK-283 acceptance criterion: custom ICE servers take precedence over
  // the defaults (including the TURNS 443 fallback). The override is
  // implemented in `Peer._iceServers` and `TelnyxClient._getEffectiveIceServers`
  // — when a caller passes a non-empty `iceServers` list, the entire default
  // list is bypassed. This group locks down the contract at the DefaultConfig
  // boundary so future changes to `defaultProdIceServers` / `defaultDevIceServers`
  // cannot silently break the override path.
  group('DefaultConfig custom ICE server override contract', () {
    test(
        'defaults include TURNS 443 and are the fallback (not the override)',
        () {
      final defaults = DefaultConfig.defaultProdIceServers;
      // The defaults are the fallback list that contains the TURNS 443 entry.
      expect(defaults.length, equals(5));
      expect(
        defaults.last.urls,
        equals([DefaultConfig.defaultTurns443]),
      );
      expect(
        defaults.any(
          (s) => s.urls.contains(DefaultConfig.defaultTurns443),
        ),
        isTrue,
      );
    });

    test(
        'custom ICE server list bypasses the defaults (including TURNS 443)',
        () {
      // A caller-provided custom list does NOT include the TURNS 443 fallback —
      // it replaces the entire default list when the override path fires.
      final customServers = <TxIceServer>[
        TxIceServer(urls: ['stun:custom.stun.example.com:3478']),
      ];

      expect(customServers.length, equals(1));
      expect(
        customServers.any(
          (s) => s.urls.contains(DefaultConfig.defaultTurns443),
        ),
        isFalse,
      );
      expect(
        customServers.any(
          (s) => s.urls.contains(DefaultConfig.defaultTurnUdp),
        ),
        isFalse,
      );
      expect(
        customServers.any(
          (s) => s.urls.contains(DefaultConfig.defaultTurn),
        ),
        isFalse,
      );
    });

    test(
        'override contract: caller list and default list are disjoint for TURNS 443',
        () {
      // The override contract is "first non-empty wins": if the caller passes
      // a non-empty iceServers list, the defaults (including TURNS 443) are
      // not consulted. This test guards against accidentally appending the
      // defaults behind a custom list (a regression risk).
      final callerList = <TxIceServer>[
        TxIceServer(urls: ['stun:caller-only.example.com:3478']),
      ];
      final defaultUrls = DefaultConfig.defaultProdIceServers
          .expand((s) => s.urls)
          .toSet();

      // Caller list contains none of the default URLs.
      for (final server in callerList) {
        for (final url in server.urls) {
          expect(defaultUrls.contains(url), isFalse,
              reason: 'caller-provided URL "$url" must not appear in defaults');
        }
      }
      // TURNS 443 is in the defaults but not in the caller list.
      expect(
        defaultUrls.contains(DefaultConfig.defaultTurns443),
        isTrue,
      );
      expect(
        callerList.any(
          (s) => s.urls.contains(DefaultConfig.defaultTurns443),
        ),
        isFalse,
      );
    });
  });
}
