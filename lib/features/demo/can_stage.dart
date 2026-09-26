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
                      : visibleCanHeight + 18,
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

const _followerLabelStyle = TextStyle(
  fontSize: 11,
  height: 1.35,
  fontWeight: FontWeight.bold,
);
const _prefixStyle = TextStyle(
  fontSize: 11.5,
  height: 1.4,
  fontWeight: FontWeight.w600,
);
const _valueStyle = TextStyle(fontSize: 13.5, height: 1.4);
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
    if (compact) {
      return math.max(
        72,
        MediaQuery.textScalerOf(context).scale(10) * 1.4 + 42,
      );
    }
    if (!showLabel) {
      return math.max(
        176,
        MediaQuery.textScalerOf(context).scale(22) * 1.4 + 64,
      );
    }
    final layout = _LabelLayout(context, width - 48, profile);
    return math.max(176, layout.height + 64);
  }

  @override
  Widget build(BuildContext context) {
    final labelColor = switch (team) {
      Team.red => const Color(0xFFB83F40),
      Team.blue => const Color(0xFF286CA8),
      null => const Color(0xFFF6F0DF),
    };
    final textColor = team == null ? const Color(0xFF304D46) : Colors.white;
    return CustomPaint(
      painter: _CanPainter(
        labelColor: showLabel ? labelColor : null,
        compact: compact,
      ),
      child: Padding(
        padding: compact
            ? const EdgeInsets.fromLTRB(10, 28, 10, 14)
            : const EdgeInsets.fromLTRB(24, 44, 24, 20),
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

class _CanPainter extends CustomPainter {
  const _CanPainter({required this.labelColor, required this.compact});

  final Color? labelColor;
  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    final lip = compact ? 22.0 : 36.0;
    final body = Rect.fromLTWH(2, lip / 2, size.width - 4, size.height - lip);
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFFADBDB7),
          Color(0xFFF2F4EE),
          Color(0xFFDCE5DF),
          Color(0xFFAABDB6),
        ],
      ).createShader(body);
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(18)),
      paint,
    );
    canvas.drawOval(
      Rect.fromLTWH(2, size.height - lip - 1, size.width - 4, lip),
      Paint()..color = const Color(0xFFB7C6BD),
    );
    canvas.drawRect(
      Rect.fromLTWH(2, lip / 2, size.width - 4, size.height - lip * 1.5),
      paint,
    );
    if (labelColor != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(8, lip + 2, size.width - 8, size.height - 14),
          const Radius.circular(5),
        ),
        Paint()..color = labelColor!,
      );
    }
    canvas.drawOval(
      Rect.fromLTWH(2, 1, size.width - 4, lip),
      Paint()..color = const Color(0xFFE4EAE4),
    );
    canvas.drawOval(
      Rect.fromLTWH(7, 4, size.width - 14, lip - 7),
      Paint()
        ..color = const Color(0xFF99ADA3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * .55, lip / 2),
        width: size.width * .16,
        height: lip * .44,
      ),
      Paint()
        ..color = const Color(0xFF8C9E98)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_CanPainter oldDelegate) =>
      oldDelegate.labelColor != labelColor || oldDelegate.compact != compact;
}
