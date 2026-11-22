import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Scratchable brass foil over the award inscription on the upper medal face.
class MedalScratch extends StatefulWidget {
  const MedalScratch({
    super.key,
    required this.engraved,
    required this.enabled,
    required this.revealed,
    required this.onRevealed,
  });

  final Widget engraved;
  final bool enabled;
  final bool revealed;
  final VoidCallback onRevealed;

  @override
  State<MedalScratch> createState() => _MedalScratchState();
}

class _MedalScratchState extends State<MedalScratch>
    with SingleTickerProviderStateMixin {
  final _foil = _Foil();
  final _flakes = <_Flake>[];
  late final Ticker _ticker;
  Duration _now = Duration.zero;
  int? _pointer;
  Offset _previous = Offset.zero;
  double _carry = 0;
  int _seed = 0;
  int _accessiblePass = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
  }

  void _tick(Duration elapsed) {
    _now = elapsed;
    _flakes.removeWhere((flake) => elapsed - flake.born >= _Flake.life);
    if (_flakes.isEmpty) _ticker.stop();
    setState(() {});
  }

  void _shed(Offset point, Offset direction) {
    if (MediaQuery.disableAnimationsOf(context)) return;
    if (!_ticker.isActive) {
      _now = Duration.zero;
      _ticker.start();
    }
    if (_flakes.length >= 20) _flakes.removeRange(0, 2);
    _flakes.add(_Flake(point, direction, _now, _seed++));
    _flakes.add(_Flake(point, direction, _now, _seed++));
  }

  void _move(PointerMoveEvent event, double side) {
    if (!widget.enabled || _pointer != event.pointer || side <= 0) return;
    final end = event.localPosition / side;
    final start = _previous;
    _previous = end;
    _scrape(start, end);
  }

  // A screen reader activation makes one horizontal pass over the foil.
  void _scrapeBySemantics() {
    if (!widget.enabled) return;
    const heights = [.13, .18, .23, .10, .26, .16, .20];
    final y = heights[_accessiblePass++ % heights.length];
    _carry = 0;
    _scrape(Offset(.16, y), Offset(.84, y));
  }

  void _scrape(Offset start, Offset end) {
    if (_foil.complete) return;
    final delta = end - start;
    final distance = delta.distance;
    if (distance == 0) return;
    final direction = delta / distance;
    // Sample at equal spacing so a slow drag and a fast drag along the same
    // track cut the same foil, independent of pointer notification frequency.
    const spacing = .009;
    Offset? contact;
    for (var d = spacing - _carry; d <= distance; d += spacing) {
      final point = start + direction * d;
      if (_foil.score(point, direction)) contact = point;
    }
    _carry = (_carry + distance) % spacing;
    if (contact == null) return;
    if (_foil.complete) {
      widget.onRevealed();
    } else {
      _foil.updatePaths();
    }
    _shed(contact, direction);
    setState(() {});
  }

  @override
  void didUpdateWidget(covariant MedalScratch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) _pointer = null;
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
    child: AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, box) => Semantics(
          container: true,
          label: widget.revealed ? '最優秀賞' : 'メダルの箔を削る',
          button: !widget.revealed,
          liveRegion: widget.revealed,
          onTap: widget.enabled ? _scrapeBySemantics : null,
          excludeSemantics: true,
          child: Listener(
            key: const ValueKey('medal-rub'),
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) {
              if (!widget.enabled || _pointer != null || box.maxWidth <= 0) {
                return;
              }
              _pointer = event.pointer;
              _previous = event.localPosition / box.maxWidth;
              _carry = 0;
            },
            onPointerMove: (event) => _move(event, box.maxWidth),
            onPointerUp: (event) {
              if (_pointer == event.pointer) _pointer = null;
            },
            onPointerCancel: (event) {
              if (_pointer == event.pointer) _pointer = null;
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(painter: _FoilPainter(_foil.scuffed)),
                if (widget.revealed || _foil.open != null)
                  ClipPath(
                    key: const ValueKey('medal-revealed'),
                    clipper: _EngravingClip(
                      widget.revealed ? _band : _foil.open!,
                    ),
                    child: widget.engraved,
                  ),
                if (_flakes.isNotEmpty &&
                    !MediaQuery.disableAnimationsOf(context))
                  IgnorePointer(
                    child: CustomPaint(painter: _FlakePainter(_flakes, _now)),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

// The curved band follows the four engraved characters in kinpika.jpg.
// All coordinates are fractions of the square image, including its margins.
final _band = Path()
  ..moveTo(.185, .209)
  ..quadraticBezierTo(.50, -.079, .815, .209)
  ..lineTo(.777, .322)
  ..quadraticBezierTo(.50, .167, .223, .322)
  ..close();

class _Foil {
  static const _density = 240;
  static const _top = 14;
  static const _bottom = 78;
  static const _left = 43;
  static const _right = 197;
  static const _width = _right - _left;
  final _wear = Uint8List((_bottom - _top) * _width);
  static final _bandCells = Uint8List.fromList([
    for (var y = _top; y < _bottom; y++)
      for (var x = _left; x < _right; x++)
        _band.contains(Offset((x + .5) / _density, (y + .5) / _density))
            ? 1
            : 0,
  ]);
  static final _finishAt = (_bandCells.where((cell) => cell != 0).length * .7)
      .ceil();
  int _cutCells = 0;
  bool get complete => _cutCells >= _finishAt;
  Path? open;
  Path scuffed = Path();

  bool score(Offset p, Offset axis) {
    // Reject excursions into the room or over the mascot on the lower medal.
    const radius = .041;
    if (p.dx < .185 - radius ||
        p.dx > .815 + radius ||
        p.dy < .065 - radius ||
        p.dy > .322 + radius) {
      return false;
    }
    final normal = Offset(-axis.dy, axis.dx);
    final reachX = radius * normal.dx.abs() + .0065 * axis.dx.abs();
    final reachY = radius * normal.dy.abs() + .0065 * axis.dy.abs();
    final x0 = math.max(_left, ((p.dx - reachX) * _density).floor());
    final x1 = math.min(_right - 1, ((p.dx + reachX) * _density).ceil());
    final y0 = math.max(_top, ((p.dy - reachY) * _density).floor());
    final y1 = math.min(_bottom - 1, ((p.dy + reachY) * _density).ceil());
    final wobble = math.sin(p.dx * 60 + p.dy * 34) * .0015;
    var changed = false;
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        final cell = Offset((x + .5) / _density, (y + .5) / _density);
        final offset = cell - p;
        if ((offset.dx * axis.dx + offset.dy * axis.dy).abs() > .0065) continue;
        final cross = offset.dx * normal.dx + offset.dy * normal.dy;
        final grain = ((x * 17 + y * 37 + x * y) % 13) / 13;
        final i = (y - _top) * _width + x - _left;
        if (cross.abs() > radius * (.78 + .22 * grain) || _bandCells[i] == 0) {
          continue;
        }
        if (_wear[i] >= 4) continue;
        // Ridges on the scraping edge cut alternating fine grooves. Foil that
        // survives between them scores first and breaks on overlapping passes.
        final stripe = ((cross + wobble) / .012 + grain * .18) % 1;
        _wear[i] = math.min(4, _wear[i] + (stripe < .52 ? 4 : 1));
        if (_wear[i] == 4) _cutCells++;
        changed = true;
      }
    }
    return changed;
  }

  void updatePaths() {
    final exposed = Path();
    final scored = Path();
    var hasCut = false;
    for (var y = _top; y < _bottom; y++) {
      var x = _left;
      while (x < _right) {
        final i = (y - _top) * _width + x - _left;
        final value = _wear[i];
        if (value == 0) {
          x++;
          continue;
        }
        final cut = value == 4;
        final start = x++;
        while (x < _right) {
          final next = _wear[(y - _top) * _width + x - _left];
          if (next == 0 || (next == 4) != cut) break;
          x++;
        }
        (cut ? exposed : scored).addRect(
          Rect.fromLTRB(
            start / _density,
            y / _density,
            x / _density,
            (y + 1) / _density,
          ),
        );
        hasCut |= cut;
      }
    }
    open = hasCut ? exposed : null;
    scuffed = scored;
  }
}

class _EngravingClip extends CustomClipper<Path> {
  const _EngravingClip(this.open);
  final Path open;

  @override
  Path getClip(Size size) => open.transform(
    Matrix4.diagonal3Values(size.width, size.height, 1).storage,
  );

  @override
  bool shouldReclip(_EngravingClip old) => old.open != open;
}

class _FoilPainter extends CustomPainter {
  const _FoilPainter(this.scuffed);
  final Path scuffed;

  // Two cached paths keep the hundreds of flecks a pair of draw calls.
  static final _grains = () {
    final paths = [Path(), Path()];
    final random = math.Random(87);
    for (var i = 0; i < 640; i++) {
      final x = .18 + random.nextDouble() * .64;
      final y = .06 + random.nextDouble() * .27;
      final length = .0015 + random.nextDouble() * .005;
      paths[i % 2]
        ..moveTo(x, y)
        ..relativeLineTo(length, -length * .34);
    }
    return paths;
  }();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width, size.height);
    canvas.clipPath(_band);
    final paint = Paint()..color = const Color(0x276D592E);
    canvas.drawPath(_band, paint);
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = .0018
      ..color = const Color(0x77FFF4C7);
    canvas.drawPath(_grains[0], paint);
    paint.color = const Color(0x638B602D);
    canvas.drawPath(_grains[1], paint);
    paint.style = PaintingStyle.fill;
    canvas.drawPath(scuffed, paint..color = const Color(0xB5FFF0BF));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FoilPainter old) => scuffed != old.scuffed;
}

class _Flake {
  const _Flake(this.point, this.direction, this.born, this.seed);
  static const life = Duration(milliseconds: 330);
  final Offset point;
  final Offset direction;
  final Duration born;
  final int seed;
}

class _FlakePainter extends CustomPainter {
  const _FlakePainter(this.flakes, this.now);
  final List<_Flake> flakes;
  final Duration now;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width, size.height);
    final paint = Paint();
    for (final flake in flakes) {
      final t = (now - flake.born).inMicroseconds / _Flake.life.inMicroseconds;
      final side = (flake.seed % 2 == 0 ? 1 : -1);
      final normal = Offset(-flake.direction.dy, flake.direction.dx);
      final pos =
          flake.point +
          normal * (side * (.011 + t * .036)) +
          flake.direction * (.014 + t * .035) +
          Offset(0, t * t * .064);
      final length = .006 + (flake.seed % 5) * .001;
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(side * (t * 4 + flake.seed * .9));
      final chip = Path()
        ..moveTo(-length, .001)
        ..lineTo(-length * .4, -.004)
        ..lineTo(length, -.002)
        ..lineTo(length * .4, .0045)
        ..close();
      paint.color = const Color(0xFF79532E).withValues(alpha: (1 - t) * .78);
      canvas.drawPath(chip.shift(const Offset(.0015, .003)), paint);
      paint.color = const Color(0xFFFFD886).withValues(alpha: 1 - t);
      canvas.drawPath(chip, paint);
      paint
        ..color = const Color(0xFFFFF4C8).withValues(alpha: 1 - t)
        ..strokeWidth = .0016;
      canvas.drawLine(Offset(-length, .001), Offset(length, -.002), paint);
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FlakePainter old) => true;
}
