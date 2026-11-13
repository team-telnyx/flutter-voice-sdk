import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart'
    show ConnectivityResult;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telnyx_webrtc/config/telnyx_config.dart';
import 'package:telnyx_webrtc/model/connection_status.dart';
import 'package:telnyx_webrtc/model/latency_metrics.dart';
import 'package:telnyx_webrtc/model/region.dart';
import 'package:telnyx_webrtc/telnyx_client.dart';
import 'package:telnyx_webrtc/tx_socket.dart';
import 'package:telnyx_webrtc/utils/logging/log_level.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeConnectivityPlatform fakeConnectivityPlatform;
  late TelnyxClient client;
  late FakeTxSocket fakeSocket;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fakeConnectivityPlatform = FakeConnectivityPlatform();

    fakeSocket = FakeTxSocket();
    client = TelnyxClient(
      connectivityChanges: fakeConnectivityPlatform.connectivityChanges,
    )..txSocket = fakeSocket;
  });

  tearDown(() async {
    client.dispose();
    await fakeConnectivityPlatform.dispose();
  });

  test(
    'disconnect cancels connectivity updates and ignores socket callbacks',
    () async {
      final states = <ConnectionStatus>[];
      var socketMessages = 0;

      client
        ..onConnectionStateChanged = states.add
        ..onSocketMessageReceived = (_) {
          socketMessages++;
        }
        ..connectWithCredential(_credentialConfig());

      await pumpEventQueue();
      fakeConnectivityPlatform.emit([ConnectivityResult.wifi]);
      await pumpEventQueue();
      fakeConnectivityPlatform.emit([ConnectivityResult.mobile]);
      await pumpEventQueue();

      expect(states, contains(ConnectionStatus.reconnecting));

      client.disconnect();
      await pumpEventQueue();

      final stateCountAfterDisconnect = states.length;
      expect(fakeConnectivityPlatform.cancelCount, 1);

      fakeConnectivityPlatform.emit([ConnectivityResult.wifi]);
      fakeSocket.emitMessage('{"method":"telnyx_rtc.clientReady"}');
      await pumpEventQueue();

      expect(states, hasLength(stateCountAfterDisconnect));
      expect(socketMessages, 0);
    },
  );

  test('dispose is idempotent and disposes latency tracking', () async {
    final emittedMetrics = <LatencyMetrics>[];

    client
      ..latencyTracker.setLatencyMetricsListener(emittedMetrics.add)
      ..connectWithCredential(_credentialConfig());

    await pumpEventQueue();

    client
      ..dispose()
      ..dispose();
    await pumpEventQueue();

    expect(fakeSocket.closeCount, 1);
    expect(fakeConnectivityPlatform.cancelCount, 1);

    client.latencyTracker
      ..startRegistrationTracking()
      ..completeRegistrationTracking();

    expect(emittedMetrics, isEmpty);
  });

  test('TxSocket.close is safe before the underlying socket opens', () {
    final socket = TxSocket('wss://example.test');

    expect(socket.close, returnsNormally);
  });

  test('stale region fallback timers do not reconnect newer sessions',
      () async {
    client.connectWithCredential(
      _credentialConfig(
        sipUser: 'first',
        region: Region.eu,
        fallbackOnRegionFailure: true,
      ),
    );
    await pumpEventQueue();

    expect(fakeSocket.connectCount, 1);

    fakeSocket.emitClose(500, 'region failure');
    await Future<void>.delayed(const Duration(milliseconds: 100));

    client.connectWithCredential(_credentialConfig(sipUser: 'second'));
    await pumpEventQueue();

    expect(fakeSocket.connectCount, 2);

    await Future<void>.delayed(const Duration(milliseconds: 1100));

    expect(fakeSocket.connectCount, 2);
  });

  test('disconnect during reconnect does not leave attaching state stuck',
      () async {
    final states = <ConnectionStatus>[];

    client
      ..onConnectionStateChanged = states.add
      ..connectWithCredential(_credentialConfig());

    await pumpEventQueue();
    fakeConnectivityPlatform.emit([ConnectivityResult.wifi]);
    await pumpEventQueue();
    fakeConnectivityPlatform.emit([ConnectivityResult.mobile]);
    await pumpEventQueue();

    expect(states.where((state) => state == ConnectionStatus.reconnecting),
        hasLength(1));

    client.disconnect();
    client.connectWithCredential(_credentialConfig(sipUser: 'second'));

    await pumpEventQueue();
    fakeConnectivityPlatform.emit([ConnectivityResult.wifi]);
    await pumpEventQueue();
    fakeConnectivityPlatform.emit([ConnectivityResult.mobile]);
    await pumpEventQueue();

    expect(states.where((state) => state == ConnectionStatus.reconnecting),
        hasLength(2));
  });

  test(
      'disconnect while a login continuation is pending opens no second socket',
      () async {
    // Fresh store: the login helper suspends on the persisted-region check,
    // giving disconnect() a window to supersede it (PR #355 review).
    client.connectWithCredential(_credentialConfig());
    await pumpEventQueue();
    expect(fakeSocket.connectCount, 1);

    fakeSocket.emitOpen();
    // The login helper is now suspended awaiting storage checks; tearing
    // down the connection must invalidate it before it can reconnect.
    client.disconnect();
    await pumpEventQueue();

    expect(fakeSocket.connectCount, 1);
  });

  test('superseded login never sends stale credentials on the new connection',
      () async {
    // Two rapid connects: the first login is still suspended on storage
    // awaits when the second connect supersedes it. Only the fresh
    // credentials may reach the wire (PR #355 review).
    client.connectWithCredential(_credentialConfig(sipUser: 'first-user'));
    await pumpEventQueue();
    fakeSocket.emitOpen();

    client.connectWithCredential(_credentialConfig(sipUser: 'second-user'));
    await pumpEventQueue();
    fakeSocket.emitOpen();
    await pumpEventQueue();

    final sent = fakeSocket.sentMessages.whereType<String>().toList();
    expect(
      sent.where((m) => m.contains('first-user')),
      isEmpty,
      reason: 'stale login continuation must be rejected',
    );
    expect(
      sent.where((m) => m.contains('second-user')),
      isNotEmpty,
      reason: 'the current login must reach the wire',
    );
  });
}

CredentialConfig _credentialConfig({
  String sipUser = 'test',
  Region region = Region.auto,
  bool fallbackOnRegionFailure = false,
}) {
  return CredentialConfig(
    sipUser: sipUser,
    sipPassword: 'test',
    sipCallerIDName: 'test',
    sipCallerIDNumber: 'test',
    notificationToken: 'test',
    region: region,
    fallbackOnRegionFailure: fallbackOnRegionFailure,
    autoReconnect: true,
    logLevel: LogLevel.info,
    debug: false,
  );
}

class FakeConnectivityPlatform {
  int listenCount = 0;
  int cancelCount = 0;

  late final StreamController<List<ConnectivityResult>> _controller =
      StreamController<List<ConnectivityResult>>.broadcast(
    onListen: () {
      listenCount++;
    },
    onCancel: () {
      cancelCount++;
    },
  );

  Stream<List<ConnectivityResult>> connectivityChanges() {
    return _controller.stream;
  }

  void emit(List<ConnectivityResult> results) {
    _controller.add(results);
  }

  Future<void> dispose() {
    return _controller.close();
  }
}

class FakeTxSocket extends TxSocket {
  FakeTxSocket() : super('wss://example.test');

  int connectCount = 0;
  int closeCount = 0;
  final sentMessages = <dynamic>[];

  @override
  void connect() {
    connectCount++;
  }

  @override
  void close() {
    closeCount++;
  }

  @override
  void send(dynamic data) {
    sentMessages.add(data);
  }

  void emitOpen() => onOpen();

  void emitMessage(dynamic data) {
    onMessage(data);
  }

  void emitClose(int code, String reason) {
    onClose(code, reason);
  }
}
