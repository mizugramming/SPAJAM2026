import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spajam2026/domain/models.dart';
import 'package:spajam2026/features/duel/duel_game.dart';
import 'package:spajam2026/features/duel/race_course.dart';
import 'package:spajam2026/features/duel/race_field.dart';
import 'package:spajam2026/features/duel/sea_background.dart';
import 'package:spajam2026/features/duel/win_dance.dart';

const selfProfile = Profile(nickname: 'わたし', hobby: '', comment: '');
const peerProfile = Profile(nickname: 'あいて', hobby: '', comment: '');
const self = Participant(id: 'self', profile: selfProfile, team: Team.red);
const peer = Participant(id: 'peer', profile: peerProfile, team: Team.blue);

/// 親（GameScene相当）が毎秒再描画する状況を再現する。
class _RebuildingHarness extends StatefulWidget {
  const _RebuildingHarness({super.key, required this.builder});
  final WidgetBuilder builder;

  @override
  State<_RebuildingHarness> createState() => _RebuildingHarnessState();
}

class _RebuildingHarnessState extends State<_RebuildingHarness> {
  int generation = 0;
  void rebuild() => setState(() => generation++);

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

Future<void> pumpTicks(
  WidgetTester tester,
  Duration total, {
  Duration step = const Duration(milliseconds: 100),
}) async {
  for (var elapsed = Duration.zero; elapsed < total; elapsed += step) {
    await tester.pump(step);
  }
}

/// 最初のタップでスタートし、時計の最初のフレームまで進める。
Future<void> startRace(WidgetTester tester) async {
  await tester.tap(find.byType(DuelGame));
  await tester.pump();
}

Finder assetImage(String asset) => find.byWidgetPredicate((widget) {
  // 綱の継ぎ足し（rope-segment）は除き、魚の本体だけを探す。
  if (widget is! Image || widget.key == const Key('rope-segment')) {
    return false;
  }
  final image = widget.image;
  return image is AssetImage && image.assetName == asset;
});

const redFish = 'assets/characters/hikareruaka.png';
const blueFish = 'assets/characters/hikareruao.png';

/// 背景の2枚目（tunaumi2）の重なり具合。
double secondBackgroundOpacity(WidgetTester tester) =>
    tester.widget<Image>(assetImage(SeaBackground.assetB)).opacity!.value;

/// 吊られた魚の口先（着地の判定位置）のy。画像1536pxのうち1496pxの位置。
double mouthY(WidgetTester tester, String asset) {
  final rect = tester.getRect(assetImage(asset));
  return rect.top + rect.height * 1496 / 1536;
}

double guideOpacity(WidgetTester tester) =>
    tester.widget<AnimatedOpacity>(find.byKey(const Key('duel-guide'))).opacity;

double landingY(WidgetTester tester) =>
    tester.getRect(find.byKey(const Key('landing-line'))).center.dy;

Widget duel({
  required RaceCourse course,
  required RaceDecision peerDecision,
  ValueChanged<DuelGameResult>? onCompleted,
  ValueChanged<DuelGameResult>? onResolved,
}) => MaterialApp(
  home: DuelGame(
    self: self,
    peer: peer,
    onCompleted: onCompleted ?? (_) {},
    onResolved: onResolved,
    debugCourse: course,
    debugPeerDecision: peerDecision,
  ),
);

/// 綱の上端のy。継ぎ足した綱を含め、その魚の画像のいちばん上。
double ropeTop(WidgetTester tester, String asset) {
  final images = find.byWidgetPredicate((widget) {
    if (widget is! Image) return false;
    final image = widget.image;
    return image is AssetImage && image.assetName == asset;
  });
  return images
      .evaluate()
      .map((element) => tester.getRect(find.byWidget(element.widget)).top)
      .reduce((a, b) => a < b ? a : b);
}

void main() {
  testWidgets('相手が缶を越えて落ちれば、自分の位置に関わらず勝つ', (tester) async {
    final results = <DuelGameResult>[];
    await tester.pumpWidget(
      MaterialApp(
        home: DuelGame(
          self: self,
          peer: peer,
          onCompleted: results.add,
          debugCourse: const RaceCourse(fallDuration: Duration(seconds: 1)),
          debugPeerDecision: const RaceDecision.fell(),
        ),
      ),
    );

    await startRace(tester);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.tap(find.byType(DuelGame));
    await tester.pump();
    expect(find.textContaining('ぎりぎり度'), findsOneWidget);

    // 相手が落ちて決着（約1秒）してから、勝ったときは % の結果を1秒だけ見せる。
    await pumpTicks(tester, const Duration(milliseconds: 1500));
    expect(find.text('WIN'), findsOneWidget);
    expect(find.byKey(const Key('win-dance')), findsNothing);
    expect(results, isEmpty);
    // そのあと、煙の中から親方が現れて踊る（7秒）。その間も通知しない。
    // 文字（親方になった！）と、前に出てくる子分は出さない。
    await pumpTicks(tester, const Duration(milliseconds: 500));
    expect(find.byKey(const Key('win-dance')), findsOneWidget);
    expect(find.byKey(const Key('oyakata-dance')), findsOneWidget);
    expect(find.byKey(const Key('dance-smoke')), findsOneWidget);
    final danceRect = tester.getRect(find.byKey(const Key('oyakata-dance')));
    final gameRect = tester.getRect(find.byType(DuelGame));
    expect(danceRect.left, closeTo(gameRect.left, 1));
    expect(danceRect.right, closeTo(gameRect.right, 1));
    expect(find.textContaining('親方'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('win-dance')),
        matching: find.byType(Image),
      ),
      findsOneWidget,
    );
    expect(results, isEmpty);
    // 踊り始めて約6.7秒ではまだ通知せず、7秒を過ぎたら通知する。
    await pumpTicks(tester, const Duration(milliseconds: 6500));
    expect(results, isEmpty);
    await pumpTicks(tester, const Duration(seconds: 1));
    expect(results, [DuelGameResult.win]);

    // 決着後にさらに時間が進んでも、通知は一度だけ。
    await pumpTicks(tester, const Duration(seconds: 1));
    expect(results, [DuelGameResult.win]);
  });

  testWidgets('勝敗は決着時に確定通知し、完了通知は結果1秒とダンス7秒の後に一度だけ行う', (tester) async {
    final resolved = <DuelGameResult>[];
    final completed = <DuelGameResult>[];
    await tester.pumpWidget(
      duel(
        course: const RaceCourse(fallDuration: Duration(seconds: 1)),
        peerDecision: const RaceDecision.fell(),
        onResolved: resolved.add,
        onCompleted: completed.add,
      ),
    );

    await startRace(tester);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byType(DuelGame));
    await tester.pump(const Duration(milliseconds: 490));
    // 自分だけ止まった時点では、まだ相手の落下が確定していない。
    expect(resolved, isEmpty);
    expect(completed, isEmpty);

    await tester.pump(const Duration(milliseconds: 10));
    expect(resolved, [DuelGameResult.win]);
    expect(completed, isEmpty);
    expect(find.byKey(const Key('win-dance')), findsNothing);

    await tester.pump(const Duration(milliseconds: 999));
    expect(find.byKey(const Key('win-dance')), findsNothing);
    expect(completed, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byKey(const Key('win-dance')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 6999));
    expect(completed, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(completed, [DuelGameResult.win]);

    await tester.pump(const Duration(seconds: 2));
    expect(resolved, [DuelGameResult.win]);
    expect(completed, [DuelGameResult.win]);
  });

  testWidgets('相手が停止済みなら、自分の停止タップで次のフレームを待たずに勝敗を確定通知する', (tester) async {
    final resolved = <DuelGameResult>[];
    final completed = <DuelGameResult>[];
    await tester.pumpWidget(
      duel(
        course: const RaceCourse(fallDuration: Duration(seconds: 1)),
        peerDecision: const RaceDecision.stopped(0.5),
        onResolved: resolved.add,
        onCompleted: completed.add,
      ),
    );

    await startRace(tester);
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.byKey(const Key('result-peer')), findsOneWidget);
    expect(resolved, isEmpty);

    await tester.tap(find.byType(DuelGame));
    // pumpを挟まない。期限直前のタップでも、次のTickerより先に確定する。
    expect(resolved, [DuelGameResult.win]);
    expect(completed, isEmpty);
    await tester.pump();
    expect(find.text('81%'), findsOneWidget);
    expect(resolved, [DuelGameResult.win]);
  });

  testWidgets('確定後の親の再描画・ダンス省略・自然終了時刻が重なっても各通知は一度だけ', (tester) async {
    final harnessKey = GlobalKey<_RebuildingHarnessState>();
    final resolved = <DuelGameResult>[];
    final completed = <DuelGameResult>[];
    await tester.pumpWidget(
      MaterialApp(
        home: _RebuildingHarness(
          key: harnessKey,
          builder: (context) => DuelGame(
            self: self,
            peer: peer,
            onResolved: resolved.add,
            onCompleted: completed.add,
            debugCourse: const RaceCourse(fallDuration: Duration(seconds: 1)),
            debugPeerDecision: const RaceDecision.fell(),
          ),
        ),
      ),
    );

    await startRace(tester);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byType(DuelGame));
    await tester.pump(const Duration(milliseconds: 500));
    expect(resolved, [DuelGameResult.win]);
    harnessKey.currentState!.rebuild();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('win-dance')), findsOneWidget);

    // ダンス開始直後は省略できず、再描画しても確定通知を繰り返さない。
    await tester.tap(find.byType(DuelGame));
    expect(completed, isEmpty);
    harnessKey.currentState!.rebuild();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byType(DuelGame));
    expect(completed, [DuelGameResult.win]);

    // 連打、再描画、自然終了の予定時刻まで進めても二重決済につながらない。
    await tester.tap(find.byType(DuelGame));
    harnessKey.currentState!.rebuild();
    await tester.pump();
    await tester.pump(const Duration(seconds: 8));
    await tester.tap(find.byType(DuelGame));
    expect(resolved, [DuelGameResult.win]);
    expect(completed, [DuelGameResult.win]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('タップしないまま落ちると、相手が止まっていれば負ける', (tester) async {
    final results = <DuelGameResult>[];
    await tester.pumpWidget(
      MaterialApp(
        home: DuelGame(
          self: self,
          peer: peer,
          onCompleted: results.add,
          debugCourse: const RaceCourse(fallDuration: Duration(seconds: 1)),
          debugPeerDecision: const RaceDecision.stopped(0.5),
        ),
      ),
    );

    await startRace(tester);
    await pumpTicks(tester, const Duration(seconds: 4));
    expect(find.text('ボチャン！'), findsOneWidget);
    expect(results, [DuelGameResult.loss]);
  });

  testWidgets('親が毎秒再描画しても、経過時間と決着済みの結果を保持する', (tester) async {
    final harnessKey = GlobalKey<_RebuildingHarnessState>();
    final results = <DuelGameResult>[];
    await tester.pumpWidget(
      MaterialApp(
        home: _RebuildingHarness(
          key: harnessKey,
          builder: (context) => DuelGame(
            self: self,
            peer: peer,
            onCompleted: results.add,
            debugCourse: const RaceCourse(fallDuration: Duration(seconds: 2)),
            debugPeerDecision: const RaceDecision.stopped(0.5),
          ),
        ),
      ),
    );

    await startRace(tester);
    // 親を毎秒相当で再描画しながら進める。
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 300));
      harnessKey.currentState!.rebuild();
      await tester.pump();
    }
    // 1.8秒ほど経過しているはずで、自分はまだ止めていない（相手は0.5で止まっている）。
    expect(find.byKey(const Key('result-self')), findsNothing);
    expect(results, isEmpty);

    await tester.tap(find.byType(DuelGame));
    await tester.pump();
    // 1.8秒経過時点の深さ（0.81）で止まっているはず。再描画を挟んでも
    // 直前のタップが上書きされない、かつ経過時間がリセットされていないことを確認する。
    expect(find.text('81%'), findsOneWidget);
    harnessKey.currentState!.rebuild();
    await tester.pump();
    expect(find.text('81%'), findsOneWidget);

    await pumpTicks(tester, const Duration(seconds: 11));
    expect(results, [DuelGameResult.win]);
  });

  testWidgets('期限切れなどで結果が出る前に破棄されても、例外なく終わる', (tester) async {
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: DuelGame(
          self: self,
          peer: peer,
          onCompleted: (_) => completed = true,
          debugCourse: const RaceCourse(fallDuration: Duration(seconds: 5)),
          debugPeerDecision: const RaceDecision.stopped(0.9),
        ),
      ),
    );
    await startRace(tester);
    await tester.pump(const Duration(milliseconds: 200));

    // 親が場面を切り替えて、ゲームWidgetごと消す（期限切れの再現）。
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump(const Duration(seconds: 1));

    expect(completed, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('スタートするまで時計も背景も止まり、最初のタップでは止めずに開始だけする', (tester) async {
    final results = <DuelGameResult>[];
    await tester.pumpWidget(
      duel(
        course: const RaceCourse(fallDuration: Duration(seconds: 1)),
        peerDecision: const RaceDecision.stopped(0.5),
        onCompleted: results.add,
      ),
    );

    // 更新を要求し続けないので、親の毎秒再描画やpumpAndSettleを妨げない。
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 30));
    expect(find.text('タップでスタート！'), findsOneWidget);
    expect(secondBackgroundOpacity(tester), 0);
    expect(results, isEmpty);

    expect(guideOpacity(tester), 1);

    // 最初のタップで説明はフェードアウトする。
    await startRace(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect(guideOpacity(tester), 0);
    expect(find.textContaining('ぎりぎり度'), findsNothing);
    expect(results, isEmpty);
  });

  testWidgets('スタート後は2枚の背景が交互にクロスフェードして往復する', (tester) async {
    await tester.pumpWidget(
      duel(
        course: const RaceCourse(fallDuration: Duration(seconds: 30)),
        peerDecision: const RaceDecision.stopped(0.5),
      ),
    );
    await startRace(tester);
    expect(secondBackgroundOpacity(tester), closeTo(0, 1e-9));

    await tester.pump(SeaBackground.cycle ~/ 4);
    expect(secondBackgroundOpacity(tester), closeTo(0.5, 1e-6));
    await tester.pump(SeaBackground.cycle ~/ 4);
    expect(secondBackgroundOpacity(tester), closeTo(1, 1e-6));
    await tester.pump(SeaBackground.cycle ~/ 2);
    expect(secondBackgroundOpacity(tester), closeTo(0, 1e-6));
  });

  testWidgets('赤と青の魚が同じ時計で降り、止めた魚は線の手前で止まる', (tester) async {
    final results = <DuelGameResult>[];
    await tester.pumpWidget(
      duel(
        course: const RaceCourse(fallDuration: Duration(seconds: 1)),
        peerDecision: const RaceDecision.stopped(0.9),
        onCompleted: results.add,
      ),
    );
    // 自分は赤チーム、相手は青チームの魚。スタート前は同じ高さで並ぶ。
    final lineY = landingY(tester);
    final selfStart = mouthY(tester, redFish);
    expect(mouthY(tester, blueFish), closeTo(selfStart, 1e-6));
    expect(selfStart, lessThan(lineY));

    await startRace(tester);
    await pumpTicks(tester, const Duration(milliseconds: 900));
    // 同じ時計なので、どちらも同じだけ下がっている。
    final selfMoving = mouthY(tester, redFish);
    expect(selfMoving, greaterThan(selfStart));
    expect(mouthY(tester, blueFish), closeTo(selfMoving, 1e-6));

    await tester.tap(find.byType(DuelGame));
    await pumpTicks(tester, const Duration(seconds: 4));

    // 自分は0.81、相手は0.90で止まり、どちらも線を越えない。相手のほうが線に近い。
    expect(find.text('81%'), findsOneWidget);
    expect(find.text('90%'), findsOneWidget);
    // 列の上部に勝敗を出す。自分は0.81、相手は0.90なので相手の勝ち。
    expect(find.text('WIN'), findsOneWidget);
    expect(find.text('LOSE'), findsOneWidget);
    expect(
      tester.getRect(find.byKey(const Key('result-peer'))).center.dx,
      greaterThan(
        tester.getRect(find.byKey(const Key('result-self'))).center.dx,
      ),
    );
    expect(
      tester.getRect(find.text('WIN')).top,
      lessThan(tester.getRect(find.text('90%')).top),
    );
    final selfStop = mouthY(tester, redFish);
    final peerStop = mouthY(tester, blueFish);
    expect(selfStop, lessThan(lineY));
    expect(peerStop, lessThan(lineY));
    expect(peerStop, greaterThan(selfStop));
    expect(results, [DuelGameResult.loss]);
  });

  testWidgets('止める前に落ちた魚は線を越え、綱は画面の上端から切れない', (tester) async {
    for (final size in const [
      Size(412, 900),
      Size(360, 640),
      Size(412, 1000),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      // 前のサイズのゲーム状態を引き継がないよう、いったん破棄する。
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        duel(
          course: const RaceCourse(fallDuration: Duration(seconds: 1)),
          peerDecision: const RaceDecision.fell(),
        ),
      );
      await startRace(tester);
      await pumpTicks(tester, const Duration(seconds: 3));

      final lineY = landingY(tester);
      expect(
        lineY,
        closeTo(size.height * RaceField.defaultLandingRatio, 1e-6),
        reason: '$size',
      );
      // 両方落ちたら、どちらも LOSE。
      expect(find.text('LOSE'), findsNWidgets(2), reason: '$size');
      expect(find.text('WIN'), findsNothing, reason: '$size');
      expect(find.text('ボチャン！'), findsNWidgets(2), reason: '$size');
      for (final fish in [redFish, blueFish]) {
        expect(mouthY(tester, fish), greaterThan(lineY), reason: '$size $fish');
        // 最も深く落ちても、綱の上端は画面の上端より下がらない。
        expect(
          ropeTop(tester, fish),
          lessThanOrEqualTo(0),
          reason: '$size $fish',
        );
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('アウトの線は決めた位置（高さの91.3%）に固定され、説明は魚と線の間に大きく出る', (tester) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      duel(
        course: const RaceCourse(fallDuration: Duration(seconds: 10)),
        peerDecision: const RaceDecision.stopped(0.5),
      ),
    );
    expect(RaceField.defaultLandingRatio, 0.913);
    expect(landingY(tester), closeTo(900 * 0.913, 1e-6));
    // 説明は中央に大きく出し、吊られた魚ともアウトの線とも重ならない。
    final guide = tester.getRect(find.text('タップでスタート！'));
    expect(guide.top, greaterThan(mouthY(tester, redFish)));
    expect(guide.bottom, lessThan(landingY(tester)));
    expect(guide.center.dx, closeTo(206, 1));
    expect(guide.width, greaterThan(300));
    // 説明文は縮めずに大きいまま折り返す（1行26px、2行以上）。
    final body = tester.getRect(find.textContaining('赤い線のぎりぎり'));
    expect(body.height, greaterThanOrEqualTo(26 * 1.35 * 2 - 1));
    expect(body.bottom, lessThan(landingY(tester)));
  });

  testWidgets('自分の魚が線を越えて落ちたときだけ、スマホを強く一度震わせる', (tester) async {
    final vibrations = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          vibrations.add(call.arguments);
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

    // 止めたとき（相手が落ちても）は震えない。
    await tester.pumpWidget(
      duel(
        course: const RaceCourse(fallDuration: Duration(seconds: 1)),
        peerDecision: const RaceDecision.fell(),
      ),
    );
    await startRace(tester);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byType(DuelGame));
    await pumpTicks(tester, const Duration(seconds: 4));
    expect(vibrations, isEmpty);

    // 止める前に落ちたら、一度だけ強く震える。
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      duel(
        course: const RaceCourse(fallDuration: Duration(seconds: 1)),
        peerDecision: const RaceDecision.stopped(0.5),
      ),
    );
    await startRace(tester);
    await pumpTicks(tester, const Duration(seconds: 4));
    expect(vibrations, ['HapticFeedbackType.heavyImpact']);
  });

  testWidgets('負けたときは踊らずに結果へ進み、踊りは1秒見たらタップで飛ばせる', (tester) async {
    // 負け：踊りの場面は出ない。
    final lost = <DuelGameResult>[];
    await tester.pumpWidget(
      duel(
        course: const RaceCourse(fallDuration: Duration(seconds: 1)),
        peerDecision: const RaceDecision.stopped(0.5),
        onCompleted: lost.add,
      ),
    );
    await startRace(tester);
    await pumpTicks(tester, const Duration(seconds: 4));
    expect(lost, [DuelGameResult.loss]);
    expect(find.byKey(const Key('win-dance')), findsNothing);

    // 勝ち：踊り始めてすぐのタップは無視し、1秒たったら飛ばせる。
    final won = <DuelGameResult>[];
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      duel(
        course: const RaceCourse(fallDuration: Duration(seconds: 1)),
        peerDecision: const RaceDecision.fell(),
        onCompleted: won.add,
      ),
    );
    await startRace(tester);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byType(DuelGame));
    // 相手が落ちて決着（約1秒）＋ % の表示1秒のあと、踊りが始まる。
    await pumpTicks(tester, const Duration(milliseconds: 1700));
    expect(find.byKey(const Key('win-dance')), findsOneWidget);
    await tester.tap(find.byType(DuelGame));
    await tester.pump();
    expect(won, isEmpty);
    await pumpTicks(tester, const Duration(seconds: 1));
    await tester.tap(find.byType(DuelGame));
    await tester.pump();
    expect(won, [DuelGameResult.win]);
  });

  testWidgets('踊りの素材は登録済みで、動きを減らす設定では開始直後から1枚絵が見える', (tester) async {
    for (final asset in [WinDance.danceAsset, WinDance.stillAsset]) {
      final data = await rootBundle.load(asset);
      expect(data.lengthInBytes, greaterThan(0), reason: asset);
    }
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: WinDance(elapsed: Duration.zero),
        ),
      ),
    );
    final image = tester.widget<Image>(find.byKey(const Key('oyakata-dance')));
    expect((image.image as AssetImage).assetName, WinDance.stillAsset);
    final characterOpacity = tester.widget<Opacity>(
      find
          .ancestor(
            of: find.byKey(const Key('oyakata-dance')),
            matching: find.byType(Opacity),
          )
          .first,
    );
    expect(characterOpacity.opacity, 1);
  });
}
