import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/design_tokens.dart';
import '../controllers/constellation_shape_controller.dart';
import 'constellation_book_page.dart';

class ConstellationShapeEditorPage extends ConsumerStatefulWidget {
  const ConstellationShapeEditorPage({super.key});

  @override
  ConsumerState<ConstellationShapeEditorPage> createState() =>
      _ConstellationShapeEditorPageState();
}

class _ConstellationShapeEditorPageState
    extends ConsumerState<ConstellationShapeEditorPage> {
  String _selectedId = constellations.first.id;
  String? _loadedId;
  List<Offset>? _draftPoints;
  List<List<int>>? _draftConnections;
  int? _selectedPoint;
  bool _saving = false;

  ConstellationData get _selectedData =>
      constellations.firstWhere((c) => c.id == _selectedId);

  void _loadDraft(Map<String, ConstellationShape> overrides) {
    final override = overrides[_selectedId];
    final data = _selectedData;
    _draftPoints = List.of(override?.points ?? data.points);
    _draftConnections = [
      for (final c in override?.connections ?? data.connections) List.of(c),
    ];
  }

  void _selectConstellation(String id) {
    setState(() {
      _selectedId = id;
      _selectedPoint = null;
      _draftPoints = null;
      _draftConnections = null;
      _loadedId = null;
    });
  }

  void _onPanUpdate(int index, DragUpdateDetails details, Size canvasSize) {
    setState(() {
      final points = _draftPoints!;
      final current = points[index];
      points[index] = Offset(
        (current.dx + details.delta.dx / canvasSize.width).clamp(0.0, 1.0),
        (current.dy + details.delta.dy / canvasSize.height).clamp(0.0, 1.0),
      );
    });
  }

  void _onPointTap(int index) {
    setState(() {
      final selected = _selectedPoint;
      if (selected == null || selected == index) {
        _selectedPoint = selected == index ? null : index;
        return;
      }
      final connections = _draftConnections!;
      final existing = connections.indexWhere(
        (c) =>
            (c[0] == selected && c[1] == index) ||
            (c[0] == index && c[1] == selected),
      );
      if (existing >= 0) {
        connections.removeAt(existing);
      } else {
        connections.add([selected, index]);
      }
      _selectedPoint = null;
    });
  }

  void _onPointLongPress(int index) {
    setState(() {
      _draftPoints!.removeAt(index);
      _draftConnections = [
        for (final c in _draftConnections!)
          if (c[0] != index && c[1] != index)
            [c[0] > index ? c[0] - 1 : c[0], c[1] > index ? c[1] - 1 : c[1]],
      ];
      if (_selectedPoint == index) {
        _selectedPoint = null;
      } else if (_selectedPoint != null && _selectedPoint! > index) {
        _selectedPoint = _selectedPoint! - 1;
      }
    });
  }

  void _onCanvasTapUp(TapUpDetails details, Size canvasSize) {
    setState(() {
      _draftPoints!.add(
        Offset(
          (details.localPosition.dx / canvasSize.width).clamp(0.0, 1.0),
          (details.localPosition.dy / canvasSize.height).clamp(0.0, 1.0),
        ),
      );
      _selectedPoint = null;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    await ref
        .read(constellationShapeOverridesProvider.notifier)
        .save(
          _selectedId,
          ConstellationShape(
            points: _draftPoints!,
            connections: _draftConnections!,
          ),
        );
    if (mounted) setState(() => _saving = false);
  }

  void _reset() {
    ref.read(constellationShapeOverridesProvider.notifier).reset(_selectedId);
    setState(() {
      _draftPoints = null;
      _draftConnections = null;
      _selectedPoint = null;
      _loadedId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final overridesAsync = ref.watch(constellationShapeOverridesProvider);
    final overrides = overridesAsync.value ?? const {};
    if (overridesAsync.hasValue && _loadedId != _selectedId) {
      _loadDraft(overrides);
      _loadedId = _selectedId;
    }
    final points = _draftPoints;
    final connections = _draftConnections;
    final hasOverride = overrides.containsKey(_selectedId);

    return Scaffold(
      backgroundColor: ConstellationBookPage.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('星座の形を編集'),
        actions: [
          TextButton(
            onPressed: hasOverride ? _reset : null,
            child: const Text('リセット'),
          ),
        ],
      ),
      body: points == null || connections == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: constellations.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final data = constellations[index];
                        final selected = data.id == _selectedId;
                        return ChoiceChip(
                          label: Text(data.name),
                          selected: selected,
                          onSelected: (_) => _selectConstellation(data.id),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'ドラッグで移動 ・ 2点タップで線をつなぐ/切る ・ 長押しで削除 ・ 何もない場所をタップで追加',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: DesignTokens.muted),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final canvasSize = Size(
                            constraints.maxWidth,
                            constraints.maxHeight,
                          );
                          return Container(
                            decoration: BoxDecoration(
                              color: ConstellationBookPage.card,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: .06),
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapUp: (details) =>
                                  _onCanvasTapUp(details, canvasSize),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: Opacity(
                                      opacity: .15,
                                      child: Image.asset(
                                        _selectedData.imagePath,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, _, _) =>
                                            const SizedBox.shrink(),
                                      ),
                                    ),
                                  ),
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: CustomPaint(
                                        painter: ConstellationPainter(
                                          points: points,
                                          connections: connections,
                                          large: true,
                                        ),
                                      ),
                                    ),
                                  ),
                                  for (var i = 0; i < points.length; i++)
                                    Positioned(
                                      left:
                                          points[i].dx * canvasSize.width - 16,
                                      top:
                                          points[i].dy * canvasSize.height - 16,
                                      child: GestureDetector(
                                        onPanUpdate: (details) => _onPanUpdate(
                                          i,
                                          details,
                                          canvasSize,
                                        ),
                                        onTap: () => _onPointTap(i),
                                        onLongPress: () => _onPointLongPress(i),
                                        child: Container(
                                          width: 32,
                                          height: 32,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: _selectedPoint == i
                                                ? DesignTokens.gold.withValues(
                                                    alpha: .28,
                                                  )
                                                : Colors.transparent,
                                            border: Border.all(
                                              color: _selectedPoint == i
                                                  ? DesignTokens.gold
                                                  : Colors.white.withValues(
                                                      alpha: .18,
                                                    ),
                                            ),
                                          ),
                                          child: Text(
                                            '$i',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.white70,
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
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: FilledButton(
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
                          : const Text('この形で保存'),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
