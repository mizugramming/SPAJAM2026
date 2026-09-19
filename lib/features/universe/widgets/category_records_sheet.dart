import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/design_tokens.dart';
import '../../../core/models/category_type.dart';
import '../../../core/providers/space_records_provider.dart';
import '../../../core/utils/record_queries.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/planet_orb.dart';
import '../../../core/widgets/record_list.dart';

class CategoryRecordsSheet extends ConsumerWidget {
  const CategoryRecordsSheet({super.key, required this.category});
  final CategoryType category;
  @override
  Widget build(BuildContext context, WidgetRef ref) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: .78,
    minChildSize: .4,
    maxChildSize: .95,
    builder: (context, scrollController) => ref
        .watch(spaceRecordsProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const ErrorState(),
          data: (all) {
            final records = chronological(
              all.where((r) => r.category == category),
            ).reversed.toList();
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              children: [
                Center(
                  child: PlanetOrb(
                    color: category.color,
                    size: 170,
                    stage: planetStage(records.length),
                    seed: category.index + 1,
                    rings: category == CategoryType.challenge,
                  ),
                ),
                Text(
                  '${category.label}の惑星',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  planetStageLabel(records.length),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: DesignTokens.muted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 28),
                if (records.isEmpty)
                  const EmptyState(message: 'まだ、静かに眠っている惑星。', showAction: false)
                else
                  RecordList(records: records, showDate: true),
              ],
            );
          },
        ),
  );
}
