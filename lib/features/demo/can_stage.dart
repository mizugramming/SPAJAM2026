import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/models.dart';
import 'curved_label.dart';
import 'factory_backdrop.dart';
import 'parent_character.dart';

const parentAsset = 'assets/characters/oyabun.png';
const normalFollowerAsset = 'assets/characters/kobun_normal.png';
const boneFollowerAsset = 'assets/characters/kobun_bone.png';
const _followerFinalScale = .78;

enum _CanMotion { idle, emerge, returnInside, celebrate, poof }

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
    } else if (widget.phase == AppPhase.result) {
      _start(_CanMotion.poof, const Duration(milliseconds: 1300));
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
    _CanMotion.returnInside =>
      const Interval(0, .34).transform(_motion.value) * (1 - _part(.82, 1)),
    _CanMotion.emerge =>
      const Interval(0, .32).transform(_motion.value) * (1 - _part(.8, 1)),
    _CanMotion.poof =>
      const Interval(0, .18).transform(_motion.value) * (1 - _part(.3, .55)),
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
          final conveyorWidth = canWidth + 24;
          final conveyorHeight = ConveyorPlatform.heightFor(conveyorWidth);
          final canBottom = playing
              ? 18.0
              : ConveyorPlatform.canBottomOffsetFor(conveyorWidth);
          final canLeft = playing
              ? width - canWidth - 12
              : (width - canWidth) / 2;
          final parentWidth = playing ? 84.0 : canWidth * .62;
          final parentHeight = parentWidth / ParentCharacter.aspectRatio;
          final followerWidth = followerInSpotlight
              ? canWidth * .72
              : math.min(104.0, width * .28);
          final followerStyle = followerInSpotlight
              ? _resultTitleStyle
              : _followerLabelStyle;
          final followerGap = followerInSpotlight ? 12.0 : 0.0;
          final titleWidth = followerInSpotlight ? width : followerWidth;
          final followerLabel = isSetback
              ? 'ショBONE'
              : result?.promoted != null
              ? 'REBORN'
              : 'ツナがった！';
          final primaryIsBone =
              result?.rewardFollower.kind == FollowerKind.bone;
          final followerImageHeight =
              followerWidth * (primaryIsBone ? 419 / 953 : 571 / 854);
          final followerHeight =
              followerImageHeight +
              followerGap +
              _measureText(
                context,
                followerLabel,
                followerStyle,
                titleWidth,
              ).height;
          final actorHeight = math.max(
            parentVisible ? parentHeight : 0.0,
            showingResult || returning ? followerHeight : 0.0,
          );
          final stageHeight = playing
              ? constraints.hasBoundedHeight
                    ? constraints.maxHeight
                    : math.max(304.0, visibleCanHeight + parentHeight + 60)
              : canHeight +
                    actorHeight +
                    (parentVisible || followerInSpotlight ? 36 : 40) +
                    canBottom -
                    18;
          final canTop = stageHeight - canBottom - visibleCanHeight;
          final mouthY = canTop + 23 * canScale;
          // Rest the followers above the closed lid. Anchor their actual
          // layout from below so title wrapping cannot push the image down.
          final canGeometry = _CanGeometry(Size(canWidth, canHeight), false);
          final followerBaseline = canTop + canGeometry.lid.top - 2;
          final followerBottom = stageHeight - followerBaseline;
          final insideTop = canTop + canGeometry.lid.bottom + 4;
          final insideBottom = canTop + canGeometry.bottomSide - 2;
          final canCenter = playing ? width - 12 - 48 : width / 2;
          final parentLeft = canCenter - parentWidth / 2;
          final parentTop = mouthY - parentHeight;

          Widget canLayer(Widget child) => AnimatedPositioned(
            duration: duration,
            curve: Curves.easeInOutCubic,
            left: canLeft,
            bottom: canBottom,
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
                  _CanMotion.emerge => 1 - _part(.34, .8),
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
                    if (!playing)
                      Positioned(
                        left: canLeft - 12,
                        bottom: 0,
                        width: conveyorWidth,
                        height: conveyorHeight,
                        child: const ConveyorPlatform(),
                      ),
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
                                child: ParentCharacter(
                                  idle:
                                      (phase == AppPhase.home ||
                                          phase == AppPhase.pairing) &&
                                      !_motion.isAnimating,
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
                        bottom: followerBottom,
                        diveDistance:
                            insideTop -
                            followerBaseline +
                            followerImageHeight * (1 + _followerFinalScale) / 2,
                        maxDescent: insideBottom - followerBaseline,
                        width: followerWidth,
                        titleWidth: titleWidth,
                        imageHeight: followerImageHeight,
                        targetX: canCenter,
                        progress: returning ? _part(.34, .78) : 0,
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
                    if (showingResult &&
                        _kind == _CanMotion.poof &&
                        _motion.value < 1)
                      Positioned(
                        key: const Key('shobone-smoke'),
                        left: canCenter - followerWidth * .72,
                        bottom: followerBottom - 4,
                        width: followerWidth * 1.44,
                        height: followerImageHeight * 1.55,
                        child: IgnorePointer(
                          child: ExcludeSemantics(
                            child: CustomPaint(
                              painter: _SmokePainter(_motion.value),
                            ),
                          ),
                        ),
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
    required double bottom,
    required double diveDistance,
    required double maxDescent,
    required double width,
    required double titleWidth,
    required double imageHeight,
    required double targetX,
    required double progress,
    required String label,
    required String image,
    required String semanticLabel,
    required Key motionKey,
    TextStyle labelStyle = _followerLabelStyle,
    double labelGap = 0,
    Key? labelKey,
    bool celebrate = false,
  }) {
    final angle = math.sin(progress * math.pi) * (left < targetX ? .22 : -.22);
    final scale = 1 - progress * (1 - _followerFinalScale);
    // Only the image dives. The fading heading must not lengthen its path or
    // shift its rotation pivot. Account for every rotated corner at the floor.
    final rotatedHeight =
        scale *
        (imageHeight * math.cos(angle).abs() + width * math.sin(angle).abs());
    final descent = math.min(
      diveDistance * progress -
          math.sin(progress * math.pi) * 64 -
          (celebrate ? math.sin(_motion.value * math.pi) * 12 : 0),
      maxDescent - (rotatedHeight - imageHeight) / 2,
    );
    return Positioned(
      left: left - (titleWidth - width) / 2,
      bottom: bottom,
      width: titleWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          Opacity(
            opacity: progress < 1
                ? _kind == _CanMotion.poof
                      ? _part(.2, .55)
                      : 1
                : 0,
            child: Transform.translate(
              key: motionKey,
              offset: Offset((targetX - left - width / 2) * progress, descent),
              child: Transform.rotate(
                angle: angle,
                child: Transform.scale(
                  scale: scale,
                  child: Image.asset(
                    image,
                    width: width,
                    height: imageHeight,
                    fit: BoxFit.contain,
                    semanticLabel: semanticLabel,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmokePainter extends CustomPainter {
  const _SmokePainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final growth = Curves.easeOutCubic.transform(
      (progress / .5).clamp(0.0, 1.0),
    );
    final fade = 1 - const Interval(.4, 1).transform(progress);
    final opacity = (progress * 9).clamp(0.0, 1.0) * fade;
    for (var i = 0; i < 7; i++) {
      final angle = i * math.pi * 2 / 7;
      final center = Offset(
        size.width / 2 + math.cos(angle) * size.width * .23 * growth,
        size.height * .64 +
            math.sin(angle) * size.height * .2 * growth -
            size.height * .22 * progress,
      );
      final radius = size.shortestSide * (.17 + .08 * growth);
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = const Color(0xFFF4ECDE).withValues(alpha: opacity),
      );
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        angle - .7,
        2.3,
        false,
        Paint()
          ..color = const Color(0xFFBCAF9B).withValues(alpha: opacity * .8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_SmokePainter oldDelegate) =>
      progress != oldDelegate.progress;
}

const _canInk = Color(0xFF392923);
const _followerLabelStyle = TextStyle(
  fontSize: 11,
  height: 1.35,
  fontWeight: FontWeight.w500,
  color: _canInk,
);
const _resultTitleStyle = TextStyle(
  fontSize: 34,
  height: 1.15,
  fontWeight: FontWeight.w500,
  letterSpacing: 1.2,
  color: _canInk,
);
const _prefixStyle = TextStyle(
  fontSize: 12,
  height: 1.55,
  fontWeight: FontWeight.w500,
);
const _valueStyle = TextStyle(
  fontSize: 14.5,
  height: 1.55,
  fontWeight: FontWeight.w500,
);
const _nicknameStyle = TextStyle(
  fontSize: 18,
  height: 1.5,
  fontWeight: FontWeight.w500,
);
const _prefixes = ['ニックネーム：', '趣味：', 'ひとこと：'];

TextPainter _measureText(
  BuildContext context,
  String text,
  TextStyle style,
  double width,
) {
  final defaults = DefaultTextStyle.of(context);
  final media = MediaQuery.of(context);
  // Match Text's accessibility settings as well as its scale. Otherwise a
  // taller result heading (or can label) can exceed the reserved scene space.
  final effectiveStyle = defaults.style
      .merge(style)
      .copyWith(
        fontWeight: media.boldText ? FontWeight.bold : null,
        height: media.lineHeightScaleFactorOverride,
        letterSpacing: media.letterSpacingOverride,
        wordSpacing: media.wordSpacingOverride,
      );
  return TextPainter(
    text: TextSpan(text: text.isEmpty ? ' ' : text, style: effectiveStyle),
    textDirection: Directionality.of(context),
    textScaler: media.textScaler,
    locale: Localizations.maybeLocaleOf(context),
    textWidthBasis: defaults.textWidthBasis,
    textHeightBehavior:
        defaults.textHeightBehavior ??
        DefaultTextHeightBehavior.maybeOf(context),
  )..layout(maxWidth: width);
}

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
                    fontWeight: FontWeight.w500,
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

/// The unpeeled rear strip stays on the rim. A rounded fold travels backwards
/// as the tab pulls the front of the same metal sheet upwards and over it.
class _PeelingLidGeometry {
  _PeelingLidGeometry(this.lid, this.peel);

  final Rect lid;
  final double peel;

  double get foldDepth => 1 - peel * .93;

  double projectedY(double depth) {
    if (peel == 0 || depth <= foldDepth) return lid.top + lid.height * depth;
    final angle = 1.9 * (peel / .32).clamp(0.0, 1.0);
    final foldLength = math.min(.28, 1 - foldDepth);
    final distance = depth - foldDepth;
    final curved = math.min(distance, foldLength);
    final curvature = angle / foldLength;
    final flat = math.max(0.0, distance - foldLength);
    // Integrating the tangent keeps the sheet continuous at the moving fold.
    final horizontal =
        math.sin(curved * curvature) / curvature + flat * math.cos(angle);
    final vertical =
        (1 - math.cos(curved * curvature)) / curvature + flat * math.sin(angle);
    return lid.top +
        lid.height * (foldDepth + horizontal) -
        lid.width * .36 * vertical;
  }

  Offset edge(double depth, {required bool right}) {
    final halfWidth = lid.width * math.sqrt(math.max(0, depth * (1 - depth)));
    return Offset(
      lid.center.dx + (right ? halfWidth : -halfWidth),
      projectedY(depth),
    );
  }

  Path strip(double from, double to) {
    final path = Path();
    final first = edge(from, right: false);
    path.moveTo(first.dx, first.dy);
    for (var i = 1; i <= 48; i++) {
      final point = edge(from + (to - from) * i / 48, right: false);
      path.lineTo(point.dx, point.dy);
    }
    for (var i = 48; i >= 0; i--) {
      final point = edge(from + (to - from) * i / 48, right: true);
      path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  Path embossedOval(double inset) {
    final oval = lid.deflate(inset);
    final path = Path();
    for (var i = 0; i <= 80; i++) {
      final angle = i * math.pi * 2 / 80;
      final x = oval.center.dx + oval.width * .5 * math.cos(angle);
      final depth =
          (oval.center.dy + oval.height * .5 * math.sin(angle) - lid.top) /
          lid.height;
      final y = projectedY(depth);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    return path..close();
  }
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
    final tabLift = const Interval(
      0,
      .25,
      curve: Curves.easeOutCubic,
    ).transform(opening);
    final peel = const Interval(
      .2,
      1,
      curve: Curves.easeInOutSine,
    ).transform(opening);
    _paintLid(canvas, _PeelingLidGeometry(mouth, peel), ink, tabLift);
  }

  void _paintLid(
    Canvas canvas,
    _PeelingLidGeometry sheet,
    Paint ink,
    double tabLift,
  ) {
    final outline = sheet.strip(0, 1);
    final stillSealed = sheet.strip(0, sheet.foldDepth);
    final peeled = sheet.strip(sheet.foldDepth, 1);
    final lid = sheet.lid;
    final metal = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFB7C7D2), Color(0xFFECF0F0), Color(0xFFA5B4BE)],
      ).createShader(lid);
    canvas.drawPath(stillSealed, metal);
    if (sheet.peel > 0) {
      // The lifted front edge casts a small shadow into the opening, while
      // the rear silver strip remains visibly attached to the rolled rim.
      canvas.save();
      canvas.clipPath(Path()..addOval(lid));
      canvas.drawPath(
        peeled.shift(const Offset(0, 3)),
        Paint()..color = _canInk.withValues(alpha: .23),
      );
      canvas.restore();
      canvas.drawPath(
        peeled,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEBF0F2), Color(0xFFFFFFFF), Color(0xFF8599A8)],
            stops: [0, .62, 1],
          ).createShader(peeled.getBounds()),
      );
    }
    canvas.save();
    canvas.clipPath(outline);
    _wash(canvas, outline.getBounds(), const Color(0xFF6E8A9C), .14);
    canvas.restore();
    canvas.drawPath(outline, ink);
    // The stamped rings belong to the sheet and bend with it, instead of
    // staying behind as a second lid on the mouth.
    canvas.drawPath(
      sheet.embossedOval(compact ? 4 : 6),
      Paint()
        ..color = Colors.white.withValues(alpha: .9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = compact ? 1.6 : 2.8,
    );
    canvas.drawPath(
      sheet.embossedOval(compact ? 6 : 9),
      Paint()
        ..color = const Color(0xFF647681)
        ..style = PaintingStyle.stroke
        ..strokeWidth = compact ? 1.1 : 1.8,
    );
    _paintAttachedFold(canvas, sheet);
    _paintPullTab(canvas, sheet, ink, tabLift);
  }

  void _paintAttachedFold(Canvas canvas, _PeelingLidGeometry sheet) {
    final visible = const Interval(.4, .85).transform(sheet.peel);
    if (visible == 0) return;
    final lid = sheet.lid;
    final halfWidth = lid.width * .085;
    final top = lid.top - lid.height * .23 * visible;
    final bottom = lid.top + lid.height * .34 * visible;
    final middle = lid.center.dx;
    // The projected sheet is almost edge-on at its attachment. This short
    // curved return makes the remaining metal connection visibly continuous.
    final fold = Path()
      ..moveTo(middle - halfWidth, top)
      ..quadraticBezierTo(middle, top + 3, middle + halfWidth, top)
      ..quadraticBezierTo(
        middle + halfWidth * .68,
        lid.top + 3,
        middle + halfWidth * .82,
        bottom,
      )
      ..quadraticBezierTo(middle, bottom + 3, middle - halfWidth * .82, bottom)
      ..quadraticBezierTo(
        middle - halfWidth * .68,
        lid.top + 3,
        middle - halfWidth,
        top,
      )
      ..close();
    canvas.drawPath(
      fold,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFE9EFF2).withValues(alpha: visible),
            const Color(0xFF8196A5).withValues(alpha: visible),
            const Color(0xFFDCE5E9).withValues(alpha: visible),
          ],
          stops: const [0, .55, 1],
        ).createShader(fold.getBounds()),
    );
    canvas.drawPath(
      fold,
      Paint()
        ..color = _canInk.withValues(alpha: visible * .7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = compact ? .9 : 1.5,
    );
    final bend = Path()
      ..moveTo(middle - halfWidth * .73, lid.top + 4 * visible)
      ..quadraticBezierTo(
        middle,
        lid.top + 7 * visible,
        middle + halfWidth * .73,
        lid.top + 4 * visible,
      );
    canvas.drawPath(
      bend,
      Paint()
        ..color = Colors.white.withValues(alpha: visible * .85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = compact ? 1.1 : 1.8,
    );
  }

  void _paintPullTab(
    Canvas canvas,
    _PeelingLidGeometry sheet,
    Paint ink,
    double lift,
  ) {
    final lid = sheet.lid;
    final rivet = Offset(lid.center.dx, sheet.projectedY(.69));
    final tab = Rect.fromCenter(
      center: Offset(
        rivet.dx,
        rivet.dy + lid.height * .08 - lid.width * .072 * lift,
      ),
      width: lid.width * .15,
      height: lid.height * .29 + lid.width * .047 * lift,
    );
    final tabEnd = Offset(tab.center.dx, tab.bottom - 1);
    canvas.drawLine(
      rivet,
      tabEnd,
      Paint()
        ..color = _canInk
        ..strokeWidth = compact ? 4 : 6,
    );
    canvas.drawLine(
      rivet,
      tabEnd,
      Paint()
        ..color = const Color(0xFFD8E1E5)
        ..strokeWidth = compact ? 2 : 3.5,
    );
    final inner = tab.deflate(compact ? 2 : 3.2);
    final ring = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(tab)
      ..addOval(inner);
    canvas.drawPath(ring, Paint()..color = const Color(0xFFD9E3E8));
    canvas.drawOval(
      tab,
      Paint()
        ..color = _canInk
        ..style = PaintingStyle.stroke
        ..strokeWidth = compact ? 1.4 : 2.2,
    );
    canvas.drawOval(
      inner,
      Paint()
        ..color = const Color(0xFF647681)
        ..style = PaintingStyle.stroke
        ..strokeWidth = compact ? .9 : 1.4,
    );
    canvas.drawCircle(
      rivet,
      compact ? 1.8 : 2.8,
      Paint()..color = const Color(0xFF738591),
    );
    canvas.drawCircle(
      rivet.translate(-.6, -.6),
      compact ? .7 : 1.1,
      Paint()..color = const Color(0xFFF2F5F6),
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
