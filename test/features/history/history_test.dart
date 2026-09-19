import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:spajam2026/app/app.dart';
import 'package:spajam2026/app/router.dart';
import 'package:spajam2026/core/providers/space_records_provider.dart';
import 'package:spajam2026/core/widgets/record_list.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../helpers.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ja_JP'));

  for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
    testWidgets('${kind.name}: swipe months, select records, retain arrows', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final now = DateTime.now();
      final previousMonth = DateTime(now.year, now.month - 1, 10);
      final nextMonth = DateTime(now.year, now.month + 1);
      final saved = record(1, at: previousMonth, note: '先月の記録');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            spaceRepositoryProvider.overrideWith(
              (ref) async => MemoryRepository([saved]),
            ),
          ],
          child: const YohakuApp(),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(YohakuApp)),
      );
      container.read(routerProvider).go('/history');
      await tester.pumpAndSettle();
      final pages = find.byType(PageView);
      String month(DateTime day) => DateFormat.yMMMM('ja_JP').format(day);
      expect(find.text(month(now)), findsOneWidget);
      await tester.drag(pages, const Offset(-230, 0), kind: kind);
      await tester.pumpAndSettle();
      expect(find.text(month(nextMonth)), findsOneWidget);
      await tester.drag(pages, const Offset(230, 0), kind: kind);
      await tester.pumpAndSettle();
      expect(find.text(month(now)), findsOneWidget);
      await tester.drag(pages, const Offset(230, 0), kind: kind);
      await tester.pumpAndSettle();
      expect(find.text(month(previousMonth)), findsOneWidget);
      await tester.tap(find.text('10').hitTestable().first);
      await tester.pumpAndSettle();
      expect(
        tester.widget<RecordList>(find.byType(RecordList)).records.single.id,
        saved.id,
      );
      // A provider rebuild must not reset the swiped month.
      await container
          .read(spaceRecordsProvider.notifier)
          .save(record(2, at: previousMonth));
      await tester.pumpAndSettle();
      expect(find.text(month(previousMonth)), findsOneWidget);
      expect(
        tester.widget<RecordList>(find.byType(RecordList)).records,
        hasLength(2),
      );
      await tester.tap(
        find.descendant(
          of: find.byWidgetPredicate((widget) => widget is TableCalendar),
          matching: find.byIcon(Icons.chevron_right),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(month(now)), findsOneWidget);
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();
      expect(find.text(month(previousMonth)), findsOneWidget);
      final calendar = tester.widget<TableCalendar>(
        find.byWidgetPredicate((widget) => widget is TableCalendar),
      );
      expect(calendar.calendarFormat, CalendarFormat.month);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
