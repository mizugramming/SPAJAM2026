import 'package:flutter/material.dart';

import '../../core/models/course.dart';
import 'player_night_style.dart';

/// Location list used until an actual floor plan and checkpoint positions exist.
///
/// This list needs a bounded viewport and owns its vertical scrolling. When
/// supplied to `PlayerMapView`, put it directly inside an [InteractiveViewer]
/// with pan and scale disabled so the map view does not add gesture handling.
class PlayerCourseMap extends StatefulWidget {
  const PlayerCourseMap({
    super.key,
    required this.floor,
    required this.checkpoints,
    required this.clearedCheckpointIds,
  });

  final String floor;
  final List<Checkpoint> checkpoints;
  final Set<String> clearedCheckpointIds;

  @override
  State<PlayerCourseMap> createState() => _PlayerCourseMapState();
}

class _PlayerCourseMapState extends State<PlayerCourseMap> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final checkpoints = widget.checkpoints.where((checkpoint) => checkpoint.floor == widget.floor).toList();
    return ColoredBox(
      color: PlayerNight.background,
      child: Scrollbar(
        controller: _scrollController,
        child: ListView.builder(
          key: PageStorageKey('playerCourseLocations:${widget.floor}'),
          controller: _scrollController,
          primary: false,
          padding: const EdgeInsets.all(12),
          itemCount: checkpoints.isEmpty ? 2 : checkpoints.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text('仮コース・地点一覧', style: theme.textTheme.titleSmall?.copyWith(color: PlayerNight.cyan)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '実際の館内図は未登録です。位置・経路は会場の案内やスタッフに確認してください。',
                      style: theme.textTheme.bodySmall?.copyWith(color: PlayerNight.muted),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${widget.floor}の地点・上下にスクロール',
                      style: theme.textTheme.bodySmall?.copyWith(color: PlayerNight.muted),
                    ),
                  ],
                ),
              );
            }
            if (checkpoints.isEmpty) {
              return Text('このフロアの地点はありません。', style: theme.textTheme.bodyMedium?.copyWith(color: PlayerNight.text));
            }
            final checkpoint = checkpoints[index - 1];
            return _LocationCard(
              key: ValueKey('playerCourseLocation:${checkpoint.id}'),
              checkpoint: checkpoint,
              cleared: widget.clearedCheckpointIds.contains(checkpoint.id),
            );
          },
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({super.key, required this.checkpoint, required this.cleared});

  final Checkpoint checkpoint;
  final bool cleared;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kind = checkpoint.required ? '指定チェックポイント' : '自由ミッション';
    final status = cleared ? '達成済み' : '未達成';
    final accent = cleared ? PlayerNight.lime : PlayerNight.cyan;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        container: true,
        label: '${checkpoint.name}、$kind、${checkpoint.points}点、$status',
        child: ExcludeSemantics(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: PlayerNight.surface,
              border: Border.all(color: cleared ? PlayerNight.lime : PlayerNight.line),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(checkpoint.name, style: theme.textTheme.titleSmall?.copyWith(color: PlayerNight.text)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      Text(kind, style: theme.textTheme.bodySmall?.copyWith(color: PlayerNight.muted)),
                      Text(
                        '${checkpoint.points}点',
                        style: theme.textTheme.bodySmall?.copyWith(color: PlayerNight.cyan),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        cleared ? Icons.check_circle_outline : Icons.radio_button_unchecked,
                        size: 18,
                        color: accent,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(status, style: theme.textTheme.bodySmall?.copyWith(color: accent)),
                      ),
                    ],
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
