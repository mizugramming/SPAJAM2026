import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spajam2026/app/app.dart';
import 'package:spajam2026/app/router.dart';
import 'package:spajam2026/core/constants/app_routes.dart';
import 'package:spajam2026/core/models/category_type.dart';
import 'package:spajam2026/core/models/emotion_type.dart';
import 'package:spajam2026/core/providers/space_records_provider.dart';
import 'package:spajam2026/features/constellation/widgets/constellation_map.dart';
import 'package:spajam2026/features/space/widgets/choice_tile.dart';
import 'package:spajam2026/core/widgets/record_list.dart';
import 'helpers.dart';

Future<ProviderContainer> boot(
  WidgetTester tester, {
  MemoryRepository? repository,
}) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        if (repository != null)
          spaceRepositoryProvider.overrideWith((ref) async => repository),
      ],
      child: const YohakuApp(),
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(YohakuApp)),
  );
  return container;
}

Future<void> tapText(WidgetTester tester, String text) async {
  final finder = find.text(text).last;
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> goToNote(WidgetTester tester) async {
  await tapText(tester, 'SPACE');
  await tapText(tester, 'スキップして気持ちを選ぶ');
  final next = tester.widget<FilledButton>(
    find.widgetWithText(FilledButton, '次へ'),
  );
  expect(next.onPressed, isNull);
  await tapText(tester, '疲れた');
  await tapText(tester, '次へ');
  await tapText(tester, '学業・仕事');
  await tapText(tester, '次へ');
}

void main() {
  setUpAll(() async => initializeDateFormatting('ja_JP'));
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'empty screens and all navigation destinations render without errors',
    (tester) async {
      await boot(tester);
      expect(find.text('余 白'), findsOneWidget);
      await tapText(tester, '今日');
      expect(find.text('この日は、静かな宇宙。'), findsOneWidget);
      await tapText(tester, '宇宙');
      expect(find.text('まだ眠っている惑星'), findsNWidgets(6));
      await tapText(tester, '振り返り');
      expect(find.text('この日は、静かな余白。'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'record -> constellation -> restart -> planet -> history -> confirmed deletion',
    (tester) async {
      final container = await boot(tester);
      await goToNote(tester);
      await tester.enterText(find.byType(TextField), '少し休んで、また明日。');
      await tapText(tester, '星を作る');
      expect(find.text('あなたの言葉が、\n星になりました。'), findsOneWidget);
      await tapText(tester, '星を飛ばす');
      expect(find.text('その星を、\n夜空へ。'), findsOneWidget);
      expect(find.text('少し休んで、また明日。'), findsOneWidget);
      await tapText(tester, '今日の星座を作成する');
      await tapText(tester, '作成する');
      expect(find.byType(ConstellationMap), findsOneWidget);
      expect(
        container.read(spaceRecordsProvider).requireValue.single.emotion,
        EmotionType.tired,
      );
      expect(
        container.read(spaceRecordsProvider).requireValue.single.category,
        CategoryType.workStudy,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      final restarted = await boot(tester);
      expect(
        restarted.read(spaceRecordsProvider).requireValue.single.note,
        '少し休んで、また明日。',
      );
      await tapText(tester, '宇宙');
      expect(find.text('小さな惑星'), findsOneWidget);
      await tapText(tester, '学業・仕事');
      expect(find.text('学業・仕事の惑星'), findsOneWidget);
      Navigator.of(tester.element(find.text('学業・仕事の惑星'))).pop();
      await tester.pumpAndSettle();
      await tapText(tester, '振り返り');
      expect(find.byType(RecordList), findsOneWidget);
      await tapText(tester, '疲れた · 学業・仕事');
      expect(find.text('少し休んで、また明日。'), findsOneWidget);
      await tapText(tester, 'この記録を削除');
      await tapText(tester, '残す');
      expect(restarted.read(spaceRecordsProvider).requireValue, hasLength(1));
      await tapText(tester, 'この記録を削除');
      await tapText(tester, '削除する');
      expect(restarted.read(spaceRecordsProvider).requireValue, isEmpty);
      expect(find.text('この日は、静かな余白。'), findsOneWidget);
      await tapText(tester, '宇宙');
      expect(find.text('まだ眠っている惑星'), findsNWidgets(6));
      await tapText(tester, '今日');
      expect(find.text('この日は、静かな宇宙。'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    '200-character limit, failure preserves input, retry and discard confirmation',
    (tester) async {
      final repository = MemoryRepository()..failSave = true;
      await boot(tester, repository: repository);
      await goToNote(tester);
      await tester.enterText(find.byType(TextField), '🌌' * 201);
      await tester.pump();
      expect(
        tester
            .widget<TextField>(find.byType(TextField))
            .controller!
            .text
            .characters
            .length,
        200,
      );
      await tester.enterText(find.byType(TextField), '残しておきたい言葉');
      await tapText(tester, '星を作る');
      expect(find.text('保存できませんでした。入力は残っています。もう一度お試しください。'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '残しておきたい言葉',
      );
      await tester.tap(find.byTooltip('閉じる'));
      await tester.pumpAndSettle();
      expect(find.text('入力を閉じますか？'), findsOneWidget);
      await tapText(tester, '続ける');
      repository.failSave = false;
      await tapText(tester, '星を作る');
      await tapText(tester, '星を飛ばす');
      expect(repository.records, hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('swiping the star up also advances to the launch step', (
    tester,
  ) async {
    await boot(tester);
    await goToNote(tester);
    await tester.enterText(find.byType(TextField), '静かな夜。');
    await tapText(tester, '星を作る');
    expect(find.text('あなたの言葉が、\n星になりました。'), findsOneWidget);
    await tester.fling(
      find.byIcon(Icons.star_rounded),
      const Offset(0, -300),
      800,
    );
    await tester.pumpAndSettle();
    expect(find.text('その星を、\n夜空へ。'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'past date route and calendar selection agree; multiple stars render',
    (tester) async {
      final now = DateTime.now();
      final past = DateTime(now.year, now.month, now.day - 1, 12);
      final repository = MemoryRepository([
        record(1, at: past),
        record(2, at: past.add(const Duration(minutes: 1))),
      ]);
      final container = await boot(tester, repository: repository);
      container.read(routerProvider).go(AppRoutes.constellationOn(past));
      await tester.pumpAndSettle();
      expect(find.byType(ConstellationMap), findsOneWidget);
      expect(
        tester.widget<ConstellationMap>(find.byType(ConstellationMap)).records,
        hasLength(2),
      );
      await tapText(tester, '振り返り');
      if (past.month != now.month) {
        await tester.tap(find.byIcon(Icons.chevron_left).first);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('${past.day}').hitTestable().first);
      await tester.pumpAndSettle();
      expect(
        tester.widget<RecordList>(find.byType(RecordList)).records,
        hasLength(2),
      );
      await tapText(tester, 'この日の星座へ →');
      expect(
        GoRouter.of(
          tester.element(find.byType(ConstellationMap)),
        ).routeInformationProvider.value.uri.queryParameters['date'],
        isNotNull,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'narrow screen and large text preserve scrollable selection controls',
    (tester) async {
      await boot(tester);
      tester.view.physicalSize = const Size(320, 640);
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      await goToNote(tester);
      expect(find.byType(ChoiceTile), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
