import 'package:flutter/material.dart';
import '../../../core/constants/design_tokens.dart';

class ChoiceTile extends StatelessWidget {
  const ChoiceTile({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
    this.hint,
  });
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final String? hint;
  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);
    return Semantics(
      selected: selected,
      button: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AnimatedScale(
          scale: selected ? 1.02 : 1,
          duration: duration,
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: duration,
            decoration: BoxDecoration(
              color: selected
                  ? color.withValues(alpha: .12)
                  : DesignTokens.surface.withValues(alpha: .72),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: selected
                    ? color.withValues(alpha: .8)
                    : DesignTokens.border,
                width: selected ? 1.2 : .7,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: .18),
                        blurRadius: 22,
                        spreadRadius: 1,
                      ),
                    ]
                  : const [],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(22),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              color.withValues(alpha: selected ? .42 : .27),
                              color.withValues(alpha: .07),
                            ],
                          ),
                        ),
                        child: Icon(Icons.star_rounded, color: color, size: 25),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Row(
                          children: [
                            Icon(icon, color: color, size: 18),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                label,
                                style: const TextStyle(fontSize: 15),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        selected ? Icons.check_circle : Icons.circle_outlined,
                        color: selected ? color : DesignTokens.muted,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
