import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../../../models/topic.dart';
import 'sushi_capsule.dart';

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
  /// レーンの両端が画面外で切れるようにする、はみ出し幅
  static const _laneOverhang = 60.0;

  /// 手動配置モード。trueの間は大将・奥レーン・手前レーンをドラッグで
  /// 動かせる(座標は画面右上に表示される)。位置が決まったらfalseに
  /// 戻し、表示された値を各定数(okuTop/temaeTop/chefOffsetなど)に
  /// 反映する。
  static const _manualPlacementMode = true;

  Offset _bgDrag = const Offset(1, -180);
  double _bgScale = 1.19;

  Offset _fukidashiDrag = const Offset(4, -191);
  double _fukidashiScale = 1.40;

  Offset _chefDrag = const Offset(3, 31);
  double _chefScale = 1;

  Offset _okuDrag = const Offset(0, 40);
  double _okuScale = 2.16;
  Offset _okuBaseDrag = const Offset(0, -15);

  Offset _temaeDrag = const Offset(0, 49);
  double _temaeScale = 1.58;
  Offset _temaeBaseDrag = const Offset(0, -44);

  Offset _okuSushiDrag = const Offset(46, -76);
  double _okuSushiScale = 1.13;

  Offset _temaeSushiDrag = const Offset(29, -128);
  double _temaeSushiScale = 1.25;

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

        final laneSpan = constraints.maxWidth + _laneOverhang * 2;

        const okuTop = -40.0;
        const okuSurfaceHeight = 14.0;
        const okuBaseHeight = 60.0;

        const temaeTop = 50.0;
        const temaeSurfaceHeight = 35.0;
        const temaeBaseHeight = 140.0;

        // 手動配置モードの拡大・縮小を反映した実際のサイズ
        final okuSurfaceHeightEff = okuSurfaceHeight * _okuScale;
        final okuBaseHeightEff = okuBaseHeight * _okuScale;
        final okuHeight = okuSurfaceHeightEff + okuBaseHeightEff;

        final temaeSurfaceHeightEff = temaeSurfaceHeight * _temaeScale;
        final temaeBaseHeightEff = temaeBaseHeight * _temaeScale;
        final temaeHeight = temaeSurfaceHeightEff + temaeBaseHeightEff;

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                // =================================================
                // 店内背景
                // =================================================
                _buildStoreBackdrop(offset: _bgDrag, scale: _bgScale),

                // =================================================
                // 吹き出し(背景の手前)
                // =================================================
                _buildFukidashi(
                  center: center + _fukidashiDrag,
                  scale: _fukidashiScale,
                ),

                // =================================================
                // レーンの連結部(画面両端)
                //
                // 奥レーンと手前レーンが別々に見えないよう、両端で
                // 縦に繋いで一本のベルトのように見せる。
                // =================================================
                _buildLaneEdgeConnector(
                  top: center.dy + okuTop + okuHeight,
                  bottom: center.dy + temaeTop,
                  alignLeft: true,
                ),
                _buildLaneEdgeConnector(
                  top: center.dy + okuTop + okuHeight,
                  bottom: center.dy + temaeTop,
                  alignLeft: false,
                ),

                // =================================================
                // レーン(奥) - 大将の背後を通る側。奥は左向きに流れる
                // =================================================
                ..._buildLaneBar(
                  top: center.dy + okuTop + _okuDrag.dy,
                  baseTop:
                      center.dy + okuTop + okuSurfaceHeightEff + _okuBaseDrag.dy,
                  asset: 'assets/images/re-noku.png',
                  direction: -1,
                  surfaceHeight: okuSurfaceHeightEff,
                  baseHeight: okuBaseHeightEff,
                ),

                // 奥レーンに乗る寿司(2つ)。後ろ向き画像で、大将より奥に見せる
                ..._buildLaneSushi(
                  topics: topics,
                  laneTop: center.dy + okuTop + _okuDrag.dy,
                  laneHeight: okuHeight,
                  surfaceHeight: okuSurfaceHeightEff,
                  direction: -1,
                  ushiro: true,
                  baseFractions: const [0.0, 0.5],
                  scale: 0.65 * _okuSushiScale,
                  extraOffset: _okuSushiDrag,
                  laneSpan: laneSpan,
                ),

                // =================================================
                // 大将
                // =================================================
                _buildChef(center + _chefDrag, scale: _chefScale),

                // =================================================
                // レーン(手前) - 大将の手前を通る側。手前は右向きに流れる
                // =================================================
                ..._buildLaneBar(
                  top: center.dy + temaeTop + _temaeDrag.dy,
                  baseTop:
                      center.dy +
                      temaeTop +
                      temaeSurfaceHeightEff +
                      _temaeBaseDrag.dy,
                  asset: 'assets/images/re-ntemae.png',
                  direction: 1,
                  surfaceHeight: temaeSurfaceHeightEff,
                  baseHeight: temaeBaseHeightEff,
                ),

                // 手前レーンに乗る寿司(2つ)。奥レーンとは位相をずらして被りを防ぐ
                ..._buildLaneSushi(
                  topics: topics,
                  laneTop: center.dy + temaeTop + _temaeDrag.dy,
                  laneHeight: temaeHeight,
                  surfaceHeight: temaeSurfaceHeightEff,
                  direction: 1,
                  ushiro: false,
                  baseFractions: const [0.2, 0.7],
                  scale: 1 * _temaeSushiScale,
                  extraOffset: _temaeSushiDrag,
                  laneSpan: laneSpan,
                ),

                // =================================================
                // 手前のカウンター(手前レーンの下端から繋げて、
                // 背景の余白を隠す)
                // =================================================
                _buildCounter(center.dy + temaeTop + temaeHeight + _temaeDrag.dy),

                // =================================================
                // 操作説明
                // =================================================
                _buildTapHint(),

                // =================================================
                // 手動配置モード: ドラッグ用ハンドルと座標表示
                // =================================================
                if (_manualPlacementMode) ...[
                  _buildDragHandle(
                    label: '大将',
                    top: center.dy + _chefDrag.dy - 40,
                    left: center.dx + _chefDrag.dx - 40,
                    width: 80,
                    height: 80,
                    color: Colors.red,
                    onDrag: (delta) => setState(() => _chefDrag += delta),
                  ),
                  _buildDragHandle(
                    label: '奥レーン',
                    top: center.dy + okuTop + _okuDrag.dy,
                    left: 0,
                    width: constraints.maxWidth,
                    height: okuSurfaceHeightEff,
                    color: Colors.blue,
                    onDrag: (delta) => setState(() => _okuDrag += delta),
                  ),
                  _buildDragHandle(
                    label: '奥台',
                    top:
                        center.dy +
                        okuTop +
                        okuSurfaceHeightEff +
                        _okuBaseDrag.dy,
                    left: 0,
                    width: constraints.maxWidth,
                    height: okuBaseHeightEff,
                    color: Colors.lightBlue,
                    onDrag: (delta) => setState(() => _okuBaseDrag += delta),
                  ),
                  _buildDragHandle(
                    label: '手前レーン',
                    top: center.dy + temaeTop + _temaeDrag.dy,
                    left: 0,
                    width: constraints.maxWidth,
                    height: temaeSurfaceHeightEff,
                    color: Colors.green,
                    onDrag: (delta) => setState(() => _temaeDrag += delta),
                  ),
                  _buildDragHandle(
                    label: '手前台',
                    top:
                        center.dy +
                        temaeTop +
                        temaeSurfaceHeightEff +
                        _temaeBaseDrag.dy,
                    left: 0,
                    width: constraints.maxWidth,
                    height: temaeBaseHeightEff,
                    color: Colors.lightGreen,
                    onDrag: (delta) => setState(() => _temaeBaseDrag += delta),
                  ),

                  // 背景・サイズ・寿司の位置は専用の操作パネル(左上に
                  // 縦に並ぶ、移動用□と拡大縮小用◇のペア)で調整する。
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildMiniGizmo(
                          label: '背景',
                          color: Colors.purple,
                          onMove: (d) => setState(() => _bgDrag += d),
                          onResize: (dx) => setState(
                            () => _bgScale = (_bgScale + dx / 200).clamp(
                              0.5,
                              3.0,
                            ),
                          ),
                        ),
                        _buildMiniGizmo(
                          label: '吹き出し',
                          color: Colors.pink,
                          onMove: (d) => setState(() => _fukidashiDrag += d),
                          onResize: (dx) => setState(
                            () => _fukidashiScale =
                                (_fukidashiScale + dx / 100).clamp(0.3, 3.0),
                          ),
                        ),
                        _buildMiniGizmo(
                          label: '大将 拡大',
                          color: Colors.red,
                          onMove: null,
                          onResize: (dx) => setState(
                            () => _chefScale = (_chefScale + dx / 100).clamp(
                              0.3,
                              3.0,
                            ),
                          ),
                        ),
                        _buildMiniGizmo(
                          label: '奥レーン 拡大',
                          color: Colors.blue,
                          onMove: null,
                          onResize: (dx) => setState(
                            () => _okuScale = (_okuScale + dx / 100).clamp(
                              0.3,
                              3.0,
                            ),
                          ),
                        ),
                        _buildMiniGizmo(
                          label: '手前レーン 拡大',
                          color: Colors.green,
                          onMove: null,
                          onResize: (dx) => setState(
                            () => _temaeScale = (_temaeScale + dx / 100)
                                .clamp(0.3, 3.0),
                          ),
                        ),
                        _buildMiniGizmo(
                          label: '奥寿司',
                          color: Colors.orange,
                          onMove: (d) => setState(() => _okuSushiDrag += d),
                          onResize: (dx) => setState(
                            () => _okuSushiScale = (_okuSushiScale + dx / 100)
                                .clamp(0.3, 3.0),
                          ),
                        ),
                        _buildMiniGizmo(
                          label: '手前寿司',
                          color: Colors.teal,
                          onMove: (d) => setState(() => _temaeSushiDrag += d),
                          onResize: (dx) => setState(
                            () => _temaeSushiScale =
                                (_temaeSushiScale + dx / 100).clamp(0.3, 3.0),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Positioned(
                    top: 8,
                    right: 8,
                    child: _buildPlacementReadout(
                      okuTop: okuTop,
                      okuBaseTop: okuTop + okuSurfaceHeightEff,
                      temaeTop: temaeTop,
                      temaeBaseTop: temaeTop + temaeSurfaceHeightEff,
                    ),
                  ),
                ],
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

  Widget _buildStoreBackdrop({Offset offset = Offset.zero, double scale = 1}) {
    return Positioned.fill(
      child: ColoredBox(
        // 画像の縦横比が画面と合わず余白ができる部分の色
        color: const Color(0xFFD9C7A8),
        child: ClipRect(
          child: Transform.translate(
            offset: offset,
            child: Transform.scale(
              scale: scale,
              // containにして、両端が切れずに画像全体が収まるようにする
              child: Image.asset(
                'assets/images/noren.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // 吹き出し
  // ============================================================

  Widget _buildFukidashi({required Offset center, double scale = 1}) {
    const width = 260.0;
    const height = 140.0;

    return Positioned(
      left: center.dx - width * scale / 2,
      top: center.dy - height * scale / 2,
      width: width * scale,
      height: height * scale,
      child: Image.asset('assets/images/fukidashi.png', fit: BoxFit.contain),
    );
  }

  // ============================================================
  // 大将まわりのレーン(奥/手前)
  // ============================================================

  /// pngの左右にある丸い端の部分(画像全体に対する幅の割合)。
  /// この部分は固定して、真ん中の繰り返し部分だけを流す。
  static const _laneCapFrac = 0.075;

  /// png上部の透明な余白の高さの割合。実際のバーの絵はここから始まる。
  static const _laneSurfaceTopFrac = 0.32;

  /// バーの模様(動く上面)の高さの割合(png全体に対する)。土台(dai)側は
  /// 模様がない別画像を使うので、レーン側はこの上面の帯だけを切り出す。
  static const _laneSurfaceFrac = 0.185;

  static const _laneImageWidth = 2172.0;
  static const _laneImageHeight = 724.0;

  /// レーンの模様が流れる速さ(共通)。寿司もこれと同じ速さで動かし、
  /// レーンに乗って流れているように見せる。
  static const _laneSpeedFactor = 2.5;

  /// 切り出した部分(幅の割合 x 高さの割合)を、指定した高さで表示する
  /// ときの正しい横幅を求める。
  static double _laneOutWidthFor(
    double widthFrac,
    double heightFrac,
    double outHeight,
  ) {
    return outHeight *
        (widthFrac * _laneImageWidth) /
        (heightFrac * _laneImageHeight);
  }

  /// レーンの模様(真ん中の繰り返し部分)1タイル分の横幅。
  /// 寿司の移動速度をレーンと揃えるためにも使う。
  static double _laneMiddleTileWidth(double surfaceHeight) {
    const middleFrac = 1 - _laneCapFrac * 2;
    return _laneOutWidthFor(middleFrac, _laneSurfaceFrac, surfaceHeight);
  }

  /// 大将の奥・手前を通るレーンの帯(動く上面)と、その下に固定で敷く
  /// 台(dai)をまとめて返す。
  ///
  /// 実際の画面幅より広く配置し、丸まった両端は画面外で切れるようにする。
  /// pngの丸い端(キャップ)は動かさず固定し、真ん中の繰り返し部分だけを
  /// [direction] の向き(+1で右、-1で左)にスクロールさせる。土台(dai)は
  /// 模様がなく動かないので、レーンの模様だけが流れているように見える。
  /// [surfaceHeight] は模様が動く帯の高さ、[baseHeight] はその下に敷く
  /// 土台(dai)の高さ。
  List<Widget> _buildLaneBar({
    required double top,
    required double baseTop,
    required String asset,
    required double direction,
    required double surfaceHeight,
    required double baseHeight,
  }) {
    const middleTileCount = 8;

    final capWidth = _laneOutWidthFor(
      _laneCapFrac,
      _laneSurfaceFrac,
      surfaceHeight,
    );
    const middleFrac = 1 - _laneCapFrac * 2;
    final middleTileWidth = _laneMiddleTileWidth(surfaceHeight);

    final progress = (_controller.value * _laneSpeedFactor) % 1.0;
    final shift = progress * middleTileWidth * direction;

    final surface = Positioned(
      left: -_laneOverhang,
      right: -_laneOverhang,
      top: top,
      height: surfaceHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final middleWidth = constraints.maxWidth - capWidth * 2;

          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // 左端(固定)
              _buildLaneSlice(
                asset: asset,
                left: 0,
                width: capWidth,
                height: surfaceHeight,
                srcLeftFrac: 0,
                srcWidthFrac: _laneCapFrac,
                srcTopFrac: _laneSurfaceTopFrac,
                srcHeightFrac: _laneSurfaceFrac,
              ),

              // 真ん中(繰り返しスクロール)
              Positioned(
                left: capWidth,
                width: middleWidth,
                top: 0,
                height: surfaceHeight,
                child: ClipRect(
                  child: OverflowBox(
                    minWidth: middleTileWidth * middleTileCount,
                    maxWidth: middleTileWidth * middleTileCount,
                    alignment: Alignment.center,
                    child: Transform.translate(
                      offset: Offset(shift, 0),
                      child: Row(
                        children: List.generate(
                          middleTileCount,
                          (_) => _buildLaneSliceInline(
                            asset: asset,
                            width: middleTileWidth,
                            height: surfaceHeight,
                            srcLeftFrac: _laneCapFrac,
                            srcWidthFrac: middleFrac,
                            srcTopFrac: _laneSurfaceTopFrac,
                            srcHeightFrac: _laneSurfaceFrac,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 右端(固定)
              _buildLaneSlice(
                asset: asset,
                left: null,
                right: 0,
                width: capWidth,
                height: surfaceHeight,
                srcLeftFrac: 1 - _laneCapFrac,
                srcWidthFrac: _laneCapFrac,
                srcTopFrac: _laneSurfaceTopFrac,
                srcHeightFrac: _laneSurfaceFrac,
              ),
            ],
          );
        },
      ),
    );

    // 土台(dai) - レーンとは別に動かせる。両端は画面外で切れる。
    final base = Positioned(
      left: -_laneOverhang,
      right: -_laneOverhang,
      top: baseTop,
      height: baseHeight,
      child: Image.asset('assets/images/dai.png', fit: BoxFit.fill),
    );

    return [base, surface];
  }

  /// pngの一部(横方向の一区間)だけを切り出して表示する。
  Widget _buildLaneSlice({
    required String asset,
    double? left,
    double? right,
    required double width,
    required double height,
    required double srcLeftFrac,
    required double srcWidthFrac,
    required double srcTopFrac,
    required double srcHeightFrac,
  }) {
    return Positioned(
      left: left,
      right: right,
      top: 0,
      width: width,
      height: height,
      child: _buildLaneSliceInline(
        asset: asset,
        width: width,
        height: height,
        srcLeftFrac: srcLeftFrac,
        srcWidthFrac: srcWidthFrac,
        srcTopFrac: srcTopFrac,
        srcHeightFrac: srcHeightFrac,
      ),
    );
  }

  /// [_buildLaneSlice]の中身だけ(Positionedなし)。Rowの中などでも使える。
  /// pngの左上を原点として、横方向は[srcLeftFrac]から幅[srcWidthFrac]、
  /// 縦方向は[srcTopFrac]から高さ[srcHeightFrac](いずれも画像全体に対する
  /// 割合)の範囲を切り出して[width]x[height]で表示する。
  Widget _buildLaneSliceInline({
    required String asset,
    required double width,
    required double height,
    required double srcLeftFrac,
    required double srcWidthFrac,
    required double srcTopFrac,
    required double srcHeightFrac,
  }) {
    final fullWidth = width / srcWidthFrac;
    final fullHeight = height / srcHeightFrac;

    return ClipRect(
      child: SizedBox(
        width: width,
        height: height,
        child: OverflowBox(
          minWidth: fullWidth,
          maxWidth: fullWidth,
          minHeight: fullHeight,
          maxHeight: fullHeight,
          alignment: Alignment.topLeft,
          child: Transform.translate(
            offset: Offset(-srcLeftFrac * fullWidth, -srcTopFrac * fullHeight),
            child: Image.asset(
              asset,
              width: fullWidth,
              height: fullHeight,
              fit: BoxFit.fill,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // レーンの連結部
  // ============================================================

  /// 奥レーンと手前レーンを画面の端で縦に繋ぎ、1本のベルトに見せる。
  Widget _buildLaneEdgeConnector({
    required double top,
    required double bottom,
    required bool alignLeft,
  }) {
    const width = 26.0;

    return Positioned(
      top: top,
      height: bottom - top,
      left: alignLeft ? 0 : null,
      right: alignLeft ? null : 0,
      width: width,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF3C883), Color(0xFFB9824B)],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // 大将
  // ============================================================

  Widget _buildChef(Offset center, {double scale = 1}) {
    final width = 190.0 * 1.5 * scale;
    final height = 240.0 * 1.5 * scale;

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
  // レーンに乗る寿司
  // ============================================================

  /// レーンの上に寿司を並べる。
  ///
  /// [baseFractions] はレーン全幅(はみ出し込み)に対する初期位置(0〜1)。
  /// レーンの模様(1タイル=[surfaceHeight]から求まる幅)と同じ
  /// ピクセル速度で動かすことで、レーンに乗って流れているように見せる。
  /// ラップする境界(0/1の切り替わり)は、はみ出し部分(画面外)に来る
  /// ようにしてあるので、繋ぎ目は見えない。
  List<Widget> _buildLaneSushi({
    required List<Topic> topics,
    required double laneTop,
    required double laneHeight,
    required double surfaceHeight,
    required double direction,
    required bool ushiro,
    required List<double> baseFractions,
    required double scale,
    required double laneSpan,
    Offset extraOffset = Offset.zero,
  }) {
    // レーンの模様と同じピクセル速度になるよう、
    // (レーンのタイル幅 / レーン全幅)の比率をスピードに掛ける。
    final middleTileWidth = _laneMiddleTileWidth(surfaceHeight);
    final speedFactor = _laneSpeedFactor * middleTileWidth / laneSpan;

    final progress = (_controller.value * speedFactor) % 1.0;
    final size = const Size(100, 70) * scale;
    final laneCenterY = laneTop + laneHeight / 2;

    final widgets = <Widget>[];

    for (var i = 0; i < baseFractions.length && i < topics.length; i++) {
      final topic = topics[i];
      final frac = (baseFractions[i] + progress * direction) % 1.0;
      final dx = -_laneOverhang + frac * laneSpan + extraOffset.dx;

      widgets.add(
        Positioned(
          left: dx - size.width / 2,
          top: laneCenterY - size.height / 2 + extraOffset.dy,
          child: SushiCapsule(
            topic: topic,
            onTap: () => _handleTap(topic),
            ushiro: ushiro,
            size: size,
          ),
        ),
      );
    }

    return widgets;
  }

  // ============================================================
  // 手前のカウンター
  // ============================================================

  Widget _buildCounter(double top) {
    return Positioned(
      top: top,
      bottom: -25,
      left: -20,
      right: -20,
      child: Container(
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

  // ============================================================
  // 手動配置モード
  // ============================================================

  /// ドラッグで位置を動かすための、半透明の当たり判定エリア。
  Widget _buildDragHandle({
    required String label,
    required double top,
    required double left,
    required double width,
    required double height,
    required Color color,
    required ValueChanged<Offset> onDrag,
  }) {
    return Positioned(
      top: top,
      left: left,
      width: width,
      height: height,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanUpdate: (details) => onDrag(details.delta),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color.withAlpha(35),
            border: Border.all(color: color.withAlpha(180)),
          ),
          child: Align(
            alignment: Alignment.topLeft,
            child: Container(
              color: color,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 移動用[onMove]と拡大縮小用[onResize]のミニボタンを並べたもの。
  /// [onMove]がnullなら移動ボタンは出さない(拡大縮小のみの項目用)。
  Widget _buildMiniGizmo({
    required String label,
    required Color color,
    required ValueChanged<Offset>? onMove,
    required ValueChanged<double> onResize,
  }) {
    Widget miniButton({required IconData icon, required VoidCallback? tap}) {
      return Container(
        width: 22,
        height: 22,
        margin: const EdgeInsets.only(left: 2),
        color: color,
        child: Icon(icon, color: Colors.white, size: 14),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            color: color.withAlpha(200),
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
          ),
          if (onMove != null)
            GestureDetector(
              onPanUpdate: (d) => onMove(d.delta),
              child: miniButton(icon: Icons.open_with, tap: null),
            ),
          GestureDetector(
            onPanUpdate: (d) => onResize(d.delta.dx),
            child: miniButton(icon: Icons.open_in_full, tap: null),
          ),
        ],
      ),
    );
  }

  /// 現在のドラッグ量・拡大率を、コードに反映しやすいテキストにする。
  String _placementSummary({
    required double okuTop,
    required double okuBaseTop,
    required double temaeTop,
    required double temaeBaseTop,
  }) {
    String fmt(double v) => v.toStringAsFixed(2);

    return '背景: dx=${fmt(_bgDrag.dx)} dy=${fmt(_bgDrag.dy)} scale=${fmt(_bgScale)}\n'
        '吹き出し: dx=${fmt(_fukidashiDrag.dx)} dy=${fmt(_fukidashiDrag.dy)} scale=${fmt(_fukidashiScale)}\n'
        '大将: dx=${fmt(_chefDrag.dx)} dy=${fmt(_chefDrag.dy)} scale=${fmt(_chefScale)}\n'
        '奥レーン: top=${fmt(okuTop + _okuDrag.dy)} scale=${fmt(_okuScale)}\n'
        '奥台: top=${fmt(okuBaseTop + _okuBaseDrag.dy)}\n'
        '手前レーン: top=${fmt(temaeTop + _temaeDrag.dy)} scale=${fmt(_temaeScale)}\n'
        '手前台: top=${fmt(temaeBaseTop + _temaeBaseDrag.dy)}\n'
        '奥寿司: dx=${fmt(_okuSushiDrag.dx)} dy=${fmt(_okuSushiDrag.dy)} scale=${fmt(_okuSushiScale)}\n'
        '手前寿司: dx=${fmt(_temaeSushiDrag.dx)} dy=${fmt(_temaeSushiDrag.dy)} scale=${fmt(_temaeSushiScale)}';
  }

  /// 現在のドラッグ量・拡大率を表示し、コピーボタンでクリップボードに
  /// 保存できるようにする。
  Widget _buildPlacementReadout({
    required double okuTop,
    required double okuBaseTop,
    required double temaeTop,
    required double temaeBaseTop,
  }) {
    final summary = _placementSummary(
      okuTop: okuTop,
      okuBaseTop: okuBaseTop,
      temaeTop: temaeTop,
      temaeBaseTop: temaeBaseTop,
    );

    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.black.withAlpha(180),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: summary));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('配置の値をコピーしました'),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.copy, size: 12),
                  SizedBox(width: 4),
                  Text('値をコピー', style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
          ),
          Text(
            summary,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

