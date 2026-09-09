import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../../../models/topic.dart';

/// 選ばれたネタを全員の画面に表示する。スマホを置いてリアルの会話に集中してもらうための
/// 常時表示バナー(モーダルでは閉じてしまうため使わない)。
class TopicBanner extends StatefulWidget {
  const TopicBanner({
    super.key,
    required this.topic,
    required this.canAdvance,
    required this.onNext,
    required this.onEndConversation,
    required this.currentRound,
  });

  final Topic topic;
  final bool canAdvance;
  final VoidCallback onNext;

  /// お勘定(会話終了)ボタンの動作。ホストでない場合はnull。
  final VoidCallback? onEndConversation;

  /// 現在のラウンド数(「N皿目」の表示に使う)。AppBarが非表示になる分、
  /// この画面内に表示する。
  final int currentRound;

  @override
  State<TopicBanner> createState() => _TopicBannerState();
}

class _TopicBannerState extends State<TopicBanner>
    with SingleTickerProviderStateMixin {
  /// 手動配置モード。trueの間は各パーツをドラッグで動かせる
  /// (座標は画面右上に表示される)。位置が決まったらfalseに戻す。
  static const _manualPlacementMode = false;

  /// 吹き出しとネタの文字を、表示直後に半透明からフェードインさせる。
  /// 吹き出し自体は完全な不透明にはせず、少し薄いままにする。
  late final AnimationController _fadeController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..forward();

  late final Animation<double> _fukidashiOpacity = Tween<double>(
    begin: 0.15,
    end: 0.85,
  ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

  late final Animation<double> _fukidashiTextOpacity = Tween<double>(
    begin: 0.15,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Offset _saraDrag = const Offset(149, 68);
  double _saraScale = 0.60;

  Offset _fukidashiDrag = const Offset(3, 106);
  double _fukidashiScale = 1.43;

  Offset _mouhitosaraDrag = const Offset(3.33, 26.67);
  double _mouhitosaraScale = 0.88;

  Offset _okanjouDrag = const Offset(5.33, 14.67);
  double _okanjouScale = 0.69;

  // 「N皿目」表示(AppBarが非表示の間、代わりにここに出す)。
  Offset _roundLabelDrag = const Offset(-1.00, -271.33);
  double _roundLabelScale = 1.97;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE7C48F),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final center = Offset(
              constraints.maxWidth / 2,
              constraints.maxHeight / 2,
            );

            return Stack(
              clipBehavior: Clip.none,
              children: [
                // =========================================
                // 「N皿目」表示(AppBarの代わり)
                // =========================================
                Positioned(
                  left: 0,
                  right: 0,
                  top: center.dy + _roundLabelDrag.dy,
                  child: Center(
                    child: Transform.translate(
                      offset: Offset(_roundLabelDrag.dx, 0),
                      child: Text(
                        ' ${widget.currentRound}皿目のネタ',
                        style: TextStyle(
                          fontFamily: 'TamanegiKaisho',
                          fontSize: 22 * _roundLabelScale,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ),

                // =========================================
                // 皿(開いた状態)
                // =========================================
                _buildImage(
                  asset: 'assets/images/sara_open.png',
                  center: center + _saraDrag,
                  baseWidth: 200,
                  baseHeight: 202.6,
                  scale: _saraScale,
                ),

                // =========================================
                // ネタ吹き出し(トピックのテキストを重ねる)
                // =========================================
                _buildImage(
                  asset: 'assets/images/neta_fukidashi.png',
                  center: center + const Offset(0, -150) + _fukidashiDrag,
                  baseWidth: 240,
                  baseHeight: 208.6,
                  scale: _fukidashiScale,
                  imageOpacity: _fukidashiOpacity,
                  overlay: Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: AnimatedBuilder(
                          animation: _fukidashiTextOpacity,
                          builder: (context, child) => Opacity(
                            opacity: _fukidashiTextOpacity.value,
                            child: child,
                          ),
                          child: Text(
                            widget.topic.text,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'TamanegiKaisho',
                              fontSize: 20,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // =========================================
                // もう一皿(次へ回すボタン)
                // =========================================
                if (widget.canAdvance)
                  _buildImage(
                    asset: 'assets/images/mouhitosara.png',
                    center: center + const Offset(0, 150) + _mouhitosaraDrag,
                    baseWidth: 240,
                    baseHeight: 80.1,
                    scale: _mouhitosaraScale,
                    onTap: widget.onNext,
                  )
                else
                  Positioned(
                    left: 0,
                    right: 0,
                    top: center.dy + 150 - 20,
                    child: const Text(
                      '話し終わったら、選んだ人かホストが次へ回します',
                      textAlign: TextAlign.center,
                    ),
                  ),

                // =========================================
                // お勘定ボタン(AppBarのお勘定ボタンと同じ動作)
                // =========================================
                if (widget.onEndConversation != null)
                  _buildImage(
                    asset: 'assets/images/okanjou.png',
                    center: center + const Offset(0, 230) + _okanjouDrag,
                    baseWidth: 200,
                    baseHeight: 75,
                    scale: _okanjouScale,
                    onTap: widget.onEndConversation,
                  ),

                // =========================================
                // 手動配置モード: ドラッグ用ハンドルと座標表示
                // =========================================
                if (_manualPlacementMode) ...[
                  _buildDragHandle(
                    label: 'N皿目',
                    center: Offset(center.dx + _roundLabelDrag.dx, center.dy + _roundLabelDrag.dy),
                    baseWidth: 140,
                    baseHeight: 36,
                    scale: _roundLabelScale,
                    color: Colors.purple,
                    onDrag: (d) => setState(() => _roundLabelDrag += d),
                  ),
                  _buildDragHandle(
                    label: '皿',
                    center: center + _saraDrag,
                    baseWidth: 200,
                    baseHeight: 202.6,
                    scale: _saraScale,
                    color: Colors.red,
                    onDrag: (d) => setState(() => _saraDrag += d),
                  ),
                  _buildDragHandle(
                    label: '吹き出し',
                    center: center + const Offset(0, -150) + _fukidashiDrag,
                    baseWidth: 240,
                    baseHeight: 208.6,
                    scale: _fukidashiScale,
                    color: Colors.blue,
                    onDrag: (d) => setState(() => _fukidashiDrag += d),
                  ),
                  _buildDragHandle(
                    label: 'もう一皿',
                    center: center + const Offset(0, 150) + _mouhitosaraDrag,
                    baseWidth: 240,
                    baseHeight: 80.1,
                    scale: _mouhitosaraScale,
                    color: Colors.green,
                    onDrag: (d) => setState(() => _mouhitosaraDrag += d),
                  ),
                  _buildDragHandle(
                    label: 'お勘定',
                    center: center + const Offset(0, 230) + _okanjouDrag,
                    baseWidth: 200,
                    baseHeight: 75,
                    scale: _okanjouScale,
                    color: Colors.orange,
                    onDrag: (d) => setState(() => _okanjouDrag += d),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildResizeGizmo(
                          label: 'N皿目 拡大',
                          color: Colors.purple,
                          onResize: (dx) => setState(
                            () => _roundLabelScale =
                                (_roundLabelScale + dx / 100).clamp(
                                  0.3,
                                  3.0,
                                ),
                          ),
                        ),
                        _buildResizeGizmo(
                          label: '皿 拡大',
                          color: Colors.red,
                          onResize: (dx) => setState(
                            () => _saraScale = (_saraScale + dx / 100).clamp(
                              0.3,
                              3.0,
                            ),
                          ),
                        ),
                        _buildResizeGizmo(
                          label: '吹き出し 拡大',
                          color: Colors.blue,
                          onResize: (dx) => setState(
                            () => _fukidashiScale =
                                (_fukidashiScale + dx / 100).clamp(0.3, 3.0),
                          ),
                        ),
                        _buildResizeGizmo(
                          label: 'もう一皿 拡大',
                          color: Colors.green,
                          onResize: (dx) => setState(
                            () => _mouhitosaraScale =
                                (_mouhitosaraScale + dx / 100).clamp(
                                  0.3,
                                  3.0,
                                ),
                          ),
                        ),
                        _buildResizeGizmo(
                          label: 'お勘定 拡大',
                          color: Colors.orange,
                          onResize: (dx) => setState(
                            () => _okanjouScale = (_okanjouScale + dx / 100)
                                .clamp(0.3, 3.0),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _buildPlacementReadout(),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // パーツ表示
  // ============================================================

  Widget _buildImage({
    required String asset,
    required Offset center,
    required double baseWidth,
    required double baseHeight,
    required double scale,
    Widget? overlay,
    VoidCallback? onTap,
    Animation<double>? imageOpacity,
  }) {
    final width = baseWidth * scale;
    final height = baseHeight * scale;

    Widget child = Image.asset(asset, width: width, height: height, fit: BoxFit.contain);

    if (imageOpacity != null) {
      child = AnimatedBuilder(
        animation: imageOpacity,
        builder: (context, c) => Opacity(opacity: imageOpacity.value, child: c),
        child: child,
      );
    }

    if (overlay != null) {
      child = Stack(children: [child, Positioned.fill(child: overlay)]);
    }

    if (onTap != null) {
      child = GestureDetector(onTap: onTap, child: child);
    }

    return Positioned(
      left: center.dx - width / 2,
      top: center.dy - height / 2,
      width: width,
      height: height,
      child: child,
    );
  }

  // ============================================================
  // 手動配置モード
  // ============================================================

  Widget _buildDragHandle({
    required String label,
    required Offset center,
    required double baseWidth,
    required double baseHeight,
    required double scale,
    required Color color,
    required ValueChanged<Offset> onDrag,
  }) {
    final width = baseWidth * scale;
    final height = baseHeight * scale;

    return Positioned(
      left: center.dx - width / 2,
      top: center.dy - height / 2,
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

  Widget _buildResizeGizmo({
    required String label,
    required Color color,
    required ValueChanged<double> onResize,
  }) {
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
          GestureDetector(
            onPanUpdate: (d) => onResize(d.delta.dx),
            child: Container(
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(left: 2),
              color: color,
              child: const Icon(
                Icons.open_in_full,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlacementReadout() {
    String fmt(double v) => v.toStringAsFixed(2);

    final summary =
        'N皿目: dx=${fmt(_roundLabelDrag.dx)} dy=${fmt(_roundLabelDrag.dy)} scale=${fmt(_roundLabelScale)}\n'
        '皿: dx=${fmt(_saraDrag.dx)} dy=${fmt(_saraDrag.dy)} scale=${fmt(_saraScale)}\n'
        '吹き出し: dx=${fmt(_fukidashiDrag.dx)} dy=${fmt(_fukidashiDrag.dy)} scale=${fmt(_fukidashiScale)}\n'
        'もう一皿: dx=${fmt(_mouhitosaraDrag.dx)} dy=${fmt(_mouhitosaraDrag.dy)} scale=${fmt(_mouhitosaraScale)}\n'
        'お勘定: dx=${fmt(_okanjouDrag.dx)} dy=${fmt(_okanjouDrag.dy)} scale=${fmt(_okanjouScale)}';

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
              color: Colors.white24,
              child: const Text(
                '値をコピー',
                style: TextStyle(color: Colors.white, fontSize: 11),
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
