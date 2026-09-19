import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/design_tokens.dart';
import '../../../core/models/constellation_rarity.dart';
import '../../../core/providers/space_records_provider.dart';
import '../../../core/utils/constellation_name.dart';
import '../../../core/utils/record_queries.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/page_frame.dart';
import '../../../core/widgets/space_background.dart';
import '../widgets/constellation_map.dart';
import '../widgets/rarity_badge.dart';

class ConstellationRevealPage extends ConsumerWidget {
  const ConstellationRevealPage({super.key, required this.date});
  final DateTime date;

  void _close(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(spaceRecordsProvider);
    return Scaffold(
      body: SpaceBackground(
        scenic: true,
        child: SafeArea(
          child: recordsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const Center(child: ErrorState()),
            data: (all) {
              final stars = recordsOnDay(all, date);
              final rarity = computeRarity(stars);
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 48, 28, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      children: [
                        const Text(
                          'CONSTELLATION',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 4,
                            color: DesignTokens.muted,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          constellationName(stars),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          DateFormat('yyyy年M月d日（E）', 'ja').format(date),
                          style: const TextStyle(
                            fontSize: 12,
                            color: DesignTokens.muted,
                          ),
                        ),
                        const SizedBox(height: 20),
                        RarityBadge(rarity: rarity),
                        const SizedBox(height: 28),
                        GlassPanel(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16,
                          ),
                          child: stars.isEmpty
                              ? const EmptyState(
                                  message: 'この日は、静かな宇宙。',
                                  showAction: false,
                                )
                              : ConstellationMap(records: stars),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          constellationDescription(stars),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: DesignTokens.ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${stars.length}つの星が、この星座になりました。',
                          style: const TextStyle(
                            fontSize: 11,
                            color: DesignTokens.muted,
                          ),
                        ),
                        const SizedBox(height: 40),
                        OutlinedButton(
                          onPressed: () => _close(context),
                          child: const Text('閉じる'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
