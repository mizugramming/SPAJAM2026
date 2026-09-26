import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/models.dart';

const parentAsset = 'assets/characters/oyabun.png';
const normalFollowerAsset = 'assets/characters/kobun_normal.png';
const boneFollowerAsset = 'assets/characters/kobun_bone.png';

/// One persistent stage; the can moves instead of replacing the whole screen.
class CanStage extends StatelessWidget {
  const CanStage({
    super.key,
    required this.phase,
    required this.profile,
    this.result,
    this.team,
  });

  final AppPhase phase;
  final Profile profile;
  final EncounterResult? result;
  final Team? team;

  @override
  Widget build(BuildContext context) {
    final playing = phase == AppPhase.game;
    final returning = phase == AppPhase.returning;
    final showingResult = phase == AppPhase.result;
    final parentVisible = switch (phase) {
      AppPhase.home ||
      AppPhase.pairing ||
      AppPhase.game ||
      AppPhase.result ||
      AppPhase.returning => true,
      _ => false,
    };
    final isLoss = result?.outcome == Outcome.loss;
    final separateNewBone =
        result?.promoted != null &&
        result!.promoted!.id != result!.newFollower.id;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 650);
    return Semantics(
      container: true,
      label: '自分のツナ缶',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final canWidth = math.min(286.0, width * .8);
          final canScale = playing ? 96.0 / canWidth : 1.0;
          final canHeight = TunaCan.heightFor(
            context,
            canWidth,
            profile: profile,
            compact: false,
            showLabel: phase != AppPhase.entry,
          );
          final visibleCanHeight = canHeight * canScale;
          final canLeft = playing
              ? width - canWidth - 12
              : (width - canWidth) / 2;
          final parentWidth = playing ? 84.0 : canWidth * .62;
          final parentImageHeight = parentWidth * 1199 / 1312;
          // Crop only the bottom white margin in the layout so it cannot
          // cover the can lid. The supplied bitmap remains unchanged.
          final parentHeight = parentImageHeight * .92;
          final followerWidth = math.min(104.0, width * .28);
          final followerLabel = isLoss
              ? 'ショBONE'
              : result?.outcome == Outcome.win
              ? 'よろしく(ツ)ナ'
              : result?.promoted != null
              ? '元気になった！'
              : '新しい仲間';
          final followerHeight =
              followerWidth * 1003 / 1568 +
              _measureText(
                context,
                followerLabel,
                _followerLabelStyle,
                followerWidth,
              ).height;
          final actorHeight = parentVisible
              ? math.max(
                  parentHeight,
                  showingResult || returning ? followerHeight : 0.0,
                )
              : 0.0;
          final stageHeight = playing
              ? constraints.hasBoundedHeight
                    ? constraints.maxHeight
                    : math.max(304.0, visibleCanHeight + parentHeight + 60)
              : canHeight + actorHeight + (parentVisible ? 36 : 40);
          return SizedBox(
            height: stageHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedPositioned(
                  duration: duration,
                  curve: Curves.easeInOutCubic,
                  left: canLeft,
                  bottom: 18,
                  // Lay out the full label immediately. Only its painted
                  // size changes for the game, so transition frames cannot
                  // squeeze newly wrapped text into the old can dimensions.
                  child: AnimatedScale(
                    duration: duration,
                    curve: Curves.easeInOutCubic,
                    alignment: Alignment.bottomRight,
                    scale: canScale,
                    child: SizedBox(
                      width: canWidth,
                      height: canHeight,
                      child: TunaCan(
                        profile: profile,
                        showLabel: phase != AppPhase.entry,
                        team: team,
                      ),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: duration,
                  curve: Curves.easeInOutCubic,
                  left: playing
                      ? width - 12 - (96 + parentWidth) / 2
                      : (width - parentWidth) / 2,
                  bottom: returning
                      ? visibleCanHeight * .35
                      : visibleCanHeight + 18 - 9 * canScale,
                  width: parentWidth,
                  height: parentHeight,
                  child: AnimatedOpacity(
                    duration: duration,
                    opacity: parentVisible && !returning ? 1 : 0,
                    child: AnimatedScale(
                      duration: duration,
                      scale: returning ? .12 : 1,
                      child: TweenAnimationBuilder<double>(
                        key: ValueKey(
                          showingResult && result?.outcome == Outcome.win,
                        ),
                        tween: Tween(begin: 0, end: 1),
                        duration: duration * 2,
                        builder: (context, value, child) => Transform.rotate(
                          angle: showingResult && result?.outcome == Outcome.win
                              ? math.sin(value * math.pi * 6) * .12
                              : 0,
                          child: child,
                        ),
                        // Losing changes the follower, never the parent.
                        child: ClipRect(
                          child: OverflowBox(
                            alignment: Alignment.topCenter,
                            minHeight: parentImageHeight,
                            maxHeight: parentImageHeight,
                            child: Image.asset(
                              parentAsset,
                              semanticLabel: '親分',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (result != null && (showingResult || returning))
                  AnimatedPositioned(
                    duration: duration,
                    curve: Curves.easeInOutCubic,
                    left: returning ? (width - followerWidth) / 2 : 0,
                    bottom: returning ? canHeight * .35 : canHeight + 8,
                    width: followerWidth,
                    child: AnimatedOpacity(
                      duration: duration,
                      opacity: returning ? 0 : 1,
                      child: AnimatedScale(
                        duration: duration,
                        scale: returning ? .1 : 1,
                        child: Column(
                          children: [
                            Text(
                              followerLabel,
                              textAlign: TextAlign.center,
                              style: _followerLabelStyle,
                            ),
                            Image.asset(
                              (result!.promoted ?? result!.newFollower).kind ==
                                      FollowerKind.bone
                                  ? boneFollowerAsset
                                  : normalFollowerAsset,
                              semanticLabel: isLoss ? '骨の子分' : '獲得・成長した子分',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (separateNewBone && (showingResult || returning))
                  AnimatedPositioned(
                    duration: duration,
                    curve: Curves.easeInOutCubic,
                    right: returning ? (width - followerWidth) / 2 : 0,
                    bottom: returning ? canHeight * .35 : canHeight + 8,
                    width: followerWidth,
                    child: AnimatedOpacity(
                      duration: duration,
                      opacity: returning ? 0 : 1,
                      child: AnimatedScale(
                        duration: duration,
                        scale: returning ? .1 : 1,
                        child: Column(
                          children: [
                            const Text(
                              '新しい仲間',
                              textAlign: TextAlign.center,
                              style: _followerLabelStyle,
                            ),
                            Image.asset(
                              boneFollowerAsset,
                              semanticLabel: '新しく獲得した骨の子分',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

const _canInk = Color(0xFF392923);
const _followerLabelStyle = TextStyle(
  fontSize: 11,
  height: 1.35,
  fontWeight: FontWeight.bold,
  color: _canInk,
);
const _prefixStyle = TextStyle(
  fontSize: 11.5,
  height: 1.4,
  fontWeight: FontWeight.w600,
);
const _valueStyle = TextStyle(
  fontSize: 13.5,
  height: 1.4,
  fontWeight: FontWeight.w600,
);
const _nicknameStyle = TextStyle(
  fontSize: 16,
  height: 1.4,
  fontWeight: FontWeight.w800,
);
const _prefixes = ['ニックネーム：', '趣味：', 'ひとこと：'];

TextPainter _measureText(
  BuildContext context,
  String text,
  TextStyle style,
  double width,
) => TextPainter(
  text: TextSpan(
    text: text.isEmpty ? ' ' : text,
    style: DefaultTextStyle.of(context).style.merge(style),
  ),
  textDirection: Directionality.of(context),
  textScaler: MediaQuery.textScalerOf(context),
)..layout(maxWidth: width);

class TunaCan extends StatelessWidget {
  const TunaCan({
    super.key,
    required this.profile,
    this.compact = false,
    this.showLabel = true,
    this.team,
  });

  final Profile profile;
  final bool compact;
  final bool showLabel;
  final Team? team;

  static double heightFor(
    BuildContext context,
    double width, {
    required Profile profile,
    required bool compact,
    required bool showLabel,
  }) {
    final padding = _CanGeometry.textPadding(compact);
    if (compact) {
      return math.max(
        72,
        MediaQuery.textScalerOf(context).scale(10) * 1.4 + padding.vertical,
      );
    }
    if (!showLabel) {
      return math.max(
        184,
        MediaQuery.textScalerOf(context).scale(22) * 1.4 + padding.vertical,
      );
    }
    final layout = _LabelLayout(context, width - padding.horizontal, profile);
    return math.max(184, layout.height + padding.vertical);
  }

  @override
  Widget build(BuildContext context) {
    final labelColor = switch (team) {
      Team.red => const Color(0xFFBB4843),
      Team.blue => const Color(0xFF176DAD),
      null => const Color(0xFFFFEDC4),
    };
    final textColor = team == null ? _canInk : Colors.white;
    return CustomPaint(
      painter: _CanPainter(
        labelColor: showLabel ? labelColor : null,
        compact: compact,
      ),
      child: Padding(
        padding: _CanGeometry.textPadding(compact),
        child: Center(
          child: compact || !showLabel
              ? Text(
                  showLabel ? profile.nickname : 'はだ缶',
                  key: const Key('can-nickname'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 10 : 22,
                    height: 1.4,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final layout = _LabelLayout(
                      context,
                      constraints.maxWidth,
                      profile,
                    );
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < _prefixes.length; i++) ...[
                          if (i > 0) const SizedBox(height: 8),
                          _labelRow(layout, i, textColor),
                        ],
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _labelRow(_LabelLayout layout, int index, Color color) {
    final prefix = Text(
      _prefixes[index],
      style: _prefixStyle.copyWith(color: color),
    );
    final value = Text(
      layout.values[index],
      key: index == 0 ? const Key('can-nickname') : null,
      style: layout.valueStyle(index).copyWith(color: color),
    );
    if (layout.stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [prefix, const SizedBox(height: 2), value],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: layout.prefixWidth, child: prefix),
        Expanded(child: value),
      ],
    );
  }
}

/// Measure the same wrapping used by the printed label, including text scaling.
class _LabelLayout {
  _LabelLayout(this.context, this.width, Profile profile)
    : values = [profile.nickname, profile.hobby, profile.comment];

  final BuildContext context;
  final double width;
  final List<String> values;

  TextStyle valueStyle(int index) => index == 0 ? _nicknameStyle : _valueStyle;

  double get prefixWidth =>
      _measureText(
        context,
        _prefixes.first,
        _prefixStyle,
        double.infinity,
      ).width +
      8;

  bool get stacked =>
      prefixWidth + MediaQuery.textScalerOf(context).scale(64) > width;

  double get height {
    var height = 16.0;
    for (var i = 0; i < values.length; i++) {
      final prefixHeight = _measureText(
        context,
        _prefixes[i],
        _prefixStyle,
        stacked ? width : prefixWidth,
      ).height;
      final valueHeight = _measureText(
        context,
        values[i],
        valueStyle(i),
        stacked ? width : width - prefixWidth,
      ).height;
      height += stacked
          ? prefixHeight + 2 + valueHeight
          : math.max(prefixHeight, valueHeight);
    }
    return height;
  }
}

/// The label curves and the readable text area share one set of dimensions.
/// Increasing text size stretches the cylinder, never a detached label panel.
class _CanGeometry {
  _CanGeometry(this.size, this.compact);

  final Size size;
  final bool compact;

  static EdgeInsets textPadding(bool compact) => compact
      ? const EdgeInsets.fromLTRB(12, 33, 12, 19)
      : const EdgeInsets.fromLTRB(26, 60, 26, 34);

  double get stroke => compact ? 2.4 : 3.8;
  double get left => stroke / 2 + 2;
  double get right => size.width - left;
  double get lidHeight => compact ? 24 : 38;
  double get bottomRise => compact ? 8 : 14;
  double get bottomSide => size.height - bottomRise - 7;
  Rect get lid => Rect.fromLTRB(left, 4, right, 4 + lidHeight);

  Path get body => Path()
    ..moveTo(left, lid.center.dy)
    ..quadraticBezierTo(left - .8, size.height * .6, left + .6, bottomSide)
    ..quadraticBezierTo(
      size.width * .49,
      size.height + bottomRise - 7,
      right - .6,
      bottomSide,
    )
    ..quadraticBezierTo(right + .5, size.height * .57, right, lid.center.dy)
    ..close();

  Path get label {
    final top = textPadding(compact).top - (compact ? 10 : 23);
    final bottom = size.height - textPadding(compact).bottom - 1;
    return Path()
      ..moveTo(left + 2, top)
      ..quadraticBezierTo(
        size.width * .49,
        top + (compact ? 11 : 20),
        right - 2,
        top + .6,
      )
      ..lineTo(right - 2.5, bottom)
      ..quadraticBezierTo(
        size.width * .5,
        bottom + bottomRise * 2,
        left + 2.5,
        bottom + .5,
      )
      ..close();
  }

  Path frontArc(double sideY) => Path()
    ..moveTo(left + .6, sideY)
    ..quadraticBezierTo(
      size.width * .49,
      sideY + bottomRise * 2,
      right - .6,
      sideY,
    );
}

class _CanPainter extends CustomPainter {
  const _CanPainter({required this.labelColor, required this.compact});

  final Color? labelColor;
  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    final shape = _CanGeometry(size, compact);
    final bounds = Offset.zero & size;
    final ink = Paint()
      ..color = _canInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = shape.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final metal = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF8998A3),
          Color(0xFFDAE0E4),
          Color(0xFFF0F2F2),
          Color(0xFFC0CCD4),
          Color(0xFF8998A3),
        ],
        stops: [0, .16, .46, .79, 1],
      ).createShader(bounds);
    canvas.drawPath(shape.body, metal);

    canvas.save();
    canvas.clipPath(shape.body);
    _wash(canvas, bounds, const Color(0xFF627D91), 0.075);
    // A few soft rolled-metal ribs remain visible when the paper is removed.
    for (final fraction in [.29, .6, .82]) {
      final y =
          shape.lid.bottom +
          (shape.bottomSide - shape.lid.bottom - 12) * fraction;
      canvas.drawPath(
        shape.frontArc(y),
        Paint()
          ..color = const Color(0xFF667984).withValues(alpha: .3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = compact ? 1 : 1.8,
      );
      canvas.drawPath(
        shape.frontArc(y + 3),
        Paint()
          ..color = Colors.white.withValues(alpha: .6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = compact ? 1 : 2.4,
      );
    }
    if (labelColor != null) {
      canvas.save();
      canvas.clipPath(shape.label);
      canvas.drawRect(bounds, Paint()..color = labelColor!);
      _wash(canvas, bounds, _canInk, .04);
      // The paper wraps around the cylinder: both edges fall into shadow,
      // while the middle stays quiet enough for live, accessible text.
      canvas.drawRect(
        bounds,
        Paint()
          ..shader = LinearGradient(
            colors: [
              _canInk.withValues(alpha: .28),
              _canInk.withValues(alpha: .025),
              Colors.white.withValues(alpha: .035),
              Colors.transparent,
              _canInk.withValues(alpha: .24),
            ],
            stops: const [0, .13, .44, .85, 1],
          ).createShader(bounds),
      );
      canvas.restore();
      canvas.drawPath(
        shape.label,
        Paint()
          ..color = _canInk.withValues(alpha: .62)
          ..style = PaintingStyle.stroke
          ..strokeWidth = compact ? 1 : 1.5,
      );
    }
    canvas.restore();

    // The bottom rolled rim encloses the curved paper band.
    canvas.drawPath(
      shape.frontArc(shape.bottomSide - (compact ? 5 : 8)),
      Paint()
        ..color = Colors.white.withValues(alpha: .8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = compact ? 2 : 3.2,
    );
    canvas.drawPath(
      shape.frontArc(shape.bottomSide - (compact ? 2 : 4)),
      Paint()
        ..color = const Color(0xFF64737E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = compact ? 1.3 : 2,
    );
    canvas.drawPath(shape.body, ink);
    _paintLid(canvas, shape, ink);
  }

  void _paintLid(Canvas canvas, _CanGeometry shape, Paint ink) {
    final lid = shape.lid;
    // Slightly unequal Bézier handles keep the outline close to the supplied
    // brush-drawn characters without changing between animation frames.
    final outline = Path()
      ..moveTo(lid.left, lid.center.dy)
      ..cubicTo(
        lid.left + 1,
        lid.top - 3,
        lid.right - 5,
        lid.top - 1,
        lid.right,
        lid.center.dy,
      )
      ..cubicTo(
        lid.right + 1,
        lid.bottom + 3,
        lid.left - 3,
        lid.bottom + 1,
        lid.left,
        lid.center.dy,
      )
      ..close();
    canvas.drawPath(
      outline,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFB7C7D2), Color(0xFFECF0F0), Color(0xFFA5B4BE)],
        ).createShader(lid),
    );
    canvas.save();
    canvas.clipPath(outline);
    _wash(canvas, lid, const Color(0xFF6E8A9C), .14);
    canvas.restore();
    canvas.drawPath(outline, ink);
    final inner = lid.deflate(compact ? 4 : 6);
    canvas.drawOval(
      inner,
      Paint()
        ..color = Colors.white.withValues(alpha: .9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = compact ? 1.6 : 2.8,
    );
    canvas.drawOval(
      inner.deflate(compact ? 2 : 3),
      Paint()
        ..color = const Color(0xFF647681)
        ..style = PaintingStyle.stroke
        ..strokeWidth = compact ? 1.1 : 1.8,
    );
    final tab = Rect.fromCenter(
      center: Offset(lid.left + lid.width * .32, lid.center.dy + 1),
      width: lid.width * .19,
      height: lid.height * .36,
    );
    canvas.drawOval(tab, Paint()..color = const Color(0xFF778A97));
    canvas.drawOval(
      tab,
      Paint()
        ..color = _canInk.withValues(alpha: .8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = compact ? 1.8 : 2.8,
    );
    canvas.drawOval(
      tab.deflate(compact ? 2 : 3),
      Paint()
        ..color = const Color(0xFFEEF2F1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = compact ? 1.3 : 2.1,
    );
  }

  // Small, fixed translucent washes give silver and paper the same handmade
  // surface. They are decorative only; all profile text remains real Text.
  void _wash(Canvas canvas, Rect bounds, Color color, double opacity) {
    final paint = Paint();
    for (var i = 0; i < 36; i++) {
      final x = bounds.left + bounds.width * ((i * 37 % 101) / 101);
      final y = bounds.top + bounds.height * ((i * 61 % 97) / 97);
      final width = bounds.width * (.055 + (i % 4) * .017);
      final height =
          math.min(16.0, bounds.height * .15) * (.45 + (i % 3) * .19);
      paint.color = color.withValues(alpha: opacity * (.5 + (i % 4) * .15));
      canvas.drawPath(
        Path()
          ..moveTo(x - width * .5, y)
          ..lineTo(x - width * .2, y - height * .45)
          ..lineTo(x + width * .48, y - height * .28)
          ..lineTo(x + width * .36, y + height * .48)
          ..lineTo(x - width * .38, y + height * .31)
          ..close(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_CanPainter oldDelegate) =>
      oldDelegate.labelColor != labelColor || oldDelegate.compact != compact;
}
