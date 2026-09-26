import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/tsunagun_theme.dart';
import '../../domain/models.dart';
import 'can_stage.dart';

/// Plays the already settled team result once. Animation never changes scores.
class TugOfWarFinale extends StatefulWidget {
  const TugOfWarFinale({
    super.key,
    required this.snapshot,
    required this.onShowResults,
  });

  final FinalSnapshot snapshot;
  final VoidCallback onShowResults;

  @override
  State<TugOfWarFinale> createState() => _TugOfWarFinaleState();
}

class _TugOfWarFinaleState extends State<TugOfWarFinale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;
  bool _started = false;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (!_started) {
      _started = true;
      _start();
    } else if (_reduceMotion) {
      _motion.value = 1;
    }
  }

  @override
  void didUpdateWidget(TugOfWarFinale oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The controller's clock rebuilds its parent. Only a new final snapshot
    // represents a new event, and may restart this finite presentation.
    if (!identical(oldWidget.snapshot, widget.snapshot)) {
      _reduceMotion = MediaQuery.disableAnimationsOf(context);
      _start();
    }
  }

  void _start() {
    if (_reduceMotion) {
      _motion.value = 1;
    } else {
      _motion.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _motion,
    builder: (context, _) {
      final seconds = _motion.value * 6.4;
      final finished = seconds >= 5.4;
      final pulling = seconds >= 1.5 && seconds < 5.4;
      final snapshot = widget.snapshot;
      final winner = snapshot.winnerTeam;
      final winnerColor = winner == Team.red
          ? TsunagunColors.red
          : winner == Team.blue
          ? TsunagunColors.blue
          : TsunagunColors.ink;
      final headline = finished
          ? snapshot.isDraw
                ? '引き分け！'
                : '${winner!.label}の勝利！'
          : seconds < 1.5
          ? 'よーい…'
          : seconds < 4.5
          ? 'オーエス！ オーエス！'
          : 'あと、ひと引き！';
      final progress = ((seconds - 1.5) / 3).clamp(0.0, 1.0);
      final finish = Curves.easeInOutCubic.transform(
        ((seconds - 4.5) / .9).clamp(0.0, 1.0),
      );
      final direction = winner == Team.red
          ? -1.0
          : winner == Team.blue
          ? 1.0
          : 0.0;
      // Return to the centre before the final pull; this avoids a discontinuity.
      final tussle =
          math.sin(progress * math.pi * 6) * math.sin(progress * math.pi) * .3;
      final pull = tussle * (1 - finish) + direction * .7 * finish;
      final beat = pulling ? math.sin(seconds * math.pi * 5) : 0.0;
      final celebration = ((seconds - 5.4) / 1).clamp(0.0, 1.0);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'さいごの大綱引き',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 10),
          Semantics(
            liveRegion: true,
            child: Text(
              headline,
              key: const Key('tug-headline'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: finished ? winnerColor : TsunagunColors.ink,
                fontSize: 30,
                height: 1.3,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            finished
                ? snapshot.isDraw
                      ? 'いい勝負！ みんなに拍手。'
                      : 'つながった仲間が、勝利のちから！'
                : '仲間のちからを、ひとつに。',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              // Keep the countdown's natural text size. Enlarged text moves
              // the complete rope/crew stage down, instead of covering it.
              final extraTop = math.max(
                0.0,
                MediaQuery.textScalerOf(context).scale(56) - 56,
              );
              return SizedBox(
                key: const Key('tug-arena'),
                height: constraints.maxWidth * .73 + extraTop,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      top: extraTop,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _ArenaPainter(
                                pull: pull,
                                beat: beat,
                                pulling: pulling,
                                celebration: celebration,
                                celebrate: finished && !_reduceMotion,
                                winner: winner,
                              ),
                            ),
                          ),
                          for (final team in Team.values)
                            _crew(
                              team,
                              constraints.maxWidth,
                              pull,
                              beat,
                              finish,
                              celebration,
                            ),
                        ],
                      ),
                    ),
                    if (seconds < 1.5)
                      Align(
                        alignment: const Alignment(0, -.85),
                        child: Text(
                          '${3 - (seconds * 2).floor().clamp(0, 2)}',
                          key: const Key('tug-countdown'),
                          style: const TextStyle(
                            fontSize: 56,
                            height: 1,
                            fontWeight: FontWeight.w900,
                            color: TsunagunColors.ink,
                          ),
                        ),
                      ),
                    if (pulling)
                      const Align(
                        alignment: Alignment(0, -.9),
                        child: Text(
                          'ぐぐぐ…！',
                          style: TextStyle(
                            color: TsunagunColors.ink,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _score(Team.red, finished)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                child: Text(
                  'VS',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: TsunagunColors.ink,
                  ),
                ),
              ),
              Expanded(child: _score(Team.blue, finished)),
            ],
          ),
          const SizedBox(height: 18),
          if (finished) ...[
            const Text(
              '子分は 3、骨は 1 のちから',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 18),
            FilledButton(
              key: const Key('show-results'),
              onPressed: widget.onShowResults,
              child: const Text('みんなの活躍を見る'),
            ),
          ] else
            TextButton(
              key: const Key('skip-tug-animation'),
              onPressed: () => _motion.value = 1,
              child: const Text('演出をスキップ'),
            ),
        ],
      );
    },
  );

  Widget _score(Team team, bool finished) {
    final red = team == Team.red;
    return Column(
      children: [
        Text(
          team.label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: red ? TsunagunColors.red : TsunagunColors.blue,
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (finished)
          Text(
            '${red ? widget.snapshot.redPower : widget.snapshot.bluePower}',
            key: Key('tug-${team.name}-power'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
          ),
      ],
    );
  }

  Widget _crew(
    Team team,
    double width,
    double pull,
    double beat,
    double finish,
    double celebration,
  ) {
    final red = team == Team.red;
    final members = widget.snapshot.rankings.where(
      (row) => row.participant.team == team,
    );
    final normal = members.fold(0, (sum, row) => sum + row.normalCount);
    final bone = members.fold(0, (sum, row) => sum + row.boneCount);
    final followers = [
      if (normal > 0) normalFollowerAsset,
      if (bone > 0) boneFollowerAsset,
      if (normal + bone > 1 && (normal == 0 || bone == 0))
        normal > 0 ? normalFollowerAsset : boneFollowerAsset,
    ];
    final won = widget.snapshot.winnerTeam == team;
    final jump = won ? math.sin(celebration * math.pi) * 16 : 0.0;
    // The captain leads the picture, while only earned followers add power.
    return Positioned.fill(
      child: ExcludeSemantics(
        child: Stack(
          children: [
            for (var i = 0; i < followers.length; i++)
              Positioned(
                left: red
                    ? width * (.025 + i * .14) + pull * width * .065
                    : width * (.825 - i * .14) + pull * width * .065,
                top: width * .385 + beat * (i.isEven ? 2 : -2) - jump * .6,
                width: width * .15,
                height: width * .145,
                child: _actor(
                  followers[i],
                  red,
                  (red ? -.12 : .12) * (1 - finish) + beat * .025,
                ),
              ),
            Positioned(
              left: width * (red ? .18 : .55) + pull * width * .09,
              top: width * .30 + beat * 2 - jump,
              width: width * .27,
              height: width * .24,
              child: _actor(
                parentAsset,
                red,
                (red ? -.1 : .1) * (1 - finish) + beat * .02,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actor(String asset, bool faceRight, double angle) => Transform.rotate(
    angle: angle,
    alignment: Alignment.bottomCenter,
    child: Transform.flip(
      flipX: !faceRight,
      child: Image.asset(asset, fit: BoxFit.contain),
    ),
  );
}

class _ArenaPainter extends CustomPainter {
  const _ArenaPainter({
    required this.pull,
    required this.beat,
    required this.pulling,
    required this.celebration,
    required this.celebrate,
    required this.winner,
  });

  final double pull;
  final double beat;
  final bool pulling;
  final double celebration;
  final bool celebrate;
  final Team? winner;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final ground = w * .55;
    final ropeY = w * .465;
    final flagX = w * (.5 + pull * .23);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, ground + 7),
        width: w * .94,
        height: w * .10,
      ),
      Paint()..color = TsunagunColors.paper,
    );
    // Centre line remains fixed while the ribbon and the crews move.
    for (var y = ground - 6; y < ground + w * .13; y += 9) {
      canvas.drawLine(
        Offset(w / 2, y),
        Offset(w / 2, y + 4),
        stroke
          ..color = TsunagunColors.ink.withValues(alpha: .4)
          ..strokeWidth = 2,
      );
    }
    for (final side in [-1, 1]) {
      final color = side < 0 ? TsunagunColors.red : TsunagunColors.blue;
      canvas.drawPath(
        Path()
          ..moveTo(w * .5 + side * w * .09, ground + w * .12)
          ..lineTo(w * .5 + side * w * .16, ground + w * .12)
          ..lineTo(w * .5 + side * w * .14, ground + w * .10),
        stroke
          ..color = color.withValues(alpha: .55)
          ..strokeWidth = 2.5,
      );
      if (pulling) {
        for (var i = 0; i < 3; i++) {
          final x = side < 0 ? w * (.05 + i * .045) : w * (.95 - i * .045);
          canvas.drawLine(
            Offset(x, ground - i * 3 + beat * 2),
            Offset(x - side * 5, ground - 5 - i * 3 + beat * 2),
            stroke
              ..color = const Color(0xFFAC8651).withValues(alpha: .7)
              ..strokeWidth = 2,
          );
        }
      }
    }
    final rope = Path()
      ..moveTo(w * .03, ropeY)
      ..quadraticBezierTo(w * .5, ropeY + beat * 2 + 3, w * .97, ropeY);
    canvas.drawPath(
      rope,
      stroke
        ..color = TsunagunColors.ink
        ..strokeWidth = 7,
    );
    canvas.drawPath(
      rope,
      stroke
        ..color = const Color(0xFFD9B471)
        ..strokeWidth = 4,
    );
    for (var x = w * .045; x < w * .96; x += 11) {
      final local = (x + pull * 12).clamp(w * .03, w * .97);
      canvas.drawLine(
        Offset(local, ropeY - 1),
        Offset(local + 2, ropeY + 3),
        stroke
          ..color = const Color(0xFF9E7946)
          ..strokeWidth = 1.3,
      );
    }
    final ribbon = Path()
      ..moveTo(flagX - 7, ropeY - 4)
      ..lineTo(flagX + 7, ropeY - 4)
      ..lineTo(flagX + 10 + beat * 2, ropeY + 32)
      ..lineTo(flagX, ropeY + 26)
      ..lineTo(flagX - 9 + beat * 2, ropeY + 33)
      ..close();
    canvas.drawPath(ribbon, Paint()..color = TsunagunColors.yellow);
    canvas.drawPath(
      ribbon,
      stroke
        ..color = TsunagunColors.ink
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 2,
    );
    if (celebrate) {
      final alpha = (1 - celebration * .4).clamp(0.0, 1.0);
      for (var i = 0; i < 28; i++) {
        final seed = i * 2.39996;
        final x = w * (.5 + math.cos(seed) * (.1 + celebration * .43));
        final y =
            w * (.21 + math.sin(seed) * .16 * celebration) +
            celebration * celebration * w * .16;
        final color = switch (i % 3) {
          0 => TsunagunColors.yellow,
          1 => winner == Team.blue ? TsunagunColors.blue : TsunagunColors.red,
          _ => winner == Team.red ? TsunagunColors.red : TsunagunColors.blue,
        };
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(seed + celebration * 3);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-2, -4, 4, 8),
            const Radius.circular(1),
          ),
          Paint()..color = color.withValues(alpha: alpha),
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_ArenaPainter oldDelegate) =>
      pull != oldDelegate.pull ||
      beat != oldDelegate.beat ||
      pulling != oldDelegate.pulling ||
      celebration != oldDelegate.celebration ||
      celebrate != oldDelegate.celebrate ||
      winner != oldDelegate.winner;
}
