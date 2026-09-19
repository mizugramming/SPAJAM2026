import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/design_tokens.dart';
import '../../../core/models/category_type.dart';
import '../../../core/providers/space_records_provider.dart';
import '../../../core/utils/record_queries.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/record_list.dart';
import '../widgets/category_records_sheet.dart';
import '../widgets/planet_carousel.dart';

class UniversePage extends ConsumerStatefulWidget {
  const UniversePage({super.key});

  @override
  ConsumerState<UniversePage> createState() => _UniversePageState();
}

class _UniversePageState extends ConsumerState<UniversePage> {
  CategoryType _selected = CategoryType.challenge;

  void _openRecords() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => CategoryRecordsSheet(category: _selected),
  );

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayProvider);
    return ref
        .watch(spaceRecordsProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const ErrorState(),
          data: (records) {
            final counts = categoryCounts(records);
            final todaysRecords = recordsOnDay(
              records.where((record) => record.category == _selected),
              today,
            ).reversed.toList();
            return SingleChildScrollView(
              key: const PageStorageKey('universe-scroll'),
              padding: const EdgeInsets.fromLTRB(0, 28, 0, 104),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'YOUR LITTLE UNIVERSE',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 4,
                            color: DesignTokens.muted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'あなたの宇宙',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 24),
                        Center(
                          child: Text(
                            _selected.label,
                            key: const ValueKey('selected-planet-title'),
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: _selected.color,
                                  letterSpacing: 4,
                                ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Center(
                          child: Text(
                            '${planetStageLabel(counts[_selected]!)}  ·  これまで ${counts[_selected]} 個の星',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PlanetCarousel(
                    counts: counts,
                    initialCategory: _selected,
                    onChanged: (category) =>
                        setState(() => _selected = category),
                    onOpen: _openRecords,
                  ),
                  const SizedBox(height: 30),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Divider(color: DesignTokens.border, height: 1),
                        const SizedBox(height: 24),
                        Text(
                          '${DateFormat('M月d日', 'ja').format(today)} · ${_selected.label}',
                          style: TextStyle(
                            color: _selected.color,
                            fontSize: 11,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '今日、届いた記録',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 18),
                        if (todaysRecords.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              '今日はまだ、この惑星に星が届いていません。\n残したくなったときに、ひとつずつ。',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          )
                        else
                          RecordList(records: todaysRecords),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: _openRecords,
                            label: const Text('この惑星のすべての記録'),
                            icon: const Icon(Icons.arrow_forward, size: 16),
                            iconAlignment: IconAlignment.end,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
  }
}
