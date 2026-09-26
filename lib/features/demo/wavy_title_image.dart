import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// 文字を描いた画像を、少しだけ波打たせて見せる見出し。
///
/// 画像を縦に細い帯へ分け、帯ごとに少しずつずらして上下へ揺らして描く。
/// 揺れるのは表示されてから [waves] 回だけで、その後は止まる（画面の更新を
/// 要求し続けない）。「アニメーションを減らす」設定では揺らさない。
/// 画像は1枚だけ読み込み、Canvas に描く。
class WavyTitleImage extends StatefulWidget {
  const WavyTitleImage({
    super.key,
    required this.asset,
    required this.content,
    required this.semanticLabel,
    this.waves = 3,
    this.period = const Duration(milliseconds: 1600),
    this.slices = 16,
    this.amplitude = .06,
  });

  final String asset;

  /// 余白を除いた、見せたい部分（画像のピクセル座標）。置き場所の幅に合わせる。
  final Rect content;

  final String semanticLabel;

  /// 揺れる回数と、1回の長さ。
  final int waves;
  final Duration period;

  /// 縦に分ける数と、揺れの大きさ（見出しの高さに対する割合）。
  final int slices;
  final double amplitude;

  /// 幅に合わせたときの高さ。
  double heightFor(double width) => width * content.height / content.width;

  /// [i]番目の帯の上下のずれ。[progress] は 0〜1 の進み具合、[height] は見出しの高さ。
  static double offsetAt({
    required int i,
    required int slices,
    required double progress,
    required int waves,
    required double amplitude,
    required double height,
  }) {
    // 最後に揺れが0へ戻るよう、進み具合を回数ぶんの位相にする。
    final phase = progress * waves * 2 * math.pi;
    // 出だしと終わりで揺れを小さくし、止まるときに跳ねないようにする。
    final envelope = math.sin(progress * math.pi);
    return math.sin(phase - i * 2 * math.pi / slices) *
        height *
        amplitude *
        envelope;
  }

  @override
  State<WavyTitleImage> createState() => _WavyTitleImageState();
}

class _WavyTitleImageState extends State<WavyTitleImage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: widget.period * widget.waves,
  )..forward();

  ImageStream? _stream;
  late final ImageStreamListener _listener = ImageStreamListener(
    (info, _) => setState(() {
      _image?.dispose();
      _image = info.image;
    }),
  );
  ui.Image? _image;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final stream = AssetImage(
      widget.asset,
    ).resolve(createLocalImageConfiguration(context));
    if (stream.key != _stream?.key) {
      _stream?.removeListener(_listener);
      _stream = stream..addListener(_listener);
    }
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _image?.dispose();
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: widget.semanticLabel,
      image: true,
      child: LayoutBuilder(
        builder: (context, box) {
          final width = box.maxWidth;
          return SizedBox(
            width: width,
            height: widget.heightFor(width),
            child: CustomPaint(
              painter: _WavyPainter(
                image: _image,
                content: widget.content,
                wave: _wave,
                waves: widget.waves,
                slices: widget.slices,
                amplitude: still ? 0 : widget.amplitude,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WavyPainter extends CustomPainter {
  _WavyPainter({
    required this.image,
    required this.content,
    required this.wave,
    required this.waves,
    required this.slices,
    required this.amplitude,
  }) : super(repaint: wave);

  final ui.Image? image;
  final Rect content;
  final Animation<double> wave;
  final int waves;
  final int slices;
  final double amplitude;

  @override
  void paint(Canvas canvas, Size size) {
    final image = this.image;
    if (image == null) return;
    // 画像の実際の大きさと、指定した見せたい部分の割合を合わせる（解像度違いに備える）。
    final paint = Paint()..filterQuality = FilterQuality.medium;
    final sliceWidth = size.width / slices;
    final sourceSlice = content.width / slices;
    for (var i = 0; i < slices; i++) {
      final dy = WavyTitleImage.offsetAt(
        i: i,
        slices: slices,
        progress: wave.value,
        waves: waves,
        amplitude: amplitude,
        height: size.height,
      );
      final source = Rect.fromLTWH(
        content.left + i * sourceSlice,
        content.top,
        sourceSlice,
        content.height,
      );
      // 隣の帯と隙間ができないよう、描く幅を少しだけ広げる。
      final target = Rect.fromLTWH(
        i * sliceWidth,
        dy,
        sliceWidth + .6,
        size.height,
      );
      canvas.drawImageRect(image, source, target, paint);
    }
  }

  @override
  bool shouldRepaint(_WavyPainter old) =>
      old.image != image ||
      old.amplitude != amplitude ||
      old.content != content ||
      old.slices != slices;
}
