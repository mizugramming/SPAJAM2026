import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spajam2026/features/demo/can_stage.dart';
import 'package:spajam2026/features/demo/wavy_title_image.dart';

const content = Rect.fromLTRB(240, 200, 1960, 570);

Widget title({bool reduceMotion = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: const Center(
      child: SizedBox(
        width: 300,
        child: WavyTitleImage(
          asset: shoboneTitleAsset,
          content: content,
          semanticLabel: 'ショBONE',
        ),
      ),
    ),
  ),
);

double offset(int i, double progress) => WavyTitleImage.offsetAt(
  i: i,
  slices: 16,
  progress: progress,
  waves: 3,
  amplitude: .06,
  height: 100,
);

void main() {
  testWidgets('ショBONE の画像は登録済みで、幅に合わせた高さで読み上げ名を持つ', (tester) async {
    final data = await rootBundle.load(shoboneTitleAsset);
    expect(data.lengthInBytes, greaterThan(0));

    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(title());
    final size = tester.getSize(find.byType(WavyTitleImage));
    expect(size.width, 300);
    expect(size.height, closeTo(300 * content.height / content.width, 1e-6));
    expect(find.bySemanticsLabel('ショBONE'), findsOneWidget);
    // 画像部品は使わず、1枚の画像を Canvas に描く。
    expect(
      find.descendant(
        of: find.byType(WavyTitleImage),
        matching: find.byType(Image),
      ),
      findsNothing,
    );
    semantics.dispose();
  });

  test('帯ごとにずれた小さな波で、始まりと終わりは平らに戻る', () {
    final middle = [for (var i = 0; i < 16; i++) offset(i, .3)];
    expect(middle.toSet().length, greaterThan(4));
    for (final dy in middle) {
      expect(dy.abs(), lessThanOrEqualTo(6 + 1e-9));
    }
    expect(middle.any((dy) => dy.abs() > 2), isTrue);
    for (var i = 0; i < 16; i++) {
      expect(offset(i, 0).abs(), lessThan(1e-9));
      expect(offset(i, 1).abs(), lessThan(1e-9));
    }
  });

  testWidgets('揺れは3回で止まり、画面の更新を要求し続けない', (tester) async {
    await tester.pumpWidget(title());
    await tester.pump(const Duration(milliseconds: 1200));
    expect(tester.binding.hasScheduledFrame, isTrue);

    await tester.pump(const Duration(milliseconds: 3700));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('「アニメーションを減らす」設定でも表示でき、例外にならない', (tester) async {
    await tester.pumpWidget(title(reduceMotion: true));
    await tester.pumpAndSettle();
    expect(find.byType(WavyTitleImage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
