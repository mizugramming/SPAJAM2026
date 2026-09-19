import 'package:flutter/material.dart';
import '../constants/design_tokens.dart';

class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    required this.children,
  });
  final String eyebrow;
  final String title;
  final String? subtitle;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 30, 24, 88),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: DesignTokens.pageWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow,
              style: const TextStyle(
                fontSize: 10,
                letterSpacing: 4,
                color: DesignTokens.muted,
              ),
            ),
            const SizedBox(height: 10),
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 28),
            ...children,
          ],
        ),
      ),
    ),
  );
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: DesignTokens.surface.withValues(alpha: .74),
      borderRadius: BorderRadius.circular(DesignTokens.radius),
      border: Border.all(color: DesignTokens.border.withValues(alpha: .8)),
    ),
    child: child,
  );
}

class GlowButton extends StatelessWidget {
  const GlowButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.north_east,
    this.busy = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  final bool busy;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(32),
      gradient: const LinearGradient(
        colors: [Color(0xFFF7D7B6), Color(0xFFD7B9E8), Color(0xFFAAA9ED)],
      ),
      boxShadow: onPressed == null
          ? null
          : [
              BoxShadow(
                color: DesignTokens.accent.withValues(alpha: .20),
                blurRadius: 24,
                spreadRadius: 1,
              ),
            ],
    ),
    child: FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: DesignTokens.background,
        disabledBackgroundColor: DesignTokens.surface.withValues(alpha: .9),
        minimumSize: const Size(double.infinity, 58),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (busy)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
              ),
            ),
          if (!busy) ...[const SizedBox(width: 12), Icon(icon, size: 18)],
        ],
      ),
    ),
  );
}
