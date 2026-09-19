import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:spajam2026/app/app.dart';
import 'package:spajam2026/app/router.dart';
import 'package:spajam2026/core/models/category_type.dart';
import 'package:spajam2026/core/providers/space_records_provider.dart';
import 'package:spajam2026/core/widgets/planet_orb.dart';
import '../../helpers.dart';

final _today = DateTime(2026, 9, 19);

class _TestClock extends TodayNotifier {
  @override
  DateTime build() => _today;
  void nextDay() => state = state.add(const Duration(days: 1));
}

Future<ProviderContainer> _boot(
  WidgetTester tester,
  MemoryRepository repository, {
  Size size = const Size(430, 932),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        spaceRepositoryProvider.overrideWith((ref) async => repository),
        todayProvider.overrideWith(_TestClock.new),
      ],
      child: const YohakuApp(),
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(YohakuApp)),
  );
  container.read(routerProvider).go('/universe');
  await tester.pumpAndSettle();
  return container;
}

String _selected(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const ValueKey('selected-planet-title')))
    .data!;

double _size(WidgetTester tester, String id) =>
    tester.widget<PlanetOrb>(find.byKey(ValueKey('orb-$id'))).size;

void main() {
  setUpAll(() => initializeDateFormatting('ja_JP'));

  testWidgets(
    'today is filtered by central theme; growth uses all dates and updates live',
    (tester) async {
      final old = record(
        1,
        at: _today.subtract(const Duration(days: 1)),
        category: CategoryType.challenge,
        note: '昨日の挑戦',
      );
      final current = record(
        2,
        at: _today,
        category: CategoryType.challenge,
        note: '今日の挑戦',
      );
      final work = record(
        3,
        at: _today,
        category: CategoryType.workStudy,
        note: '今日の仕事',
      );
      final container = await _boot(
        tester,
        MemoryRepository([old, current, work]),
      );
      expect(find.textContaining('これまで 2 個の星'), findsOneWidget);
      expect(find.textContaining('今日の挑戦'), findsOneWidget);
      expect(find.textContaining('昨日の挑戦'), findsNothing);
      expect(find.textContaining('今日の仕事'), findsNothing);
      final initial = _size(tester, 'challenge');
      final otherSize = _size(tester, 'workStudy');
      final added = record(
        4,
        at: _today,
        category: CategoryType.challenge,
        note: 'もう一歩',
      );
      await container.read(spaceRecordsProvider.notifier).save(added);
      await tester.pumpAndSettle();
      expect(_size(tester, 'challenge'), greaterThan(initial));
      expect(_size(tester, 'workStudy'), otherSize);
      expect(find.textContaining('もう一歩'), findsOneWidget);
      await container.read(spaceRecordsProvider.notifier).deleteById(added.id);
      await tester.pumpAndSettle();
      expect(_size(tester, 'challenge'), closeTo(initial, .001));
      expect(find.textContaining('もう一歩'), findsNothing);
      await tester.tap(find.byTooltip('学業・仕事を表示'));
      await tester.pumpAndSettle();
      expect(_selected(tester), '学業・仕事');
      expect(find.textContaining('今日の挑戦'), findsNothing);
      expect(find.textContaining('今日の仕事'), findsOneWidget);
      (container.read(todayProvider.notifier) as _TestClock).nextDay();
      await tester.pumpAndSettle();
      expect(find.textContaining('今日の仕事'), findsNothing);
      expect(find.textContaining('今日はまだ、この惑星に星が届いていません。'), findsOneWidget);
      expect(find.textContaining('これまで 1 個の星'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'drag tracks finger, fling crosses multiple planets, and can be interrupted',
    (tester) async {
      await _boot(tester, MemoryRepository());
      final orbit = find.byKey(const ValueKey('planet-orbit'));
      final orb = find.byKey(const ValueKey('orb-challenge'));
      final initial = tester.getCenter(orb);
      final finger = await tester.startGesture(tester.getCenter(orbit));
      await finger.moveBy(const Offset(-25, 0));
      await tester.pump();
      await finger.moveBy(const Offset(-20, 0));
      await tester.pump();
      expect(tester.getCenter(orb).dx, lessThan(initial.dx));
      expect(_selected(tester), '挑戦');
      await finger.cancel();
      await tester.pumpAndSettle();
      expect(_selected(tester), '挑戦');
      await tester.fling(orbit, const Offset(-160, 0), 2500);
      await tester.pump(const Duration(milliseconds: 200));
      final interrupt = await tester.startGesture(tester.getCenter(orbit));
      final held = tester.getCenter(orb);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.getCenter(orb), held);
      await interrupt.cancel();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('挑戦を表示'));
      await tester.pumpAndSettle();
      await tester.fling(orbit, const Offset(-160, 0), 2500);
      await tester.pumpAndSettle();
      expect(_selected(tester), isNot(anyOf('挑戦', '人間関係')));
      await tester.tap(find.byTooltip('挑戦を表示'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('前の惑星'));
      await tester.pumpAndSettle();
      expect(_selected(tester), '日常');
      await tester.fling(orbit, const Offset(-160, 0), 2500);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('small display, enlarged text and reduced motion remain usable', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _boot(tester, MemoryRepository(), size: const Size(320, 640));
    await tester.ensureVisible(find.byTooltip('学業・仕事を表示'));
    await tester.tap(find.byTooltip('学業・仕事を表示'));
    await tester.pumpAndSettle();
    expect(_selected(tester), '学業・仕事');
    final allRecords = find.text('この惑星のすべての記録');
    await tester.ensureVisible(allRecords);
    await tester.tap(allRecords);
    await tester.pumpAndSettle();
    expect(find.text('学業・仕事の惑星'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
