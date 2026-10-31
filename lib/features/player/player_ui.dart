import 'package:flutter/material.dart';

import 'player_night_style.dart';
export 'player_night_style.dart';

/// Player-only body layout. The application owns its Scaffold and global theme.
/// Actions stay visible when space permits and join the scroll content when
/// the keyboard, a short window, or large text reduces the available space.
class PlayerPage extends StatelessWidget {
  const PlayerPage({
    super.key,
    required this.title,
    required this.children,
    this.description,
    this.actions,
    this.compactHeader = false,
    this.eyebrow,
  });

  final String title;
  final String? description;
  final List<Widget> children;
  final Widget? actions;
  final bool compactHeader;
  final String? eyebrow;

  @override
  Widget build(BuildContext context) {
    final theme = PlayerNight.themeOf(context);
    return Theme(
      data: theme,
      child: LayoutBuilder(
        builder: (context, constraints) => SizedBox(
          width: constraints.hasBoundedWidth ? constraints.maxWidth : null,
          height: constraints.hasBoundedHeight ? constraints.maxHeight : null,
          child: DefaultTextStyle(
            style: theme.textTheme.bodyMedium!,
            child: ColoredBox(
              color: PlayerNight.background,
              child: CustomPaint(
                painter: const _BlueprintGrid(),
                child: Builder(builder: (context) => _buildBody(context, theme)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ThemeData theme) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final pinActions =
              actions != null &&
              constraints.hasBoundedHeight &&
              constraints.maxHeight >= 480 &&
              MediaQuery.textScalerOf(context).scale(16) <= 24;
          final content = SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(20),
            child: _ReadableWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _MissionHeader(title: title, description: description, compact: compactHeader, eyebrow: eyebrow),
                  SizedBox(height: compactHeader ? 16 : 24),
                  ...children,
                  if (actions != null && !pinActions) ...[const SizedBox(height: 24), actions!],
                ],
              ),
            ),
          );
          if (!pinActions) return content;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: content),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: PlayerNight.background,
                  border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: _ReadableWidth(child: actions!),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReadableWidth extends StatelessWidget {
  const _ReadableWidth({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: SizedBox(width: double.infinity, child: child),
    ),
  );
}

/// A consistent night panel within the player feature.
class PlayerSection extends StatelessWidget {
  const PlayerSection({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [PlayerNight.raised, PlayerNight.surface],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      border: Border.all(color: PlayerNight.line),
      borderRadius: BorderRadius.circular(14),
    ),
    child: CustomPaint(
      foregroundPainter: const _PanelCorners(),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  );
}

/// An announced status with a text description independent of its color/icon.
class PlayerNotice extends StatelessWidget {
  const PlayerNotice({
    super.key,
    required this.message,
    this.icon = Icons.info_outline,
    this.isError = false,
    this.busy = false,
  });

  final String message;
  final IconData icon;
  final bool isError;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final foreground = isError ? PlayerNight.error : PlayerNight.cyan;
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isError ? const Color(0xFF30262E) : PlayerNight.surface,
          border: Border.all(color: isError ? const Color(0xFF7E4F53) : PlayerNight.line),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: busy
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
                      )
                    : Icon(icon, color: foreground),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: PlayerNight.themeOf(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: isError ? PlayerNight.text : PlayerNight.muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MissionHeader extends StatelessWidget {
  const _MissionHeader({required this.title, required this.compact, this.description, this.eyebrow});
  final String title;
  final String? description;
  final bool compact;
  final String? eyebrow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const ExcludeSemantics(child: Icon(Icons.explore_outlined, color: PlayerNight.cyan, size: 26)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'まよいクエスト',
                style: theme.textTheme.titleMedium?.copyWith(color: PlayerNight.cyan, fontWeight: FontWeight.w800),
              ),
            ),
            const ExcludeSemantics(child: Icon(Icons.map_outlined, color: PlayerNight.cyan, size: 22)),
          ],
        ),
        const SizedBox(height: 16),
        if (eyebrow != null) ...[
          ExcludeSemantics(
            child: Text(
              eyebrow!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: PlayerNight.cyan,
                fontSize: 10,
                letterSpacing: 2.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
        Semantics(
          header: true,
          child: Text(title, style: compact ? theme.textTheme.titleMedium : theme.textTheme.headlineSmall),
        ),
        if (description != null && description!.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(description!, style: theme.textTheme.bodyMedium?.copyWith(color: PlayerNight.muted)),
        ],
      ],
    );
  }
}

class PlayerMetric extends StatelessWidget {
  const PlayerMetric({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.accent = false,
    this.compactValue = false,
  });
  final String label;
  final String value;
  final IconData? icon;
  final bool accent;
  final bool compactValue;

  @override
  Widget build(BuildContext context) {
    final theme = PlayerNight.themeOf(context);
    return PlayerSection(
      child: MergeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[
                  ExcludeSemantics(child: Icon(icon, size: 18, color: PlayerNight.cyan)),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(label, style: theme.textTheme.labelMedium?.copyWith(color: PlayerNight.muted)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: (compactValue ? theme.textTheme.titleMedium : theme.textTheme.headlineSmall)?.copyWith(
                color: accent ? PlayerNight.lime : PlayerNight.text,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlueprintGrid extends CustomPainter {
  const _BlueprintGrid();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x0986D5E2)
      ..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BlueprintGrid oldDelegate) => false;
}

class _PanelCorners extends CustomPainter {
  const _PanelCorners();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x9986D5E2)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(
      Path()
        ..moveTo(8, 22)
        ..lineTo(8, 8)
        ..lineTo(22, 8),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width - 22, size.height - 8)
        ..lineTo(size.width - 8, size.height - 8)
        ..lineTo(size.width - 8, size.height - 22),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _PanelCorners oldDelegate) => false;
}
