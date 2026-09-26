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

const _ropeY = .58;
const _groundY = .72;
const _goalOffset = .145;
const _flagTravel = .23;
const _countdownSeconds = 3.0;
const _pullSeconds = 6.5;
const _revealSeconds = 11.0;
const _totalSeconds = 13.0;

class _TugOfWarFinaleState extends State<TugOfWarFinale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;
  bool _started = false;
  bool _reduceMotion = false;
  bool _resultsOpened = false;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 13),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_started && _reduceMotion) _motion.value = 1;
  }

  @override
  void didUpdateWidget(TugOfWarFinale oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Clock-driven parent rebuilds keep their place. A new snapshot waits for
    // its own explicit start, including reduced-motion and zero-power events.
    if (!identical(oldWidget.snapshot, widget.snapshot)) {
      _motion.stop();
      _motion.value = 0;
      _started = false;
      _resultsOpened = false;
    }
  }

  bool get _hasNoPower =>
      widget.snapshot.redPower + widget.snapshot.bluePower == 0;

  void _start() {
    if (_started) return;
    setState(() => _started = true);
    if (_reduceMotion || _hasNoPower) {
      _motion.value = 1;
    } else {
      _motion.forward(from: 0);
    }
  }

  void _showResults() {
    if (_resultsOpened) return;
    setState(() => _resultsOpened = true);
    widget.onShowResults();
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
      final seconds = _motion.value * _totalSeconds;
      final finished = _started && seconds >= _revealSeconds;
      final counting = _started && seconds < _countdownSeconds;
      final pulling =
          _started && seconds >= _countdownSeconds && seconds < _revealSeconds;
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
          : counting
          ? 'よーい…'
          : seconds < _countdownSeconds + _pullSeconds
          ? 'オーエス！ オーエス！'
          : snapshot.isDraw
          ? 'どちらも、ゆずらない！'
          : 'あと、ひと引き！';
      final progress = ((seconds - _countdownSeconds) / _pullSeconds).clamp(
        0.0,
        1.0,
      );
      final finish = Curves.easeInOutCubic.transform(
        ((seconds - _countdownSeconds - _pullSeconds) / 1.5).clamp(0.0, 1.0),
      );
      final direction = winner == Team.red
          ? -1.0
          : winner == Team.blue
          ? 1.0
          : 0.0;
      final total = snapshot.redPower + snapshot.bluePower;
      final margin = total == 0
          ? 0.0
          : (snapshot.redPower - snapshot.bluePower).abs() / total;
      // The first half stays around the centre, even for a large score gap.
      // Only later does the settled winner gain ground; no score is invented.
      final advantage =
          direction *
          (.08 + margin * .47) *
          Curves.easeInCubic.transform(
            ((progress - .45) / .55).clamp(0.0, 1.0),
          );
      final tussle =
          math.sin(progress * math.pi * 4.5) *
          math.sin(progress * math.pi) *
          .24 *
          (1 - margin * .45);
      final contest = advantage + tussle;
      final pull = contest * (1 - finish) + direction * .82 * finish;
      final beat = pulling ? math.sin(seconds * math.pi * 5) : 0.0;
      final celebration = ((seconds - _revealSeconds) / 2).clamp(0.0, 1.0);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '最後の大綱引き',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 30,
              height: 1.3,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          if (_started) ...[
            Semantics(
              liveRegion: true,
              child: Text(
                headline,
                key: const Key('tug-headline'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: finished ? winnerColor : TsunagunColors.ink,
                  fontSize: 26,
                  height: 1.3,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            finished
                ? snapshot.isDraw
                      ? _hasNoPower
                            ? '次は仲間をつなげて、いざ勝負！'
                            : 'いい勝負！ みんなに拍手。'
                      : '子分のエールがチームのちから！'
                : '仲間のちからを、ひとつに。',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: 12),
          // Keep the arena still as the countdown becomes a smaller chant.
          // The minimum grows with text scale; larger content can still expand.
          if (counting || pulling)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.textScalerOf(context).scale(56),
                ),
                child: Center(
                  child: counting
                      ? Text(
                          '${3 - seconds.floor().clamp(0, 2)}',
                          key: const Key('tug-countdown'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 56,
                            height: 1,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      : const Text(
                          'ぐぐぐ…！',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ),
              ),
            ),
          LayoutBuilder(
            builder: (context, constraints) => SizedBox(
              key: const Key('tug-arena'),
              height: constraints.maxWidth * .87,
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: CustomPaint(painter: _FactoryArenaPainter()),
                  ),
                  _audience(constraints.maxWidth),
                  for (final team in Team.values)
                    Positioned(
                      left:
                          constraints.maxWidth *
                              (.5 + (team == Team.red ? -1 : 1) * _goalOffset) -
                          2,
                      top: constraints.maxWidth * (_ropeY - .055),
                      width: 4,
                      height: constraints.maxWidth * .25,
                      child: CustomPaint(
                        key: Key('tug-${team.name}-goal'),
                        painter: _GoalPainter(team),
                      ),
                    ),
                  for (final team in Team.values)
                    _captain(
                      team,
                      constraints.maxWidth,
                      pull,
                      beat,
                      finish,
                      celebration,
                    ),
                  Positioned.fill(
                    child: ExcludeSemantics(
                      child: CustomPaint(
                        painter: _RopePainter(
                          pull: pull,
                          beat: beat,
                          pulling: pulling,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: constraints.maxWidth * (.5 + pull * _flagTravel) - 10,
                    top: constraints.maxWidth * _ropeY - 4,
                    width: 20,
                    height: 38,
                    child: CustomPaint(
                      key: const Key('tug-rope-flag'),
                      painter: _RibbonPainter(beat),
                    ),
                  ),
                  if (finished &&
                      !_reduceMotion &&
                      !_hasNoPower &&
                      celebration < 1)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: ExcludeSemantics(
                          child: CustomPaint(
                            key: const Key('tug-confetti'),
                            painter: _ConfettiPainter(progress: celebration),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (finished) ...[
            _score(Team.red),
            const SizedBox(height: 18),
            _score(Team.blue),
            const SizedBox(height: 22),
            FilledButton(
              key: const Key('show-results'),
              onPressed: _resultsOpened ? null : _showResults,
              child: const Text('みんなの活躍を見る'),
            ),
          ] else ...[
            Row(
              children: [
                for (final team in Team.values)
                  Expanded(child: _teamName(team)),
              ],
            ),
            const SizedBox(height: 18),
            if (!_started)
              FilledButton(
                key: const Key('start-tug-button'),
                onPressed: _start,
                child: const Text('綱引きスタート！'),
              )
            else
              TextButton(
                key: const Key('skip-tug-animation'),
                onPressed: () => _motion.value = 1,
                child: const Text('演出をスキップ'),
              ),
          ],
        ],
      );
    },
  );

  Widget _teamName(Team team) => Text(
    team.label,
    textAlign: TextAlign.center,
    style: TextStyle(
      color: team == Team.red ? TsunagunColors.red : TsunagunColors.blue,
      fontSize: 19,
      fontWeight: FontWeight.w500,
    ),
  );

  Widget _score(Team team) {
    final members = widget.snapshot.rankings.where(
      (row) => row.participant.team == team,
    );
    final normal = members.fold(0, (sum, row) => sum + row.normalCount);
    final bone = members.fold(0, (sum, row) => sum + row.boneCount);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          children: [
            _teamName(team),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'ちから ',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '${team == Team.red ? widget.snapshot.redPower : widget.snapshot.bluePower}',
                  key: Key('tug-${team.name}-power'),
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        _breakdown(
          team,
          normalFollowerAsset,
          'normal',
          '子分 $normal匹 × 3pt = ${normal * 3}pt',
        ),
        const SizedBox(height: 4),
        _breakdown(
          team,
          boneFollowerAsset,
          'bone',
          '骨 $bone匹 × 1pt = ${bone}pt',
        ),
      ],
    );
  }

  Widget _breakdown(Team team, String asset, String kind, String text) => Row(
    children: [
      ExcludeSemantics(
        child: Image.asset(asset, width: 32, height: 28, fit: BoxFit.contain),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          key: Key('tug-${team.name}-$kind-breakdown'),
          style: const TextStyle(fontSize: 15, height: 1.5),
        ),
      ),
    ],
  );

  Widget _audience(double width) => Positioned.fill(
    child: ExcludeSemantics(
      child: Stack(
        key: const Key('tug-decorative-audience'),
        children: [
          // Twelve spectators are part of the scenery, never an inventory.
          for (final red in [true, false])
            for (var row = 0; row < 2; row++)
              for (var seat = 0; seat < 3; seat++)
                Positioned(
                  left: width * ((red ? .065 : .565) + seat * .13),
                  top: width * (.07 + row * .12),
                  width: width * .11,
                  height: width * .095,
                  child: _actor(
                    (seat + row).isEven
                        ? normalFollowerAsset
                        : boneFollowerAsset,
                    red,
                    0,
                  ),
                ),
        ],
      ),
    ),
  );

  Widget _captain(
    Team team,
    double width,
    double pull,
    double beat,
    double finish,
    double celebration,
  ) {
    final red = team == Team.red;
    final won = widget.snapshot.winnerTeam == team;
    final jump = won ? math.sin(celebration * math.pi) * 16 : 0.0;
    return Positioned(
      left: width * (red ? .105 : .565) + pull * width * .09,
      top: width * .40 + beat * 2 - jump,
      width: width * .33,
      height: width * .29,
      child: ExcludeSemantics(
        child: _actor(
          parentAsset,
          red,
          (red ? -.1 : .1) * (1 - finish) + beat * .02,
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

class _FactoryArenaPainter extends CustomPainter {
  const _FactoryArenaPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // Two stepped stands use muted timber and metal, leaving the rope clear.
    for (final red in [true, false]) {
      final x = w * (red ? .03 : .53);
      final teamColor = red ? TsunagunColors.red : TsunagunColors.blue;
      for (var row = 0; row < 2; row++) {
        final y = w * (.15 + row * .12);
        final board = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, w * .44, w * .045),
          const Radius.circular(3),
        );
        canvas.drawRRect(board, Paint()..color = const Color(0xFFE6C99B));
        canvas.drawRRect(
          board,
          stroke
            ..color = const Color(0xFF8F775E)
            ..strokeWidth = 1.5,
        );
        for (final end in [.025, .405]) {
          canvas.drawLine(
            Offset(x + w * end, y + w * .045),
            Offset(x + w * end, w * .34),
            stroke
              ..color = const Color(0xFF9AA7A9)
              ..strokeWidth = 3,
          );
          canvas.drawCircle(
            Offset(x + w * end, y + w * .022),
            1.5,
            Paint()..color = TsunagunColors.ink.withValues(alpha: .55),
          );
        }
      }
      final rail = Path()
        ..moveTo(x, w * .335)
        ..lineTo(x + w * .44, w * .335);
      canvas.drawPath(
        rail,
        stroke
          ..color = teamColor.withValues(alpha: .5)
          ..strokeWidth = 4,
      );
    }
    final ground = w * _groundY;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, ground + 7),
        width: w * .96,
        height: w * .15,
      ),
      Paint()..color = const Color(0xFFEDE7D6),
    );
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
      canvas.drawPath(
        Path()
          ..moveTo(w * .5 + side * w * .09, ground + w * .12)
          ..lineTo(w * .5 + side * w * .16, ground + w * .12)
          ..lineTo(w * .5 + side * w * .14, ground + w * .10),
        stroke
          ..color = (side < 0 ? TsunagunColors.red : TsunagunColors.blue)
              .withValues(alpha: .55)
          ..strokeWidth = 2.5,
      );
    }
  }

  @override
  bool shouldRepaint(_FactoryArenaPainter oldDelegate) => false;
}

class _RopePainter extends CustomPainter {
  const _RopePainter({
    required this.pull,
    required this.beat,
    required this.pulling,
  });

  final double pull;
  final double beat;
  final bool pulling;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final ropeY = w * _ropeY;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final rope = Path()
      ..moveTo(w * .03, ropeY)
      ..quadraticBezierTo(w * .5, ropeY + beat * 2 + 3, w * .97, ropeY);
    canvas.drawPath(
      rope,
      stroke
        ..color = TsunagunColors.ink
        ..strokeWidth = 9,
    );
    canvas.drawPath(
      rope,
      stroke
        ..color = const Color(0xFFD9B471)
        ..strokeWidth = 5,
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
    if (pulling) {
      for (final side in [-1, 1]) {
        for (var i = 0; i < 3; i++) {
          final x = side < 0 ? w * (.05 + i * .045) : w * (.95 - i * .045);
          canvas.drawLine(
            Offset(x, w * _groundY - i * 3 + beat * 2),
            Offset(x - side * 5, w * _groundY - 5 - i * 3 + beat * 2),
            stroke
              ..color = const Color(0xFFAC8651).withValues(alpha: .7)
              ..strokeWidth = 2,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_RopePainter oldDelegate) =>
      pull != oldDelegate.pull ||
      beat != oldDelegate.beat ||
      pulling != oldDelegate.pulling;
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final alpha = (1 - ((progress - .65) / .35).clamp(0.0, 1.0));
    for (var i = 0; i < 26; i++) {
      final seed = i * 2.39996;
      final x =
          size.width * ((i % 9 + .5) / 9) + math.sin(seed + progress * 6) * 9;
      final y = size.height * (-.05 - (i % 4) * .07 + progress * 1.2);
      final color = switch (i % 3) {
        0 => TsunagunColors.yellow,
        1 => TsunagunColors.blue,
        _ => TsunagunColors.red,
      };
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(seed + progress * 4);
      // Broad, short paper strips read as confetti instead of sparkle dots.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-3, -7, 6, 14),
          const Radius.circular(.5),
        ),
        Paint()..color = color.withValues(alpha: alpha),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) =>
      progress != oldDelegate.progress;
}

class _GoalPainter extends CustomPainter {
  const _GoalPainter(this.team);

  final Team team;

  @override
  void paint(Canvas canvas, Size size) {
    final color = team == Team.red ? TsunagunColors.red : TsunagunColors.blue;
    final paint = Paint()
      ..color = color.withValues(alpha: .72)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;
    for (var y = 0.0; y < size.height; y += 10) {
      canvas.drawLine(Offset(2, y), Offset(2, y + 5), paint);
    }
    // Small triangular ground markers keep both victory lines visible without
    // adding another label over the enlarged crews.
    for (final y in [0.0, size.height]) {
      canvas.drawPath(
        Path()
          ..moveTo(-5, y)
          ..lineTo(9, y)
          ..lineTo(2, y + (y == 0 ? 7 : -7))
          ..close(),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_GoalPainter oldDelegate) => team != oldDelegate.team;
}

class _RibbonPainter extends CustomPainter {
  const _RibbonPainter(this.beat);

  final double beat;

  @override
  void paint(Canvas canvas, Size size) {
    final ribbon = Path()
      ..moveTo(3, 0)
      ..lineTo(17, 0)
      ..lineTo(20 + beat * 2, 36)
      ..lineTo(10, 30)
      ..lineTo(1 + beat * 2, 37)
      ..close();
    canvas.drawPath(ribbon, Paint()..color = TsunagunColors.yellow);
    canvas.drawPath(
      ribbon,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = TsunagunColors.ink
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_RibbonPainter oldDelegate) => beat != oldDelegate.beat;
}
