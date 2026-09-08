import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spajam2026/features/conversation/widgets/sushi_capsule.dart';
import 'package:spajam2026/main.dart';

void main() {
  testWidgets('PCプレビューではアプリ全体をスマホサイズに制限する', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const AppRoot());
    await tester.pump();

    expect(tester.getSize(find.byType(Scaffold)), const Size(390, 844));
    expect(tester.takeException(), isNull);
  });

  testWidgets('小型スマホでもRoom画面が崩れない', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const AppRoot());
    await tester.pump();

    expect(find.text('部屋を作る'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('スマホサイズでRoom作成からResult表示まで進める', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const AppRoot());
    await tester.pump();

    await tester.tap(find.text('部屋を作る'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '山田 太郎');
    await tester.tap(find.text('学生'));
    await tester.tap(find.text('ゲーム'));
    await tester.enterText(fields.at(1), '最近買ってよかったもの');
    await tester.tap(find.text('準備完了'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(find.text('部屋番号'), findsOneWidget);
    expect(tester.getSize(find.byType(AppBar)).width, 390);
    await tester.tap(find.byIcon(Icons.bolt));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();

    expect(find.byType(SushiCapsule), findsWidgets);
    final capsule = tester.widget<SushiCapsule>(
      find.byType(SushiCapsule).first,
    );
    final selectedTopic = capsule.topic.text;
    capsule.onTap();
    await tester.pump();

    await tester.tap(find.text('会輪を終了'));
    await tester.pump();
    await tester.tap(find.text('終了する'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('1 / 1人'), findsOneWidget);
    expect(find.text('山田 太郎'), findsOneWidget);
    expect(find.text(selectedTopic), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
