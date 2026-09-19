import 'package:flutter/material.dart';
import '../../../core/constants/design_tokens.dart';

class PlanetChoice extends StatelessWidget {
  const PlanetChoice({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
    required this.width,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: SizedBox(
        width: width,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  AnimatedScale(
                    scale: selected ? 1.06 : 1,
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    child: AnimatedContainer(
                      duration: duration,
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          center: const Alignment(-.35, -.4),
                          colors: [
                            color.withValues(alpha: selected ? .82 : .62),
                            color.withValues(alpha: .34),
                            DesignTokens.surface,
                          ],
                          stops: const [0, .55, 1],
                        ),
                        border: Border.all(
                          color: selected ? color : DesignTokens.border,
                          width: selected ? 2 : 1,
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: .27),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ]
                            : const [],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(icon, color: DesignTokens.ink, size: 30),
                          if (selected)
                            const Positioned(
                              right: 5,
                              bottom: 5,
                              child: Icon(
                                Icons.check_circle,
                                size: 20,
                                color: DesignTokens.ink,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: selected ? DesignTokens.ink : DesignTokens.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
