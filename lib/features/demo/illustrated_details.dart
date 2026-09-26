import 'package:flutter/material.dart';

import '../../app/tsunagun_theme.dart';

class TsunagunWordmark extends StatelessWidget {
  const TsunagunWordmark({super.key});

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: const _WordmarkPainter(),
    child: const Padding(
      padding: EdgeInsets.fromLTRB(0, 2, 14, 9),
      child: Text(
        'つなぐん',
        style: TextStyle(
          fontSize: 28,
          height: 1.2,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.5,
          color: TsunagunColors.blue,
        ),
      ),
    ),
  );
}

class _WordmarkPainter extends CustomPainter {
  const _WordmarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = TsunagunColors.yellow.withValues(alpha: .7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(3, size.height - 6)
        ..quadraticBezierTo(
          size.width * .45,
          size.height - 2,
          size.width - 19,
          size.height - 7,
        ),
      stroke,
    );
    canvas.drawCircle(
      Offset(size.width - 5, 9),
      3,
      Paint()
        ..color = TsunagunColors.blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
  }

  @override
  bool shouldRepaint(_WordmarkPainter oldDelegate) => false;
}

/// A quote belongs to a follower; it is not a container around the whole page.
class FollowerQuote extends StatelessWidget {
  const FollowerQuote({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: const _QuotePainter(),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 18),
      child: Text(text, style: const TextStyle(fontSize: 16, height: 1.6)),
    ),
  );
}

class _QuotePainter extends CustomPainter {
  const _QuotePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(21, 13)
      ..lineTo(32, 13)
      ..lineTo(40, 3)
      ..lineTo(48, 13)
      ..lineTo(w - 20, 11)
      ..quadraticBezierTo(w - 2, 11, w - 2, 29)
      ..lineTo(w - 3, h - 20)
      ..quadraticBezierTo(w - 3, h - 3, w - 21, h - 2)
      ..lineTo(21, h - 3)
      ..quadraticBezierTo(2, h - 3, 2, h - 21)
      ..lineTo(3, 31)
      ..quadraticBezierTo(3, 13, 21, 13)
      ..close();
    canvas.drawPath(path, Paint()..color = TsunagunColors.paper);
    canvas.drawPath(
      path,
      Paint()
        ..color = TsunagunColors.ink
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_QuotePainter oldDelegate) => false;
}

class IllustratedRope extends StatelessWidget {
  const IllustratedRope({super.key});

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: const _RopePainter(),
    size: const Size(double.infinity, 12),
  );
}

class _RopePainter extends CustomPainter {
  const _RopePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 5)
      ..quadraticBezierTo(size.width * .5, 9, size.width, 5);
    canvas.drawPath(
      path,
      Paint()
        ..color = TsunagunColors.ink
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 8,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFD9B471)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 4.5,
    );
    for (var x = 7.0; x < size.width; x += 14) {
      canvas.drawLine(
        Offset(x, 4),
        Offset(x + 3, 9),
        Paint()
          ..color = const Color(0xFF9E7946)
          ..strokeWidth = 1.4,
      );
    }
  }

  @override
  bool shouldRepaint(_RopePainter oldDelegate) => false;
}
