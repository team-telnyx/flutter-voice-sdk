import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/model/tx_ice_server.dart';

void main() {
  group('TxIceServer', () {
    group('constructor', () {
      test('creates instance with required urls', () {
        final server = TxIceServer(urls: ['stun:stun.example.com:3478']);

        expect(server.urls, ['stun:stun.example.com:3478']);
        expect(server.username, isNull);
        expect(server.credential, isNull);
      });

      test('creates instance with all parameters', () {
        final server = TxIceServer(
          urls: ['turn:turn.example.com:3478?transport=tcp'],
          username: 'testuser',
          credential: 'testpass',
        );

        expect(server.urls, ['turn:turn.example.com:3478?transport=tcp']);
        expect(server.username, 'testuser');
        expect(server.credential, 'testpass');
      });

      test('creates instance with multiple urls', () {
        final server = TxIceServer(
          urls: [
            'turn:turn.example.com:3478?transport=tcp',
            'turn:turn.example.com:3478?transport=udp',
          ],
          username: 'user',
          credential: 'pass',
        );

        expect(server.urls.length, 2);
        expect(server.urls[0], 'turn:turn.example.com:3478?transport=tcp');
        expect(server.urls[1], 'turn:turn.example.com:3478?transport=udp');
      });
    });

    group('fromUrl factory', () {
      test('creates instance from single URL', () {
        final server = TxIceServer.fromUrl('stun:stun.example.com:3478');

        expect(server.urls, ['stun:stun.example.com:3478']);
        expect(server.username, isNull);
        expect(server.credential, isNull);
      });

      test('creates instance from URL with credentials', () {
        final server = TxIceServer.fromUrl(
          'turn:turn.example.com:3478',
          username: 'user',
          credential: 'pass',
        );

        expect(server.urls, ['turn:turn.example.com:3478']);
        expect(server.username, 'user');
        expect(server.credential, 'pass');
      });
    });

    group('fromJson factory', () {
      test('creates instance from JSON with urls array', () {
        final json = {
          'urls': ['stun:stun.example.com:3478'],
          'username': 'user',
          'credential': 'pass',
        };

        final server = TxIceServer.fromJson(json);

        expect(server.urls, ['stun:stun.example.com:3478']);
        expect(server.username, 'user');
        expect(server.credential, 'pass');
      });

      test('creates instance from JSON with single url string', () {
        final json = {
          'url': 'stun:stun.example.com:3478',
        };

        final server = TxIceServer.fromJson(json);

        expect(server.urls, ['stun:stun.example.com:3478']);
        expect(server.username, isNull);
        expect(server.credential, isNull);
      });

      test('creates instance from JSON with multiple urls', () {
        final json = {
          'urls': [
            'turn:turn.example.com:3478?transport=tcp',
            'turn:turn.example.com:3478?transport=udp',
          ],
          'username': 'user',
          'credential': 'pass',
        };

        final server = TxIceServer.fromJson(json);

        expect(server.urls.length, 2);
        expect(server.username, 'user');
        expect(server.credential, 'pass');
      });

      test('handles missing urls gracefully', () {
        final json = <String, dynamic>{};

        final server = TxIceServer.fromJson(json);

        expect(server.urls, isEmpty);
      });
    });

    group('toJson', () {
      test('converts to JSON with all fields', () {
        final server = TxIceServer(
          urls: ['turn:turn.example.com:3478'],
          username: 'user',
          credential: 'pass',
        );

        final json = server.toJson();

        expect(json['urls'], ['turn:turn.example.com:3478']);
        expect(json['username'], 'user');
        expect(json['credential'], 'pass');
      });

      test('excludes null fields', () {
        final server = TxIceServer(urls: ['stun:stun.example.com:3478']);

        final json = server.toJson();

        expect(json['urls'], ['stun:stun.example.com:3478']);
        expect(json.containsKey('username'), isFalse);
        expect(json.containsKey('credential'), isFalse);
      });
    });

    group('toWebRTCMap', () {
      test('always uses urls key for single URL', () {
        final server = TxIceServer(
          urls: ['stun:stun.example.com:3478'],
          username: 'user',
          credential: 'pass',
        );

        final map = server.toWebRTCMap();

        expect(map['urls'], ['stun:stun.example.com:3478']);
        expect(map.containsKey('url'), isFalse);
        expect(map['username'], 'user');
        expect(map['credential'], 'pass');
      });

      test('always uses urls key for multiple URLs', () {
        final server = TxIceServer(
          urls: [
            'turn:turn.example.com:3478?transport=tcp',
            'turn:turn.example.com:3478?transport=udp',
          ],
          username: 'user',
          credential: 'pass',
        );

        final map = server.toWebRTCMap();

        expect(map.containsKey('url'), isFalse);
        expect(map['urls'], [
          'turn:turn.example.com:3478?transport=tcp',
          'turn:turn.example.com:3478?transport=udp',
        ]);
      });

      test('excludes null credentials', () {
        final server = TxIceServer(urls: ['stun:stun.example.com:3478']);

        final map = server.toWebRTCMap();

        expect(map.containsKey('username'), isFalse);
        expect(map.containsKey('credential'), isFalse);
      });
    });

    group('toString', () {
      test('masks credentials in output', () {
        final server = TxIceServer(
          urls: ['turn:turn.example.com:3478'],
          username: 'secretuser',
          credential: 'secretpass',
        );

        final str = server.toString();

        expect(str.contains('secretuser'), isFalse);
        expect(str.contains('secretpass'), isFalse);
        expect(str.contains('***'), isTrue);
      });

      test('shows null for missing credentials', () {
        final server = TxIceServer(urls: ['stun:stun.example.com:3478']);

        final str = server.toString();

        expect(str.contains('username: null'), isTrue);
        expect(str.contains('credential: null'), isTrue);
      });
    });

    group('equality', () {
      test('equal instances are equal', () {
        final server1 = TxIceServer(
          urls: ['stun:stun.example.com:3478'],
          username: 'user',
          credential: 'pass',
        );
        final server2 = TxIceServer(
          urls: ['stun:stun.example.com:3478'],
          username: 'user',
          credential: 'pass',
        );

        expect(server1, equals(server2));
        expect(server1.hashCode, equals(server2.hashCode));
      });

      test('different urls are not equal', () {
        final server1 = TxIceServer(urls: ['stun:stun1.example.com:3478']);
        final server2 = TxIceServer(urls: ['stun:stun2.example.com:3478']);

        expect(server1, isNot(equals(server2)));
      });

      test('different credentials are not equal', () {
        final server1 = TxIceServer(
          urls: ['stun:stun.example.com:3478'],
          username: 'user1',
        );
        final server2 = TxIceServer(
          urls: ['stun:stun.example.com:3478'],
          username: 'user2',
        );

        expect(server1, isNot(equals(server2)));
      });
    });

    group('const constructor', () {
      test('can be used as const', () {
        const server = TxIceServer(urls: ['stun:stun.example.com:3478']);

        expect(server.urls, ['stun:stun.example.com:3478']);
      });
    });
  });
}
