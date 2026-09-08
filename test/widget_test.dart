import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spajam2026/main.dart';

void main() {
  testWidgets('部屋作成/参加の入り口画面が表示される', (WidgetTester tester) async {
    await tester.pumpWidget(const AppRoot());
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) => widget is Image && widget.semanticLabel == '会輪',
      ),
      findsOneWidget,
    );
    expect(find.text('部屋を作る'), findsOneWidget);
    expect(find.text('参加する'), findsOneWidget);
    expect(find.text('AI寿司大将'), findsNothing);
  });

  testWidgets('参加画面では部屋番号を大文字化して6文字を検証する', (tester) async {
    await tester.pumpWidget(const AppRoot());
    await tester.pumpAndSettle();

    await tester.tap(find.text('参加する'));
    await tester.pumpAndSettle();

    final joinButtonFinder = find.widgetWithText(FilledButton, '部屋に参加する');
    expect(tester.widget<FilledButton>(joinButtonFinder).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'a7k3px');
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, 'A7K3PX');
    expect(find.text('6 / 6'), findsOneWidget);
    expect(tester.widget<FilledButton>(joinButtonFinder).onPressed, isNotNull);
  });
}
