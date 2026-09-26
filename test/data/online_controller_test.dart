import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:spajam2026/data/online_controller.dart';
import 'package:spajam2026/data/online_session_store.dart';
import 'package:spajam2026/data/online_transport.dart';
import 'package:spajam2026/domain/models.dart';

Map<String, dynamic> snapshot({int revision = 1, String status = 'lobby'}) => {
  'code': 'ABCDEF012345',
  'mode': 'presentation',
  'status': status,
  'hostId': 'p1',
  'selfId': 'p1',
  'pairCode': 'AABBCCDD',
  'serverNow': 100000,
  'revision': revision,
  'endsAt': null,
  'finaleStartsAt': null,
  'participants': [
    {
      'id': 'p1',
      'team': 'red',
      'profile': {'nickname': 'あか', 'hobby': '散歩', 'comment': ''},
    },
    {
      'id': 'p2',
      'team': 'blue',
      'profile': {'nickname': 'あお', 'hobby': '音楽', 'comment': ''},
    },
  ],
  'followers': <dynamic>[],
  'encounter': null,
  'finalSnapshot': null,
};

class FakeSocket implements OnlineSocket {
  FakeSocket(this.owner);
  final FakeTransport owner;
  final events = StreamController<Map<String, dynamic>>(sync: true);
  final sent = <Map<String, Object?>>[];
  bool closed = false;
  @override
  Stream<Map<String, dynamic>> get messages => events.stream;
  @override
  void send(Map<String, Object?> value) {
    sent.add(value);
    if (value['type'] == 'auth') {
      if (owner.authRejected) {
        events.addError(const OnlineFailure('auth rejected', status: 401));
      } else {
        emit(owner.value);
      }
    }
    if (value['type'] == 'ping') {
      events.add({'type': 'pong', 'id': value['id'], 'serverNow': 100000});
    }
    if (value['type'] == 'command' && owner.acknowledge) {
      final ack = {
        'type': 'ack',
        'requestId': value['requestId'],
        'snapshot': owner.value,
      };
      events.add(ack);
      if (owner.duplicateAck) events.add(ack);
    }
  }

  void emit(Map<String, dynamic> value) =>
      events.add({'type': 'snapshot', 'snapshot': value});
  @override
  Future<void> close() async {
    if (!closed) {
      closed = true;
      await events.close();
    }
  }
}

class FakeTransport implements OnlineTransport {
  Map<String, dynamic> value = snapshot();
  final requests = <Map<String, Object?>>[];
  final sockets = <FakeSocket>[];
  bool acknowledge = true, duplicateAck = false, authRejected = false;
  OnlineFailure? failure;
  Completer<Map<String, dynamic>>? actionPending;
  @override
  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    String? token,
    Map<String, Object?>? body,
  }) async {
    requests.add({'method': method, 'path': path, 'body': body});
    if (failure != null) throw failure!;
    if (path.endsWith('/actions') && actionPending != null) {
      return actionPending!.future;
    }
    if (path == '/rooms' || path.endsWith('/join')) {
      return {
        'code': 'ABCDEF012345',
        'participantId': 'p1',
        'token': 'a' * 64,
        'snapshot': value,
      };
    }
    return {'snapshot': value};
  }

  @override
  Future<OnlineSocket> connect(String code) async {
    final socket = FakeSocket(this);
    sockets.add(socket);
    return socket;
  }

  @override
  void dispose() {}
}

Future<void> settle() async {
  await Future<void>.delayed(Duration.zero);
}

Future<OnlineController> launch(
  FakeTransport transport, [
  MemoryOnlineSessionStore? store,
]) async {
  final controller = OnlineController(
    serverUrl: 'https://example.test',
    transport: transport,
    store: store,
    autoTick: false,
  );
  addTearDown(controller.dispose);
  expect(
    await controller.createRoom(
      presentation: true,
      duration: const Duration(minutes: 3),
    ),
    isTrue,
  );
  await settle();
  expect(controller.connected, isTrue);
  return controller;
}

void main() {
  test(
    'real session is saved and QR never contains its bearer token',
    () async {
      final transport = FakeTransport();
      final store = MemoryOnlineSessionStore();
      final controller = await launch(transport, store);
      expect(store.value?.token, 'a' * 64);
      expect(controller.self?.profile.nickname, 'あか');
      expect(controller.roomQr, 'tsunagun:room:ABCDEF012345');
      expect(controller.pairQr, 'tsunagun:pair:ABCDEF012345:AABBCCDD');
      expect(controller.pairQr, isNot(contains(store.value!.token)));
      expect(controller.participants.length, 2);
    },
  );

  test(
    'invalid or foreign-room QR is rejected before network access',
    () async {
      final transport = FakeTransport();
      final controller = await launch(transport);
      final before = transport.requests.length;
      expect(
        await controller.pair('tsunagun:pair:FFFFFFFFFFFF:AABBCCDD'),
        isFalse,
      );
      expect(
        await controller.pair('https://untrusted.example/credentials'),
        isFalse,
      );
      expect(transport.requests.length, before);
      expect(controller.error, isNotNull);
    },
  );

  test(
    'an old HTTP response cannot overwrite a newer socket snapshot',
    () async {
      final transport = FakeTransport();
      final controller = await launch(transport);
      transport.actionPending = Completer<Map<String, dynamic>>();
      final action = controller.saveProfile(
        const Profile(nickname: 'あか', hobby: '散歩', comment: ''),
      );
      await settle();
      transport.sockets.single.emit(snapshot(revision: 3, status: 'active'));
      transport.actionPending!.complete({'snapshot': snapshot(revision: 2)});
      expect(await action, isTrue);
      expect(controller.room?.revision, 3);
      expect(controller.room?.status, 'active');
    },
  );

  test(
    'duplicate input acknowledgements do not disconnect or grant local rewards',
    () async {
      final transport = FakeTransport()..duplicateAck = true;
      final controller = await launch(transport);
      expect(
        await controller.sendGameInput('duelInput', {
          'encounterId': 'g1',
          'round': 1,
          'at': 100000,
          'fell': false,
        }),
        isTrue,
      );
      expect(controller.connected, isTrue);
      expect(controller.followers, isEmpty);
      expect(controller.result, isNull);
    },
  );

  test(
    'background closes connection, cancels pending inputs and restores on resume',
    () async {
      final transport = FakeTransport()..acknowledge = false;
      final controller = await launch(transport);
      final input = controller.sendGameInput('duelInput', {
        'encounterId': 'g1',
        'round': 1,
      });
      controller.setForeground(false);
      expect(await input, isFalse);
      expect(controller.connected, isFalse);
      expect(transport.sockets.single.closed, isTrue);
      expect(await controller.sendGameInput('duelInput', {}), isFalse);
      controller.setForeground(true);
      await settle();
      expect(transport.sockets.length, 2);
      expect(controller.connected, isTrue);
      expect(controller.followers, isEmpty);
    },
  );

  test(
    'restoring uses saved participant rather than registering a new one',
    () async {
      final transport = FakeTransport();
      final store = MemoryOnlineSessionStore();
      await store.save(
        OnlineSession(
          endpoint: 'https://example.test',
          code: 'ABCDEF012345',
          participantId: 'p1',
          token: 'b' * 64,
        ),
      );
      final controller = OnlineController(
        serverUrl: 'https://example.test',
        transport: transport,
        store: store,
        autoTick: false,
      );
      addTearDown(controller.dispose);
      await controller.restore();
      await settle();
      expect(controller.self?.id, 'p1');
      expect(transport.requests.single['method'], 'GET');
      expect(controller.connected, isTrue);
    },
  );

  test(
    'expired session is cleared without pretending it is connected',
    () async {
      final transport = FakeTransport()
        ..failure = const OnlineFailure('expired', status: 410);
      final store = MemoryOnlineSessionStore();
      await store.save(
        OnlineSession(
          endpoint: 'https://example.test',
          code: 'ABCDEF012345',
          participantId: 'p1',
          token: 'c' * 64,
        ),
      );
      final controller = OnlineController(
        serverUrl: 'https://example.test',
        transport: transport,
        store: store,
        autoTick: false,
      );
      addTearDown(controller.dispose);
      await controller.restore();
      expect(store.value, isNull);
      expect(controller.room, isNull);
      expect(controller.connected, isFalse);
      expect(controller.error, contains('終了'));
    },
  );

  test(
    'HTTP errors keep local profile/room and do not fabricate followers',
    () async {
      final transport = FakeTransport();
      final controller = await launch(transport);
      final room = controller.room;
      transport.failure = const OnlineFailure('通信に時間がかかっています。');
      expect(await controller.startRoom(), isFalse);
      expect(controller.room, same(room));
      expect(controller.followers, isEmpty);
      expect(controller.busy, isFalse);
      expect(controller.error, contains('通信'));
    },
  );
  for (final invalidStatus in [401, 404, 410]) {
    testWidgets(
      'restore outage then repeated auth failure clears invalid $invalidStatus session',
      (tester) async {
        final transport = FakeTransport()
          ..failure = const OnlineFailure('offline')
          ..authRejected = true;
        final store = MemoryOnlineSessionStore();
        await store.save(
          OnlineSession(
            endpoint: 'https://example.test',
            code: 'ABCDEF012345',
            participantId: 'p1',
            token: 'a' * 64,
          ),
        );
        await store.savePending(
          PendingAdmission(
            endpoint: 'https://example.test',
            key: 'b' * 64,
            kind: 'join',
            roomCode: 'ABCDEF012345',
          ),
        );
        final controller = OnlineController(
          serverUrl: 'https://example.test',
          transport: transport,
          store: store,
          autoTick: false,
        );
        addTearDown(controller.dispose);
        await controller.restore();
        await tester.pump();
        transport.failure = OnlineFailure('expired', status: invalidStatus);
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 2));
        await tester.pump();
        expect(store.value, isNull);
        expect(store.pending, isNull);
        expect(controller.room, isNull);
        expect(controller.connected, isFalse);
        expect(controller.restoring, isFalse);
        expect(controller.error, contains('終了'));
        // The entry screen can create another room without restarting the app.
        transport.failure = null;
        transport.authRejected = false;
        expect(
          await controller.createRoom(
            presentation: true,
            duration: const Duration(minutes: 3),
          ),
          isTrue,
        );
        await tester.pump();
        expect(controller.connected, isTrue);
        controller.setForeground(false);
        await tester.pump();
      },
    );
  }

  testWidgets('transient reconnect probes preserve secrets and recover later', (
    tester,
  ) async {
    final transport = FakeTransport()
      ..failure = const OnlineFailure('offline')
      ..authRejected = true;
    final store = MemoryOnlineSessionStore();
    await store.save(
      OnlineSession(
        endpoint: 'https://example.test',
        code: 'ABCDEF012345',
        participantId: 'p1',
        token: 'a' * 64,
      ),
    );
    final controller = OnlineController(
      serverUrl: 'https://example.test',
      transport: transport,
      store: store,
      autoTick: false,
    );
    addTearDown(controller.dispose);
    await controller.restore();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 2));
    expect(store.value?.token, 'a' * 64);
    transport.failure = null;
    transport.authRejected = false;
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(controller.connected, isTrue);
    expect(controller.self?.id, 'p1');
    expect(transport.requests.every((r) => r['method'] == 'GET'), isTrue);
    controller.setForeground(false);
    await tester.pump();
  });

  test(
    'lost join response retries one durable admission, then clears its secret',
    () async {
      final transport = FakeTransport()
        ..failure = const OnlineFailure('lost response');
      final store = MemoryOnlineSessionStore();
      final controller = OnlineController(
        serverUrl: 'https://example.test',
        transport: transport,
        store: store,
        autoTick: false,
      );
      addTearDown(controller.dispose);
      expect(await controller.joinRoom('ABCDEF012345'), isFalse);
      final key = store.pending!.key;
      expect(key, matches(RegExp(r'^[a-f0-9]{64}$')));
      expect(store.value, isNull);
      transport.failure = null;
      expect(await controller.joinRoom('ABCDEF012345'), isTrue);
      await settle();
      final bodies = transport.requests.map((r) => r['body'] as Map);
      expect(bodies.every((body) => body['admissionKey'] == key), isTrue);
      expect(store.pending, isNull);
      expect(store.value?.token, 'a' * 64);
      expect(controller.roomQr, isNot(contains(key)));
    },
  );

  test(
    'restarting after a lost create response resumes the saved admission',
    () async {
      final store = MemoryOnlineSessionStore();
      final failed = FakeTransport()
        ..failure = const OnlineFailure('lost response');
      final first = OnlineController(
        serverUrl: 'https://example.test',
        transport: failed,
        store: store,
        autoTick: false,
      );
      expect(
        await first.createRoom(
          presentation: true,
          duration: const Duration(minutes: 3),
        ),
        isFalse,
      );
      final key = store.pending!.key;
      first.dispose();
      final transport = FakeTransport();
      final second = OnlineController(
        serverUrl: 'https://example.test',
        transport: transport,
        store: store,
        autoTick: false,
      );
      addTearDown(second.dispose);
      await second.restore();
      await settle();
      expect(transport.requests.single['path'], '/rooms');
      expect((transport.requests.single['body'] as Map)['admissionKey'], key);
      expect(second.connected, isTrue);
      expect(store.pending, isNull);
    },
  );

  test(
    'pending ticket cannot leak into a different room or endpoint',
    () async {
      final store = MemoryOnlineSessionStore();
      final previous = PendingAdmission(
        endpoint: 'https://different.test',
        key: 'b' * 64,
        kind: 'join',
        roomCode: 'FFFFFFFFFFFF',
      );
      await store.savePending(previous);
      final transport = FakeTransport();
      final controller = OnlineController(
        serverUrl: 'https://example.test',
        transport: transport,
        store: store,
        autoTick: false,
      );
      addTearDown(controller.dispose);
      await controller.restore();
      expect(transport.requests, isEmpty);
      expect(await controller.joinRoom('ABCDEF012345'), isTrue);
      expect(
        (transport.requests.single['body'] as Map)['admissionKey'],
        isNot(previous.key),
      );
    },
  );

  test('admission never contacts the server if durable saving fails', () async {
    final transport = FakeTransport();
    final controller = OnlineController(
      serverUrl: 'https://example.test',
      transport: transport,
      store: _FailingPendingStore(),
      autoTick: false,
    );
    addTearDown(controller.dispose);
    expect(await controller.joinRoom('ABCDEF012345'), isFalse);
    expect(transport.requests, isEmpty);
    expect(controller.error, contains('保存'));
    expect(controller.busy, isFalse);
  });
}

class _FailingPendingStore extends MemoryOnlineSessionStore {
  @override
  Future<void> savePending(PendingAdmission value) async =>
      throw StateError('disk unavailable');
}
