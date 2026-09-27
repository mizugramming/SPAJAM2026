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
  final failures = <OnlineFailure>[];
  Completer<Map<String, dynamic>>? actionPending;
  @override
  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    String? token,
    Map<String, Object?>? body,
  }) async {
    requests.add({'method': method, 'path': path, 'body': body});
    if (failures.isNotEmpty) throw failures.removeAt(0);
    if (failure != null) throw failure!;
    if (path.endsWith('/actions') && actionPending != null) {
      return actionPending!.future;
    }
    if (path == '/rooms' || path.endsWith('/join')) {
      return {
        'code': value['code'],
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
  const collision = OnlineFailure(
    'occupied',
    status: 409,
    code: 'ROOM_CODE_COLLISION',
  );
  test(
    'confirmed creation collision rotates only after saving the replacement ticket',
    () async {
      final store = MemoryOnlineSessionStore();
      final transport = FakeTransport()..failures.add(collision);
      final controller = await launch(transport, store);
      expect(transport.requests, hasLength(2));
      final oldKey = (transport.requests.first['body'] as Map)['admissionKey'];
      final newKey = (transport.requests.last['body'] as Map)['admissionKey'];
      expect(newKey, isNot(oldKey));
      expect(newKey, matches(RegExp(r'^[a-f0-9]{64}$')));
      expect(store.pending, isNull);
      expect(controller.connected, isTrue);
    },
  );

  test(
    'restored pending creation also handles collisions and caps attempts',
    () async {
      final store = MemoryOnlineSessionStore();
      await store.savePending(
        PendingAdmission(
          endpoint: 'https://example.test',
          key: 'b' * 64,
          kind: 'create',
          presentation: true,
          durationSeconds: 180,
        ),
      );
      final transport = FakeTransport()..failure = collision;
      final controller = OnlineController(
        serverUrl: 'https://example.test',
        transport: transport,
        store: store,
        autoTick: false,
      );
      addTearDown(controller.dispose);
      await controller.restore();
      expect(transport.requests, hasLength(5));
      final keys = transport.requests
          .map((r) => (r['body'] as Map)['admissionKey'])
          .toList();
      expect(keys.toSet(), hasLength(5));
      expect(keys.first, 'b' * 64);
      expect(store.pending!.key, keys.last);
      expect(controller.connected, isFalse);
      transport.failure = null;
      await controller.restore();
      await settle();
      expect(
        (transport.requests.last['body'] as Map)['admissionKey'],
        keys.last,
      );
      expect(controller.connected, isTrue);
    },
  );

  for (final failure in [
    const OnlineFailure('conflict', status: 409),
    const OnlineFailure('expired', status: 410),
    const OnlineFailure('timeout'),
  ]) {
    test('creation preserves its secret after ${failure.message}', () async {
      final store = MemoryOnlineSessionStore();
      final transport = FakeTransport()..failure = failure;
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
        isFalse,
      );
      expect(transport.requests, hasLength(1));
      final key = store.pending!.key;
      transport.failure = null;
      expect(
        await controller.createRoom(
          presentation: true,
          duration: const Duration(minutes: 3),
        ),
        isTrue,
      );
      expect((transport.requests.last['body'] as Map)['admissionKey'], key);
    });
  }

  test('a failed replacement save prevents another creation request', () async {
    final store = _FailingRotationStore();
    final transport = FakeTransport()..failure = collision;
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
      isFalse,
    );
    expect(transport.requests, hasLength(1));
    expect(
      store.pending!.key,
      (transport.requests.single['body'] as Map)['admissionKey'],
    );
    expect(controller.error, contains('保存'));
  });

  test(
    'join never rotates its admission ticket on a collision response',
    () async {
      final store = MemoryOnlineSessionStore();
      final transport = FakeTransport()..failure = collision;
      final controller = OnlineController(
        serverUrl: 'https://example.test',
        transport: transport,
        store: store,
        autoTick: false,
      );
      addTearDown(controller.dispose);
      expect(await controller.joinRoom('01234'), isFalse);
      expect(transport.requests, hasLength(1));
      expect(
        store.pending!.key,
        (transport.requests.single['body'] as Map)['admissionKey'],
      );
    },
  );

  test(
    'five-digit codes preserve leading zeroes through admission and restore',
    () async {
      final transport = FakeTransport()..value['code'] = '01234';
      final store = MemoryOnlineSessionStore();
      final first = OnlineController(
        serverUrl: 'https://example.test',
        transport: transport,
        store: store,
        autoTick: false,
      );
      expect(await first.joinRoom('tsunagun:room:01234'), isTrue);
      await settle();
      expect(transport.requests.single['path'], '/rooms/01234/join');
      expect(first.roomQr, 'tsunagun:room:01234');
      expect(first.pairQr, 'tsunagun:pair:01234:AABBCCDD');
      final saved = OnlineSession.fromJson(store.value!.toJson());
      expect(saved.code, '01234');
      first.dispose();
      await store.save(saved);
      final restoredTransport = FakeTransport()..value['code'] = '01234';
      final restored = OnlineController(
        serverUrl: 'https://example.test',
        transport: restoredTransport,
        store: store,
        autoTick: false,
      );
      addTearDown(restored.dispose);
      await restored.restore();
      await settle();
      expect(restoredTransport.requests.single['path'], '/rooms/01234');
      expect(restored.connected, isTrue);
      expect(restored.room?.code, '01234');
      expect(await restored.pair('tsunagun:pair:01234:AABBCCDD'), isTrue);
      final count = restoredTransport.requests.length;
      expect(await restored.pair('tsunagun:pair:01235:AABBCCDD'), isFalse);
      expect(restoredTransport.requests, hasLength(count));
    },
  );

  test(
    'a lost five-digit admission resumes the same durable ticket after restart',
    () async {
      final store = MemoryOnlineSessionStore();
      final failed = FakeTransport()
        ..value['code'] = '01234'
        ..failure = const OnlineFailure('lost response');
      final first = OnlineController(
        serverUrl: 'https://example.test',
        transport: failed,
        store: store,
        autoTick: false,
      );
      expect(await first.joinRoom('01234'), isFalse);
      final pending = PendingAdmission.fromJson(store.pending!.toJson());
      first.dispose();
      expect(pending.roomCode, '01234');
      await store.savePending(pending);
      final transport = FakeTransport()..value['code'] = '01234';
      final restored = OnlineController(
        serverUrl: 'https://example.test',
        transport: transport,
        store: store,
        autoTick: false,
      );
      addTearDown(restored.dispose);
      await restored.restore();
      await settle();
      expect(transport.requests.single['path'], '/rooms/01234/join');
      expect(
        (transport.requests.single['body'] as Map)['admissionKey'],
        pending.key,
      );
      expect(store.pending, isNull);
      expect(store.value?.code, '01234');
      expect(restored.connected, isTrue);
      expect(restored.roomQr, isNot(contains(pending.key)));
    },
  );

  test(
    'bot lookup stays separate from real members and pairing sends only its ID',
    () async {
      const botId = 'demo:ABCDEF012345:blue:1';
      final transport = FakeTransport();
      transport.value['demoParticipants'] = [
        {
          'id': botId,
          'profile': {'nickname': 'デモ参加者4', 'hobby': '', 'comment': ''},
          'team': 'blue',
          'ready': true,
          'connected': true,
          'isDemo': true,
          'normalCount': 1,
          'boneCount': 1,
          'power': 4,
          'playable': true,
        },
      ];
      final controller = await launch(transport);
      expect(controller.participants, hasLength(2));
      expect(controller.participantById(botId)?.profile.nickname, 'デモ参加者4');
      expect(controller.participantById('p1')?.id, 'p1');
      expect(controller.participantById('missing'), isNull);
      expect(controller.followers, isEmpty);
      expect(await controller.pairBot(botId), isTrue);
      final body = transport.requests.last['body'] as Map;
      expect(body['type'], 'pairBot');
      expect(body['botId'], botId);
      expect(body.keys.toSet(), {'requestId', 'type', 'botId'});
      expect(controller.followers, isEmpty);
    },
  );

  test(
    'real session is saved and QR never contains its bearer token',
    () async {
      final transport = FakeTransport();
      final store = MemoryOnlineSessionStore();
      final controller = await launch(transport, store);
      expect(store.value?.token, 'a' * 64);
      expect(controller.self?.profile.nickname, 'あか');
      expect((transport.requests.single['body'] as Map)['roomCodeDigits'], 5);
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
      expect((transport.requests.single['body'] as Map)['roomCodeDigits'], 5);
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

class _FailingRotationStore extends MemoryOnlineSessionStore {
  @override
  Future<void> savePending(PendingAdmission value) async {
    if (pending != null) throw StateError('disk unavailable');
    await super.savePending(value);
  }
}
