import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/design_tokens.dart';
import '../../../core/models/space_record.dart';
import '../../../core/providers/space_records_provider.dart';
import '../../../core/utils/date_key.dart';
import '../../../core/utils/record_queries.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/page_frame.dart';
import '../../../core/widgets/record_list.dart';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});
  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  late DateTime _selected = localDay(DateTime.now());
  late DateTime _focused = _selected;
  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayProvider);
    return PageFrame(
      eyebrow: 'MOMENTS TO REMEMBER',
      title: '振り返り',
      subtitle: 'あの日の自分に、そっと会いにいく。',
      children: [
        ref
            .watch(spaceRecordsProvider)
            .when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const ErrorState(),
              data: (records) {
                final byDay = <String, List<SpaceRecord>>{};
                for (final record in records) {
                  byDay
                      .putIfAbsent(dateKey(record.createdAt), () => [])
                      .add(record);
                }
                final selected = recordsOnDay(records, _selected);
                var firstDay = DateTime(today.year - 100);
                var lastDay = DateTime(today.year + 1, 12, 31);
                for (final record in records) {
                  final day = localDay(record.createdAt);
                  if (day.isBefore(firstDay)) firstDay = day;
                  if (day.isAfter(lastDay)) lastDay = day;
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GlassPanel(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                      child: TableCalendar<SpaceRecord>(
                        locale: 'ja_JP',
                        firstDay: firstDay,
                        lastDay: lastDay,
                        focusedDay: _focused,
                        currentDay: today,
                        startingDayOfWeek: StartingDayOfWeek.monday,
                        availableGestures: AvailableGestures.horizontalSwipe,
                        daysOfWeekStyle: const DaysOfWeekStyle(
                          weekdayStyle: TextStyle(
                            color: DesignTokens.muted,
                            fontSize: 12,
                          ),
                          weekendStyle: TextStyle(
                            color: DesignTokens.muted,
                            fontSize: 12,
                          ),
                        ),
                        rowHeight: 49,
                        daysOfWeekHeight: 26,
                        selectedDayPredicate: (day) =>
                            isSameDay(day, _selected),
                        onDaySelected: (selected, focused) => setState(() {
                          _selected = localDay(selected);
                          _focused = focused;
                        }),
                        onPageChanged: (focused) => _focused = focused,
                        eventLoader: (day) => byDay[dateKey(day)] ?? const [],
                        headerStyle: const HeaderStyle(
                          formatButtonVisible: false,
                          titleCentered: true,
                          titleTextStyle: TextStyle(
                            fontSize: 15,
                            letterSpacing: 1,
                          ),
                          leftChevronIcon: Icon(Icons.chevron_left, size: 22),
                          rightChevronIcon: Icon(Icons.chevron_right, size: 22),
                        ),
                        calendarStyle: CalendarStyle(
                          outsideDaysVisible: false,
                          defaultTextStyle: const TextStyle(
                            color: DesignTokens.ink,
                            fontSize: 13,
                          ),
                          weekendTextStyle: const TextStyle(
                            color: DesignTokens.ink,
                            fontSize: 13,
                          ),
                          todayDecoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: DesignTokens.accent),
                          ),
                          selectedDecoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: DesignTokens.accent,
                          ),
                          selectedTextStyle: const TextStyle(
                            color: DesignTokens.background,
                          ),
                          markerDecoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: DesignTokens.gold,
                          ),
                          markersMaxCount: 1,
                          markerSize: 5,
                          cellMargin: const EdgeInsets.all(6),
                        ),
                        calendarBuilders: CalendarBuilders(
                          markerBuilder: (context, day, events) =>
                              events.isEmpty
                              ? null
                              : const Positioned(
                                  bottom: 0,
                                  child: Icon(
                                    Icons.star_rounded,
                                    color: DesignTokens.gold,
                                    size: 13,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      children: [
                        Text(
                          DateFormat('M月d日（E）', 'ja').format(_selected),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        TextButton(
                          onPressed: () =>
                              context.go(AppRoutes.constellationOn(_selected)),
                          child: const Text('この日の星座へ →'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (selected.isEmpty)
                      const EmptyState(
                        message: 'この日は、静かな余白。',
                        showAction: false,
                      )
                    else
                      RecordList(records: selected),
                  ],
                );
              },
            ),
      ],
    );
  }
}
