import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/constants/design_tokens.dart';
import '../../../core/providers/space_records_provider.dart';
import '../../../core/utils/record_queries.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/planet_orb.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    final records = ref.watch(spaceRecordsProvider);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF071A2A),
              Color(0xFF112C42),
              Color(0xFF1D3850),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        DateFormat('M月d日（E）', 'ja').format(today),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Column(
                      children: [
                        Text(
                          '余 白',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w200,
                            letterSpacing: 10,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'すこし、止まって。わたしを見つける。',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white60,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    const Center(
                      child: PlanetOrb(
                        color: Color(0xFF90B8BE),
                        size: 130,
                        stage: 3,
                        seed: 8,
                        rings: true,
                      ),
                    ),

                    const SizedBox(height: 20),

                    records.when(
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(
                            color: Colors.white70,
                          ),
                        ),
                      ),
                      error: (_, _) => const ErrorState(),
                      data: (all) {
                        final stars = recordsOnDay(all, today);

                        return GestureDetector(
                          onTap: () => context.go(AppRoutes.constellationOn(today)),
                          child: GlassCard(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 16,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '今日の余白',
                                        style: TextStyle(
                                          fontSize: 11,
                                          letterSpacing: 2,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(width: 4),
                                      Icon(
                                        Icons.chevron_right,
                                        color: Colors.white54,
                                        size: 14,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  if (stars.isEmpty) ...[
                                    const Icon(
                                      Icons.auto_awesome_outlined,
                                      color: DesignTokens.gold,
                                      size: 20,
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'あなたのペースで、星をひとつ。',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ] else ...[
                                    Wrap(
                                      alignment: WrapAlignment.center,
                                      spacing: 12,
                                      runSpacing: 4,
                                      children: stars
                                          .take(7)
                                          .map(
                                            (r) => Tooltip(
                                              message:
                                                  '${r.emotion.label}・${r.category.label}',
                                              child: Icon(
                                                Icons.star_rounded,
                                                color: r.emotion.color,
                                                size: 24,
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${stars.length}つの気持ちが、星になりました。',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    SpaceKeyButton(
                      onPressed: () => context.push(AppRoutes.space),
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => context.go(AppRoutes.universe),
                            icon: const Icon(Icons.public, size: 14),
                            label: const Text(
                              '宇宙を眺める',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => context.go(AppRoutes.history),
                            icon: const Icon(
                              Icons.calendar_month_outlined,
                              size: 14,
                            ),
                            label: const Text(
                              '振り返る',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;

  const GlassCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withOpacity(0.18),
              width: 1.2,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class SpaceKeyButton extends StatefulWidget {
  final VoidCallback onPressed;

  const SpaceKeyButton({super.key, required this.onPressed});

  @override
  State<SpaceKeyButton> createState() => _SpaceKeyButtonState();
}

class _SpaceKeyButtonState extends State<SpaceKeyButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        SystemSound.play(SystemSoundType.click);
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: SizedBox(
        height: 54,
        width: double.infinity,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              height: 46,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 70),
              bottom: _isPressed ? 0 : 5,
              left: 0,
              right: 0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.25),
                        width: 1.2,
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.2),
                          Colors.white.withOpacity(0.05),
                        ],
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4.0),
                      child: Text(
                        'SPACE',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 4.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}