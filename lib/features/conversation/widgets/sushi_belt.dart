import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../models/topic.dart';
import 'sushi_capsule.dart';

/// レーン1本分の設定。ここに要素を足すだけでレーンを増やせる。
class _LaneConfig {
  const _LaneConfig({
    required this.radiusXFactor,
    required this.radiusYFactor,
    required this.scaleMin,
    required this.scaleMax,
    required this.borderWidth,
    this.phaseOffset = 0,
  });

  /// 画面幅・高さに対する楕円の半径の割合(画面サイズが変わっても比率を保つ)。
  final double radiusXFactor;
  final double radiusYFactor;

  /// 奥(上)にいるときと手前(下)にいるときの寿司の大きさ。
  final double scaleMin;
  final double scaleMax;

  final double borderWidth;

  /// レーンごとに寿司の位置をずらして、радиально重ならないようにする。
  final double phaseOffset;
}

/// 1フレーム分の寿司の配置情報。depthで大将の前後どちらに描くかを決める。
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
  final double scale;

  /// 0 = 最も奥(大将の後ろ) / 1 = 最も手前(大将の前)。
  final double depth;
}

/// 大将を中心に、楕円のレーンを寿司が回るUI。
/// 奥側(上半分)の寿司は大将の後ろ、手前側(下半分)の寿司は大将の前に描画して立体感を出す。
/// タップ可否や指名表示はConversationScreen側のロジックに委ねる(canSelect/onSelectTopic)。
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

class _SushiBeltState extends State<SushiBelt> with SingleTickerProviderStateMixin {
  // レーンを増やしたい場合はここに_LaneConfigを足すだけでよい。
  static const _lanes = [
    _LaneConfig(radiusXFactor: 0.26, radiusYFactor: 0.15, scaleMin: 0.45, scaleMax: 0.85, borderWidth: 16),
    _LaneConfig(radiusXFactor: 0.44, radiusYFactor: 0.27, scaleMin: 0.6, scaleMax: 1.3, borderWidth: 20, phaseOffset: 0.5),
  ];

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
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
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFC4935D), Color(0xFFE8C48F), Color(0xFFC9975D)],
        ),
      ),
      child: topics.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final center = Offset(constraints.maxWidth / 2, constraints.maxHeight * 0.44);
                final radii = [
                  for (final lane in _lanes)
                    Offset(
                      constraints.maxWidth * lane.radiusXFactor,
                      constraints.maxHeight * lane.radiusYFactor,
                    ),
                ];

                return AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final placements = <_SushiPlacement>[];
                    for (var laneIndex = 0; laneIndex < _lanes.length; laneIndex++) {
                      final lane = _lanes[laneIndex];
                      for (var i = 0; i < topics.length; i++) {
                        final t = (_controller.value + (i + lane.phaseOffset) / topics.length) % 1.0;
                        placements.add(_placeSushi(topics[i], center, radii[laneIndex], lane, t));
                      }
                    }

                    // 奥にあるものから順に描くことで、手前の寿司が奥の寿司に重なる。
                    final behindChef = placements.where((p) => p.depth < 0.5).toList()
                      ..sort((a, b) => a.depth.compareTo(b.depth));
                    final frontOfChef = placements.where((p) => p.depth >= 0.5).toList()
                      ..sort((a, b) => a.depth.compareTo(b.depth));

                    return Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        _buildStoreBackdrop(),
                        for (var i = 0; i < _lanes.length; i++)
                          _buildOrbitLane(center, radii[i], borderWidth: _lanes[i].borderWidth),
                        for (final placement in behindChef) _buildSushi(placement),
                        _buildChef(center),
                        for (final placement in frontOfChef) _buildSushi(placement),
                        _buildCounter(constraints),
                        _buildTapHint(),
                      ],
                    );
                  },
                );
              },
            ),
    );
  }

  // 店内の奥・床のグラデーション背景。
  Widget _buildStoreBackdrop() {
    return Positioned.fill(
      child: Column(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.brown.shade300, Colors.orange.shade100],
                ),
              ),
            ),
          ),
          Expanded(flex: 2, child: Container(color: const Color(0xFFD9A568))),
        ],
      ),
    );
  }

  // 大将を中心にした楕円のレーン。寿司の移動経路と同じcenter/radiusを使うので必ず一致する。
  Widget _buildOrbitLane(Offset center, Offset radius, {required double borderWidth}) {
    return Positioned(
      left: center.dx - radius.dx,
      top: center.dy - radius.dy,
      width: radius.dx * 2,
      height: radius.dy * 2,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black, width: borderWidth),
          borderRadius: BorderRadius.circular(math.max(radius.dx, radius.dy)),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(60), blurRadius: 12, offset: const Offset(0, 6))],
        ),
      ),
    );
  }

  // 中央のAI大将(将来的に画像を差し込むプレースホルダーとして、指名中の人の名前を添える)。
  Widget _buildChef(Offset center) {
    const width = 120.0;
    const height = 104.0;
    return Positioned(
      left: center.dx - width / 2,
      top: center.dy - height / 2,
      width: width,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8EF),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(64), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 26,
              backgroundColor: Color(0xFFE8D4BE),
              child: Icon(Icons.person, size: 34, color: Colors.brown),
            ),
            const SizedBox(height: 6),
            Text(
              widget.speakerName?.isNotEmpty == true ? widget.speakerName! : 'AI大将',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // 楕円のレーン上をtで一周する位置と、手前ほど大きくなるスケールを計算する。
  _SushiPlacement _placeSushi(Topic topic, Offset center, Offset radius, _LaneConfig lane, double t) {
    final angle = 2 * math.pi * t;
    final depth = (math.sin(angle) + 1) / 2; // 0=最も奥(上) 1=最も手前(下)
    return _SushiPlacement(
      topic: topic,
      dx: center.dx + radius.dx * math.cos(angle),
      dy: center.dy + radius.dy * math.sin(angle),
      scale: lane.scaleMin + (lane.scaleMax - lane.scaleMin) * depth,
      depth: depth,
    );
  }

  Widget _buildSushi(_SushiPlacement placement) {
    return Positioned(
      left: placement.dx - 45 * placement.scale,
      top: placement.dy - 30 * placement.scale,
      child: Transform.scale(
        scale: placement.scale,
        child: SushiCapsule(topic: placement.topic, onTap: () => _handleTap(placement.topic)),
      ),
    );
  }

  // 手前のカウンター/テーブル。
  Widget _buildCounter(BoxConstraints constraints) {
    return Positioned(
      bottom: -20,
      left: -20,
      right: -20,
      child: Container(
        height: constraints.maxHeight * 0.17,
        decoration: BoxDecoration(
          color: const Color(0xFFB9783D),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(64), blurRadius: 10, offset: const Offset(0, -3))],
        ),
      ),
    );
  }

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
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
