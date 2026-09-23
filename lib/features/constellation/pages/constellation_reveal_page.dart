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
import 'constellation_book_page.dart' show constellationByName;

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
              final result = createConstellationResult(stars);
              final entry = constellationByName(result.name);
              final rarity = computeRarity(
                stars,
                baseRarity: entry?.rarity ?? 1,
              );
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
                          result.name.isEmpty ? '静かな星座' : result.name,
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
                              : Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    if (result.imagePath.isNotEmpty)
                                      Opacity(
                                        opacity: .16,
                                        child: Image.asset(
                                          result.imagePath,
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, _, _) =>
                                              const SizedBox.shrink(),
                                        ),
                                      ),
                                    ConstellationMap(
                                      records: stars,
                                      shape: entry?.points,
                                    ),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          result.message.isEmpty
                              ? '今日は、まだ何も語られていない。'
                              : result.message,
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
