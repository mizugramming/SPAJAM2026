import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/design_tokens.dart';
import '../../../core/models/category_type.dart';
import '../../../core/providers/space_records_provider.dart';
import '../../../core/utils/record_queries.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/page_frame.dart';
import '../../../core/widgets/planet_orb.dart';
import '../widgets/category_records_sheet.dart';

class UniversePage extends ConsumerWidget {
  const UniversePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => PageFrame(
    eyebrow: 'YOUR LITTLE UNIVERSE',
    title: 'あなたの宇宙',
    subtitle: 'どんな気持ちも、この宇宙を育てている。',
    children: [
      ref
          .watch(spaceRecordsProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const ErrorState(),
            data: (records) {
              final counts = categoryCounts(records);
              return LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth > 600 ? 3 : 2;
                  final width =
                      (constraints.maxWidth - 14 * (columns - 1)) / columns;
                  return Wrap(
                    spacing: 14,
                    runSpacing: 18,
                    children: [
                      for (final category in CategoryType.values)
                        SizedBox(
                          width: width,
                          child: Semantics(
                            button: true,
                            label:
                                '${category.label}、${planetStageLabel(counts[category]!)}',
                            child: Material(
                              color: DesignTokens.surface.withValues(
                                alpha: .46,
                              ),
                              borderRadius: BorderRadius.circular(24),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(24),
                                onTap: () => showModalBottomSheet<void>(
                                  context: context,
                                  isScrollControlled: true,
                                  useSafeArea: true,
                                  builder: (_) =>
                                      CategoryRecordsSheet(category: category),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    8,
                                    16,
                                    8,
                                    22,
                                  ),
                                  child: Column(
                                    children: [
                                      SizedBox(
                                        height: 126,
                                        child: Center(
                                          child: PlanetOrb(
                                            color: category.color,
                                            size:
                                                86 +
                                                planetStage(counts[category]!) *
                                                    15.0,
                                            stage: planetStage(
                                              counts[category]!,
                                            ),
                                            seed: category.index + 1,
                                            rings:
                                                category ==
                                                CategoryType.challenge,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        category.label,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        planetStageLabel(counts[category]!),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: DesignTokens.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
      const SizedBox(height: 28),
      const Center(
        child: Text(
          'うれしさも、不安も。\n残した気持ちは、ひとつずつ惑星の一部に。',
          textAlign: TextAlign.center,
          style: TextStyle(color: DesignTokens.muted, fontSize: 12, height: 2),
        ),
      ),
    ],
  );
}
