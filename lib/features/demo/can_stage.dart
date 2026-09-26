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
  });

  final AppPhase phase;
  final Profile profile;
  final EncounterResult? result;

  @override
  Widget build(BuildContext context) {
    final playing = phase == AppPhase.game;
    final returning = phase == AppPhase.returning;
    final showingResult = phase == AppPhase.result;
    final parentVisible = playing || showingResult || returning;
    final isLoss = result?.outcome == Outcome.loss;
    final scaler = MediaQuery.textScalerOf(context);
    final extraLabelHeight = playing
        ? (scaler.scale(10) - 10).clamp(0.0, double.infinity) * 1.6
        : ([22.0, 14.0, 11.0]
                      .map((size) => scaler.scale(size) - size)
                      .reduce((a, b) => a + b))
                  .clamp(0.0, double.infinity) *
              1.6;
    final separateNewBone =
        result?.promoted != null &&
        result!.promoted!.id != result!.newFollower.id;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 650);
    return Semantics(
      container: true,
      label: 'プロフィールが書かれた自分の缶',
      child: Container(
        height:
            (parentVisible ? 300 : 244) +
            extraLabelHeight +
            (playing
                ? (scaler.scale(14) - 14).clamp(0.0, double.infinity) * 8
                : 0),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final canWidth = playing ? 88.0 : math.min(210.0, width * .65);
            final canHeight = canWidth * .66 + extraLabelHeight;
            final canLeft = playing
                ? width - canWidth - 18
                : (width - canWidth) / 2;
            final parentWidth = playing ? 76.0 : math.min(126.0, width * .4);
            return Stack(
              children: [
                if (playing)
                  const Positioned(
                    left: 20,
                    top: 22,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.sports_esports_outlined, size: 34),
                        SizedBox(height: 10),
                        Text('ミニゲームのスペース'),
                      ],
                    ),
                  ),
                AnimatedPositioned(
                  duration: duration,
                  curve: Curves.easeInOutCubic,
                  left: canLeft,
                  bottom: 18,
                  width: canWidth,
                  height: canHeight,
                  child: TunaCan(profile: profile, compact: playing),
                ),
                AnimatedPositioned(
                  duration: duration,
                  curve: Curves.easeInOutCubic,
                  left: playing
                      ? width - parentWidth - 24
                      : (width - parentWidth) / 2,
                  bottom: returning ? 36 : canHeight + 7,
                  width: parentWidth,
                  height: parentWidth,
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
                        // The parent is always alive, including a lost duel.
                        child: Image.asset(parentAsset, semanticLabel: '親分'),
                      ),
                    ),
                  ),
                ),
                if (result != null && (showingResult || returning))
                  AnimatedPositioned(
                    duration: duration,
                    curve: Curves.easeInOutCubic,
                    left: returning ? width / 2 - 44 : 8,
                    bottom: returning ? 34 : canHeight + 8,
                    width: math.min(100, width * .3),
                    child: AnimatedOpacity(
                      duration: duration,
                      opacity: returning ? 0 : 1,
                      child: AnimatedScale(
                        duration: duration,
                        scale: returning ? .1 : 1,
                        child: Column(
                          children: [
                            Text(
                              isLoss
                                  ? 'ショBONE'
                                  : result!.outcome == Outcome.win
                                  ? 'よろしく(ツ)ナ'
                                  : result!.promoted != null
                                  ? '元気になった！'
                                  : '新しい仲間',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
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
                    right: returning ? width / 2 - 42 : 4,
                    bottom: returning ? 34 : canHeight + 8,
                    width: math.min(90, width * .27),
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
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
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
                if (!parentVisible)
                  const Positioned(
                    top: 20,
                    left: 12,
                    right: 12,
                    child: Text(
                      '出会いが、仲間になる。',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF5D736D),
                        letterSpacing: 2,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class TunaCan extends StatelessWidget {
  const TunaCan({super.key, required this.profile, this.compact = false});

  final Profile profile;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _CanPainter(),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, compact ? 17 : 35, 16, 12),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                profile.nickname.isEmpty ? 'はだ缶' : profile.nickname,
                key: const Key('can-nickname'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 10 : 22,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF315F5B),
                ),
              ),
              if (!compact && profile.hobby.isNotEmpty)
                Text(
                  profile.hobby,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              if (!compact && profile.comment.isNotEmpty)
                Text(
                  profile.comment,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF5D736D),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CanPainter extends CustomPainter {
  const _CanPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final lip = size.height * .22;
    final body = Rect.fromLTWH(2, lip / 2, size.width - 4, size.height - lip);
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFFBBC8C4),
          Color(0xFFF1F4EE),
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
      Rect.fromLTWH(2, lip, size.width - 4, size.height - lip * 1.65),
      paint,
    );
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
  bool shouldRepaint(_CanPainter oldDelegate) => false;
}
