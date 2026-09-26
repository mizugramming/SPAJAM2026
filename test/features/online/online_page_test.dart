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

class ScreenController extends OnlineController {
  ScreenController([Map<String, dynamic>? initial]) : super(autoTick: false) {
    if (initial != null) data = OnlineRoom.fromJson(initial);
  }
  OnlineRoom? data;
  bool available = true;
  bool saveSucceeds = true;
  bool? presentation;
  Profile? savedProfile;
  String? joinedCode, pairedCode;
  String? failure;
  final foreground = <bool>[];
  int starts = 0;
  void emit(Map<String, dynamic> value) {
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
  Participant? get self => data?.participants.first;
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
    final value = roomJson();
    value['participants'] = [
      person('self', profile.nickname, hobby: profile.hobby),
      person('peer', '相手'),
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
  Future<bool> startRoom() async {
    starts++;
    emit(roomJson(status: 'active'));
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

Widget app(ScreenController controller, {Sounds? sounds, double scale = 1}) =>
    MaterialApp(
      theme: tsunagunTheme(),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
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

  testWidgets('コード入力で実ルームへ参加し、相手コードでペアを要求する', (tester) async {
    final controller = ScreenController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(app(controller));
    await tapVisible(tester, find.byKey(const Key('join-online-room')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('qr-manual-code')),
      'abcd ef01 2345',
    );
    await tester.tap(find.byKey(const Key('submit-qr-code')));
    await tester.pumpAndSettle();
    expect(controller.joinedCode, 'ABCDEF012345');
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
    expect(controller.foreground, [false, true]);
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
}
