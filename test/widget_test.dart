import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spajam2026/app/app.dart';
import 'package:spajam2026/app/app_shell.dart';
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
  Size size = const Size(430, 932),
}) async {
  tester.view.physicalSize = size;
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
  await tapText(tester, 'はじめる');
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
  testWidgets('desktop viewport contains routes, sheets and dialogs', (
    tester,
  ) async {
    await boot(
      tester,
      size: const Size(1440, 1080),
      repository: MemoryRepository([record(1, at: DateTime.now())]),
    );
    final phone = Rect.fromLTWH(505, 74, 430, 932);
    expect(tester.getRect(find.byType(AppShell)), phone);
    expect(tester.getSize(find.byType(NavigationBar)).width, 430);
    await tapText(tester, 'SPACE');
    expect(tester.getRect(find.byType(Scaffold).last), phone);
    expect(
      MediaQuery.sizeOf(tester.element(find.byType(Scaffold).last)),
      phone.size,
    );
    final context = tester.element(find.byType(Scaffold).last);
    GoRouter.of(context).pop();
    await tester.pumpAndSettle();
    await tapText(tester, '振り返り');
    await tapText(tester, '疲れた · 学業・仕事');
    final sheet = tester.getRect(find.byType(BottomSheet));
    expect(sheet.left, phone.left);
    expect(sheet.right, phone.right);
    expect(sheet.top, greaterThanOrEqualTo(phone.top));
    expect(sheet.bottom, lessThanOrEqualTo(phone.bottom));
    await tapText(tester, 'この記録を削除');
    final dialog = tester.getRect(find.byType(AlertDialog));
    expect(dialog.intersect(phone), dialog);
    await tapText(tester, '残す');
    Navigator.of(tester.element(find.byType(BottomSheet))).pop();
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byType(Scaffold).last),
      const Rect.fromLTWH(0, 0, 390, 844),
    );
    tester.view.physicalSize = const Size(1280, 640);
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byType(Scaffold).last),
      const Rect.fromLTWH(425, 0, 430, 640),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'empty screens and all navigation destinations render without errors',
    (tester) async {
      await boot(tester);
      expect(find.text('余 白'), findsOneWidget);
      await tapText(tester, '今日');
      expect(find.text('この日は、静かな宇宙。'), findsOneWidget);
      await tapText(tester, '宇宙');
      expect(find.textContaining('まだ眠っている惑星'), findsOneWidget);
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
      await tester.pump();
      await tapText(tester, '確認へ進む');
      await tapText(tester, '星にする');
      expect(find.text('ひとつ、星が生まれました。'), findsOneWidget);
      await tapText(tester, '今日の星座を見る');
      await tester.pumpAndSettle();
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
      await tester.tap(find.byTooltip('学業・仕事を表示'));
      await tester.pumpAndSettle();
      expect(find.textContaining('小さな惑星'), findsOneWidget);
      expect(
        tester.widget<RecordList>(find.byType(RecordList)).records.single.note,
        '少し休んで、また明日。',
      );
      await tapText(tester, 'この惑星のすべての記録');
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
      expect(find.textContaining('まだ眠っている惑星'), findsOneWidget);
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
      await tapText(tester, '確認へ進む');
      await tapText(tester, '星にする');
      expect(find.text('記録を保存できませんでした。入力内容はそのまま残っています。'), findsOneWidget);
      await tester.tap(find.byTooltip('前のステップへ'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '残しておきたい言葉',
      );
      await tapText(tester, '確認へ進む');
      await tester.tap(find.byTooltip('閉じる'));
      await tester.pumpAndSettle();
      expect(find.text('入力を閉じますか？'), findsOneWidget);
      await tapText(tester, '続ける');
      repository.failSave = false;
      await tapText(tester, '星にする');
      await tester.pumpAndSettle();
      expect(repository.records, hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
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
    'SPACE can be left without a record and empty note can become a star',
    (tester) async {
      final repository = MemoryRepository();
      await boot(tester, repository: repository);
      await tapText(tester, 'SPACE');
      expect(find.text('30秒だけ、ここに。'), findsOneWidget);
      await tapText(tester, '今はやめておく');
      expect(repository.records, isEmpty);
      expect(find.text('余 白'), findsOneWidget);
      await goToNote(tester);
      await tapText(tester, '何も書かずに進む');
      expect(find.text('この瞬間を、星に。'), findsOneWidget);
      await tapText(tester, '星にする');
      expect(repository.records.single.note, isEmpty);
      expect(find.text('ひとつ、星が生まれました。'), findsOneWidget);
      await tapText(tester, '今日の星座を見る');
      expect(find.byType(ConstellationMap), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('swiping the saved star opens constellation creation', (
    tester,
  ) async {
    await boot(tester);
    await goToNote(tester);
    await tapText(tester, '何も書かずに進む');
    await tapText(tester, '星にする');
    expect(find.text('ひとつ、星が生まれました。'), findsOneWidget);
    await tester.fling(
      find.byIcon(Icons.star_rounded),
      const Offset(0, -300),
      800,
    );
    await tester.pumpAndSettle();
    expect(find.text('その星を、夜空へ。'), findsOneWidget);
    await tapText(tester, '今日の星座を作成する');
    await tapText(tester, '作成する');
    expect(find.byType(ConstellationMap), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
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
