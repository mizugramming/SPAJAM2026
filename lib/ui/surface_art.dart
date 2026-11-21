// Artwork is generated from the same material and progress used by the game.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../game/game.dart';

Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

/// A stroke briefly scatters dirt and moves the reflection over the metal.
class SurfaceArt extends StatefulWidget {
  const SurfaceArt({
    super.key,
    required this.material,
    required this.progress,
    this.strokeCount = 0,
    this.reveal = false,
  });

  final WorkMaterial material;
  final double progress;
  final int strokeCount;
  final bool reveal;

  @override
  State<SurfaceArt> createState() => _SurfaceArtState();
}

class _SurfaceArtState extends State<SurfaceArt>
    with SingleTickerProviderStateMixin {
  late final _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
    value: 1,
  );

  final _tarnish = _TarnishTexture();
  bool _initialReveal = false;
  double _rustRemoved = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.reveal &&
        !_initialReveal &&
        !MediaQuery.disableAnimationsOf(context)) {
      _initialReveal = true;
      _flash.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(SurfaceArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (MediaQuery.disableAnimationsOf(context)) return;
    if (widget.reveal && !oldWidget.reveal) {
      _rustRemoved = 0;
      _flash.duration = const Duration(milliseconds: 520);
      _flash.forward(from: 0);
    } else if (widget.strokeCount > oldWidget.strokeCount) {
      _rustRemoved =
          (oldWidget.material.rustAt(oldWidget.progress) -
                  widget.material.rustAt(widget.progress))
              .clamp(0.0, 1.0);
      _flash.duration = const Duration(milliseconds: 180);
      _flash.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _flash.dispose();
    _tarnish.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _SurfacePainter(
          widget.material,
          widget.progress,
          _flash,
          widget.strokeCount,
          widget.reveal,
          _rustRemoved,
          _tarnish,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _SurfacePainter extends CustomPainter {
  _SurfacePainter(
    this.material,
    this.progress,
    this.flash,
    this.strokes,
    this.reveal,
    this.rustRemoved,
    this.tarnish,
  ) : super(repaint: flash);

  final WorkMaterial material;
  final double progress;
  final Animation<double> flash;
  final int strokes;
  final bool reveal;
  final double rustRemoved;
  final _TarnishTexture tarnish;

  static const _white = Color(0xFFFFF3D8);
  static const _shadow = Color(0xFF171514);
  static final _grains = _makeGrains();

  static List<({double x, double y, double r, double seed})> _makeGrains() {
    final rng = math.Random(241);
    return List.generate(
      1350,
      (_) => (
        x: rng.nextDouble() * 2 - 1,
        y: rng.nextDouble() * 2 - 1,
        r: rng.nextDouble(),
        seed: rng.nextDouble(),
      ),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final radius = math.min(size.width * .425, size.height * .419);
    final center = Offset(size.width * .50, size.height * .47);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(radius);
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(.045, .91),
        width: 1.83,
        height: .24,
      ),
      Paint()
        ..color = const Color(0xB5000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, .08),
    );
    canvas.rotate(material.glyph == null ? -.12 : -.065);
    final ink = material.colorAt(progress);
    final rust = material.rustAt(progress);
    final shine = material.shineAt(progress);
    final glyph = material.glyph;
    final face = glyph == null
        ? (Path()..addOval(const Rect.fromLTWH(-1, -1, 2, 2)))
        : _plate();
    canvas.drawPath(
      face.shift(const Offset(.025, .07)),
      Paint()..color = _mix(ink, _shadow, .65),
    );
    final metal = Paint()
      ..shader = LinearGradient(
        begin: const Alignment(-.88, -.92),
        end: const Alignment(.95, .92),
        colors: [
          _mix(ink, _shadow, .38),
          _mix(ink, _white, .49 + shine * .12),
          ink,
          _mix(ink, _shadow, .35),
          _mix(ink, _white, .19),
        ],
        stops: const [0, .21, .47, .76, 1],
      ).createShader(const Rect.fromLTWH(-1, -1, 2, 2));
    canvas.drawPath(face, metal);
    canvas.save();
    canvas.clipPath(face);
    _brushing(canvas);
    if (glyph == null) {
      _medal(canvas, ink, shine);
    } else {
      _inscription(canvas, ink, glyph, shine);
    }
    // A finished surface holds a sharper reflection even after movement stops.
    if (shine > .05) {
      const bounds = Rect.fromLTWH(-1, -1, 2, 2);
      final highlight = LinearGradient(
        begin: const Alignment(-.92, -.46),
        end: const Alignment(.92, .5),
        colors: [
          Colors.transparent,
          _white.withValues(alpha: shine * .31),
          _white.withValues(alpha: shine * .05),
          Colors.transparent,
          _white.withValues(alpha: shine * .22),
          Colors.transparent,
        ],
        stops: const [0, .24, .31, .53, .59, .69],
      );
      canvas.drawRect(bounds, Paint()..shader = highlight.createShader(bounds));
    }
    tarnish.draw(canvas, rust, plaque: glyph != null);
    if (flash.value < 1 && shine > .02) {
      // Start a stroke on the face so even a quick reversal catches the light.
      final x = reveal ? -2.1 + flash.value * 4.2 : -.68 + flash.value * 2.1;
      final area = Rect.fromLTWH(x - .34, -1.8, .68, 3.6);
      canvas.save();
      canvas.rotate(.44);
      canvas.drawRect(
        area,
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.transparent,
              _white.withValues(alpha: .12 + shine * .3),
              Colors.transparent,
            ],
          ).createShader(area),
      );
      canvas.restore();
    }
    canvas.restore();
    if (flash.value < 1 && rustRemoved > 0) {
      _flakes(canvas);
    }
    canvas.restore();
  }

  Path _plate() => Path()
    ..moveTo(-.86, -.88)
    ..lineTo(.77, -.88)
    ..lineTo(.94, -.71)
    ..lineTo(.94, .71)
    ..lineTo(.78, .88)
    ..lineTo(-.77, .88)
    ..lineTo(-.94, .71)
    ..lineTo(-.94, -.79)
    ..close();

  void _brushing(Canvas c) {
    final brush = Paint()..strokeWidth = .003;
    for (final g in _grains.take(220)) {
      brush.color = (g.seed > .5 ? Colors.black : Colors.white).withValues(
        alpha: .025 + .065 * g.r,
      );
      c.drawLine(Offset(g.x, g.y), Offset(g.x + g.r * .36, g.y - .015), brush);
    }
  }

  void _medal(Canvas c, Color ink, double shine) {
    final light = _mix(ink, _white, .70);
    final dark = _mix(ink, _shadow, .66);
    final pen = Paint()..style = PaintingStyle.stroke;
    for (final ring in [
      (.97, .018, dark),
      (.946, .012, light),
      (.806, .012, dark),
      (.79, .008, light),
      (.716, .008, dark),
    ]) {
      c.drawCircle(
        Offset.zero,
        ring.$1,
        pen
          ..strokeWidth = ring.$2
          ..color = ring.$3,
      );
    }
    for (var i = 0; i < 84; i++) {
      final angle = 2 * math.pi * i / 84;
      final direction = Offset(math.cos(angle), math.sin(angle));
      c.drawLine(
        direction * .842,
        direction * .914,
        pen
          ..strokeWidth = .012
          ..color = i.isEven ? light.withValues(alpha: .67) : dark,
      );
    }
    // The compass is cast into the face. Its facets retain a dark and a lit edge.
    for (var i = 0; i < 8; i++) {
      c.save();
      c.rotate(i * math.pi / 4);
      final tip = i.isEven ? -.66 : -.44;
      final a = Path()
        ..moveTo(0, tip)
        ..lineTo(.127, -.142)
        ..lineTo(0, 0)
        ..close();
      final b = Path()
        ..moveTo(0, tip)
        ..lineTo(-.127, -.142)
        ..lineTo(0, 0)
        ..close();
      c.drawPath(a, Paint()..color = _mix(ink, _shadow, i < 4 ? .61 : .32));
      c.drawPath(b, Paint()..color = _mix(ink, _white, i < 4 ? .34 : .63));
      c.drawLine(
        Offset(0, tip),
        Offset.zero,
        pen
          ..strokeWidth = .008
          ..color = light,
      );
      c.restore();
    }
    c.drawCircle(Offset.zero, .09, Paint()..color = dark);
    c.drawCircle(const Offset(-.006, -.009), .072, Paint()..color = light);
    c.drawCircle(Offset.zero, .048, Paint()..color = ink);
    if (shine > .15) {
      c.drawArc(
        const Rect.fromLTWH(-.947, -.947, 1.894, 1.894),
        3.65,
        .78,
        false,
        pen
          ..strokeWidth = .025
          ..strokeCap = StrokeCap.round
          ..color = _white.withValues(alpha: shine),
      );
    }
  }

  void _inscription(Canvas c, Color ink, String glyph, double shine) {
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .013;
    c.save();
    c.scale(.934);
    c.drawPath(_plate(), pen..color = _mix(ink, _shadow, .57));
    c.drawPath(
      _plate().shift(const Offset(.008, .012)),
      pen..color = _mix(ink, _white, .47),
    );
    c.restore();
    for (final x in [-.76, .76]) {
      for (final y in [-.7, .7]) {
        c.drawCircle(
          Offset(x, y),
          .025,
          Paint()..color = _mix(ink, _shadow, .76),
        );
        c.drawLine(
          Offset(x - .014, y + .014),
          Offset(x + .014, y - .014),
          pen
            ..strokeWidth = .006
            ..color = _mix(ink, _white, .5),
        );
      }
    }
    // Paint in normal font units to preserve rasterizer precision.
    c.save();
    c.scale(.01);
    final tp = TextPainter(
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    );
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        _mix(ink, _shadow, .42),
        _mix(ink, _white, .78),
        ink,
        _mix(ink, _shadow, .22),
        _mix(ink, _white, .66 + shine * .2),
      ],
      stops: const [0, .34, .48, .62, 1],
    );
    void drawGlyph(Offset offset, Paint paint) {
      tp.text = TextSpan(
        text: glyph,
        style: TextStyle(
          fontFamily: 'WorkshopSans',
          fontFamilyFallback: const ['Noto Sans CJK JP', 'Noto Sans JP'],
          fontSize: 124,
          fontWeight: FontWeight.w900,
          height: 1,
          foreground: paint,
        ),
      );
      tp.layout();
      tp.paint(c, offset - Offset(tp.width / 2, tp.height / 2));
    }

    drawGlyph(const Offset(2, 3), Paint()..color = _mix(ink, _shadow, .86));
    drawGlyph(const Offset(-1, -1), Paint()..color = _mix(ink, _white, .66));
    drawGlyph(
      Offset.zero,
      Paint()
        ..shader = gradient.createShader(const Rect.fromLTWH(0, 0, 128, 128)),
    );
    tp.dispose();
    c.restore();
  }

  void _flakes(Canvas c) {
    final t = flash.value;
    final count = (rustRemoved * 160).ceil().clamp(0, 28);
    for (var i = 0; i < count; i++) {
      final g = _grains[(strokes * 23 + i) % _grains.length];
      final x = (.67 + .3 * g.r) * (g.x.sign) + g.x * t * .30;
      final y = .22 + (g.y + 1) * .18 + (t * t) * (.39 + g.r * .31);
      c.drawRect(
        Rect.fromCenter(
          center: Offset(x, y),
          width: .016 + g.r * .028,
          height: .011,
        ),
        Paint()
          ..color = _mix(
            const Color(0xFF846545),
            _white,
            g.r * .45,
          ).withValues(alpha: (1 - t) * .85),
      );
    }
  }

  @override
  bool shouldRepaint(_SurfacePainter old) =>
      material != old.material ||
      progress != old.progress ||
      strokes != old.strokes ||
      reveal != old.reveal ||
      rustRemoved != old.rustRemoved ||
      flash != old.flash;
}

// One irregular oxidation field persists on the face. A lower amount exposes
// progressively more of the same metal; particles never flicker while idle.
class _TarnishTexture {
  static const side = 104;
  static const count = side * side;
  static final Float32List points = Float32List.fromList([
    for (var i = 0; i < count; i++) ...[
      2 * (i % side) / (side - 1) - 1,
      2 * (i ~/ side) / (side - 1) - 1,
    ],
  ]);
  static final Uint16List indices = Uint16List.fromList([
    for (var i = 0; i < count - side; i++)
      if (i % side != side - 1) ...[
        i,
        i + 1,
        i + side,
        i + 1,
        i + side + 1,
        i + side,
      ],
  ]);

  static double _noise(int x, int y, int seed) {
    final n = math.sin(x * 127.1 + y * 311.7 + seed * 79.0) * 43758.54;
    return n - n.floorToDouble();
  }

  static double _field(double x, double y, int seed) {
    final ix = x.floor(), iy = y.floor();
    final dx = x - ix, dy = y - iy;
    final u = dx * dx * (3 - 2 * dx), v = dy * dy * (3 - 2 * dy);
    final a = ui.lerpDouble(_noise(ix, iy, seed), _noise(ix + 1, iy, seed), u)!;
    final b = ui.lerpDouble(
      _noise(ix, iy + 1, seed),
      _noise(ix + 1, iy + 1, seed),
      u,
    )!;
    return ui.lerpDouble(a, b, v)!;
  }

  static final pores = List.generate(count, (i) {
    final x = points[i * 2], y = points[i * 2 + 1];
    final mottling =
        _field(x * 2.3, y * 2.3, 4) * .47 +
        _field(x * 5.2, y * 5.2, 8) * .27 +
        _field(x * 14.4, y * 14.4, 12) * .16 +
        _noise(i % side, i ~/ side, 15) * .10;
    final grain = _noise(i % side, i ~/ side, 19);
    final warm = (_field(x * 6, y * 6, 24) * .69 + grain * .31);
    final copper = _mix(const Color(0xFF342D26), const Color(0xFFA46338), warm);
    final green = _mix(const Color(0xFF384B3D), const Color(0xFFA2A47E), warm);
    final verdigris = ((_field(x * 3, y * 3, 5) - .50) * 3).clamp(0.0, .8);
    final dirt = _mix(
      const Color(0xFF302C24),
      const Color(0xFF807760),
      _field(x * 5.6, y * 5.6, 7) * .34 + grain * .66,
    );
    return (
      depth: (mottling - .24) * 1.9,
      oxide: _mix(copper, green, verdigris).toARGB32(),
      dirt: dirt.toARGB32(),
    );
  });

  ui.Vertices? mesh;
  (double, bool)? stamp;

  void draw(Canvas c, double amount, {required bool plaque}) {
    if (amount <= 0) return;
    if (stamp != (amount, plaque)) {
      final colors = Int32List(count);
      final coverage = plaque ? amount * 1.09 : amount * .82;
      for (var i = 0; i < count; i++) {
        final pore = pores[i];
        final alpha = ((coverage - pore.depth) * 4).clamp(0.0, 1.0);
        final rgb = plaque ? pore.dirt : pore.oxide;
        colors[i] = ((alpha * 255).round() << 24) | (rgb & 0xFFFFFF);
      }
      mesh?.dispose();
      mesh = ui.Vertices.raw(
        ui.VertexMode.triangles,
        points,
        colors: colors,
        indices: indices,
      );
      stamp = (amount, plaque);
    }
    c.drawVertices(mesh!, BlendMode.dst, Paint());
  }

  void dispose() => mesh?.dispose();
}
