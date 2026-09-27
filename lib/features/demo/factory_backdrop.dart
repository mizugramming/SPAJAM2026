import 'dart:math' as math;

import 'package:flutter/material.dart';

const conveyorBeltAsset = 'assets/home/conveyor_belt.png';

/// A quiet workshop wall. Belts move once when a scene changes, then stop so
/// profile entry and reading never compete with a looping background.
class FactoryBackdrop extends StatefulWidget {
  const FactoryBackdrop({
    super.key,
    required this.transitionKey,
    required this.child,
  });

  final Object transitionKey;
  final Widget child;

  @override
  State<FactoryBackdrop> createState() => _FactoryBackdropState();
}

class _FactoryBackdropState extends State<FactoryBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _belt = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );
  bool _ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_ready) {
      _ready = true;
      _move();
    } else if (MediaQuery.disableAnimationsOf(context)) {
      _belt.value = 1;
    }
  }

  @override
  void didUpdateWidget(FactoryBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transitionKey != widget.transitionKey) _move();
  }

  void _move() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _belt.value = 1;
    } else {
      _belt.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _belt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _belt,
    child: widget.child,
    builder: (context, child) => _BeltMotion(
      progress: Curves.easeInOutCubic.transform(_belt.value),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: CustomPaint(painter: _WorkshopPainter()),
              ),
            ),
          ),
          child!,
        ],
      ),
    ),
  );
}

class _BeltMotion extends InheritedWidget {
  const _BeltMotion({required this.progress, required super.child});
  final double progress;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_BeltMotion>()?.progress ?? 1;

  @override
  bool updateShouldNotify(_BeltMotion oldWidget) =>
      progress != oldWidget.progress;
}

/// The original 2172 × 724 illustration stays intact at its 3:1 aspect ratio.
/// The front of the belt is 44% down the image; reserve the rest for its legs.
class ConveyorPlatform extends StatelessWidget {
  const ConveyorPlatform({super.key});

  static const aspectRatio = 3.0;
  static double heightFor(double width) => width / aspectRatio;
  static double canBottomOffsetFor(double width) => heightFor(width) * .56;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              conveyorBeltAsset,
              key: const Key('conveyor-belt-image'),
              fit: BoxFit.contain,
              excludeFromSemantics: true,
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _ConveyorWheelPainter(_BeltMotion.of(context)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _WorkshopPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFFFFCF3),
    );
    final faint = Paint()
      ..color = const Color(0xFFE8E1D4)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final window = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width - 102, 87, 86, 116),
      const Radius.circular(20),
    );
    canvas.drawRRect(window, Paint()..color = const Color(0xFFECF5F2));
    canvas.drawRRect(window, faint);
    canvas.drawLine(
      Offset(size.width - 59, 88),
      Offset(size.width - 59, 201),
      faint,
    );
    canvas.drawLine(
      Offset(size.width - 101, 145),
      Offset(size.width - 17, 145),
      faint,
    );
    final pipe = Path()
      ..moveTo(-8, 150)
      ..lineTo(11, 150)
      ..quadraticBezierTo(23, 150, 23, 164)
      ..lineTo(23, size.height * .66)
      ..quadraticBezierTo(23, size.height * .66 + 14, 9, size.height * .66 + 14)
      ..lineTo(-8, size.height * .66 + 14);
    canvas.drawPath(
      pipe,
      Paint()
        ..color = const Color(0xFFEDE7D9)
        ..strokeWidth = 13
        ..style = PaintingStyle.stroke,
    );
    canvas.drawPath(
      pipe,
      Paint()
        ..color = const Color(0xFFF7F2E7)
        ..strokeWidth = 7
        ..style = PaintingStyle.stroke,
    );
    // The wall stays almost plain behind text. The floor anchors the workshop.
    final floor = size.height - 72;
    canvas.drawRect(
      Rect.fromLTWH(0, floor, size.width, 72),
      Paint()..color = const Color(0xFFF2EDDF),
    );
    canvas.drawLine(Offset(0, floor), Offset(size.width, floor), faint);
    for (var x = -size.width; x < size.width * 2; x += 94) {
      canvas.drawLine(
        Offset(x, floor),
        Offset(x - 30, size.height),
        Paint()
          ..color = const Color(0xFFE7E0D2)
          ..strokeWidth = 1.4,
      );
    }
    canvas.drawLine(
      Offset(0, floor + 36),
      Offset(size.width, floor + 36),
      faint..strokeWidth = 1.4,
    );
    // Short ceiling rail and bolts suggest a factory without decorative text.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-8, 0, size.width + 16, 9),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFFE4E8DF),
    );
    for (final x in [24.0, size.width - 24]) {
      canvas.drawCircle(
        Offset(x, 4),
        2,
        Paint()..color = const Color(0xFFC4CFC8),
      );
    }
  }

  @override
  bool shouldRepaint(_WorkshopPainter oldDelegate) => false;
}

class _ConveyorWheelPainter extends CustomPainter {
  const _ConveyorWheelPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = const Color(0xFF807F79)
      ..strokeWidth = math.max(.7, size.width / 380)
      ..strokeCap = StrokeCap.round;
    final angle = progress * math.pi * 2;
    final radius = size.width * .006;
    final direction = Offset(math.cos(angle), math.sin(angle)) * radius;
    // Subtle spokes follow the two existing end rollers. The complete frame
    // and its feet stay planted; only the rollers turn during scene changes.
    for (final fraction in [.037, .96]) {
      final center = Offset(size.width * fraction, size.height * .519);
      canvas.drawLine(center - direction, center + direction, stroke);
    }
  }

  @override
  bool shouldRepaint(_ConveyorWheelPainter oldDelegate) =>
      progress != oldDelegate.progress;
}
