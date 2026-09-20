import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/design_tokens.dart';
import '../../../core/widgets/space_background.dart';
import '../controllers/star_placement_controller.dart';
import '../widgets/placed_star.dart';

class StarPlacementEditorPage extends ConsumerStatefulWidget {
  const StarPlacementEditorPage({super.key});
  @override
  ConsumerState<StarPlacementEditorPage> createState() =>
      _StarPlacementEditorPageState();
}

class _StarPlacementEditorPageState
    extends ConsumerState<StarPlacementEditorPage> {
  StarPlacement? _draft;
  bool _saving = false;

  void _pan(DragUpdateDetails details, Size canvasSize) {
    final draft = _draft;
    if (draft == null) return;
    setState(() {
      _draft = draft.copyWith(
        alignX: (draft.alignX + details.delta.dx / (canvasSize.width / 2))
            .clamp(-1.0, 1.0),
        alignY: (draft.alignY + details.delta.dy / (canvasSize.height / 2))
            .clamp(-1.0, 1.0),
      );
    });
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null || _saving) return;
    setState(() => _saving = true);
    await ref.read(starPlacementProvider.notifier).save(draft);
    if (mounted) Navigator.of(context).pop();
  }

  void _reset() => setState(() => _draft = const StarPlacement());

  @override
  Widget build(BuildContext context) {
    final placementAsync = ref.watch(starPlacementProvider);
    _draft ??= placementAsync.value;
    final draft = _draft;
    return Scaffold(
      backgroundColor: DesignTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('星の位置を調整'),
        actions: [
          TextButton(
            onPressed: draft == null ? null : _reset,
            child: const Text('リセット'),
          ),
        ],
      ),
      body: draft == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  children: [
                    const Text(
                      'ドラッグして星の位置を決めよう。',
                      style: TextStyle(fontSize: 12, color: DesignTokens.muted),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          DesignTokens.radius,
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) => SpaceBackground(
                            scenic: true,
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onPanUpdate: (details) => _pan(
                                details,
                                Size(
                                  constraints.maxWidth,
                                  constraints.maxHeight,
                                ),
                              ),
                              child: PlacedStar(placement: draft),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Icon(
                          Icons.zoom_out,
                          color: DesignTokens.muted,
                          size: 18,
                        ),
                        Expanded(
                          child: Slider(
                            value: draft.scale,
                            min: 0.5,
                            max: 1.8,
                            onChanged: (value) => setState(
                              () => _draft = draft.copyWith(scale: value),
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.zoom_in,
                          color: DesignTokens.muted,
                          size: 18,
                        ),
                      ],
                    ),
                    Text(
                      'x: ${draft.alignX.toStringAsFixed(2)}  '
                      'y: ${draft.alignY.toStringAsFixed(2)}  '
                      '大きさ: ${draft.scale.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: DesignTokens.muted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('この位置で保存'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
