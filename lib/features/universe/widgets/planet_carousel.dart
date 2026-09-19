import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import '../../../core/constants/design_tokens.dart';
import '../../../core/models/category_type.dart';
import '../../../core/utils/record_queries.dart';
import '../../../core/widgets/planet_orb.dart';

/// A continuous orbit: drag distance and release velocity determine travel.
class PlanetCarousel extends StatefulWidget {
  const PlanetCarousel({
    super.key,
    required this.counts,
    required this.initialCategory,
    required this.onChanged,
    required this.onOpen,
  });

  final Map<CategoryType, int> counts;
  final CategoryType initialCategory;
  final ValueChanged<CategoryType> onChanged;
  final VoidCallback onOpen;

  @override
  State<PlanetCarousel> createState() => _PlanetCarouselState();
}

class _PlanetCarouselState extends State<PlanetCarousel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _orbit = AnimationController.unbounded(
    vsync: this,
    value: widget.initialCategory.index.toDouble(),
  )..addListener(_changed);
  late int _selected = widget.initialCategory.index;
  static final _length = CategoryType.values.length;

  void _changed() {
    final next = _orbit.value.round() % _length;
    if (next != _selected) {
      _selected = next;
      widget.onChanged(CategoryType.values[next]);
    }
    setState(() {});
  }

  Future<void> _settle(double velocity) async {
    final motion = FrictionSimulation(
      .025,
      _orbit.value,
      velocity.clamp(-16.0, 16.0),
      tolerance: const Tolerance(velocity: .25, distance: .01),
    );
    if (MediaQuery.disableAnimationsOf(context)) {
      _orbit.value = motion.finalX.roundToDouble() % _length;
      return;
    }
    try {
      if (velocity.abs() > .25) {
        await _orbit.animateWith(motion).orCancel;
      }
      await _orbit
          .animateTo(
            _orbit.value.roundToDouble(),
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
          )
          .orCancel;
      _orbit.value %= _length;
    } on TickerCanceled {
      // A new gesture takes over immediately, or the page was disposed.
    }
  }

  Future<void> _select(int index) async {
    _orbit.stop();
    final delta = (index - _orbit.value + _length / 2) % _length - _length / 2;
    final target = _orbit.value + delta;
    if (MediaQuery.disableAnimationsOf(context)) {
      _orbit.value = target;
      return;
    }
    try {
      await _orbit
          .animateTo(
            target,
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeInOutCubic,
          )
          .orCancel;
    } on TickerCanceled {
      // Tapping another planet or dragging interrupts this transition.
    }
  }

  @override
  void dispose() {
    _orbit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final extent = width * .52;
          final planets = CategoryType.values.map((category) {
            final angle =
                (category.index - _orbit.value) * math.pi * 2 / _length;
            return (
              category: category,
              depth: (math.cos(angle) + 1) / 2,
              x: math.sin(angle) * width * .39,
            );
          }).toList()..sort((a, b) => a.depth.compareTo(b.depth));
          return GestureDetector(
            key: const ValueKey('planet-orbit'),
            behavior: HitTestBehavior.opaque,
            onHorizontalDragDown: (_) => _orbit.stop(),
            onHorizontalDragUpdate: (details) =>
                _orbit.value -= details.delta.dx / extent,
            onHorizontalDragEnd: (details) =>
                _settle(-details.velocity.pixelsPerSecond.dx / extent),
            onHorizontalDragCancel: () => _settle(0),
            child: SizedBox(
              height: 280,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(painter: _OrbitPainter()),
                    ),
                  ),
                  for (final planet in planets)
                    Positioned(
                      key: ValueKey(planet.category),
                      left: width / 2 + planet.x - width * .38,
                      top: 15 + planet.depth * 46,
                      width: width * .76,
                      height: 220,
                      child: Center(
                        child: Transform.scale(
                          scale: .38 + planet.depth * .62,
                          child: Opacity(
                            opacity: .35 + planet.depth * .65,
                            child: TweenAnimationBuilder<double>(
                              duration: MediaQuery.disableAnimationsOf(context)
                                  ? Duration.zero
                                  : const Duration(milliseconds: 650),
                              curve: Curves.easeOutCubic,
                              tween: Tween(
                                end:
                                    width *
                                    (.57 +
                                        .19 *
                                            (1 -
                                                math.exp(
                                                  -(widget.counts[planet
                                                              .category] ??
                                                          0) /
                                                      12,
                                                ))),
                              ),
                              builder: (context, size, _) => Semantics(
                                button: true,
                                selected: planet.category.index == _selected,
                                label: '${planet.category.label}の惑星',
                                child: GestureDetector(
                                  key: ValueKey('planet-${planet.category.id}'),
                                  onTap: () {
                                    if (planet.category.index == _selected) {
                                      widget.onOpen();
                                    } else {
                                      _select(planet.category.index);
                                    }
                                  },
                                  child: PlanetOrb(
                                    key: ValueKey('orb-${planet.category.id}'),
                                    color: planet.category.color,
                                    size: size,
                                    stage: planetStage(
                                      widget.counts[planet.category] ?? 0,
                                    ),
                                    seed: planet.category.index + 1,
                                    rings:
                                        planet.category ==
                                        CategoryType.challenge,
                                  ),
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
        },
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: '前の惑星',
            onPressed: () => _select(_selected - 1),
            icon: const Icon(Icons.chevron_left, size: 20),
          ),
          for (final category in CategoryType.values)
            Semantics(
              selected: category.index == _selected,
              child: Tooltip(
                message: '${category.label}を表示',
                child: InkResponse(
                  onTap: () => _select(category.index),
                  radius: 22,
                  child: SizedBox(
                    width: 28,
                    height: 48,
                    child: Center(
                      child: Container(
                        width: category.index == _selected ? 18 : 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: category.index == _selected
                              ? category.color
                              : DesignTokens.muted.withValues(alpha: .35),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          IconButton(
            tooltip: '次の惑星',
            onPressed: () => _select(_selected + 1),
            icon: const Icon(Icons.chevron_right, size: 20),
          ),
        ],
      ),
      const Text(
        '指でなぞって、宇宙をめぐる',
        style: TextStyle(
          color: DesignTokens.muted,
          fontSize: 11,
          letterSpacing: 1,
        ),
      ),
    ],
  );
}

class _OrbitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final oval = Rect.fromCenter(
      center: Offset(size.width / 2, 144),
      width: size.width * .84,
      height: 110,
    );
    canvas.drawOval(
      oval,
      Paint()
        ..color = DesignTokens.gold.withValues(alpha: .13)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .7,
    );
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter oldDelegate) => false;
}
