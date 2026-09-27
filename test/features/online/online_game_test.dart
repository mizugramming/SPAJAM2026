import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spajam2026/data/online_controller.dart';
import 'package:spajam2026/domain/models.dart';
import 'package:spajam2026/domain/online_room.dart';
import 'package:spajam2026/features/duel/race_field.dart';
import 'package:spajam2026/features/duel/win_dance.dart';
import 'package:spajam2026/features/online/online_game.dart';

const _profiles = [
  Profile(nickname: 'あか', hobby: '料理', comment: ''),
  Profile(nickname: 'あお', hobby: '音楽', comment: ''),
];

class _Controller extends OnlineController {
  _Controller({this.selfId = 'a', this.bot = false}) : super(autoTick: false);

  final String selfId;
  final bool bot;
  int now = 1000;
  bool isConnected = true;
  bool acceptInput = true;
  int readyCalls = 0;
  int cancelCalls = 0;
  int returnCalls = 0;
  final List<Map<String, Object?>> sent = [];
  OnlineEncounter? current;

  @override
  int get serverNow => now;
  @override
  bool get connected => isConnected;
  @override
  bool get busy => false;
  @override
  OnlineEncounter? get encounter => current;
  @override
  List<Participant> get participants => [
    Participant(id: 'a', profile: _profiles[0], team: Team.red),
    if (!bot) Participant(id: 'b', profile: _profiles[1], team: Team.blue),
  ];
  @override
  Participant? participantById(String id) => bot && id == 'bot'
      ? const Participant(
          id: 'bot',
          profile: Profile(nickname: 'デモ参加者4', hobby: '', comment: ''),
          team: Team.blue,
        )
      : super.participantById(id);
  @override
  Participant get self => participants.firstWhere((p) => p.id == selfId);
  @override
  Future<bool> readyGame() async {
    readyCalls++;
    return true;
  }

  @override
  Future<bool> cancelGame() async {
    cancelCalls++;
    return true;
  }

  @override
  Future<bool> returnHome() async {
    returnCalls++;
    return true;
  }

  @override
  Future<bool> sendGameInput(String type, Map<String, Object?> payload) async {
    sent.add({'type': type, ...payload});
    return acceptInput;
  }

  void snapshot({
    String kind = 'duel',
    String status = 'playing',
    int round = 1,
    int startAt = 1000,
    int hop = 1,
    int level = 0,
    List<String> ready = const [],
    String? outcome,
    Map<String, dynamic> decisions = const {},
  }) {
    final peerId = bot
        ? 'bot'
        : selfId == 'a'
        ? 'b'
        : 'a';
    current = OnlineEncounter.fromJson({
      'id': 'encounter',
      'kind': kind,
      'status': status,
      'round': round,
      'playerIds': ['a', bot ? 'bot' : 'b'],
      'readyIds': ready,
      'startAt': startAt,
      'fallMs': 1800,
      'decisions': decisions,
      'coop': {'level': level, 'levelStartAt': startAt, 'hop': hop, 'hits': []},
      'result': outcome == null
          ? null
          : {
              'outcome': outcome,
              'peer': {
                'id': peerId,
                'profile': {'nickname': 'あいて', 'hobby': 'ゲーム', 'comment': ''},
                'team': peerId == 'a' ? 'red' : 'blue',
              },
              'newFollower': {
                'id': 'child',
                'ownerId': selfId,
                'peerId': peerId,
                'profile': {'nickname': 'あいて', 'hobby': 'ゲーム', 'comment': ''},
                'kind': outcome == 'win' ? 'normal' : 'bone',
                'ordinal': 0,
              },
              'delta': outcome == 'win' ? 3 : 1,
            },
    }, selfId);
    notifyListeners();
  }
}

Future<void> _mount(
  WidgetTester tester,
  _Controller controller, {
  VoidCallback? onComplete,
  double textScale = 1,
}) async {
  await tester.binding.setSurfaceSize(const Size(412, 700));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(412, 700),
          textScaler: TextScaler.linear(textScale),
          disableAnimations: true,
        ),
        child: Scaffold(
          body: OnlineGame(
            controller: controller,
            onPresentationComplete: onComplete ?? () {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _advance(
  WidgetTester tester,
  _Controller controller,
  int milliseconds,
) async {
  for (var elapsed = 0; elapsed < milliseconds; elapsed += 50) {
    controller.now += 50;
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _tap(WidgetTester tester) =>
    tester.tap(find.byKey(const Key('online-game-input')));

void main() {
  testWidgets('server bot is a peer without becoming a real participant', (
    tester,
  ) async {
    final c = _Controller(bot: true)
      ..snapshot(status: 'offered', ready: ['bot']);
    await _mount(tester, c);
    expect(c.participants, hasLength(1));
    expect(find.text('相手の接続を確認しています…'), findsNothing);
    expect(tester.widget<RaceField>(find.byType(RaceField)).peer.id, 'bot');
    await tester.tap(find.byKey(const Key('online-game-ready')));
    expect(c.readyCalls, 1);
    expect(c.sent, isEmpty);
  });

  testWidgets('server bot decision is displayed but never sends a human stop', (
    tester,
  ) async {
    final c = _Controller(bot: true)..snapshot();
    var completed = 0;
    await _mount(tester, c, onComplete: () => completed++);
    await _advance(tester, c, 1400);
    c.snapshot(
      decisions: {
        'bot': {'fell': false, 'depth': .49},
      },
    );
    await tester.pump();
    final field = tester.widget<RaceField>(find.byType(RaceField));
    expect(field.peerDecision?.depth, .49);
    expect(field.selfDecision, isNull);
    expect(field.selfWins, isNull);
    expect(c.sent, isEmpty);
    await _tap(tester);
    expect(c.sent, hasLength(1));
    expect(c.sent.single['fell'], isFalse);
    expect(completed, 0);
  });

  testWidgets('a delayed bot coop turn does not trigger a fabricated miss', (
    tester,
  ) async {
    final c = _Controller(bot: true)
      ..now = 3000
      ..snapshot(kind: 'coop', hop: 2);
    var completed = 0;
    await _mount(tester, c, onComplete: () => completed++);
    expect(find.textContaining('あなたは右の缶'), findsWidgets);
    await _tap(tester);
    await _advance(tester, c, 800);
    expect(c.sent, isEmpty);
    expect(completed, 0);
    c.snapshot(kind: 'coop', hop: 3);
    await tester.pump();
    await _advance(tester, c, 500);
    await _tap(tester);
    expect(c.sent, hasLength(1));
    expect(c.sent.single['hop'], 3);
    expect(c.sent.single['miss'], isFalse);
    expect(completed, 0);
  });

  testWidgets(
    'ready waits for the partner; countdown taps are not race inputs',
    (tester) async {
      final c = _Controller()..snapshot(status: 'offered');
      await _mount(tester, c);
      await tester.tap(find.byKey(const Key('online-game-ready')));
      expect(c.readyCalls, 1);
      c.snapshot(status: 'offered', ready: ['a']);
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('online-game-ready')))
            .onPressed,
        isNull,
      );
      c.snapshot(status: 'countdown', startAt: 4000);
      await tester.pump();
      expect(find.text('3'), findsOneWidget);
      await tester.tapAt(const Offset(206, 200));
      expect(c.sent, isEmpty);
    },
  );

  testWidgets('one real stop is sent; missing peer never resolves locally', (
    tester,
  ) async {
    final c = _Controller()..snapshot();
    var completed = 0;
    await _mount(tester, c, onComplete: () => completed++);
    await _advance(tester, c, 1500);
    await _tap(tester);
    await _tap(tester);
    expect(c.sent, hasLength(1));
    expect(c.sent.single, {
      'type': 'duelInput',
      'encounterId': 'encounter',
      'round': 1,
      'at': 2500,
      'fell': false,
    });
    await _advance(tester, c, 4000);
    final field = tester.widget<RaceField>(find.byType(RaceField));
    expect(field.peerDecision, isNull);
    expect(field.selfWins, isNull);
    expect(completed, 0);
  });

  testWidgets('continuous water crossing sends exactly one real fall', (
    tester,
  ) async {
    final c = _Controller()..snapshot();
    await _mount(tester, c);
    await _advance(tester, c, 2200);
    expect(c.sent, hasLength(1));
    expect(c.sent.single['fell'], isTrue);
    expect(c.sent.single['at'], 2800);
    await _tap(tester);
    expect(c.sent, hasLength(1));
  });

  testWidgets('late resumed snapshot is not converted to an invented fall', (
    tester,
  ) async {
    final c = _Controller()
      ..now = 5000
      ..snapshot();
    await _mount(tester, c);
    await _advance(tester, c, 1000);
    expect(c.sent, isEmpty);
    expect(tester.widget<RaceField>(find.byType(RaceField)).selfWins, isNull);
  });

  testWidgets('late visible hop is not mistaken for a missed chance', (
    tester,
  ) async {
    final c = _Controller()
      ..now = 2480
      ..snapshot(kind: 'coop');
    await _mount(tester, c);
    // Target is 2300, window closes at 2530. Only 50ms of it was visible.
    await _advance(tester, c, 500);
    expect(c.sent, isEmpty);
    c.now = 2600;
    c.snapshot(kind: 'duel', round: 2);
    await tester.pump();
    // The race was first visible only 200ms before the water line.
    await _advance(tester, c, 500);
    expect(c.sent, isEmpty);
  });

  testWidgets(
    'second device cannot drive first player; even hop 6 has a ring',
    (tester) async {
      final c = _Controller(selfId: 'b')..snapshot(kind: 'coop');
      await _mount(tester, c);
      expect(find.textContaining('あなたは左の缶'), findsWidgets);
      await _tap(tester);
      await _advance(tester, c, 2000);
      expect(c.sent, isEmpty);
      c.now = 7200;
      c.snapshot(kind: 'coop', hop: 6);
      await tester.pump();
      expect(find.byKey(const Key('online-soul-ring')), findsOneWidget);
      await _tap(tester);
      await _tap(tester);
      expect(c.sent, hasLength(1));
      expect(c.sent.single, {
        'type': 'coopInput',
        'encounterId': 'encounter',
        'round': 1,
        'level': 0,
        'hop': 6,
        'at': 7200,
        'miss': false,
      });
    },
  );

  testWidgets(
    'own visible missed window sends miss but never assigns outcome',
    (tester) async {
      final c = _Controller()..snapshot(kind: 'coop');
      var completed = 0;
      await _mount(tester, c, onComplete: () => completed++);
      await _advance(tester, c, 1800);
      expect(c.sent, hasLength(1));
      expect(c.sent.single['miss'], isTrue);
      expect(c.sent.single['hop'], 1);
      expect(completed, 0);
    },
  );

  testWidgets('a failed delivery blocks extra inputs without inventing loss', (
    tester,
  ) async {
    final c = _Controller()
      ..acceptInput = false
      ..snapshot();
    var completed = 0;
    await _mount(tester, c, onComplete: () => completed++);
    await _advance(tester, c, 1000);
    await _tap(tester);
    await tester.pump();
    expect(find.text('通信を確認しています…'), findsOneWidget);
    await _advance(tester, c, 3000);
    expect(c.sent, hasLength(1));
    expect(completed, 0);
  });

  testWidgets('background and disconnection never send a missed input', (
    tester,
  ) async {
    final c = _Controller()..snapshot();
    await _mount(tester, c);
    await _advance(tester, c, 1000);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await _advance(tester, c, 1500);
    expect(c.sent, isEmpty);
    c.isConnected = false;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _advance(tester, c, 1000);
    expect(c.sent, isEmpty);
    c.snapshot(status: 'cancelled');
    await tester.pump();
    expect(find.text('ゲームを中断しました'), findsOneWidget);
  });

  testWidgets('draw offers a fresh ready round with no reward presentation', (
    tester,
  ) async {
    final c = _Controller()..snapshot();
    var completed = 0;
    await _mount(tester, c, onComplete: () => completed++);
    await _advance(tester, c, 500);
    await _tap(tester);
    c.snapshot(status: 'draw');
    await tester.pump();
    expect(find.text('ぴったり同点！'), findsOneWidget);
    await tester.tap(find.text('もう一度、準備OK！'));
    expect(c.readyCalls, 1);
    c.snapshot(round: 2, startAt: c.now);
    await tester.pump();
    await _advance(tester, c, 500);
    await _tap(tester);
    expect(c.sent, hasLength(2));
    expect(c.sent.last['round'], 2);
    expect(completed, 0);
  });

  testWidgets(
    'confirmed loss completes once; unrelated updates cannot replay',
    (tester) async {
      final c = _Controller()..snapshot();
      var completed = 0;
      await _mount(tester, c, onComplete: () => completed++);
      c.snapshot(
        status: 'finished',
        outcome: 'loss',
        decisions: {
          'a': {'fell': true, 'depth': 1},
          'b': {'fell': true, 'depth': 1},
        },
      );
      await tester.pump();
      await _advance(tester, c, 2000);
      expect(completed, 1);
      c.notifyListeners();
      await _advance(tester, c, 2000);
      expect(completed, 1);
    },
  );

  testWidgets('only confirmed win dances; finite presentation can be skipped', (
    tester,
  ) async {
    final c = _Controller()
      ..snapshot(
        status: 'finished',
        outcome: 'win',
        decisions: {
          'a': {'fell': false, 'depth': .9},
          'b': {'fell': true, 'depth': 1},
        },
      );
    var completed = 0;
    await _mount(tester, c, onComplete: () => completed++);
    await _advance(tester, c, 1100);
    expect(find.byType(WinDance), findsOneWidget);
    await _tap(tester);
    expect(completed, 0);
    await _advance(tester, c, 1000);
    await _tap(tester);
    expect(completed, 1);
    await _advance(tester, c, 6500);
    expect(completed, 1);
  });

  testWidgets('large text keeps ready controls reachable without overflow', (
    tester,
  ) async {
    final c = _Controller()..snapshot(kind: 'coop', status: 'offered');
    await _mount(tester, c, textScale: 2);
    await tester.ensureVisible(find.byKey(const Key('online-game-ready')));
    await tester.tap(find.byKey(const Key('online-game-ready')));
    expect(c.readyCalls, 1);
    expect(tester.takeException(), isNull);
  });
}
