import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spajam2026/app/tsunagun_theme.dart';
import 'package:spajam2026/data/online_controller.dart';
import 'package:spajam2026/domain/models.dart';
import 'package:spajam2026/domain/online_room.dart';
import 'package:spajam2026/features/demo/can_stage.dart';
import 'package:spajam2026/features/demo/parent_character.dart';
import 'package:spajam2026/features/demo/result_sound_player.dart';
import 'package:spajam2026/features/demo/tug_of_war_finale.dart';
import 'package:spajam2026/features/online/online_game.dart';
import 'package:spajam2026/features/online/online_page.dart';
import 'package:spajam2026/features/online/qr_panel.dart';

Map<String, Object?> person(String id, String name, {String hobby = '音楽'}) => {
  'id': id,
  'profile': {'nickname': name, 'hobby': hobby, 'comment': ''},
  'team': id == 'self' ? 'red' : 'blue',
  'ready': name.isNotEmpty,
  'connected': true,
};
Map<String, dynamic> roomJson({
  String status = 'lobby',
  bool profile = true,
  bool host = true,
  Map<String, dynamic>? encounter,
}) => {
  'code': 'ABCDEF012345',
  'mode': 'presentation',
  'status': status,
  'hostId': host ? 'self' : 'peer',
  'selfId': 'self',
  'pairCode': '1234ABCD',
  'revision': 1,
  'serverNow': 1000,
  'endsAt': 181000,
  'finaleStartsAt': null,
  'participants': [
    person('self', profile ? '自分' : '', hobby: profile ? '音楽' : ''),
    person('peer', '相手'),
  ],
  'followers': [],
  'encounter': encounter,
  'finalSnapshot': null,
};
Map<String, dynamic> finished({String outcome = 'loss'}) => {
  'id': 'encounter-1',
  'kind': outcome.startsWith('coop') ? 'coop' : 'duel',
  'status': 'finished',
  'round': 1,
  'playerIds': ['self', 'peer'],
  'readyIds': ['self', 'peer'],
  'startAt': 0,
  'fallMs': 1800,
  'decisions': {},
  'coop': {},
  'result': {
    'outcome': outcome,
    'peer': person('peer', '相手'),
    'delta': 1,
    'promoted': null,
    'newFollower': {
      'id': 'child',
      'ownerId': 'self',
      'peerId': 'peer',
      'profile': {'nickname': '相手', 'hobby': '音楽', 'comment': 'よろしく'},
      'kind': 'bone',
      'ordinal': 1,
    },
  },
};

Map<String, dynamic> supporter(
  String id,
  String team,
  int power, {
  bool playable = true,
  bool busy = false,
  String? nextKind = 'duel',
}) => {
  ...person(id, '$id（デモ）'),
  'team': team,
  'isDemo': true,
  'normalCount': power ~/ 3,
  'boneCount': power % 3,
  'power': power,
  'playable': playable,
  'busy': busy,
  'nextKind': nextKind,
  'ready': false,
};

Map<String, dynamic> presentationRoom({
  String status = 'lobby',
  int realCount = 1,
  bool hostReady = true,
  bool peerReady = true,
}) => {
  ...roomJson(status: status),
  'participants': [
    {...person('self', '自分'), 'ready': hostReady},
    if (realCount == 2)
      {
        ...person('peer', peerReady ? '相手' : '', hobby: peerReady ? '音楽' : ''),
        'ready': peerReady,
      },
  ],
  'demoParticipants': [
    supporter('red-demo-1', 'red', 4),
    supporter('red-demo-2', 'red', 2),
    supporter('blue-demo-1', 'blue', 4),
    supporter('blue-demo-2', 'blue', 2),
    if (realCount == 1)
      supporter(
        'second-player-slot',
        'blue',
        0,
        playable: false,
        nextKind: null,
      ),
  ],
};

class ScreenController extends OnlineController {
  ScreenController([Map<String, dynamic>? initial]) : super(autoTick: false) {
    if (initial != null) {
      raw = initial;
      data = OnlineRoom.fromJson(initial);
    }
  }
  OnlineRoom? data;
  Map<String, dynamic>? raw;
  bool available = true;
  bool saveSucceeds = true;
  bool? presentation;
  Profile? savedProfile;
  String? joinedCode, pairedCode, pairedBot;
  String? failure;
  final foreground = <bool>[];
  int starts = 0;
  void emit(Map<String, dynamic> value) {
    raw = value;
    data = OnlineRoom.fromJson(value);
    notifyListeners();
  }

  @override
  OnlineRoom? get room => data;
  @override
  bool get configured => true;
  @override
  bool get connected => available;
  @override
  bool get busy => false;
  @override
  String? get error => failure;
  @override
  List<Participant> get participants => data?.participants ?? [];
  @override
  Participant? get self =>
      data?.participants.firstWhere((p) => p.id == data!.selfId);
  @override
  List<Follower> get followers => data?.followers ?? [];
  @override
  OnlineEncounter? get encounter => data?.encounter;
  @override
  EncounterResult? get result => encounter?.result;
  @override
  FinalSnapshot? get finalSnapshot => data?.finalSnapshot;
  @override
  bool get isHost => data?.hostId == 'self';
  @override
  String? get roomQr => data == null ? null : 'tsunagun:room:${data!.code}';
  @override
  String? get pairQr =>
      data == null ? null : 'tsunagun:pair:${data!.code}:${data!.pairCode}';
  @override
  int get serverNow => 1000;
  @override
  Duration get remaining => const Duration(minutes: 3);
  @override
  Future<bool> createRoom({
    required bool presentation,
    required Duration duration,
  }) async {
    this.presentation = presentation;
    emit(roomJson(profile: false));
    return true;
  }

  @override
  Future<bool> saveProfile(Profile profile) async {
    savedProfile = profile;
    if (!saveSucceeds) {
      failure = '保存できませんでした';
      notifyListeners();
      return false;
    }
    final value = {...?raw};
    value['participants'] = [
      for (final dynamic participant in value['participants'] as List)
        if (participant['id'] == value['selfId'])
          {
            ...Map<String, Object?>.from(participant as Map),
            'profile': profileToJson(profile),
            'ready': true,
          }
        else
          participant,
    ];
    emit(value);
    return true;
  }

  @override
  Future<bool> joinRoom(String codeOrQr) async {
    joinedCode = codeOrQr;
    emit(roomJson(profile: false));
    return true;
  }

  @override
  Future<bool> pair(String codeOrQr) async {
    pairedCode = codeOrQr;
    return true;
  }

  @override
  Future<bool> pairBot(String id) async {
    pairedBot = id;
    return true;
  }

  @override
  Future<bool> startRoom() async {
    starts++;
    emit({...?raw, 'status': 'active'});
    return true;
  }

  @override
  Future<bool> returnHome() async {
    emit(roomJson(status: 'active'));
    return true;
  }

  @override
  void setForeground(bool value) => foreground.add(value);
}

class Sounds implements ResultSoundPlayer {
  int plays = 0, stops = 0, disposals = 0;
  @override
  Future<void> prepare() async {}
  @override
  Future<void> playShobone() async {
    plays++;
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> dispose() async {
    disposals++;
  }
}

Widget app(
  ScreenController controller, {
  Sounds? sounds,
  double scale = 1,
  double keyboardInset = 0,
}) => MaterialApp(
  theme: tsunagunTheme(),
  home: MediaQuery(
    data: MediaQueryData(
      textScaler: TextScaler.linear(scale),
      viewInsets: EdgeInsets.only(bottom: keyboardInset),
    ),
    child: CharacterPlaybackScope(
      enabled: false,
      child: OnlinePage(controller: controller, resultSoundPlayer: sounds),
    ),
  ),
);

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
}

void main() {
  testWidgets('412×900の通常文字では各場面の主要操作まで1画面に収まる', (tester) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    void expectFits(String scene, Key control) {
      final scroll = tester.widget<SingleChildScrollView>(
        find.byKey(const Key('online-page-scroll')),
      );
      expect(scroll.controller!.position.maxScrollExtent, 0, reason: scene);
      final bounds = tester.getRect(find.byKey(control));
      expect(bounds.top, greaterThanOrEqualTo(0), reason: scene);
      expect(bounds.bottom, lessThanOrEqualTo(900), reason: scene);
      expect(find.byKey(control).hitTestable(), findsOneWidget, reason: scene);
      expect(tester.takeException(), isNull, reason: scene);
    }

    for (final scene in [
      'entry',
      'profile',
      'lobby',
      'home',
      'home-alone',
      'pairing',
      'loss',
      'win',
      'reborn',
      'finale',
      'finale-finished',
      'results',
    ]) {
      Map<String, dynamic>? state = switch (scene) {
        'entry' => null,
        'profile' => roomJson(profile: false),
        'lobby' => presentationRoom(realCount: 2),
        'home-alone' => presentationRoom(status: 'active'),
        _ => presentationRoom(status: 'active', realCount: 2),
      };
      if (['loss', 'win', 'reborn'].contains(scene)) {
        final encounter = finished(
          outcome: scene == 'reborn' ? 'coopSuccess' : scene,
        );
        final result = encounter['result'] as Map<String, dynamic>;
        if (scene != 'loss') {
          final follower = {...result['newFollower'] as Map, 'kind': 'normal'};
          result['delta'] = scene == 'reborn' ? 2 : 3;
          result['newFollower'] = scene == 'reborn' ? null : follower;
          result['promoted'] = scene == 'reborn' ? follower : null;
        }
        state!['encounter'] = encounter;
      }
      if (scene.startsWith('finale') || scene == 'results') {
        state!['status'] = 'finale';
        if (scene == 'finale-finished') state['finaleStartsAt'] = -13000;
        state['finalSnapshot'] = {
          'redPower': 7,
          'bluePower': 5,
          'rankings': [
            for (var rank = 1; rank <= 4; rank++)
              {
                'participant': person(
                  rank == 4 ? 'self' : 'demo-$rank',
                  rank == 4 ? '自分' : 'デモ$rank',
                ),
                'normalCount': rank < 3 ? 1 : 0,
                'boneCount': rank.isEven ? 1 : 0,
                'power': 5 - rank,
                'rank': rank,
              },
          ],
          'mvpIds': ['demo-1'],
        };
      }
      final controller = ScreenController(state);
      await tester.pumpWidget(app(controller));
      await tester.pumpAndSettle();
      if (scene == 'pairing') {
        await tester.tap(find.byKey(const Key('online-connect')));
        await tester.pumpAndSettle();
      }
      if (['loss', 'win', 'reborn'].contains(scene) &&
          find.byType(OnlineGame).evaluate().isNotEmpty) {
        tester
            .widget<OnlineGame>(find.byType(OnlineGame))
            .onPresentationComplete();
        await tester.pumpAndSettle();
      }
      if (scene == 'results') {
        tester
            .widget<TugOfWarFinale>(find.byType(TugOfWarFinale))
            .onShowResults();
        await tester.pumpAndSettle();
      }
      final control = switch (scene) {
        'entry' => const Key('join-online-room'),
        'profile' => const Key('save-online-profile'),
        'lobby' => const Key('start-online-room'),
        'home-alone' => const Key('invite-second-player'),
        'home' => const Key('online-team-members'),
        'pairing' => const Key('choose-demo-peer'),
        'finale' => const Key('start-tug-button'),
        'finale-finished' => const Key('show-results'),
        'results' => const Key('view-final-followers'),
        _ => const Key('return-online-home'),
      };
      expectFits(scene, control);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    }
  });
  testWidgets(
    'visible web blur preserves connection and sound; hidden always suspends',
    (tester) async {
      final controller = ScreenController(roomJson(status: 'active'));
      final sounds = Sounds();
      addTearDown(controller.dispose);
      await tester.pumpWidget(app(controller, sounds: sounds));
      final stops = sounds.stops;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(controller.foreground.last, kIsWeb);
      expect(sounds.stops, kIsWeb ? stops : greaterThan(stops));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(controller.foreground.last, isTrue);
      for (final state in [
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.detached,
      ]) {
        final before = sounds.stops;
        tester.binding.handleAppLifecycleStateChanged(state);
        await tester.pump();
        expect(controller.foreground.last, isFalse);
        expect(sounds.stops, greaterThan(before));
      }
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(controller.foreground.last, isTrue);
    },
  );

  testWidgets('長いプロフィール・文字2倍・キーボード表示ではスクロールして保存できる', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = ScreenController(roomJson(profile: false));
    addTearDown(controller.dispose);
    await tester.pumpWidget(app(controller, scale: 2, keyboardInset: 280));
    await tester.enterText(find.byKey(const Key('online-nickname')), 'つな' * 10);
    await tester.enterText(find.byKey(const Key('online-hobby')), '海' * 60);
    await tester.enterText(find.byKey(const Key('online-comment')), '魚' * 80);
    await tester.pumpAndSettle();
    final scroll = tester.widget<SingleChildScrollView>(
      find.byKey(const Key('online-page-scroll')),
    );
    expect(scroll.controller!.position.maxScrollExtent, greaterThan(0));
    final save = find.byKey(const Key('save-online-profile'));
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    expect(save.hitTestable(), findsOneWidget);
    expect(tester.getRect(save).bottom, lessThanOrEqualTo(520));
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(controller.savedProfile!.nickname, 'つな' * 10);
    expect(controller.savedProfile!.hobby, '海' * 60);
    expect(controller.savedProfile!.comment, '魚' * 80);
    expect(tester.takeException(), isNull);
  });

  testWidgets('通常入口は仮想操作を見せず、発表ルームを選んで空のプロフィールを作れる', (tester) async {
    final controller = ScreenController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(app(controller));
    expect(find.textContaining('DEMO'), findsNothing);
    expect(find.textContaining('TSUNA'), findsNothing);
    expect(find.text('QRでルームに参加'), findsNothing);
    expect(find.text('ルームに参加する'), findsOneWidget);
    await tapVisible(tester, find.byType(SwitchListTile));
    await tapVisible(tester, find.byKey(const Key('create-online-room')));
    expect(controller.presentation, isTrue);
    expect(find.text('あなたのラベル'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('online-nickname')))
          .controller!
          .text,
      '',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('プロフィールは通信通知や保存失敗で消えず、缶へ即時反映される', (tester) async {
    final controller = ScreenController(roomJson(profile: false))
      ..saveSucceeds = false;
    addTearDown(controller.dispose);
    await tester.pumpWidget(app(controller));
    await tester.enterText(find.byKey(const Key('online-nickname')), 'つな');
    await tester.enterText(find.byKey(const Key('online-hobby')), '映画');
    controller.emit(roomJson(profile: false));
    await tester.pump();
    expect(
      tester.widget<CanStage>(find.byType(CanStage)).profile.nickname,
      'つな',
    );
    await tapVisible(tester, find.byKey(const Key('save-online-profile')));
    expect(controller.savedProfile!.nickname, 'つな');
    expect(find.text('保存できませんでした'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('online-hobby')))
          .controller!
          .text,
      '映画',
    );
    controller.saveSucceeds = true;
    await tapVisible(tester, find.byKey(const Key('save-online-profile')));
    expect(find.text('まもなく、交流の時間。'), findsOneWidget);
    expect(find.byKey(const Key('room-share-code')), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('参加者は主催者の開始を待ち、通信断では開始できない', (tester) async {
    final controller = ScreenController(roomJson(host: false));
    addTearDown(controller.dispose);
    await tester.pumpWidget(app(controller));
    expect(find.byKey(const Key('start-online-room')), findsNothing);
    expect(find.text('主催者の開始を待っています。'), findsOneWidget);
    controller.available = false;
    controller.emit(roomJson());
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('start-online-room')))
          .onPressed,
      isNull,
    );
    expect(find.textContaining('再接続しています'), findsOneWidget);
    controller.available = true;
    controller.emit(roomJson());
    await tester.pump();
    await tapVisible(tester, find.byKey(const Key('start-online-room')));
    expect(controller.starts, 1);
    expect(find.text('ツナがる'), findsOneWidget);
  });

  testWidgets('5桁コード入力で実ルームへ参加し、8桁相手コードでペアを要求する', (tester) async {
    final controller = ScreenController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(app(controller));
    await tapVisible(tester, find.byKey(const Key('join-online-room')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('qr-manual-code')), '01234');
    await tester.tap(find.byKey(const Key('submit-qr-code')));
    await tester.pumpAndSettle();
    expect(controller.joinedCode, '01234');
    controller.emit(roomJson(status: 'active'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const Key('online-connect')));
    await tapVisible(tester, find.text('相手のコードを入力する'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('qr-manual-code')), '1234abcd');
    await tester.tap(find.byKey(const Key('submit-qr-code')));
    await tester.pumpAndSettle();
    expect(controller.pairedCode, '1234ABCD');
    expect(find.text('仮想の相手を選ぶ'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('サーバー確定後の結果音は表示時一度だけ、更新・復帰で再生せず帰還で停止', (tester) async {
    final controller = ScreenController(
      roomJson(status: 'active', encounter: finished()),
    );
    final sounds = Sounds();
    addTearDown(controller.dispose);
    await tester.pumpWidget(app(controller, sounds: sounds));
    expect(sounds.plays, 0);
    tester.widget<OnlineGame>(find.byType(OnlineGame)).onPresentationComplete();
    await tester.pump();
    await tester.pump();
    expect(find.text('骨の子分も、大切な仲間。'), findsOneWidget);
    expect(sounds.plays, 1);
    controller.emit(roomJson(status: 'active', encounter: finished()));
    await tester.pump();
    expect(sounds.plays, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(sounds.plays, 1);
    expect(controller.foreground, [kIsWeb, true]);
    final stops = sounds.stops;
    await tapVisible(tester, find.byKey(const Key('return-online-home')));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(sounds.stops, greaterThan(stops));
    expect(find.text('ツナがる'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(sounds.disposals, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('360幅・文字2倍でもプロフィールの保存と入力に到達できる', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = ScreenController(roomJson(profile: false));
    addTearDown(controller.dispose);
    await tester.pumpWidget(app(controller, scale: 2));
    for (final name in ['nickname', 'hobby', 'comment']) {
      await tester.ensureVisible(find.byKey(Key('online-$name')));
      expect(find.byKey(Key('online-$name')).hitTestable(), findsOneWidget);
    }
    await tester.ensureVisible(find.byKey(const Key('save-online-profile')));
    expect(
      find.byKey(const Key('save-online-profile')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('復活の誘導は通常ルールと発表用の残る交流に合わせる', (tester) async {
    for (final item in [
      (presentation: false, outcome: 'loss', copy: '同じチームと協力して、元気にしよう！'),
      (presentation: false, outcome: 'coopFailure', copy: '同じチームと協力して、元気にしよう！'),
      (presentation: true, outcome: 'loss', copy: '次は協力して、元気にしよう！'),
      (presentation: true, outcome: 'coopFailure', copy: null),
    ]) {
      final state = roomJson(
        status: 'active',
        encounter: finished(outcome: item.outcome),
      );
      state['mode'] = item.presentation ? 'presentation' : 'standard';
      final controller = ScreenController(state);
      await tester.pumpWidget(app(controller));
      tester
          .widget<OnlineGame>(find.byType(OnlineGame))
          .onPresentationComplete();
      await tester.pump();
      expect(find.text('骨の子分も、大切な仲間。'), findsOneWidget);
      for (final copy in ['同じチームと協力して、元気にしよう！', '次は協力して、元気にしよう！']) {
        expect(
          find.text(copy),
          copy == item.copy ? findsOneWidget : findsNothing,
        );
      }
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('待機画面は入室コードだけを共有し、コピー内容にもQRを含めない', (tester) async {
    final controller = ScreenController(roomJson());
    addTearDown(controller.dispose);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(app(controller));
    expect(find.byType(QrImageView), findsNothing);
    expect(
      tester
          .widget<SelectableText>(find.byKey(const Key('room-share-code')))
          .data,
      'ABCD EF01 2345',
    );
    await tapVisible(tester, find.byKey(const Key('copy-room-code')));
    expect(copied, 'ABCDEF012345');
    expect(find.text('ルームコードをコピーしました'), findsOneWidget);
    controller.emit(roomJson(status: 'active'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const Key('online-connect')));
    expect(find.byType(QrImageView), findsOneWidget);
    expect(
      tester.widget<SharedQrPanel>(find.byType(SharedQrPanel)).data,
      'tsunagun:pair:ABCDEF012345:1234ABCD',
    );
    expect(find.text('相手のQRを読み取る'), findsOneWidget);
  });

  testWidgets('5桁ルームコードを分割せず表示・コピーし、相手QRでも先頭0を保つ', (tester) async {
    final state = {...roomJson(), 'code': '01234'};
    final controller = ScreenController(state);
    addTearDown(controller.dispose);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(app(controller));
    expect(find.byType(QrImageView), findsNothing);
    expect(
      tester
          .widget<SelectableText>(find.byKey(const Key('room-share-code')))
          .data,
      '01234',
    );
    await tapVisible(tester, find.byKey(const Key('copy-room-code')));
    expect(copied, '01234');
    controller.emit({...state, 'status': 'active'});
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const Key('online-connect')));
    expect(
      tester.widget<SharedQrPanel>(find.byType(SharedQrPanel)).data,
      'tsunagun:pair:01234:1234ABCD',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('発表用は準備済みの主催者1人で開始し、コード共有とQR導線を維持する', (tester) async {
    final controller = ScreenController(presentationRoom());
    addTearDown(controller.dispose);
    await tester.pumpWidget(app(controller));
    expect(find.text('参加者 1人'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('start-online-room')))
          .onPressed,
      isNotNull,
    );
    await tapVisible(tester, find.byKey(const Key('start-online-room')));
    expect(controller.starts, 1);
    expect(find.byKey(const Key('waiting-second-player')), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('invite-second-player')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('room-share-code')), findsOneWidget);
    expect(find.byKey(const Key('copy-room-code')), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
    expect(controller.participants, hasLength(1));
    expect(controller.followers, isEmpty);
    await tapVisible(tester, find.byKey(const Key('close-online-details')));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const Key('online-connect')));
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('相手のQRを読み取る'), findsOneWidget);
    expect(
      tester.widget<SharedQrPanel>(find.byType(SharedQrPanel)).data,
      'tsunagun:pair:ABCDEF012345:1234ABCD',
    );
  });

  testWidgets('通常ルームは1人で開始できず、発表用も実参加者全員の準備が必要', (tester) async {
    final controller = ScreenController({
      ...presentationRoom(),
      'mode': 'standard',
    });
    addTearDown(controller.dispose);
    await tester.pumpWidget(app(controller));
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('start-online-room')))
          .onPressed,
      isNull,
    );
    expect(find.text('2人以上のラベルがそろうと、はじめられます。'), findsOneWidget);
    expect(find.byKey(const Key('lobby-demo-members')), findsNothing);
    controller.emit(presentationRoom(realCount: 2, peerReady: false));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('start-online-room')))
          .onPressed,
      isNull,
    );
    expect(find.text('参加者のラベルがそろうまで、お待ちください。'), findsOneWidget);
    controller.emit(presentationRoom(hostReady: false));
    await tester.pump();
    expect(find.byKey(const Key('start-online-room')), findsNothing);
    expect(find.text('あなたのラベル'), findsOneWidget);
  });

  testWidgets('開始後に入った実参加者はプロフィール登録後ホームへ進み、更新中も入力を保つ', (tester) async {
    final state = presentationRoom(
      status: 'active',
      realCount: 2,
      peerReady: false,
    )..['selfId'] = 'peer';
    final controller = ScreenController(state);
    addTearDown(controller.dispose);
    await tester.pumpWidget(app(controller));
    expect(find.text('あなたのラベル'), findsOneWidget);
    expect(find.byKey(const Key('online-connect')), findsNothing);
    await tester.enterText(find.byKey(const Key('online-nickname')), '後から参加');
    await tester.enterText(find.byKey(const Key('online-hobby')), '音楽');
    controller.emit({...state, 'revision': 2});
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('online-nickname')))
          .controller!
          .text,
      '後から参加',
    );
    await tapVisible(tester, find.byKey(const Key('save-online-profile')));
    expect(controller.savedProfile!.nickname, '後から参加');
    expect(find.byKey(const Key('online-connect')), findsOneWidget);
    expect(find.text('まもなく、交流の時間。'), findsNothing);
    expect(controller.room!.status, 'active');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app(controller));
    expect(find.byKey(const Key('online-connect')), findsOneWidget);
    expect(find.text('あなたのラベル'), findsNothing);
  });

  testWidgets('開始後の未登録プロフィール中に期限が来ても最終画面へ移る', (tester) async {
    final state = presentationRoom(
      status: 'active',
      realCount: 2,
      peerReady: false,
    )..['selfId'] = 'peer';
    final controller = ScreenController(state);
    addTearDown(controller.dispose);
    await tester.pumpWidget(app(controller));
    expect(find.text('あなたのラベル'), findsOneWidget);
    controller.emit({
      ...state,
      'status': 'finale',
      'finalSnapshot': {
        'redPower': 6,
        'bluePower': 6,
        'rankings': [],
        'mvpIds': [],
      },
    });
    await tester.pump();
    expect(find.text('最後の大綱引き'), findsOneWidget);
    expect(find.byKey(const Key('save-online-profile')), findsNothing);
  });

  testWidgets('応援メンバーは実人数・所持子分と別に、チーム色と現在得点を表示する', (tester) async {
    final controller = ScreenController(presentationRoom());
    addTearDown(controller.dispose);
    await tester.pumpWidget(app(controller));
    await tapVisible(tester, find.byKey(const Key('lobby-demo-members')));
    await tester.pumpAndSettle();
    expect(find.text('4pt'), findsNWidgets(2));
    expect(find.text('2pt'), findsNWidgets(2));
    expect(find.text('0pt'), findsOneWidget);
    expect(find.text('参加者 1人'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('red-demo-1（デモ）')).style!.color,
      TsunagunColors.red,
    );
    expect(
      tester.widget<Text>(find.text('blue-demo-1（デモ）')).style!.color,
      TsunagunColors.blue,
    );
    await tapVisible(tester, find.byKey(const Key('close-online-details')));
    await tester.pumpAndSettle();
    controller.emit(presentationRoom(status: 'active', realCount: 2));
    await tester.pumpAndSettle();
    expect(find.text('子分 0 匹'), findsOneWidget);
    expect(find.text('骨 0 匹'), findsOneWidget);
    expect(find.text('ちから 0'), findsOneWidget);
    expect(find.byKey(const Key('room-share-code')), findsNothing);
    await tapVisible(tester, find.byKey(const Key('online-team-members')));
    await tester.pumpAndSettle();
    expect(find.text('参加者 2人・応援 4人（デモ）'), findsOneWidget);
    expect(find.byKey(const ValueKey('team-member-self')), findsOneWidget);
    expect(find.byKey(const ValueKey('team-member-peer')), findsOneWidget);
    expect(find.text('4pt'), findsNWidgets(2));
    expect(
      find.byKey(const ValueKey('team-member-second-player-slot')),
      findsNothing,
    );
  });

  testWidgets('実相手がプロフィール入力中でも自分のQRとデモ相手選択を表示できる', (tester) async {
    final state = presentationRoom(
      status: 'active',
      realCount: 2,
      peerReady: false,
    );
    final bots = state['demoParticipants'] as List;
    bots[0] = supporter('red-demo-1', 'red', 7, busy: true);
    bots[1] = supporter('red-demo-2', 'red', 5, nextKind: null);
    bots[2] = supporter('blue-demo-1', 'blue', 5, nextKind: 'coop');
    final controller = ScreenController(state);
    addTearDown(controller.dispose);
    await tester.pumpWidget(app(controller));
    expect(find.byKey(const Key('waiting-peer-profile')), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('online-connect')));
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('相手のQRを読み取る'), findsOneWidget);
    expect(find.byType(CanStage), findsNothing);
    await tapVisible(tester, find.byKey(const Key('choose-demo-peer')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('pair-demo-red-demo-1')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('pair-demo-red-demo-2')))
          .onPressed,
      isNull,
    );
    expect(find.text('交流済み'), findsOneWidget);
    expect(find.text('次は協力'), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('pair-demo-blue-demo-1')));
    expect(controller.pairedBot, 'blue-demo-1');
    expect(controller.pairedCode, isNull);
    expect(find.byKey(const Key('pair-demo-second-player-slot')), findsNothing);
  });
}
