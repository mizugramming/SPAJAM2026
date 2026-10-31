import 'package:flutter/material.dart';

import 'player_ui.dart';

/// Map body for a parent-owned Scaffold.
///
/// The parent supplies map contents, progress, and available game actions.
/// Only the selected floor and each floor's viewport are kept locally.
class PlayerMapView extends StatefulWidget {
  const PlayerMapView({
    super.key,
    required this.courseName,
    required this.remainingTimeLabel,
    required this.progressLabel,
    required this.floors,
    required this.canScanGoal,
    this.initialFloor,
    this.onFloorChanged,
    this.onScanCheckpoint,
    this.onScanGoal,
    this.onOpenRanking,
    this.onOpenFreeMissions,
    this.goalStatusLabel,
  });

  final String courseName;
  final String remainingTimeLabel;
  final String progressLabel;

  /// Floor names mapped to parent-provided maps, including their markers.
  ///
  /// Each map receives a bounded 4:3 viewport. Supply static map contents to
  /// use this view's zoom controls. A directly supplied [InteractiveViewer]
  /// owns its gestures and controls, so it is not wrapped in another viewer.
  /// If a custom widget handles pan/zoom internally, verify its interaction
  /// with the outer viewer: hidden recognizers cannot be detected here.
  final Map<String, Widget> floors;
  final String? initialFloor;
  final ValueChanged<String>? onFloorChanged;
  final VoidCallback? onScanCheckpoint;
  final VoidCallback? onScanGoal;

  /// Uses the common game state; no goal conditions are inferred by this view.
  final bool canScanGoal;
  final VoidCallback? onOpenRanking;
  final VoidCallback? onOpenFreeMissions;
  final String? goalStatusLabel;

  @override
  State<PlayerMapView> createState() => _PlayerMapViewState();
}

class _PlayerMapViewState extends State<PlayerMapView> {
  static const _minScale = 1.0;
  static const _maxScale = 4.0;

  final _viewportKey = GlobalKey();
  final _floorTransforms = <String, TransformationController>{};
  String? _selectedFloor;

  @override
  void initState() {
    super.initState();
    _syncFloorTransforms();
    _selectedFloor = _availableFloor(widget.initialFloor);
  }

  @override
  void didUpdateWidget(covariant PlayerMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncFloorTransforms();
    _selectedFloor = _availableFloor(_selectedFloor);
  }

  @override
  void dispose() {
    for (final controller in _floorTransforms.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _syncFloorTransforms() {
    final removed = _floorTransforms.keys.where((floor) => !widget.floors.containsKey(floor)).toList();
    for (final floor in removed) {
      _floorTransforms.remove(floor)!.dispose();
    }
    for (final floor in widget.floors.keys) {
      _floorTransforms.putIfAbsent(floor, TransformationController.new);
    }
  }

  String? _availableFloor(String? preferredFloor) {
    if (widget.floors.containsKey(preferredFloor)) {
      return preferredFloor;
    }
    return widget.floors.isEmpty ? null : widget.floors.keys.first;
  }

  void _selectFloor(String floor) {
    if (floor == _selectedFloor) return;
    setState(() => _selectedFloor = floor);
    widget.onFloorChanged?.call(floor);
  }

  void _zoom(TransformationController controller, double factor) {
    final size = _viewportKey.currentContext?.size;
    if (size == null || size.isEmpty) return;
    final scale = controller.value.getMaxScaleOnAxis();
    final nextScale = (scale * factor).clamp(_minScale, _maxScale).toDouble();
    final center = Offset(size.width / 2, size.height / 2);
    final sceneCenter = controller.toScene(center);
    final dx = (center.dx - sceneCenter.dx * nextScale).clamp(size.width * (1 - nextScale), 0.0).toDouble();
    final dy = (center.dy - sceneCenter.dy * nextScale).clamp(size.height * (1 - nextScale), 0.0).toDouble();
    controller.value = Matrix4.identity()
      ..setEntry(0, 0, nextScale)
      ..setEntry(1, 1, nextScale)
      ..setEntry(0, 3, dx)
      ..setEntry(1, 3, dy);
  }

  Widget _buildZoomControls(TransformationController controller) {
    return ValueListenableBuilder<Matrix4>(
      valueListenable: controller,
      builder: (context, transform, _) {
        final scale = transform.getMaxScaleOnAxis();
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              key: const ValueKey('playerMapZoomIn'),
              onPressed: scale < _maxScale - 0.001 ? () => _zoom(controller, 1.5) : null,
              icon: const Icon(Icons.add),
              label: const Text('拡大'),
            ),
            OutlinedButton.icon(
              key: const ValueKey('playerMapZoomOut'),
              onPressed: scale > _minScale + 0.001 ? () => _zoom(controller, 1 / 1.5) : null,
              icon: const Icon(Icons.remove),
              label: const Text('縮小'),
            ),
            TextButton.icon(
              key: const ValueKey('playerMapReset'),
              onPressed: () => controller.value = Matrix4.identity(),
              icon: const Icon(Icons.fit_screen),
              label: const Text('全体表示'),
            ),
            Semantics(
              label: 'マップの拡大率 ${(scale * 100).round()}パーセント',
              child: ExcludeSemantics(child: Text('${(scale * 100).round()}%')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = PlayerNight.themeOf(context);
    final selectedFloor = _availableFloor(_selectedFloor);
    final map = widget.floors[selectedFloor];
    final controller = _floorTransforms[selectedFloor];
    final ownsGestures = map is InteractiveViewer;

    return PlayerPage(
      title: widget.courseName,
      eyebrow: 'FIELD MAP',
      compactHeader: true,
      actions: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton.icon(
            onPressed: widget.onScanCheckpoint,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('チェックポイントQRを読み取る'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: widget.canScanGoal ? widget.onScanGoal : null,
            icon: const Icon(Icons.flag_outlined),
            label: const Text('ゴールQRを読み取る'),
          ),
        ],
      ),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final stackMetrics = constraints.maxWidth < 280 || MediaQuery.textScalerOf(context).scale(16) > 24;
            final time = PlayerMetric(
              label: '残り時間',
              value: widget.remainingTimeLabel,
              icon: Icons.timer_outlined,
              accent: true,
            );
            final progress = PlayerMetric(
              label: '進捗',
              value: widget.progressLabel,
              icon: Icons.route_outlined,
              compactValue: true,
            );
            if (stackMetrics) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [time, const SizedBox(height: 10), progress],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: time),
                const SizedBox(width: 10),
                Expanded(child: progress),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Semantics(header: true, child: Text('館内マップ', style: theme.textTheme.titleLarge)),
            ExcludeSemantics(
              child: Text(
                'FLOOR PLAN',
                style: theme.textTheme.labelSmall?.copyWith(color: PlayerNight.cyan, letterSpacing: 1.8),
              ),
            ),
          ],
        ),
        if (map != null && controller != null) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final floor in widget.floors.keys)
                Semantics(
                  key: ValueKey('playerFloor:$floor'),
                  button: true,
                  selected: floor == selectedFloor,
                  label: '$floorのマップを表示',
                  onTap: () => _selectFloor(floor),
                  child: ExcludeSemantics(
                    child: ChoiceChip(
                      label: Text(floor),
                      selected: floor == selectedFloor,
                      selectedColor: PlayerNight.lime,
                      backgroundColor: PlayerNight.surface,
                      checkmarkColor: PlayerNight.ink,
                      labelStyle: theme.textTheme.labelLarge?.copyWith(
                        color: floor == selectedFloor ? PlayerNight.ink : PlayerNight.muted,
                        fontWeight: FontWeight.w700,
                      ),
                      side: BorderSide(color: floor == selectedFloor ? PlayerNight.lime : PlayerNight.line),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      onSelected: (_) => _selectFloor(floor),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Semantics(
            container: true,
            label: '$selectedFloorのマップ',
            child: _MapViewportFrame(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: AspectRatio(
                  key: _viewportKey,
                  aspectRatio: 4 / 3,
                  child: ownsGestures
                      ? KeyedSubtree(key: ValueKey('playerSuppliedMap:$selectedFloor'), child: map)
                      : InteractiveViewer(
                          key: ValueKey('playerMapViewer:$selectedFloor'),
                          transformationController: controller,
                          minScale: _minScale,
                          maxScale: _maxScale,
                          child: SizedBox.expand(
                            child: KeyedSubtree(key: ValueKey(selectedFloor), child: map),
                          ),
                        ),
                ),
              ),
            ),
          ),
          if (!ownsGestures) ...[
            const SizedBox(height: 8),
            _buildZoomControls(controller),
            const SizedBox(height: 4),
            Text('2本指で拡大・縮小 · ドラッグで移動', style: theme.textTheme.bodySmall),
          ],
        ] else ...[
          const SizedBox(height: 12),
          const PlayerNotice(message: '表示できるマップがありません。会場の案内やスタッフに場所を確認してください。', icon: Icons.map_outlined),
        ],
        if (widget.goalStatusLabel != null || !widget.canScanGoal) ...[
          const SizedBox(height: 16),
          PlayerNotice(message: widget.goalStatusLabel ?? '現在はゴールQRを読み取れません。', icon: Icons.flag_outlined),
        ],
        if (widget.onOpenFreeMissions != null || widget.onOpenRanking != null) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              if (widget.onOpenFreeMissions != null)
                TextButton.icon(
                  onPressed: widget.onOpenFreeMissions,
                  icon: const Icon(Icons.explore_outlined),
                  label: const Text('自由ミッション'),
                ),
              if (widget.onOpenRanking != null)
                TextButton.icon(
                  onPressed: widget.onOpenRanking,
                  icon: const Icon(Icons.leaderboard_outlined),
                  label: const Text('ランキング'),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Technical framing belongs to the player UI; supplied maps keep their own
/// colors, markers and gesture recognizers unchanged.
class _MapViewportFrame extends StatelessWidget {
  const _MapViewportFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: PlayerNight.surface,
      border: Border.all(color: PlayerNight.line),
      borderRadius: BorderRadius.circular(12),
    ),
    child: CustomPaint(
      painter: const _MapGridPainter(),
      foregroundPainter: const _MapCornersPainter(),
      child: Padding(padding: const EdgeInsets.all(8), child: child),
    ),
  );
}

class _MapGridPainter extends CustomPainter {
  const _MapGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = PlayerNight.line.withValues(alpha: 0.45)
      ..strokeWidth = 0.5;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)));
    for (var x = 8.0; x < size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 8.0; y < size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MapGridPainter oldDelegate) => false;
}

class _MapCornersPainter extends CustomPainter {
  const _MapCornersPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final marker = Paint()
      ..color = PlayerNight.cyan
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const inset = 4.0;
    const length = 12.0;
    for (final corner in [
      const Offset(inset, inset),
      Offset(size.width - inset, inset),
      Offset(inset, size.height - inset),
      Offset(size.width - inset, size.height - inset),
    ]) {
      final dx = corner.dx < size.width / 2 ? length : -length;
      final dy = corner.dy < size.height / 2 ? length : -length;
      canvas.drawPath(
        Path()
          ..moveTo(corner.dx + dx, corner.dy)
          ..lineTo(corner.dx, corner.dy)
          ..lineTo(corner.dx, corner.dy + dy),
        marker,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MapCornersPainter oldDelegate) => false;
}
