import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spajam2026/domain/models.dart';
import 'package:spajam2026/features/cooperative/cooperative_game.dart';
import 'package:spajam2026/features/cooperative/soul_course.dart';
import 'package:spajam2026/features/cooperative/soul_stage.dart';

const self = Participant(
  id: 'self',
  profile: Profile(nickname: 'わたし', hobby: '', comment: ''),
  team: Team.red,
);
const peer = Participant(
  id: 'peer',
  profile: Profile(nickname: 'なかま', hobby: '', comment: ''),
  team: Team.red,
);

/// 相方はいつもぴったりで押す。
List<Duration?> perfectPartner(SoulLevel level) => const [
  Duration.zero,
  Duration.zero,
  Duration.zero,
];

/// 親（GameScene相当）が毎秒再描画する状況を再現する。
class _RebuildingHarness extends StatefulWidget {
  const _RebuildingHarness({super.key, required this.builder});
  final WidgetBuilder builder;

  @override
  State<_RebuildingHarness> createState() => _RebuildingHarnessState();
}

class _RebuildingHarnessState extends State<_RebuildingHarness> {
  void rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

Widget game({
  required ValueChanged<CooperativeGameResult> onCompleted,
  PartnerOffsets partner = perfectPartner,
}) => MaterialApp(
  home: CooperativeGame(
    self: self,
    peer: peer,
    onCompleted: onCompleted,
    debugPartnerOffsets: partner,
  ),
);

Future<void> tapGame(WidgetTester tester) async {
  await tester.tap(find.byType(CooperativeGame));
  await tester.pump();
}

/// 「タップでスタート」から、最初のレベルの紹介が始まるところまで。
Future<void> start(WidgetTester tester) => tapGame(tester);

/// 紹介を見せ、右の缶（1・3・5番）を魂が着く時刻ちょうどに押して、穴へ入れる。
/// 最後は次の場面（次のレベルの紹介、または最後の結果）へ進んだところで止まる。
Future<void> playLevel(
  WidgetTester tester,
  SoulLevel level, {
  VoidCallback? betweenTaps,
}) async {
  await tester.pump(SoulTiming.intro);
  var t = Duration.zero;
  for (final hop in [1, 3, 5]) {
    final at = level.firstArrival + level.flight * (hop - 1);
    await tester.pump(at - t);
    t = at;
    await tapGame(tester);
    betweenTaps?.call();
    await tester.pump();
  }
  final hole = level.firstArrival + level.flight * SoulRun.hops;
  await tester.pump(hole - t);
  await tester.pump(SoulTiming.holeSink + SoulTiming.clearLinger);
}

double guideOpacity(WidgetTester tester) =>
    tester.widget<AnimatedOpacity>(find.byKey(const Key('coop-guide'))).opacity;

String hud(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('coop-hud'))).data!;

void main() {
  testWidgets('たましいの画像を使い、登録済みの素材として読み込める', (tester) async {
    for (final asset in [
      SoulStage.soulAsset,
      SoulStage.canAsset,
      SoulStage.holeAsset,
    ]) {
      final data = await rootBundle.load(asset);
      expect(data.lengthInBytes, greaterThan(0), reason: asset);
    }

    await tester.pumpWidget(game(onCompleted: (_) {}));
    final images = tester.widgetList<Image>(find.byType(Image)).where((image) {
      final provider = image.image;
      final asset = provider is ResizeImage ? provider.imageProvider : provider;
      return asset is AssetImage && asset.assetName == SoulStage.soulAsset;
    });
    expect(images, hasLength(1));
    // 両端に3個ずつのツナ缶と、最後の穴。
    for (var hop = 1; hop <= 6; hop++) {
      expect(find.byKey(Key('soul-can-$hop')), findsOneWidget);
    }
    expect(find.byKey(const Key('soul-hole')), findsOneWidget);
  });

  testWidgets('スタート前は時計が止まり、タップでレベル1が始まる', (tester) async {
    final results = <CooperativeGameResult>[];
    await tester.pumpWidget(game(onCompleted: results.add));

    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 30));
    expect(find.text('タップで\nスタート！'), findsOneWidget);
    expect(guideOpacity(tester), 1);
    expect(results, isEmpty);

    await start(tester);
    expect(find.byKey(const Key('coop-intro')), findsOneWidget);
    expect(find.text('レベル 1'), findsOneWidget);
    // 最初のタップで説明はフェードアウトする。
    await tester.pump(const Duration(milliseconds: 500));
    expect(guideOpacity(tester), 0);
  });

  testWidgets('3レベルとも運べば成功し、魂ポイントは1+2+3=6pt。通知は一度だけ', (tester) async {
    final results = <CooperativeGameResult>[];
    await tester.pumpWidget(game(onCompleted: results.add));
    await start(tester);

    await playLevel(tester, SoulLevel.all[0]);
    expect(hud(tester), contains('魂 1 pt'));
    expect(find.text('レベル 2'), findsOneWidget);
    await playLevel(tester, SoulLevel.all[1]);
    expect(hud(tester), contains('魂 3 pt'));
    await playLevel(tester, SoulLevel.all[2]);
    expect(hud(tester), contains('魂 6 pt'));
    expect(find.text('ぜんぶ運べた！'), findsOneWidget);
    expect(results, isEmpty);

    await tester.pump(SoulTiming.finalPanel);
    expect(results, [CooperativeGameResult.success]);
    await tester.pump(const Duration(seconds: 5));
    expect(results, [CooperativeGameResult.success]);
  });

  testWidgets('押さずにいると魂は海へ落ちて失敗。運んだレベルの魂ポイントは残る', (tester) async {
    final results = <CooperativeGameResult>[];
    await tester.pumpWidget(game(onCompleted: results.add));
    await start(tester);
    await playLevel(tester, SoulLevel.all[0]);

    // レベル2は何も押さない。
    final level = SoulLevel.all[1];
    await tester.pump(SoulTiming.intro);
    await tester.pump(level.firstArrival + level.window);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(SoulTiming.fall);
    expect(find.text('ボチャン！'), findsOneWidget);
    await tester.pump(SoulTiming.fallLinger);
    expect(find.text('ざんねん…'), findsOneWidget);
    expect(find.textContaining('魂ポイント +1 pt'), findsOneWidget);

    await tester.pump(SoulTiming.finalPanel);
    expect(results, [CooperativeGameResult.failure]);
  });

  testWidgets('相方が押しそこねても落ちて失敗する', (tester) async {
    final results = <CooperativeGameResult>[];
    await tester.pumpWidget(
      game(
        onCompleted: results.add,
        partner: (_) => const [Duration.zero, null, Duration.zero],
      ),
    );
    await start(tester);
    final level = SoulLevel.all[0];
    await tester.pump(SoulTiming.intro);
    var t = Duration.zero;
    for (final hop in [1, 3]) {
      final at = level.firstArrival + level.flight * (hop - 1);
      await tester.pump(at - t);
      t = at;
      await tapGame(tester);
    }
    final missed = level.firstArrival + level.flight * 3 + level.window;
    await tester.pump(missed - t + const Duration(milliseconds: 1));
    await tester.pump(SoulTiming.fall + SoulTiming.fallLinger);
    await tester.pump(SoulTiming.finalPanel);
    expect(results, [CooperativeGameResult.failure]);
  });

  testWidgets('親が毎秒再描画しても、レベルと魂ポイントを保持する', (tester) async {
    final harnessKey = GlobalKey<_RebuildingHarnessState>();
    final results = <CooperativeGameResult>[];
    await tester.pumpWidget(
      MaterialApp(
        home: _RebuildingHarness(
          key: harnessKey,
          builder: (context) => CooperativeGame(
            self: self,
            peer: peer,
            onCompleted: results.add,
            debugPartnerOffsets: perfectPartner,
          ),
        ),
      ),
    );
    await start(tester);
    await playLevel(
      tester,
      SoulLevel.all[0],
      betweenTaps: () => harnessKey.currentState!.rebuild(),
    );
    harnessKey.currentState!.rebuild();
    await tester.pump();
    expect(hud(tester), contains('レベル 2/3'));
    expect(hud(tester), contains('魂 1 pt'));
    expect(results, isEmpty);
  });

  testWidgets('期限切れなどで結果が出る前に破棄されても、例外なく終わる', (tester) async {
    var completed = false;
    await tester.pumpWidget(game(onCompleted: (_) => completed = true));
    await start(tester);
    await tester.pump(const Duration(milliseconds: 1500));

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump(const Duration(seconds: 10));
    expect(completed, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('小さい画面・文字2倍でもはみ出さない', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(game(onCompleted: (_) {}));
    await start(tester);
    await tester.pump(SoulTiming.intro + const Duration(milliseconds: 1300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('スタート前の説明は中央に大きく出し、両端の缶と重ならない', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(game(onCompleted: (_) {}));

    final guide = tester.getRect(find.text('タップで\nスタート！'));
    for (var hop = 1; hop <= 6; hop++) {
      final can = tester.getRect(find.byKey(Key('soul-can-$hop')));
      expect(guide.overlaps(can), isFalse, reason: 'can $hop');
    }
    expect(guide.center.dx, closeTo(200, 1));
    expect(guide.width, greaterThan(150));
    // 見出しも「輪が小さくなったらタップ！」も、狭い幅で大きく出す（縮めても元の8割以上）。
    expect(guide.height, greaterThan(44 * 1.15 * 2 * 0.8));
    final body = tester.getRect(find.text('輪が小さくなったら\nタップ！'));
    expect(body.height, greaterThan(26 * 1.3 * 2 * 0.8));
    expect(body.top, greaterThan(guide.bottom));
    for (var hop = 1; hop <= 6; hop++) {
      final can = tester.getRect(find.byKey(Key('soul-can-$hop')));
      expect(body.overlaps(can), isFalse, reason: 'can $hop');
    }
  });
}
