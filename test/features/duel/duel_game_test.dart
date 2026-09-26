import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spajam2026/domain/models.dart';
import 'package:spajam2026/features/duel/duel_game.dart';
import 'package:spajam2026/features/duel/race_course.dart';

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

    await tester.pump(const Duration(milliseconds: 150));
    await tester.tap(find.byType(DuelGame));
    await tester.pump();
    expect(find.textContaining('ぎりぎり度'), findsOneWidget);

    await pumpTicks(tester, const Duration(seconds: 2));
    expect(results, [DuelGameResult.win]);

    // 決着後にさらに時間が進んでも、通知は一度だけ。
    await pumpTicks(tester, const Duration(seconds: 1));
    expect(results, [DuelGameResult.win]);
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

    await pumpTicks(tester, const Duration(seconds: 2));
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

    // 親を毎秒相当で再描画しながら進める。
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 300));
      harnessKey.currentState!.rebuild();
      await tester.pump();
    }
    // 1.8秒ほど経過しているはずで、まだ誰も決着していない。
    expect(find.textContaining('タップでストップ'), findsOneWidget);
    expect(results, isEmpty);

    await tester.tap(find.byType(DuelGame));
    await tester.pump();
    // 1.8秒経過時点の深さ（0.81）で止まっているはず。再描画を挟んでも
    // 直前のタップが上書きされない、かつ経過時間がリセットされていないことを確認する。
    expect(find.text('ぎりぎり度 81%'), findsOneWidget);
    harnessKey.currentState!.rebuild();
    await tester.pump();
    expect(find.text('ぎりぎり度 81%'), findsOneWidget);

    await pumpTicks(tester, const Duration(seconds: 2));
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
    await tester.pump(const Duration(milliseconds: 200));

    // 親が場面を切り替えて、ゲームWidgetごと消す（期限切れの再現）。
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump(const Duration(seconds: 1));

    expect(completed, isFalse);
    expect(tester.takeException(), isNull);
  });
}
