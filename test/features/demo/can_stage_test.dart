import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spajam2026/domain/models.dart';
import 'package:spajam2026/features/demo/can_stage.dart';

void main() {
  const profile = Profile(nickname: 'つな', hobby: '散歩', comment: 'よろしく');
  const peer = Participant(id: 'peer', profile: profile, team: Team.red);
  const grownFollower = Follower(
    id: 'grown',
    ownerId: 'self',
    peerId: 'old-peer',
    profile: profile,
    kind: FollowerKind.normal,
    ordinal: 1,
  );
  const newBone = Follower(
    id: 'new',
    ownerId: 'self',
    peerId: 'peer',
    profile: profile,
    kind: FollowerKind.bone,
    ordinal: 2,
  );

  for (final settings in [
    (name: '通常文字', scale: 1.0, lineHeight: null, width: 372.0),
    (name: '文字2倍・360幅', scale: 2.0, lineHeight: null, width: 320.0),
    (name: '行高2倍', scale: 1.0, lineHeight: 2.0, width: 372.0),
  ]) {
    testWidgets('勝利・協力成功の子分と見出しを缶上面より上に収める（${settings.name}）', (tester) async {
      for (final outcome in [Outcome.win, Outcome.coopSuccess]) {
        final result = EncounterResult(
          outcome: outcome,
          peer: peer,
          newFollower: outcome == Outcome.win ? grownFollower : newBone,
          promoted: outcome == Outcome.coopSuccess ? grownFollower : null,
          delta: 3,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(
                  textScaler: TextScaler.linear(settings.scale),
                  lineHeightScaleFactorOverride: settings.lineHeight,
                ),
                child: SingleChildScrollView(
                  child: SizedBox(
                    width: settings.width,
                    child: CanStage(
                      phase: AppPhase.result,
                      profile: profile,
                      result: result,
                      team: Team.red,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final stageRect = tester.getRect(find.byType(CanStage));
        final canRect = tester.getRect(find.byType(TunaCan));
        final images = find.descendant(
          of: find.byType(CanStage),
          matching: find.byType(Image),
        );
        expect(images, findsNWidgets(outcome == Outcome.win ? 1 : 2));
        for (final image in images.evaluate()) {
          final rect = tester.getRect(find.byWidget(image.widget));
          expect(rect.top, greaterThanOrEqualTo(stageRect.top));
          // The top of the silver rim starts four pixels below the can bounds.
          expect(rect.bottom, lessThanOrEqualTo(canRect.top + 4));
          expect(stageRect.inflate(.1).contains(rect.topLeft), isTrue);
          expect(stageRect.inflate(.1).contains(rect.bottomRight), isTrue);
        }
        final title = find.text(outcome == Outcome.win ? 'やった！' : 'REBORN');
        expect(title, findsOneWidget);
        final titleRect = tester.getRect(title);
        expect(stageRect.inflate(.1).contains(titleRect.topLeft), isTrue);
        expect(stageRect.inflate(.1).contains(titleRect.bottomRight), isTrue);
        expect(tester.takeException(), isNull);
      }
    });
  }

  for (final reduceMotion in [false, true]) {
    testWidgets('帰還完了は再描画されても一度だけ通知する（動作軽減: $reduceMotion）', (tester) async {
      var completions = 0;
      Widget scene() => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: CanStage(
                  phase: AppPhase.returning,
                  profile: const Profile(
                    nickname: 'つな',
                    hobby: '散歩',
                    comment: '',
                  ),
                  onReturnComplete: () => completions++,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpWidget(scene());
      if (reduceMotion) {
        // Reduced motion must complete without waiting for the dive duration.
        expect(completions, 1);
        expect(tester.widget<TunaCan>(find.byType(TunaCan)).opening, 0);
      } else {
        expect(completions, 0);
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          tester.widget<TunaCan>(find.byType(TunaCan)).opening,
          greaterThan(0),
        );
        expect(completions, 0);
      }

      // A parent's unrelated rebuild must neither restart nor repeat completion.
      await tester.pumpWidget(scene());
      await tester.pumpAndSettle();
      expect(completions, 1);
      expect(tester.widget<TunaCan>(find.byType(TunaCan)).opening, 0);
      await tester.pumpWidget(scene());
      await tester.pump(const Duration(seconds: 3));
      expect(completions, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
