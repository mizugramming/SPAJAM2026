import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spajam2026/domain/models.dart';
import 'package:spajam2026/features/demo/can_stage.dart';

void main() {
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
