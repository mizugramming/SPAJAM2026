import 'package:flutter/material.dart';

import '../game/game.dart';
import 'workshop_theme.dart';

/// One clock plays the optional material arrival, then the round announcement.
class RoundIntroduction extends StatefulWidget {
  const RoundIntroduction({
    super.key,
    required this.round,
    this.total = GameController.roundCount,
    required this.arrival,
    required this.builder,
  });

  final int round;

  /// Rounds in this play.
  final int total;
  final Duration arrival;
  final Widget Function(Animation<double>? arrival, Widget? cue) builder;

  @override
  State<RoundIntroduction> createState() => _RoundIntroductionState();
}

class _RoundIntroductionState extends State<RoundIntroduction>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _readingTime = Duration(milliseconds: 1050);
  static String _numeral(int round) => switch (round) {
    1 => '一',
    2 => '二',
    3 => '三',
    _ => round.toString(),
  };
  late final _clock = AnimationController(
    vsync: this,
    duration: widget.arrival + _readingTime,
    animationBehavior: AnimationBehavior.preserve,
  )..addStatusListener(_onStatus);

  bool _currentRoute = true;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    final binding = WidgetsBinding.instance;
    binding.addObserver(this);
    _foreground =
        binding.lifecycleState == null ||
        binding.lifecycleState == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _currentRoute = ModalRoute.isCurrentOf(context) ?? true;
    _updateClock();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _updateClock();
  }

  void _updateClock() {
    if (!_foreground || !_currentRoute) {
      _clock.stop();
    } else if (!_clock.isAnimating && !_clock.isCompleted) {
      _clock.forward();
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_clock.isCompleted) return widget.builder(null, null);
    final split =
        widget.arrival.inMilliseconds / _clock.duration!.inMilliseconds;
    final arrival = split == 0
        ? null
        : _clock.drive(CurveTween(curve: Interval(0, split)));
    final reduced = MediaQuery.disableAnimationsOf(context);
    final ordinal = '${_numeral(widget.round)}回目';
    final total = '全${_numeral(widget.total)}回';
    final cue = AnimatedBuilder(
      animation: _clock,
      builder: (context, banner) {
        if (_clock.value < split) return const SizedBox.shrink();
        final t = Interval(split, 1).transform(_clock.value);
        if (reduced) return banner!;
        final enter = const Interval(
          0,
          .17,
          curve: Curves.easeOutCubic,
        ).transform(t);
        final exit = const Interval(
          .80,
          1,
          curve: Curves.easeInCubic,
        ).transform(t);
        return ClipRect(
          child: FractionalTranslation(
            translation: Offset((enter - 1 + exit) * .65, 0),
            child: Opacity(opacity: enter * (1 - exit), child: banner),
          ),
        );
      },
      child: Semantics(
        key: const ValueKey('round-intro'),
        liveRegion: true,
        label: '$ordinal、$total',
        excludeSemantics: true,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: Color(0xF21C1616),
            border: Border.symmetric(
              horizontal: BorderSide(color: ember, width: 1.5),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: FittedBox(
              fit: BoxFit.contain,
              child: Text.rich(
                TextSpan(
                  text: ordinal,
                  children: [
                    TextSpan(
                      text: ' ／ $total',
                      style: const TextStyle(fontSize: 29, color: ember),
                    ),
                  ],
                ),
                style: const TextStyle(
                  fontFamily: appFont,
                  fontSize: 64,
                  height: 1.16,
                  fontWeight: FontWeight.w800,
                  color: chalk,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return widget.builder(arrival, cue);
  }
}
