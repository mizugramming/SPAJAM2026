import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/models.dart';
import 'curved_label.dart';

const parentAsset = 'assets/characters/oyabun.png';
const normalFollowerAsset = 'assets/characters/kobun_normal.png';
const boneFollowerAsset = 'assets/characters/kobun_bone.png';

enum _CanMotion { idle, emerge, returnInside, celebrate }

/// A single scene keeps the mouth behind the actors and the can front above
/// them, so entering characters disappear through the opening, not by fading.
class CanStage extends StatefulWidget {
  const CanStage({
    super.key,
    required this.phase,
    required this.profile,
    this.result,
    this.team,
    this.onReturnComplete,
  });

  final AppPhase phase;
  final Profile profile;
  final EncounterResult? result;
  final Team? team;
  final VoidCallback? onReturnComplete;

  @override
  State<CanStage> createState() => _CanStageState();
}

class _CanStageState extends State<CanStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;
  _CanMotion _kind = _CanMotion.idle;
  bool _reduceMotion = false;
  bool _initialized = false;
  int _generation = 0;
  int? _notifiedGeneration;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(vsync: this, value: 1)
      ..addStatusListener(_onMotionStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (!_initialized) {
      _initialized = true;
      _beginForPhase(null);
    } else if (_reduceMotion && _motion.isAnimating) {
      _motion.value = 1;
      _notifyReturn();
    }
  }

  @override
  void didUpdateWidget(CanStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.phase != oldWidget.phase) _beginForPhase(oldWidget.phase);
  }

  void _beginForPhase(AppPhase? previous) {
    if (widget.phase == AppPhase.returning) {
      _start(_CanMotion.returnInside, const Duration(milliseconds: 1800));
    } else if (widget.phase == AppPhase.home &&
        (previous == null ||
            previous == AppPhase.lobby ||
            previous == AppPhase.returning)) {
      _start(_CanMotion.emerge, const Duration(milliseconds: 1250));
    } else if (widget.phase == AppPhase.result &&
        (widget.result?.outcome == Outcome.win ||
            widget.result?.outcome == Outcome.coopSuccess)) {
      _start(_CanMotion.celebrate, const Duration(milliseconds: 1000));
    } else if (!(previous == AppPhase.home &&
        widget.phase == AppPhase.pairing &&
        _kind == _CanMotion.emerge)) {
      _generation++;
      _kind = _CanMotion.idle;
      _motion.stop();
      _motion.value = 1;
    }
  }

  void _start(_CanMotion kind, Duration duration) {
    _generation++;
    _kind = kind;
    _motion.stop();
    _motion.duration = duration;
    if (_reduceMotion) {
      _motion.value = 1;
      _notifyReturn();
    } else {
      _motion.forward(from: 0);
    }
  }

  void _onMotionStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _notifyReturn();
  }

  void _notifyReturn() {
    if (_kind != _CanMotion.returnInside ||
        widget.phase != AppPhase.returning ||
        _notifiedGeneration == _generation) {
      return;
    }
    final generation = _generation;
    _notifiedGeneration = generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          generation == _generation &&
          widget.phase == AppPhase.returning) {
        widget.onReturnComplete?.call();
      }
    });
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  double _part(double start, double end) => Interval(
    start,
    end,
    curve: Curves.easeInOutCubic,
  ).transform(_motion.value);

  double get _opening => switch (_kind) {
    _CanMotion.returnInside => _part(0, .18) * (1 - _part(.82, 1)),
    _CanMotion.emerge => _part(0, .2) * (1 - _part(.78, 1)),
    _ => 0,
  };

  @override
  Widget build(BuildContext context) {
    final phase = widget.phase;
    final result = widget.result;
    final playing = phase == AppPhase.game;
    final returning = phase == AppPhase.returning;
    final showingResult = phase == AppPhase.result;
    final isSetback =
        result?.outcome == Outcome.loss ||
        result?.outcome == Outcome.coopFailure;
    final followerInSpotlight = result != null && (showingResult || returning);
    final parentVisible =
        !followerInSpotlight &&
        switch (phase) {
          AppPhase.home ||
          AppPhase.pairing ||
          AppPhase.game ||
          AppPhase.result ||
          AppPhase.returning => true,
          _ => false,
        };
    final separateNewBone =
        result != null &&
        result.promoted != null &&
        result.promoted!.id != result.newFollower.id;
    final duration = _reduceMotion
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
            profile: widget.profile,
            compact: false,
            showLabel: phase != AppPhase.entry,
          );
          final visibleCanHeight = canHeight * canScale;
          final canLeft = playing
              ? width - canWidth - 12
              : (width - canWidth) / 2;
          final parentWidth = playing ? 84.0 : canWidth * .62;
          final parentHeight = parentWidth * 1122 / 1402;
          final followerWidth = followerInSpotlight
              ? canWidth * .72
              : math.min(104.0, width * .28);
          final followerStyle = followerInSpotlight
              ? _resultTitleStyle
              : _followerLabelStyle;
          final followerGap = followerInSpotlight ? 12.0 : 0.0;
          final followerLabel = isSetback
              ? 'ショBONE'
              : result?.outcome == Outcome.win
              ? 'やった！'
              : result?.promoted != null
              ? '大成功！'
              : '新しい仲間';
          final primaryIsBone =
              (result?.promoted ?? result?.newFollower)?.kind ==
              FollowerKind.bone;
          final followerImageHeight =
              followerWidth * (primaryIsBone ? 419 / 953 : 571 / 854);
          final extraBoneWidth = math.min(64.0, width * .18);
          final extraBoneImageHeight = extraBoneWidth * 419 / 953;
          final followerHeight =
              followerImageHeight +
              followerGap +
              _measureText(
                context,
                followerLabel,
                followerStyle,
                followerWidth,
              ).height;
          final extraBoneHeight =
              extraBoneImageHeight +
              _measureText(
                context,
                '新しい仲間',
                _followerLabelStyle,
                extraBoneWidth,
              ).height;
          final actorHeight = math.max(
            parentVisible ? parentHeight : 0.0,
            showingResult || returning
                ? math.max(
                    followerHeight,
                    separateNewBone ? extraBoneHeight : 0.0,
                  )
                : 0.0,
          );
          final stageHeight = playing
              ? constraints.hasBoundedHeight
                    ? constraints.maxHeight
                    : math.max(304.0, visibleCanHeight + parentHeight + 60)
              : canHeight +
                    actorHeight +
                    (parentVisible || followerInSpotlight ? 36 : 40);
          final canTop = stageHeight - 18 - visibleCanHeight;
          final mouthY = canTop + 23 * canScale;
          final canCenter = playing ? width - 12 - 48 : width / 2;
          final parentLeft = canCenter - parentWidth / 2;
          final parentTop = mouthY - parentHeight;

          Widget canLayer(Widget child) => AnimatedPositioned(
            duration: duration,
            curve: Curves.easeInOutCubic,
            left: canLeft,
            bottom: 18,
            // Text is always laid out at its final size, never squeezed while
            // changing phases. Only the complete can is painted smaller.
            child: AnimatedScale(
              duration: duration,
              curve: Curves.easeInOutCubic,
              alignment: Alignment.bottomRight,
              scale: canScale,
              child: SizedBox(width: canWidth, height: canHeight, child: child),
            ),
          );

          return SizedBox(
            height: stageHeight,
            child: AnimatedBuilder(
              animation: _motion,
              builder: (context, _) {
                final parentProgress = switch (_kind) {
                  _CanMotion.returnInside => _part(.34, .79),
                  _CanMotion.emerge => 1 - _part(.18, .76),
                  _ => 0.0,
                };
                final parentTravel =
                    mouthY +
                    parentHeight * .55 -
                    (parentTop + parentHeight / 2);
                final parentOffset = Offset(
                  math.sin(parentProgress * math.pi) * canWidth * .07,
                  parentTravel * parentProgress -
                      math.sin(parentProgress * math.pi) * canWidth * .20,
                );
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    canLayer(
                      CustomPaint(
                        key: const Key('can-mouth'),
                        painter: _CanPainter(
                          labelColor: null,
                          compact: false,
                          opening: _opening,
                          layer: _CanLayer.back,
                        ),
                      ),
                    ),
                    if (parentVisible)
                      AnimatedPositioned(
                        duration: duration,
                        curve: Curves.easeInOutCubic,
                        left: parentLeft,
                        top: parentTop,
                        width: parentWidth,
                        height: parentHeight,
                        child: Opacity(
                          opacity: parentVisible && parentProgress < 1 ? 1 : 0,
                          child: Transform.translate(
                            key: const Key('parent-motion'),
                            offset: parentOffset,
                            child: Transform.rotate(
                              angle: _kind == _CanMotion.celebrate
                                  ? math.sin(_motion.value * math.pi * 6) * .10
                                  : math.sin(parentProgress * math.pi) * .16,
                              child: Transform.scale(
                                scale: 1 - parentProgress * .25,
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
                    if (result != null && (showingResult || returning))
                      _follower(
                        left: followerInSpotlight
                            ? canCenter - followerWidth / 2
                            : 0,
                        top: mouthY - followerHeight,
                        width: followerWidth,
                        height: followerHeight,
                        imageHeight: followerImageHeight,
                        target: Offset(canCenter, mouthY),
                        progress: returning ? _part(.16, .62) : 0,
                        label: followerLabel,
                        labelStyle: followerStyle,
                        labelGap: followerGap,
                        labelKey: isSetback
                            ? const Key('shobone-title')
                            : const Key('result-title'),
                        celebrate: showingResult && !isSetback,
                        image: primaryIsBone
                            ? boneFollowerAsset
                            : normalFollowerAsset,
                        semanticLabel: primaryIsBone ? '骨の子分' : '獲得・成長した子分',
                        motionKey: const Key('follower-motion-primary'),
                      ),
                    if (separateNewBone && (showingResult || returning))
                      _follower(
                        left: width - extraBoneWidth,
                        top: mouthY - extraBoneHeight - 12,
                        width: extraBoneWidth,
                        height: extraBoneHeight,
                        imageHeight: extraBoneImageHeight,
                        target: Offset(canCenter, mouthY),
                        progress: returning ? _part(.24, .7) : 0,
                        label: '新しい仲間',
                        image: boneFollowerAsset,
                        semanticLabel: '新しく獲得した骨の子分',
                        motionKey: const Key('follower-motion-new-bone'),
                      ),
                    canLayer(
                      TunaCan(
                        key: const Key('can-front'),
                        profile: widget.profile,
                        showLabel: phase != AppPhase.entry,
                        team: widget.team,
                        opening: _opening,
                        foregroundOnly: true,
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _follower({
    required double left,
    required double top,
    required double width,
    required double height,
    required double imageHeight,
    required Offset target,
    required double progress,
    required String label,
    required String image,
    required String semanticLabel,
    required Key motionKey,
    TextStyle labelStyle = _followerLabelStyle,
    double labelGap = 0,
    Key? labelKey,
    bool celebrate = false,
  }) => Positioned(
    left: left,
    top: top,
    width: width,
    child: Opacity(
      opacity: progress < 1 ? 1 : 0,
      child: Transform.translate(
        key: motionKey,
        offset: Offset(
          (target.dx - left - width / 2) * progress,
          (target.dy + height * .55 - top - height / 2) * progress -
              math.sin(progress * math.pi) * 64 -
              (celebrate ? math.sin(_motion.value * math.pi) * 12 : 0),
        ),
        child: Transform.rotate(
          angle: math.sin(progress * math.pi) * (left < target.dx ? .22 : -.22),
          child: Transform.scale(
            scale: 1 - progress * .22,
            child: Column(
              children: [
                Opacity(
                  opacity: (1 - progress * 4).clamp(0.0, 1.0),
                  child: Text(
                    label,
                    key: labelKey,
                    textAlign: TextAlign.center,
                    style: labelStyle,
                  ),
                ),
                if (labelGap > 0) SizedBox(height: labelGap),
                Image.asset(
                  image,
                  width: width,
                  height: imageHeight,
                  fit: BoxFit.contain,
                  semanticLabel: semanticLabel,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

const _canInk = Color(0xFF392923);
const _followerLabelStyle = TextStyle(
  fontSize: 11,
  height: 1.35,
  fontWeight: FontWeight.bold,
  color: _canInk,
);
const _resultTitleStyle = TextStyle(
  fontSize: 34,
  height: 1.15,
  fontWeight: FontWeight.w900,
  letterSpacing: 1.2,
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
    this.opening = 0,
    this.foregroundOnly = false,
  });

  final Profile profile;
  final bool compact;
  final bool showLabel;
  final Team? team;

  /// Fraction of the lid opening. The stage coordinates the actor motion.
  final double opening;
  final bool foregroundOnly;

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
    return math.max(
      184,
      layout.height + CurvedLabel.defaultDrop + padding.vertical,
    );
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
        opening: opening,
        layer: foregroundOnly ? _CanLayer.front : _CanLayer.whole,
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
                    return CurvedLabel(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < _prefixes.length; i++) ...[
                            if (i > 0) const SizedBox(height: 8),
                            _labelRow(layout, i, textColor),
                          ],
                        ],
                      ),
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
    ..cubicTo(
      size.width * .88,
      lid.bottom + 3,
      size.width * .12,
      lid.bottom + 3,
      left,
      lid.center.dy,
    )
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

enum _CanLayer { whole, back, front }

class _CanPainter extends CustomPainter {
  const _CanPainter({
    required this.labelColor,
    required this.compact,
    this.opening = 0,
    this.layer = _CanLayer.whole,
  });

  final Color? labelColor;
  final bool compact;
  final double opening;
  final _CanLayer layer;

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
    if (layer != _CanLayer.front) _paintBack(canvas, shape, ink);
    if (layer == _CanLayer.back) return;
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
    // This front lip is painted after the actors, along with the opaque body.
    // A diving character is therefore occluded by the can itself.
    final frontLip = Path()
      ..moveTo(shape.lid.left, shape.lid.center.dy)
      ..cubicTo(
        size.width * .12,
        shape.lid.bottom + 3,
        size.width * .88,
        shape.lid.bottom + 3,
        shape.lid.right,
        shape.lid.center.dy,
      );
    canvas.drawPath(frontLip, ink);
  }

  void _paintBack(Canvas canvas, _CanGeometry shape, Paint ink) {
    final mouth = shape.lid;
    canvas.drawOval(
      mouth,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF17232C), Color(0xFF586773)],
        ).createShader(mouth),
    );
    canvas.drawOval(mouth, ink);
    canvas.drawOval(
      mouth.deflate(compact ? 3 : 5),
      Paint()
        ..color = const Color(0xFFCCD8DD)
        ..style = PaintingStyle.stroke
        ..strokeWidth = compact ? 1.4 : 2.4,
    );
    // The far rim is the hinge. Its projected depth flips as the lid rises;
    // changing the drawing coordinates keeps outline strokes a steady width.
    final depth =
        mouth.height * (1 - opening) - shape.size.width * .34 * opening;
    final lid = Rect.fromLTRB(
      mouth.left,
      mouth.top + math.min(0, depth),
      mouth.right,
      mouth.top + math.max(2, depth),
    );
    _paintLid(canvas, lid, ink);
  }

  void _paintLid(Canvas canvas, Rect lid, Paint ink) {
    // Explicit top/bottom anchors keep the raised lid attached to the far
    // rim. Two half-ellipse curves stop short of those anchors and leave a gap.
    final horizontalHandle = lid.width * .5 * .5522848;
    final verticalHandle = lid.height * .5 * .5522848;
    final outline = Path()
      ..moveTo(lid.center.dx, lid.top)
      ..cubicTo(
        lid.center.dx + horizontalHandle,
        lid.top,
        lid.right,
        lid.center.dy - verticalHandle,
        lid.right,
        lid.center.dy,
      )
      ..cubicTo(
        lid.right,
        lid.center.dy + verticalHandle,
        lid.center.dx + horizontalHandle,
        lid.bottom,
        lid.center.dx,
        lid.bottom,
      )
      ..cubicTo(
        lid.center.dx - horizontalHandle,
        lid.bottom,
        lid.left,
        lid.center.dy + verticalHandle,
        lid.left,
        lid.center.dy,
      )
      ..cubicTo(
        lid.left,
        lid.center.dy - verticalHandle,
        lid.center.dx - horizontalHandle,
        lid.top,
        lid.center.dx,
        lid.top,
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
    if (lid.height < (compact ? 12 : 18)) return;
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
      oldDelegate.labelColor != labelColor ||
      oldDelegate.compact != compact ||
      oldDelegate.opening != opening ||
      oldDelegate.layer != layer;
}
