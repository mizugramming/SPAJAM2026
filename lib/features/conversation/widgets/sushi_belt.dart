import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../models/topic.dart';
import 'sushi_capsule.dart';

/// 回転寿司レーンの設定
class _LaneConfig {
  const _LaneConfig({required this.radiusXFactor, required this.radiusYFactor});

  final double radiusXFactor;
  final double radiusYFactor;
}

/// 寿司1個の配置情報
class _SushiPlacement {
  const _SushiPlacement({
    required this.topic,
    required this.dx,
    required this.dy,
    required this.scale,
    required this.depth,
  });

  final Topic topic;

  final double dx;
  final double dy;

  /// 奥→手前で寿司の大きさを変える
  final double scale;

  /// 0 = 奥
  /// 1 = 手前
  final double depth;
}

/// 回転寿司レーン
class SushiBelt extends StatefulWidget {
  const SushiBelt({
    super.key,
    required this.topics,
    required this.canSelect,
    required this.speakerName,
    required this.onSelectTopic,
  });

  final List<Topic> topics;
  final bool canSelect;
  final String? speakerName;
  final ValueChanged<Topic> onSelectTopic;

  @override
  State<SushiBelt> createState() => _SushiBeltState();
}

class _SushiBeltState extends State<SushiBelt>
    with SingleTickerProviderStateMixin {
  /// レーン全体の大きさ
  static const _lane = _LaneConfig(radiusXFactor: 0.43, radiusYFactor: 0.28);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap(Topic topic) {
    if (!widget.canSelect) return;

    widget.onSelectTopic(topic);
  }

  @override
  Widget build(BuildContext context) {
    final topics = widget.topics;

    if (topics.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final center = Offset(
          constraints.maxWidth / 2,
          constraints.maxHeight * 0.43,
        );

        final radius = Offset(
          constraints.maxWidth * _lane.radiusXFactor,
          constraints.maxHeight * _lane.radiusYFactor,
        );

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final placements = <_SushiPlacement>[];

            // =====================================================
            // 寿司の位置を計算
            // =====================================================

            for (var i = 0; i < topics.length; i++) {
              final t = (_controller.value + i / topics.length) % 1.0;

              placements.add(_placeSushi(topics[i], center, radius, t));
            }

            // 奥 → 手前の順番に並べる
            final behindChef = placements.where((p) => p.depth < 0.5).toList()
              ..sort((a, b) => a.depth.compareTo(b.depth));

            final frontOfChef = placements.where((p) => p.depth >= 0.5).toList()
              ..sort((a, b) => a.depth.compareTo(b.depth));

            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                // =================================================
                // 店内背景
                // =================================================
                _buildStoreBackdrop(),

                // =================================================
                // 回転寿司レーン
                // =================================================
                Positioned.fill(
                  child: CustomPaint(
                    painter: ConveyorBeltPainter(
                      center: center,
                      radius: radius,
                      animationValue: _controller.value,
                    ),
                  ),
                ),

                // =================================================
                // 奥側の寿司
                // =================================================
                for (final placement in behindChef) _buildSushi(placement),

                // =================================================
                // 大将
                // =================================================
                _buildChef(center),

                // =================================================
                // 手前側の寿司
                // =================================================
                for (final placement in frontOfChef) _buildSushi(placement),

                // =================================================
                // 手前のカウンター
                // =================================================
                _buildCounter(constraints),

                // =================================================
                // 操作説明
                // =================================================
                _buildTapHint(),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // 背景
  // ============================================================

  Widget _buildStoreBackdrop() {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFBDA694), Color(0xFFD6C1A9), Color(0xFFE7C38F)],
            stops: [0.0, 0.58, 0.58],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // 大将
  // ============================================================

  Widget _buildChef(Offset center) {
    const width = 190.0;
    const height = 240.0;

    return Positioned(
      left: center.dx - width / 2,
      top: center.dy - height / 2,
      width: width,
      height: height,
      child: Image.asset(
        'assets/images/taishou.png',
        width: width,
        height: height,
        fit: BoxFit.contain,
      ),
    );
  }

  // ============================================================
  // 寿司の位置
  // ============================================================

  _SushiPlacement _placeSushi(
    Topic topic,
    Offset center,
    Offset radius,
    double t,
  ) {
    final angle = 2 * math.pi * t;

    // 奥と手前の判定
    final depth = (math.sin(angle) + 1) / 2;

    // 奥は小さく、手前は大きく
    final scale = 0.55 + (1.15 - 0.55) * depth;

    return _SushiPlacement(
      topic: topic,

      dx: center.dx + radius.dx * math.cos(angle),

      dy: center.dy + radius.dy * math.sin(angle),

      scale: scale,

      depth: depth,
    );
  }

  // ============================================================
  // 寿司
  // ============================================================

  Widget _buildSushi(_SushiPlacement placement) {
    return Positioned(
      left: placement.dx - 48 * placement.scale,

      top: placement.dy - 34 * placement.scale,

      child: Transform.scale(
        scale: placement.scale,
        child: SushiCapsule(
          topic: placement.topic,
          onTap: () => _handleTap(placement.topic),
        ),
      ),
    );
  }

  // ============================================================
  // 手前のカウンター
  // ============================================================

  Widget _buildCounter(BoxConstraints constraints) {
    return Positioned(
      bottom: -25,
      left: -20,
      right: -20,
      child: Container(
        height: constraints.maxHeight * 0.15,
        decoration: BoxDecoration(
          color: const Color(0xFFB9824B),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(55),
              blurRadius: 14,
              offset: const Offset(0, -5),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 操作説明
  // ============================================================

  Widget _buildTapHint() {
    final message = widget.canSelect
        ? '寿司をタップして話題を開く'
        : (widget.speakerName?.isNotEmpty == true
              ? '${widget.speakerName}さんがネタを選んでいます'
              : 'ネタが選ばれるのを待っています');

    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(235),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.canSelect ? Icons.touch_app : Icons.hourglass_top),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

///
/// 回転寿司レーンを描画するCustomPainter
///
/// ただの黒い楕円ではなく、
///
/// ・ベルト本体
/// ・外側レール
/// ・内側レール
/// ・ベルトの継ぎ目
/// ・光沢
/// ・奥行き
///
/// を描画する。
///
class ConveyorBeltPainter extends CustomPainter {
  const ConveyorBeltPainter({
    required this.center,
    required this.radius,
    required this.animationValue,
  });

  final Offset center;
  final Offset radius;
  final double animationValue;

  @override
  void paint(Canvas canvas, Size size) {
    final outerRect = Rect.fromCenter(
      center: center,
      width: radius.dx * 2,
      height: radius.dy * 2,
    );

    // ------------------------------------------------------------
    // レーンの厚み
    // ------------------------------------------------------------

    final beltWidth = math.min(radius.dx, radius.dy) * 0.22;

    final innerRadius = Offset(radius.dx - beltWidth, radius.dy - beltWidth);

    final innerRect = Rect.fromCenter(
      center: center,
      width: innerRadius.dx * 2,
      height: innerRadius.dy * 2,
    );

    // ------------------------------------------------------------
    // ベルト本体
    // ------------------------------------------------------------

    final beltPath = Path()..fillType = PathFillType.evenOdd;

    beltPath.addOval(outerRect);
    beltPath.addOval(innerRect);

    final beltPaint = Paint()
      ..shader =
          const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE5E1DA),
              Color(0xFFB8B4AD),
              Color(0xFF8E8A83),
              Color(0xFFC9C5BE),
            ],
            stops: [0.0, 0.35, 0.65, 1.0],
          ).createShader(
            Rect.fromCenter(
              center: center,
              width: radius.dx * 2,
              height: radius.dy * 2,
            ),
          );

    canvas.drawPath(beltPath, beltPaint);

    // ------------------------------------------------------------
    // レーンの影
    // ------------------------------------------------------------

    final shadowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = beltWidth
      ..color = Colors.black.withAlpha(45);

    canvas.drawOval(outerRect.shift(const Offset(0, 7)), shadowPaint);

    // ------------------------------------------------------------
    // 外側のレール
    // ------------------------------------------------------------

    final outerRailPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..color = const Color(0xFF4D4A46);

    canvas.drawOval(outerRect, outerRailPaint);

    // ------------------------------------------------------------
    // 外側レールのハイライト
    // ------------------------------------------------------------

    final outerHighlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withAlpha(150);

    canvas.drawArc(
      outerRect,
      math.pi + 0.25,
      math.pi * 0.9,
      false,
      outerHighlightPaint,
    );

    // ------------------------------------------------------------
    // 内側のレール
    // ------------------------------------------------------------

    final innerRailPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..color = const Color(0xFF55514C);

    canvas.drawOval(innerRect, innerRailPaint);

    // ------------------------------------------------------------
    // ベルトの継ぎ目
    // ------------------------------------------------------------

    _drawBeltSegments(canvas, center, radius, innerRadius, animationValue);

    // ------------------------------------------------------------
    // ベルト上の光
    // ------------------------------------------------------------

    final shinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.white.withAlpha(80);

    final shineRect = Rect.fromCenter(
      center: center.translate(0, -3),
      width: radius.dx * 2 - beltWidth * 0.5,
      height: radius.dy * 2 - beltWidth * 0.5,
    );

    canvas.drawArc(shineRect, math.pi * 1.05, math.pi * 0.9, false, shinePaint);
  }

  // ============================================================
  // ベルトの継ぎ目を描画
  // ============================================================

  void _drawBeltSegments(
    Canvas canvas,
    Offset center,
    Offset outerRadius,
    Offset innerRadius,
    double animationValue,
  ) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF77736D).withAlpha(120);

    const segmentCount = 28;

    for (var i = 0; i < segmentCount; i++) {
      // ベルトの回転に合わせて継ぎ目も動かす
      final t = (i / segmentCount + animationValue * 0.55) % 1.0;

      final angle = t * math.pi * 2;

      final outerPoint = Offset(
        center.dx + outerRadius.dx * math.cos(angle),

        center.dy + outerRadius.dy * math.sin(angle),
      );

      final innerPoint = Offset(
        center.dx + innerRadius.dx * math.cos(angle),

        center.dy + innerRadius.dy * math.sin(angle),
      );

      canvas.drawLine(innerPoint, outerPoint, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ConveyorBeltPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
