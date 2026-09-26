import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/conveyor_settings.dart';
import '../../domain/conveyor_layout.dart';
import '../../domain/models.dart';
import 'can_stage.dart';
import 'parent_character.dart';

/// Edits a private draft. Only a successful persistent write changes the app.
class ConveyorEditor extends StatefulWidget {
  const ConveyorEditor({
    super.key,
    required this.settings,
    required this.phase,
    required this.profile,
    this.team,
    this.result,
  });

  final ConveyorSettings settings;
  final AppPhase phase;
  final Profile profile;
  final Team? team;
  final EncounterResult? result;

  @override
  State<ConveyorEditor> createState() => _ConveyorEditorState();
}

class _ConveyorEditorState extends State<ConveyorEditor> {
  late ConveyorLayout _draft = widget.settings.value;
  String? _error;
  String? _copyNotice;

  void _change(ConveyorLayout value) => setState(() {
    _draft = value.copyWith(
      scale: double.parse(value.scale.toStringAsFixed(2)),
      offsetX: value.offsetX.roundToDouble(),
      offsetY: value.offsetY.roundToDouble(),
    );
    _error = null;
    _copyNotice = null;
  });

  Future<void> _save() async {
    setState(() => _error = null);
    final saved = await widget.settings.save(_draft);
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop(true);
    } else {
      setState(
        () => _error = widget.settings.error ?? '保存できませんでした。もう一度お試しください。',
      );
    }
  }

  Future<void> _copy() async {
    try {
      await Clipboard.setData(ClipboardData(text: _draft.encode()));
      if (mounted) setState(() => _copyNotice = '設定値をコピーしました');
    } catch (_) {
      if (mounted) setState(() => _copyNotice = 'コピーできませんでした。もう一度お試しください。');
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.settings,
    builder: (context, _) {
      final busy = widget.settings.isSaving;
      return PopScope(
        canPop: !busy,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('ベルトコンベアの配置', style: TextStyle(fontSize: 20)),
                  ),
                  IconButton(
                    key: const Key('cancel-conveyor-editor'),
                    tooltip: '保存せず閉じる',
                    onPressed: busy ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                key: const Key('conveyor-editor-scroll'),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('缶とのバランスを見ながら調整できます。'),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 260,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: MediaQuery(
                          data: MediaQuery.of(
                            context,
                          ).copyWith(disableAnimations: true),
                          child: CharacterPlaybackScope(
                            enabled: false,
                            child: ColoredBox(
                              color: const Color(0xFFFFFCF3),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: LayoutBuilder(
                                  builder: (context, constraints) => FittedBox(
                                    fit: BoxFit.contain,
                                    child: SizedBox(
                                      width: constraints.maxWidth,
                                      child: CanStage(
                                        key: const Key(
                                          'conveyor-editor-preview',
                                        ),
                                        phase: switch (widget.phase) {
                                          AppPhase.finale ||
                                          AppPhase.results ||
                                          AppPhase.returning ||
                                          AppPhase.game => AppPhase.home,
                                          _ => widget.phase,
                                        },
                                        profile: widget.profile,
                                        result: widget.result,
                                        team: widget.team,
                                        conveyorLayout: _draft,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _adjustment(
                      name: '大きさ',
                      id: 'scale',
                      value: _draft.scale,
                      min: ConveyorLayout.minScale,
                      max: ConveyorLayout.maxScale,
                      step: .05,
                      label: '${(_draft.scale * 100).round()}%',
                      onChanged: (value) =>
                          _change(_draft.copyWith(scale: value)),
                      busy: busy,
                    ),
                    _adjustment(
                      name: '横位置',
                      id: 'x',
                      value: _draft.offsetX,
                      min: ConveyorLayout.minOffset,
                      max: ConveyorLayout.maxOffset,
                      step: 1,
                      label: _draft.offsetX == 0
                          ? '中央'
                          : '${_draft.offsetX < 0 ? '左' : '右'}へ ${_draft.offsetX.abs().round()}',
                      onChanged: (value) =>
                          _change(_draft.copyWith(offsetX: value)),
                      busy: busy,
                    ),
                    _adjustment(
                      name: '縦位置',
                      id: 'y',
                      value: _draft.offsetY,
                      min: ConveyorLayout.minOffset,
                      max: ConveyorLayout.maxOffset,
                      step: 1,
                      label: _draft.offsetY == 0
                          ? '基準位置'
                          : '${_draft.offsetY < 0 ? '上' : '下'}へ ${_draft.offsetY.abs().round()}',
                      onChanged: (value) =>
                          _change(_draft.copyWith(offsetY: value)),
                      busy: busy,
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        TextButton.icon(
                          key: const Key('reset-conveyor-layout'),
                          onPressed: busy
                              ? null
                              : () => _change(const ConveyorLayout()),
                          icon: const Icon(Icons.restart_alt),
                          label: const Text('初期配置に戻す'),
                        ),
                        TextButton.icon(
                          key: const Key('copy-conveyor-layout'),
                          onPressed: busy ? null : _copy,
                          icon: const Icon(Icons.copy_outlined),
                          label: const Text('設定値をコピー'),
                        ),
                      ],
                    ),
                    if (_copyNotice != null)
                      Semantics(liveRegion: true, child: Text(_copyNotice!)),
                    if (widget.settings.loadError != null)
                      const Text('前回の配置を読み込めませんでした。現在の配置で編集できます。'),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) ...[
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const Text(
                    '保存すると、この端末のすべての缶に反映されます。',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    key: const Key('save-conveyor-layout'),
                    onPressed: busy || !widget.settings.isLoaded ? null : _save,
                    icon: busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(busy ? '保存中…' : 'この配置を保存'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _adjustment({
    required String name,
    required String id,
    required double value,
    required double min,
    required double max,
    required double step,
    required String label,
    required ValueChanged<double> onChanged,
    required bool busy,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 12,
        children: [
          Text(name),
          Text(label, key: Key('conveyor-$id-value')),
        ],
      ),
      Row(
        children: [
          IconButton(
            key: Key('conveyor-$id-minus'),
            tooltip: '$nameを減らす',
            onPressed: busy || value <= min
                ? null
                : () => onChanged((value - step).clamp(min, max)),
            icon: const Icon(Icons.remove),
          ),
          Expanded(
            child: Slider(
              key: Key('conveyor-$id-slider'),
              value: value,
              min: min,
              max: max,
              divisions: ((max - min) / step).round(),
              label: label,
              semanticFormatterCallback: (_) => '$name $label',
              onChanged: busy ? null : onChanged,
            ),
          ),
          IconButton(
            key: Key('conveyor-$id-plus'),
            tooltip: '$nameを増やす',
            onPressed: busy || value >= max
                ? null
                : () => onChanged((value + step).clamp(min, max)),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      const SizedBox(height: 4),
    ],
  );
}
