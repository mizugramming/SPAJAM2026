import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spajam2026/core/models/category_type.dart';
import 'package:spajam2026/features/space/pages/space_page.dart';
import 'package:spajam2026/features/space/widgets/planet_choice.dart';

Future<void> tapVisible(WidgetTester tester, String label) async {
  final target = find.text(label);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void expectWorldHeading(WidgetTester tester, String label, double fontSize) {
  final heading = find.text(label);
  expect(heading, findsOneWidget);
  final style = tester.widget<Text>(heading).style!;
  expect(style.fontFamily, 'NotoSansJP');
  expect(style.fontSize, fontSize);
  expect(style.fontWeight, FontWeight.w300);
  expect(style.letterSpacing, 2.2);
  expect(style.height, 1.65);
  expect(tester.getSize(heading).height, lessThan(42));
}

void main() {
  testWidgets('SPACE planet symbols preserve every theme and selection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SpacePage())),
    );

    expectWorldHeading(tester, '30秒だけ、ここに。', 22);
    await tapVisible(tester, 'はじめる');
    expectWorldHeading(tester, '今に近いものを、ひとつ。', 22);
    await tapVisible(tester, '疲れた');
    await tapVisible(tester, '次へ');
    expectWorldHeading(tester, 'この気持ちは、どこに近い？', 22);
    expect(
      find.byType(PlanetChoice),
      findsNWidgets(CategoryType.values.length),
    );

    for (final category in CategoryType.values) {
      await tapVisible(tester, category.label);
      final selected = tester
          .widgetList<PlanetChoice>(find.byType(PlanetChoice))
          .where((planet) => planet.selected)
          .single;
      expect(selected.label, category.label);
      expect(selected.symbol, switch (category) {
        CategoryType.relationships => PlanetSymbol.connection,
        CategoryType.self => PlanetSymbol.innerCenter,
        _ => PlanetSymbol.icon,
      });
      final selectedPlanet = find.byWidgetPredicate(
        (widget) => widget is PlanetChoice && widget.selected,
      );
      expect(
        find.descendant(
          of: selectedPlanet,
          matching: find.byIcon(Icons.check_circle),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<AnimatedScale>(
              find.descendant(
                of: selectedPlanet,
                matching: find.byType(AnimatedScale),
              ),
            )
            .scale,
        1.06,
      );
    }

    await tapVisible(tester, '次へ');
    expectWorldHeading(tester, 'ことばにしたくなったら。', 19);
    await tapVisible(tester, '何も書かずに進む');
    expectWorldHeading(tester, 'この瞬間を、星に。', 22);
    expect(tester.takeException(), isNull);
  });
}
