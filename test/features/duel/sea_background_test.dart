import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spajam2026/features/duel/sea_background.dart';

void main() {
  test('2枚目の重なりは0から1へなめらかに往復し、一周で元に戻る', () {
    expect(SeaBackground.mixAt(Duration.zero), 0);
    expect(SeaBackground.mixAt(SeaBackground.cycle ~/ 4), closeTo(0.5, 1e-9));
    expect(SeaBackground.mixAt(SeaBackground.cycle ~/ 2), closeTo(1, 1e-9));
    expect(SeaBackground.mixAt(SeaBackground.cycle), closeTo(0, 1e-9));
    expect(SeaBackground.mixAt(SeaBackground.cycle * 2.5), closeTo(1, 1e-9));
  });

  test('経過時間が負でも1枚目だけを表示する', () {
    expect(SeaBackground.mixAt(const Duration(seconds: -1)), 0);
  });

  testWidgets('背景の2枚は登録済みの素材として読み込める', (tester) async {
    for (final asset in [SeaBackground.assetA, SeaBackground.assetB]) {
      final data = await rootBundle.load(asset);
      expect(data.lengthInBytes, greaterThan(0), reason: asset);
    }
  });

  testWidgets('アニメーションを減らす設定では背景を動かさない', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: SeaBackground(elapsed: Duration(milliseconds: 1500)),
        ),
      ),
    );

    final second = tester.widget<Image>(
      find.byWidgetPredicate((widget) {
        if (widget is! Image) return false;
        final image = widget.image;
        return image is AssetImage && image.assetName == SeaBackground.assetB;
      }),
    );
    expect(second.opacity!.value, 0);
  });
}
