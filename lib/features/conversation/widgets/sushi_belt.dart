import 'package:flutter/material.dart';

import '../../../models/topic.dart';
import 'sushi_capsule.dart';

/// 回転寿司の見た目(二重レーン・対象者カード・カウンター・タップ誘導)。
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
                return Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    _buildStoreBackdrop(),
                    _buildLane(
                      top: constraints.maxHeight * 0.25,
                      height: constraints.maxHeight * 0.30,
                      borderWidth: 22,
                      color: const Color(0xFF8D6A47),
                      filled: false,
                    ),
                    _buildSushiLayer(constraints, topics, isBack: true),
                    _buildTargetCard(constraints),
                    _buildLane(
                      bottom: constraints.maxHeight * 0.10,
                      height: constraints.maxHeight * 0.30,
                      borderWidth: 12,
                      color: const Color(0xFFB57C43),
                      filled: true,
                    ),
                    _buildSushiLayer(constraints, topics, isBack: false),
                    _buildCounter(constraints),
                    _buildTapHint(),
                  ],
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

  // 奥/手前のレーン(軌道)。filled=falseで枠だけのリング、trueで塗りつぶしのベルト。
  Widget _buildLane({
    double? top,
    double? bottom,
    required double height,
    required double borderWidth,
    required Color color,
    required bool filled,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: -60,
      right: -60,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: filled ? const Color(0xFFB57C43) : null,
          border: Border.all(color: color, width: borderWidth),
          borderRadius: BorderRadius.circular(180),
          boxShadow: filled
              ? [BoxShadow(color: Colors.black.withAlpha(77), blurRadius: 15, offset: const Offset(0, 7))]
              : null,
        ),
      ),
    );
  }

  // 中央のAI大将(将来的に画像を差し込むプレースホルダーとして、指名中の人の名前を添える)。
  Widget _buildTargetCard(BoxConstraints constraints) {
    return Positioned(
      top: constraints.maxHeight * 0.20,
      left: constraints.maxWidth * 0.25,
      right: constraints.maxWidth * 0.25,
      child: Container(
        height: constraints.maxHeight * 0.24,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8EF),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(64), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 34,
              backgroundColor: Color(0xFFE8D4BE),
              child: Icon(Icons.person, size: 44, color: Colors.brown),
            ),
            const SizedBox(height: 8),
            Text(
              widget.speakerName?.isNotEmpty == true ? widget.speakerName! : 'AI大将',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // 寿司の1レイヤー分(奥/手前)をまとめてアニメーションさせる。
  Widget _buildSushiLayer(BoxConstraints constraints, List<Topic> items, {required bool isBack}) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Stack(
          children: [
            for (var i = 0; i < items.length; i++)
              _buildSushi(
                constraints,
                items[i],
                (_controller.value + i / items.length) % 1.0,
                isBack,
              ),
          ],
        );
      },
    );
  }

  // レーン上を一周する位置計算。0-0.25:奥 0.25-0.50:右 0.50-0.75:手前 0.75-1.00:左。
  Widget _buildSushi(BoxConstraints constraints, Topic topic, double progress, bool isBack) {
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;

    double x;
    double y;
    double scale;

    if (progress < 0.25) {
      final p = progress / 0.25;
      x = width * (0.12 + p * 0.76);
      y = height * 0.30;
      scale = 0.55;
    } else if (progress < 0.50) {
      final p = (progress - 0.25) / 0.25;
      x = width * 0.88;
      y = height * (0.30 + p * 0.30);
      scale = 0.55 + p * 0.25;
    } else if (progress < 0.75) {
      final p = (progress - 0.50) / 0.25;
      x = width * (0.88 - p * 0.76);
      y = height * (0.60 + p * 0.15);
      // 手前に来るほど大きくする
      scale = 0.80 + p * 0.55;
    } else {
      final p = (progress - 0.75) / 0.25;
      x = width * 0.12;
      y = height * (0.75 - p * 0.45);
      scale = 1.35 - p * 0.80;
    }

    if (isBack) {
      y -= 20;
      scale *= 0.75;
    }

    return Positioned(
      left: x - 45 * scale,
      top: y - 30 * scale,
      child: Transform.scale(
        scale: scale,
        child: SushiCapsule(topic: topic, onTap: () => _handleTap(topic)),
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
