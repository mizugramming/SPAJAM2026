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
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: selected
            ? color.withValues(alpha: .16)
            : DesignTokens.surface.withValues(alpha: .65),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: selected ? color : DesignTokens.border,
            width: selected ? 1.3 : .6,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Icon(icon, color: color, size: 26),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: const TextStyle(fontSize: 16)),
                      if (hint != null)
                        Text(
                          hint!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: DesignTokens.muted,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  color: selected ? color : DesignTokens.border,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
