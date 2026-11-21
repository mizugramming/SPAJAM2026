import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'workshop_layout.dart';
import 'workshop_theme.dart';

/// 配置の編集は開発中のChromeだけ。実機・リリース・テストでは出さない。
const layoutEditorEnabled = kDebugMode && kIsWeb;

/// Chromeではスマホ型の枠に表示する（縦横比 9:20）。
const _previewAspect = 9 / 20;

enum Screen {
  title('タイトル'),
  select('素材選択'),
  voice('採音'),
  ready('やすり決定'),
  polishing('研磨'),
  result('仕上がり');

  const Screen(this.label);
  final String label;
}

/// 部品の位置と大きさ。画面の幅・高さに対する割合（0〜1）。[t] は文字の倍率。
@immutable
class Box {
  const Box(this.x, this.y, this.w, this.h, [this.t = 1]);
  final double x, y, w, h, t;

  Rect rectIn(Size size) => Rect.fromLTWH(
    x * size.width,
    y * size.height,
    w * size.width,
    h * size.height,
  );

  Box copyWith({double? x, double? y, double? w, double? h, double? t}) =>
      Box(x ?? this.x, y ?? this.y, w ?? this.w, h ?? this.h, t ?? this.t);

  /// 画面からはみ出して置ける最大の大きさ（画面の何倍か）と、画面内に残す最小の端。
  static const maxSize = 3.0;
  static const keepVisible = .05;

  /// 大きさと位置を編集できる範囲に収め、小数3桁に丸める。画面からはみ出してよいが、
  /// つかんで戻せるよう、端の [keepVisible] 分は必ず画面内に残す。
  Box tidy() {
    double r(double v) => double.parse(v.toStringAsFixed(3));
    final nw = w.clamp(.02, maxSize).toDouble();
    final nh = h.clamp(.004, maxSize).toDouble();
    return Box(
      r(x.clamp(keepVisible - nw, 1 - keepVisible)),
      r(y.clamp(keepVisible - nh, 1 - keepVisible)),
      r(nw),
      r(nh),
      double.parse(t.clamp(.5, 2.5).toStringAsFixed(2)),
    );
  }

  String code() {
    final f = formatLayoutValue;
    return 'Box(${f(x)}, ${f(y)}, ${f(w)}, ${f(h)}${t == 1 ? '' : ', ${f(t)}'})';
  }

  @override
  bool operator ==(Object other) =>
      other is Box &&
      other.x == x &&
      other.y == y &&
      other.w == w &&
      other.h == h &&
      other.t == t;

  @override
  int get hashCode => Object.hash(x, y, w, h, t);
}

const _fallbackBox = Box(.056, .5, .888, .1);

String formatLayoutValue(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  final text = value
      .toStringAsFixed(3)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
  if (text.startsWith('0.')) return text.substring(1);
  if (text.startsWith('-0.')) return '-${text.substring(2)}';
  return text;
}

final layoutTuner = LayoutTuner();

/// 編集中の配置。編集していない部品はファイル（workshop_layout.dart）の値を返す。
class LayoutTuner extends ChangeNotifier {
  final _edits = <Screen, Map<String, Box>>{};

  bool _editing = false;
  bool get editing => _editing;
  set editing(bool value) {
    _editing = value;
    if (!value) selected = null;
    notifyListeners();
  }

  String? _selected;
  String? get selected => _selected;
  set selected(String? id) {
    _selected = id;
    notifyListeners();
  }

  bool _snap = true;
  bool get snap => _snap;
  set snap(bool value) {
    _snap = value;
    notifyListeners();
  }

  Box base(Screen screen, String id) =>
      screenLayouts[screen]?[id] ?? _fallbackBox;

  Box boxOf(Screen screen, String id) =>
      _edits[screen]?[id] ?? base(screen, id);

  bool isChanged(Screen screen, String id) =>
      _edits[screen]?.containsKey(id) ?? false;

  bool get hasChanges => _edits.values.any((m) => m.isNotEmpty);

  void set(Screen screen, String id, Box box) {
    final next = box.tidy();
    final edits = _edits.putIfAbsent(screen, () => {});
    if (next == base(screen, id) && screenLayouts[screen]?[id] != null) {
      edits.remove(id);
    } else {
      edits[id] = next;
    }
    notifyListeners();
  }

  void reset({Screen? screen, String? id}) {
    if (screen == null) {
      _edits.clear();
    } else if (id == null) {
      _edits.remove(screen);
    } else {
      _edits[screen]?.remove(id);
    }
    notifyListeners();
  }

  List<String> _ids(Screen screen) => [
    ...?screenLayouts[screen]?.keys,
    for (final id in _edits[screen]?.keys ?? const <String>[])
      if (screenLayouts[screen]?[id] == null) id,
  ];

  /// workshop_layout.dart にそのまま貼れる全文。
  String fileText() {
    final b = StringBuffer(_fileHead);
    for (final screen in Screen.values) {
      final ids = _ids(screen);
      if (ids.isEmpty) continue;
      b.writeln('  Screen.${screen.name}: {');
      for (final id in ids) {
        b.writeln("    '$id': ${boxOf(screen, id).code()},");
      }
      b.writeln('  },');
    }
    b.writeln('};');
    return b.toString();
  }

  /// 会話やメモに貼る変更点の一覧。
  String changesText() => [
    for (final screen in Screen.values)
      for (final id in _ids(screen))
        if (isChanged(screen, id))
          '${screen.label} / $id: '
              '${base(screen, id).code()} → ${boxOf(screen, id).code()}',
  ].join('\n');
}

const _fileHead = '''
// 画面ごとの部品の位置と大きさ。値は画面の幅・高さに対する割合（0〜1）。
// Box(左, 上, 幅, 高さ, 文字の倍率) — 文字の倍率は省略すると1。
// Chromeの開発版では右下の「配置を編集」で四角を動かせる。決まったら「ファイル用にコピー」で
// このファイルの中身と置き換えて保存する。
// dart format off
import 'layout_tuner.dart';

const screenLayouts = <Screen, Map<String, Box>>{
''';

/// 画面に置く部品。[fill] は四角いっぱいに広げる部品（素材・カード・ボタン）。
/// それ以外は四角の幅で並べ、高さが足りなければ縮めて収める。
class Part {
  const Part(
    this.id,
    this.label,
    this.child, {
    this.transition,
    this.fill = false,
    this.align = Alignment.topLeft,
  });
  final String id;
  final String label;

  /// null なら今は表示しない（編集中は四角だけ出る）。
  final Widget? child;
  final Widget Function(Size canvas, Rect bounds, Widget child)? transition;
  final bool fill;
  final Alignment align;
}

/// 部品を配置表どおりに並べる画面。Chromeではスマホ型の枠と編集パネルを出す。
class LayoutStage extends StatelessWidget {
  const LayoutStage({
    super.key,
    required this.screen,
    required this.parts,
    this.background,
  });
  final Screen screen;
  final List<Part> parts;

  /// 部品の後ろに画面いっぱいに敷くもの（背景画像など）。
  final Widget? background;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: layoutTuner,
    builder: (context, _) {
      if (!kIsWeb) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: _Canvas(
              screen: screen,
              parts: parts,
              background: background,
            ),
          ),
        );
      }
      final editing = layoutEditorEnabled && layoutTuner.editing;
      return Row(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: _previewAspect,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: _Canvas(
                            screen: screen,
                            parts: parts,
                            background: background,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (layoutEditorEnabled && !editing)
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: FloatingActionButton.extended(
                      heroTag: 'layout-editor',
                      backgroundColor: seam,
                      foregroundColor: chalk,
                      onPressed: () => layoutTuner.editing = true,
                      icon: const Icon(Icons.dashboard_customize_outlined),
                      label: const Text('配置を編集'),
                    ),
                  ),
              ],
            ),
          ),
          if (editing)
            SizedBox(
              width: 340,
              child: _EditorPanel(screen: screen, parts: parts),
            ),
        ],
      );
    },
  );
}

class _Canvas extends StatelessWidget {
  const _Canvas({required this.screen, required this.parts, this.background});
  final Screen screen;
  final List<Part> parts;
  final Widget? background;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, frame) {
      final size = frame.biggest;
      final editing = layoutEditorEnabled && layoutTuner.editing;
      Widget position(Part part) {
        final box = layoutTuner.boxOf(screen, part.id);
        final bounds = box.rectIn(size);
        final child = _PartView(part: part, scale: box.t);
        return Positioned.fromRect(
          rect: bounds,
          child: editing
              ? child
              : part.transition?.call(size, bounds, child) ?? child,
        );
      }

      return Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          if (background case final background?)
            Positioned.fill(child: background),
          for (final part in parts)
            if (part.child != null) position(part),
          if (editing)
            Positioned.fill(
              child: _EditLayer(screen: screen, parts: parts, size: size),
            ),
        ],
      );
    },
  );
}

class _PartView extends StatelessWidget {
  const _PartView({required this.part, required this.scale});
  final Part part;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final base = media.textScaler.scale(16) / 16;
    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.linear(base * scale)),
      child: LayoutBuilder(
        builder: (context, box) {
          if (part.fill) return SizedBox.expand(child: part.child);
          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: part.align,
            child: SizedBox(width: box.maxWidth, child: part.child),
          );
        },
      ),
    );
  }
}

/// 編集中に部品の上へ重ねる四角。ドラッグで移動、右下の角で大きさを変える。
class _EditLayer extends StatefulWidget {
  const _EditLayer({
    required this.screen,
    required this.parts,
    required this.size,
  });
  final Screen screen;
  final List<Part> parts;
  final Size size;

  @override
  State<_EditLayer> createState() => _EditLayerState();
}

class _EditLayerState extends State<_EditLayer> {
  final _focus = FocusNode();
  Box? _origin;
  Offset _moved = Offset.zero;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  double _snap(double v) => layoutTuner.snap ? (v / .005).round() * .005 : v;

  void _begin(String id) {
    layoutTuner.selected = id;
    _focus.requestFocus();
    _origin = layoutTuner.boxOf(widget.screen, id);
    _moved = Offset.zero;
  }

  void _drag(String id, Offset delta, {required bool resize}) {
    final o = _origin;
    if (o == null) return;
    _moved += delta;
    final dx = _moved.dx / widget.size.width;
    final dy = _moved.dy / widget.size.height;
    layoutTuner.set(
      widget.screen,
      id,
      resize
          ? o.copyWith(w: _snap(o.w + dx), h: _snap(o.h + dy))
          : o.copyWith(x: _snap(o.x + dx), y: _snap(o.y + dy)),
    );
  }

  KeyEventResult _key(FocusNode _, KeyEvent event) {
    final id = layoutTuner.selected;
    if (id == null || event is KeyUpEvent) return KeyEventResult.ignored;
    final px = 1 / widget.size.width, py = 1 / widget.size.height;
    final step = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowLeft => Offset(-px, 0),
      LogicalKeyboardKey.arrowRight => Offset(px, 0),
      LogicalKeyboardKey.arrowUp => Offset(0, -py),
      LogicalKeyboardKey.arrowDown => Offset(0, py),
      _ => null,
    };
    if (step == null) return KeyEventResult.ignored;
    final b = layoutTuner.boxOf(widget.screen, id);
    final resize = HardwareKeyboard.instance.isShiftPressed;
    layoutTuner.set(
      widget.screen,
      id,
      resize
          ? b.copyWith(w: b.w + step.dx, h: b.h + step.dy)
          : b.copyWith(x: b.x + step.dx, y: b.y + step.dy),
    );
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _key,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => layoutTuner.selected = null,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (final part in widget.parts)
              Builder(
                builder: (context) {
                  final b = layoutTuner.boxOf(widget.screen, part.id);
                  final selected = layoutTuner.selected == part.id;
                  final color = selected ? ember : const Color(0xFF7FD1C0);
                  return Positioned(
                    left: b.x * size.width,
                    top: b.y * size.height,
                    width: b.w * size.width,
                    height: b.h * size.height,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.move,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _begin(part.id),
                        onPanStart: (_) => _begin(part.id),
                        onPanUpdate: (d) =>
                            _drag(part.id, d.delta, resize: false),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: color.withValues(
                                    alpha: selected ? .18 : .08,
                                  ),
                                  border: Border.all(
                                    color: color,
                                    width: selected ? 2 : 1,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 2,
                              top: 1,
                              right: 2,
                              child: Text(
                                part.child == null
                                    ? '${part.label}（今は非表示）'
                                    : part.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: color,
                                  fontWeight: FontWeight.w700,
                                  shadows: const [
                                    Shadow(color: bench, blurRadius: 3),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              right: -7,
                              bottom: -7,
                              child: MouseRegion(
                                cursor: SystemMouseCursors.resizeDownRight,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onPanStart: (_) => _begin(part.id),
                                  onPanUpdate: (d) =>
                                      _drag(part.id, d.delta, resize: true),
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: color,
                                      border: Border.all(color: bench),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _EditorPanel extends StatelessWidget {
  const _EditorPanel({required this.screen, required this.parts});
  final Screen screen;
  final List<Part> parts;

  Future<void> _copy(BuildContext context, String text, String done) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Clipboard.setData(ClipboardData(text: text));
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (_) {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('自動でコピーできませんでした'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(child: SelectableText(text)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('閉じる'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = layoutTuner.selected;
    Part? part;
    for (final p in parts) {
      if (p.id == selected) part = p;
    }
    return Material(
      color: metalPanel,
      shape: const Border(left: BorderSide(color: seam)),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 12, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '配置の編集 · ${screen.label}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: chalk,
                  ),
                ),
              ),
              IconButton(
                tooltip: '編集を終えてゲームを操作する（配置はそのまま）',
                onPressed: () => layoutTuner.editing = false,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const Text(
            '四角をドラッグで移動、右下の角で大きさを変えます。矢印キーで1pxずつ移動、'
            'Shift＋矢印で大きさを変えます。別の画面を編集するときは、編集を終えてゲームを'
            '進めてから、もう一度「配置を編集」を押してください。',
            style: TextStyle(fontSize: 12, color: muted, height: 1.5),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                onPressed: () => _copy(
                  context,
                  layoutTuner.fileText(),
                  'コピーしました。lib/ui/workshop_layout.dart の中身と置き換えて保存してください。',
                ),
                icon: const Icon(Icons.content_copy_rounded, size: 18),
                label: const Text('ファイル用にコピー'),
              ),
              OutlinedButton(
                onPressed: layoutTuner.hasChanges
                    ? () => _copy(
                        context,
                        layoutTuner.changesText(),
                        '変更点をコピーしました。',
                      )
                    : null,
                child: const Text('変更点だけコピー'),
              ),
            ],
          ),
          Row(
            children: [
              Checkbox(
                value: layoutTuner.snap,
                onChanged: (v) => layoutTuner.snap = v ?? true,
              ),
              const Expanded(
                child: Text(
                  'ドラッグを0.5%刻みにそろえる',
                  style: TextStyle(fontSize: 13, color: chalk),
                ),
              ),
            ],
          ),
          const Divider(color: seam),
          if (part == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '四角か下の一覧から部品を選ぶと、位置と大きさの数値が出ます。',
                style: TextStyle(fontSize: 13, color: muted),
              ),
            )
          else
            _Inspector(screen: screen, part: part),
          const Divider(color: seam),
          const Text(
            'この画面の部品',
            style: TextStyle(
              color: ember,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          for (final p in parts)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              selected: p.id == selected,
              selectedColor: ember,
              title: Text(p.child == null ? '${p.label}（今は非表示）' : p.label),
              subtitle: Text(
                p.id,
                style: const TextStyle(fontSize: 11, color: muted),
              ),
              trailing: layoutTuner.isChanged(screen, p.id)
                  ? const Icon(Icons.edit_rounded, size: 16, color: ember)
                  : null,
              onTap: () => layoutTuner.selected = p.id,
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: () => layoutTuner.reset(screen: screen),
                child: Text('${screen.label}画面を元に戻す'),
              ),
              TextButton(
                onPressed: layoutTuner.hasChanges
                    ? () => layoutTuner.reset()
                    : null,
                child: const Text('すべて元に戻す'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Inspector extends StatelessWidget {
  const _Inspector({required this.screen, required this.part});
  final Screen screen;
  final Part part;

  @override
  Widget build(BuildContext context) {
    final b = layoutTuner.boxOf(screen, part.id);
    void put(Box next) => layoutTuner.set(screen, part.id, next);
    Widget row(
      String name,
      double value,
      Box Function(double) change, {
      double step = .005,
      bool percent = true,
    }) {
      return Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              name,
              style: const TextStyle(fontSize: 13, color: chalk),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: '小さく',
            onPressed: () => put(change(value - step)),
            icon: const Icon(Icons.remove_rounded, size: 18),
          ),
          Expanded(
            child: Text(
              percent
                  ? '${(value * 100).toStringAsFixed(1)}%'
                  : '×${value.toStringAsFixed(2)}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: ember,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: '大きく',
            onPressed: () => put(change(value + step)),
            icon: const Icon(Icons.add_rounded, size: 18),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          part.label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: chalk,
          ),
        ),
        Text(b.code(), style: const TextStyle(fontSize: 12, color: muted)),
        const SizedBox(height: 4),
        row('左', b.x, (v) => b.copyWith(x: v)),
        row('上', b.y, (v) => b.copyWith(y: v)),
        row('幅', b.w, (v) => b.copyWith(w: v)),
        row('高さ', b.h, (v) => b.copyWith(h: v)),
        row('文字', b.t, (v) => b.copyWith(t: v), step: .05, percent: false),
        if (layoutTuner.isChanged(screen, part.id))
          TextButton.icon(
            onPressed: () => layoutTuner.reset(screen: screen, id: part.id),
            icon: const Icon(Icons.undo_rounded, size: 18),
            label: const Text('この部品を元に戻す'),
          ),
      ],
    );
  }
}
