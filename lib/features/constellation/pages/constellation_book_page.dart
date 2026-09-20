import 'package:flutter/material.dart';

class ConstellationBookPage extends StatelessWidget {
  const ConstellationBookPage({super.key});

  static const Color background = Color(0xFF050714);
  static const Color card = Color(0xFF0E1326);
  static const Color lavender = Color(0xFFC7B8FF);
  static const Color gold = Color(0xFFFFE29A);
  static const Color muted = Color(0xFF858CA8);

  @override
  Widget build(BuildContext context) {
    final discoveredCount = constellations.where((e) => e.discovered).length;

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _Header(
                discovered: discoveredCount,
                total: constellations.length,
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.82,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final data = constellations[index];

                  return ConstellationCard(
                    data: data,
                    onTap: () {
                      showConstellationDetail(context, data);
                    },
                  );
                }, childCount: constellations.length),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ヘッダー
// ============================================================

class _Header extends StatelessWidget {
  const _Header({required this.discovered, required this.total});

  final int discovered;
  final int total;

  @override
  Widget build(BuildContext context) {
    final progress = discovered / total;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
      child: Column(
        children: [
          const Icon(
            Icons.auto_awesome,
            color: ConstellationBookPage.gold,
            size: 25,
          ),

          const SizedBox(height: 10),

          const Text(
            '星 座 図 鑑',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
              letterSpacing: 5,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'あなたの余白から生まれた星座たち',
            style: TextStyle(color: ConstellationBookPage.muted, fontSize: 12),
          ),

          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: ConstellationBookPage.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: .06)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '発見した星座',
                      style: TextStyle(
                        color: ConstellationBookPage.muted,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '$discovered / $total',
                      style: const TextStyle(
                        color: ConstellationBookPage.gold,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: Colors.white.withValues(alpha: .06),
                    valueColor: const AlwaysStoppedAnimation(
                      ConstellationBookPage.lavender,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 星座カード
// ============================================================

class ConstellationCard extends StatelessWidget {
  const ConstellationCard({
    super.key,
    required this.data,
    required this.onTap,
  });

  final ConstellationData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: ConstellationBookPage.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: data.discovered
                  ? ConstellationBookPage.lavender.withValues(alpha: .15)
                  : Colors.white.withValues(alpha: .04),
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 15, 12, 4),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // ----------------------------
                      // 後ろのイラスト
                      // ----------------------------
                      Opacity(
                        opacity: data.discovered ? .23 : .045,
                        child: Image.asset(
                          data.imagePath,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),

                      // ----------------------------
                      // 星座
                      // ----------------------------
                      if (data.discovered)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: ConstellationPainter(
                              points: data.points,
                              connections: data.connections,
                            ),
                          ),
                        ),

                      // ----------------------------
                      // 未発見
                      // ----------------------------
                      if (!data.discovered)
                        const Icon(
                          Icons.lock_outline_rounded,
                          color: Color(0xFF626981),
                          size: 27,
                        ),
                    ],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  children: [
                    Text(
                      data.discovered ? data.name : '？？？？？',
                      style: TextStyle(
                        color: data.discovered
                            ? Colors.white
                            : const Color(0xFF626981),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 6),

                    if (data.discovered)
                      RarityStars(rarity: data.rarity, size: 10),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 詳細
// ============================================================

void showConstellationDetail(BuildContext context, ConstellationData data) {
  if (!data.discovered) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF090D1C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(30, 32, 30, 42),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                color: Color(0xFF707892),
                size: 38,
              ),

              const SizedBox(height: 18),

              const Text(
                'まだ見つかっていない星座',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                '日常に余白をつくって、\n新しい星を宇宙へ送ってみよう。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ConstellationBookPage.muted,
                  height: 1.7,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        );
      },
    );

    return;
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF090D1C),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    builder: (_) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(25, 15, 25, 42),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .15),
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            const SizedBox(height: 20),

            // ====================================
            // 大きい星座
            // ====================================
            SizedBox(
              width: double.infinity,
              height: 260,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: .18,
                    child: Image.asset(
                      data.imagePath,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),

                  Positioned.fill(
                    child: CustomPaint(
                      painter: ConstellationPainter(
                        points: data.points,
                        connections: data.connections,
                        large: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 15),

            Text(
              data.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            RarityStars(rarity: data.rarity, size: 15),

            const SizedBox(height: 20),

            Text(
              data.description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ConstellationBookPage.muted,
                fontSize: 13,
                height: 1.7,
              ),
            ),

            if (data.discoveredDate != null) ...[
              const SizedBox(height: 22),

              Text(
                '発見日  ${data.discoveredDate}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .35),
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}

// ============================================================
// レア度
// ============================================================

class RarityStars extends StatelessWidget {
  const RarityStars({super.key, required this.rarity, required this.size});

  final int rarity;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          Icons.star_rounded,
          size: size,
          color: index < rarity
              ? ConstellationBookPage.gold
              : Colors.white.withValues(alpha: .08),
        );
      }),
    );
  }
}

// ============================================================
// 星座Painter
// ============================================================

class ConstellationPainter extends CustomPainter {
  ConstellationPainter({
    required this.points,
    required this.connections,
    this.large = false,
  });

  final List<Offset> points;

  final List<List<int>> connections;

  final bool large;

  @override
  void paint(Canvas canvas, Size size) {
    Offset position(Offset point) {
      return Offset(point.dx * size.width, point.dy * size.height);
    }

    // ------------------------------------------
    // 星を結ぶ線
    // ------------------------------------------
    final linePaint = Paint()
      ..color = const Color(0xFFC7B8FF).withValues(alpha: .38)
      ..strokeWidth = large ? 1.3 : .8
      ..strokeCap = StrokeCap.round;

    for (final connection in connections) {
      if (connection.length < 2) continue;

      if (connection[0] >= points.length || connection[1] >= points.length) {
        continue;
      }

      canvas.drawLine(
        position(points[connection[0]]),
        position(points[connection[1]]),
        linePaint,
      );
    }

    // ------------------------------------------
    // 星
    // ------------------------------------------
    for (var i = 0; i < points.length; i++) {
      final point = position(points[i]);

      final glow = Paint()
        ..color = const Color(0xFFFFE6A7).withValues(alpha: .16)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, large ? 8 : 5);

      canvas.drawCircle(point, large ? 8 : 5, glow);

      final star = Paint()..color = const Color(0xFFFFE9A9);

      canvas.drawCircle(point, large ? 3.5 : 2.5, star);

      canvas.drawCircle(
        point,
        large ? 1.4 : .9,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ConstellationPainter oldDelegate) {
    return true;
  }
}

// ============================================================
// データ
// ============================================================

class ConstellationData {
  const ConstellationData({
    required this.id,
    required this.name,
    required this.description,
    required this.imagePath,
    required this.rarity,
    required this.discovered,
    required this.points,
    required this.connections,
    this.discoveredDate,
  });

  final String id;

  final String name;

  final String description;

  final String imagePath;

  final int rarity;

  final bool discovered;

  final String? discoveredDate;

  /// 0〜1で指定
  final List<Offset> points;

  /// pointsのindex同士を接続
  final List<List<int>> connections;
}

// ============================================================
// 共通の星配置
//
// 今は仮配置。
// あとで星座ごとに専用配置へ変更できる。
// ============================================================

const defaultPoints = <Offset>[
  Offset(.18, .58),
  Offset(.32, .35),
  Offset(.48, .48),
  Offset(.61, .28),
  Offset(.76, .44),
  Offset(.84, .65),
  Offset(.58, .70),
  Offset(.36, .68),
];

const defaultConnections = <List<int>>[
  [0, 1],
  [1, 2],
  [2, 3],
  [2, 4],
  [4, 5],
  [5, 6],
  [6, 7],
  [7, 0],
];

// ============================================================
// 20種類
//
// imagePathはassets/constellation/配下を指す。実際の画像はまだ
// 用意されていないため、Image.assetはerrorBuilderで静かに失敗する。
// ============================================================

const List<ConstellationData> constellations = [
  ConstellationData(
    id: 'roller_coaster',
    name: 'ジェットコースター座',
    description: '気持ちが大きく上がったり、下がったりした日に現れる星座。',
    imagePath: 'assets/constellation/roller_coaster.png',
    rarity: 3,
    discovered: true,
    discoveredDate: '2026.09.18',
    points: defaultPoints,
    connections: defaultConnections,
  ),

  ConstellationData(
    id: 'calm',
    name: '凪座',
    description: '心が穏やかで、静かな時間が流れた日に現れる星座。',
    imagePath: 'assets/constellation/calm.png',
    rarity: 2,
    discovered: true,
    discoveredDate: '2026.09.17',
    points: defaultPoints,
    connections: defaultConnections,
  ),

  ConstellationData(
    id: 'sunrise',
    name: '日の出座',
    description: '少しずつ気持ちが上向いていった日に現れる星座。',
    imagePath: 'assets/constellation/sunrise.png',
    rarity: 2,
    discovered: true,
    discoveredDate: '2026.09.15',
    points: defaultPoints,
    connections: defaultConnections,
  ),

  ConstellationData(
    id: 'after_rain',
    name: '雨上がり座',
    description: '沈んでいた気持ちが、最後には晴れていった日に現れる星座。',
    imagePath: 'assets/constellation/after_rain.png',
    rarity: 4,
    discovered: true,
    discoveredDate: '2026.09.12',
    points: defaultPoints,
    connections: defaultConnections,
  ),

  ConstellationData(
    id: 'wave',
    name: 'なみのり座',
    description: 'いろいろな感情を行ったり来たりした日に現れる星座。',
    imagePath: 'assets/constellation/wave.png',
    rarity: 2,
    discovered: true,
    discoveredDate: '2026.09.10',
    points: defaultPoints,
    connections: defaultConnections,
  ),

  ConstellationData(
    id: 'zero_gravity',
    name: '無重力座',
    description: '力を抜いて、何にも縛られず過ごせた日に現れる星座。',
    imagePath: 'assets/constellation/zero_gravity.png',
    rarity: 4,
    discovered: true,
    discoveredDate: '2026.09.08',
    points: defaultPoints,
    connections: defaultConnections,
  ),

  ConstellationData(
    id: 'sparkle',
    name: 'きらめき座',
    description: '小さな嬉しいことが、いくつも心に残った日に現れる星座。',
    imagePath: 'assets/constellation/sparkle.png',
    rarity: 3,
    discovered: false,
    points: defaultPoints,
    connections: defaultConnections,
  ),

  ConstellationData(
    id: 'crescent_moon',
    name: '三日月座',
    description: '静かに自分と向き合えた夜に現れる星座。',
    imagePath: 'assets/constellation/crescent_moon.png',
    rarity: 2,
    discovered: false,
    points: defaultPoints,
    connections: defaultConnections,
  ),

  ConstellationData(
    id: 'rocket',
    name: 'ロケット座',
    description: 'やってみたい気持ちや勢いが強くなった日に現れる星座。',
    imagePath: 'assets/constellation/rocket.png',
    rarity: 3,
    discovered: false,
    points: defaultPoints,
    connections: defaultConnections,
  ),

  ConstellationData(
    id: 'parachute',
    name: 'パラシュート座',
    description: '高ぶっていた気持ちが、ゆっくり落ち着いていった日に現れる星座。',
    imagePath: 'assets/constellation/parachute.png',
    rarity: 3,
    discovered: false,
    points: defaultPoints,
    connections: defaultConnections,
  ),

  ConstellationData(
    id: 'lightning',
    name: 'いなずま座',
    description: '気持ちが急激に変化した日に現れる星座。',
    imagePath: 'assets/constellation/lightning.png',
    rarity: 3,
    discovered: false,
    points: defaultPoints,
    connections: defaultConnections,
  ),

  ConstellationData(
    id: 'butterfly',
    name: 'ちょうちょ座',
    description: 'いろいろな気持ちの間を軽やかに行き来した日に現れる星座。',
    imagePath: 'assets/constellation/butterfly.png',
    rarity: 3,
    discovered: false,
    points: defaultPoints,
    connections: defaultConnections,
  ),

  ConstellationData(
    id: 'traveler',
    name: '旅人座',
    description: 'いつもとは少し違う場所や時間で余白を過ごした日に現れる星座。',
    imagePath: 'assets/constellation/traveler.png',
    rarity: 4,
    discovered: false,
    points: defaultPoints,
    connections: defaultConnections,
  ),

  ConstellationData(
    id: 'lost_child',
    name: '迷い子座',
    description: 'たくさん考えて、答えを探していた日に現れる星座。',
    imagePath: 'assets/constellation/lost_child.png',
    rarity: 3,
    discovered: false,
    points: defaultPoints,
    connections: defaultConnections,
  ),

  ConstellationData(
    id: 'sun',
    name: '太陽座',
    description: '明るい気持ちやエネルギーが一日を通して続いた日に現れる星座。',
    imagePath: 'assets/constellation/sun.png',
    rarity: 4,
    discovered: false,
    points: defaultPoints,
    connections: defaultConnections,
  ),

  ConstellationData(
    id: 'rain_cloud',
    name: '雨雲座',
    description: '少し沈んだ気持ちを抱えながら過ごした日に現れる星座。',
    imagePath: 'assets/constellation/rain_cloud.png',
    rarity: 2,
    discovered: false,
    points: defaultPoints,
    connections: defaultConnections,
  ),

  ConstellationData(
    id: 'spiral',
    name: 'ぐるぐる座',
    description: '考えや感情が頭の中をぐるぐる巡った日に現れる星座。',
    imagePath: 'assets/constellation/spiral.png',
    rarity: 3,
    discovered: false,
    points: defaultPoints,
    connections: defaultConnections,
  ),

  ConstellationData(
    id: 'first_star',
    name: '一等星座',
    description: 'ひとつの出来事や感情が、とても強く心に残った日に現れる星座。',
    imagePath: 'assets/constellation/first_star.png',
    rarity: 5,
    discovered: false,
    points: defaultPoints,
    connections: defaultConnections,
  ),

  ConstellationData(
    id: 'miracle',
    name: '奇跡座',
    description: 'めったにない特別な感情の動きが生まれた日に現れる星座。',
    imagePath: 'assets/constellation/miracle.png',
    rarity: 5,
    discovered: false,
    points: defaultPoints,
    connections: defaultConnections,
  ),

  ConstellationData(
    id: 'welcome_back',
    name: 'おかえり座',
    description: '久しぶりに自分のための余白をつくれた日に現れる星座。',
    imagePath: 'assets/constellation/welcome_back.png',
    rarity: 4,
    discovered: false,
    points: defaultPoints,
    connections: defaultConnections,
  ),
];
