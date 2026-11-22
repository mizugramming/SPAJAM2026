import 'dart:async';
import 'dart:ui' show Color, lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show GestureBinding;

enum GamePhase { select, voice, ready, polishing, result }

enum Grit {
  coarse('粗目', 3.5, 78, 255),
  medium('中目', 2.25, 59, 231),
  fine('細目', 1.25, 46, 205);

  const Grit(
    this.label,
    this.removal,
    this.roughDurationMs,
    this.roughAmplitude,
  );

  final String label;
  final double removal;
  final int roughDurationMs;
  final int roughAmplitude;
}

/// Game thresholds around the typical speaking pitch of each selectable range.
enum VoiceProfile {
  low('声が低い人', 110, 135, [100, 120, 150]),
  high('声が高い人', 220, 270, [200, 240, 300]);

  const VoiceProfile(
    this.label,
    this.mediumFromHz,
    this.fineFromHz,
    this._demoHz,
  );

  final String label;
  final double mediumFromHz;
  final double fineFromHz;
  final List<double> _demoHz;

  double demoHz(Grit grit) => _demoHz[grit.index];

  Grit gritAt(double hz) {
    if (hz < mediumFromHz) return Grit.coarse;
    if (hz < fineFromHz) return Grit.medium;
    return Grit.fine;
  }
}

class VoiceSample {
  const VoiceSample(this.hz);

  /// Null when the recording did not yield a stable fundamental frequency.
  final double? hz;
}

const pitchRetryMessage = '声の高さを判定できませんでした。\n同じ高さでもう一度、\n声を出してください。';

Grit? classify(VoiceSample sample, {VoiceProfile profile = VoiceProfile.low}) {
  final hz = sample.hz;
  if (hz == null || !hz.isFinite || hz < 65 || hz > 600) return null;
  return profile.gritAt(hz);
}

class FinishStage {
  const FinishStage(
    this.threshold,
    this.name,
    this.color,
    this.rust,
    this.shine, {
    this.polishing = const {},
  });

  /// The first normalized removal progress at which this name applies.
  final double threshold;
  final String name;
  final Color color;
  final double rust;
  final double shine;

  /// Amount removed per stroke and the furthest finish each grit can produce.
  final Map<Grit, ({double amount, double limit})> polishing;
}

enum TargetFinish { under, onTarget, over }

class WorkMaterial {
  const WorkMaterial({
    required this.id,
    required this.name,
    required this.initialValue,
    required this.maxRemoval,
    required this.stages,
    this.description,
    this.glyph,
    this.targetValue,
    this.targetTolerance = 0,
    this.finishAtLeast,
    this.rounds = GameController.roundCount,
    this.afterEarlierRounds,
  }) : assert(maxRemoval > 0),
       assert(targetTolerance >= 0);

  final String id;
  final String name;
  final double initialValue;
  final double maxRemoval;

  /// Remaining material at the deepest successful finish. The tolerance is on
  /// the shallower side so polishing away more than the target always breaks it.
  final double? targetValue;
  final double targetTolerance;

  TargetFinish? finishAt(double value) {
    final target = targetValue;
    if (target == null) return null;
    // Fractional stroke counts can put an exact boundary a few ULPs away.
    final epsilon = maxRemoval * 1e-12;
    if (value < target - epsilon) return TargetFinish.over;
    if (value > target + targetTolerance + epsilon) return TargetFinish.under;
    return TargetFinish.onTarget;
  }

  final String? description;

  /// A stamped medallion by default, or a metal glyph such as 漢.
  final String? glyph;

  /// Ordered by increasing threshold, starting at zero.
  final List<FinishStage> stages;

  /// The progress every play reaches by the end of the last round, however
  /// little was polished. Null keeps the polished amount as it is.
  /// It is reached one second before the last round ends.
  final double? finishAtLeast;

  /// How many rounds a play of this material has.
  final int rounds;

  /// Where the progress is held at the end of each round before the last one,
  /// however much was polished. Null keeps the polished amount as it is.
  final ({double min, double max})? afterEarlierRounds;

  double progressAt(double value) =>
      ((initialValue - value) / maxRemoval).clamp(0.0, 1.0);

  FinishStage stageAt(double progress) => stages.lastWhere(
    (stage) => progress >= stage.threshold,
    orElse: () => stages.first,
  );

  /// On the last round, all grits can reach the medal's guaranteed finish.
  /// This minimum amount uses the same stroke-count scale as the grit rates.
  static const _finalRoundAmount = 2.5;

  double valueAfterStroke(double value, Grit grit, {bool finalRound = false}) {
    final progress = progressAt(value);
    final polish = stageAt(progress).polishing[grit];
    var share = polish?.limit ?? 1.0;
    var amount = polish?.amount ?? grit.removal;
    final floor = finishAtLeast;
    // Only the gold stages limit each grit, so only they are lifted.
    if (finalRound && polish != null && floor != null && progress < floor) {
      if (share < floor) share = floor;
      if (amount < _finalRoundAmount) amount = _finalRoundAmount;
    }
    final limit = initialValue - maxRemoval * share;
    if (value <= limit) return value;
    // Preserve the relative removal of each grit and each polishing stage.
    const coarseStep = _medalMaxRemoval * _goldThreshold / _strokesToGold;
    final step = coarseStep * amount / Grit.coarse.removal;
    final next = (value - step).clamp(limit, value);
    // Repeated fractional strokes can land a few ULPs short of a boundary.
    for (final stage in stages) {
      final boundary = initialValue - maxRemoval * stage.threshold;
      if ((next - boundary).abs() < maxRemoval * 1e-12) {
        return boundary.clamp(limit, value);
      }
    }
    return next;
  }

  // Use the same anchors for all appearance channels. Beyond the last anchor
  // the surface keeps its final material properties.
  (FinishStage, FinishStage, double) _blend(double progress) {
    final from = stageAt(progress);
    final to = stages.firstWhere(
      (stage) => stage.threshold > progress,
      orElse: () => from,
    );
    final span = to.threshold - from.threshold;
    final t = span > 0
        ? ((progress - from.threshold) / span).clamp(0.0, 1.0)
        : 0.0;
    return (from, to, t);
  }

  Color colorAt(double progress) {
    final (from, to, t) = _blend(progress);
    return Color.lerp(from.color, to.color, t)!;
  }

  double rustAt(double progress) {
    final (from, to, t) = _blend(progress);
    return lerpDouble(from.rust, to.rust, t)!;
  }

  double shineAt(double progress) {
    final (from, to, t) = _blend(progress);
    return lerpDouble(from.shine, to.shine, t)!;
  }
}

const _goldPolishing = {
  Grit.coarse: (amount: 0.25, limit: 0.70),
  Grit.medium: (amount: 1.5, limit: 0.85),
  Grit.fine: (amount: 3.5, limit: 1.0),
};

const _strokesToGold = 50;
const _medalMaxRemoval = 100.0;
const _goldThreshold = .50;
const _shinyGoldThreshold = .95;

const materials = [
  WorkMaterial(
    id: 'medal',
    name: 'メダル磨き',
    description: '銅・銀・金の輝き',
    initialValue: 100,
    maxRemoval: _medalMaxRemoval,
    // 発表用の二段階：1回目の終わりは必ず輝く前の金、2回目は残り1秒で必ず金ピカ。
    rounds: 2,
    afterEarlierRounds: (min: .50, max: .90),
    finishAtLeast: _shinyGoldThreshold,
    stages: [
      FinishStage(0, 'サビた銅メダル', Color(0xFF9B6447), 0.90, 0.05),
      FinishStage(0.12, '銅メダル', Color(0xFFC88356), 0.04, 0.28),
      FinishStage(0.30, '銀メダル', Color(0xFFBBC8CE), 0.01, 0.54),
      FinishStage(
        _goldThreshold,
        '金メダル',
        Color(0xFFD9A540),
        0,
        0.60,
        polishing: _goldPolishing,
      ),
      FinishStage(
        _shinyGoldThreshold,
        '金ピカのメダル',
        Color(0xFFFFD777),
        0,
        1,
        polishing: _goldPolishing,
      ),
    ],
  ),
  WorkMaterial(
    id: 'kanji',
    name: '漢磨き',
    description: '汚れに隠れた一字',
    glyph: '漢',
    initialValue: 100,
    targetValue: 10,
    targetTolerance: 10,
    maxRemoval: 100,
    stages: [
      FinishStage(0, '汚れに覆われた漢', Color(0xFF726454), 1, 0.02),
      FinishStage(0.38, '輪郭の現れた漢', Color(0xFFAA9780), 0.30, 0.22),
      FinishStage(0.80, '光沢を帯びた漢', Color(0xFFDBCDB0), 0, 0.95),
    ],
  ),
];

class HapticPulse {
  const HapticPulse(this.durationMs, this.amplitude);

  final int durationMs;
  final int amplitude;
}

/// Both channels soften as the surface clears. Duration remains meaningful
/// on Android devices without amplitude control.
HapticPulse pulseFor(Grit grit, double progress) {
  final t = progress.clamp(0.0, 1.0);
  return HapticPulse(
    (grit.roughDurationMs * (1.0 - 0.35 * t)).round(),
    (grit.roughAmplitude * (1.0 - 0.25 * t)).round(),
  );
}

typedef FinishJudge = String? Function(WorkMaterial material, double value);

class GameController extends ChangeNotifier {
  GameController({this.judge});

  /// The default number of rounds; each material may set its own.
  static const roundCount = 3;

  /// Rounds for the selected material.
  int get rounds => _material?.rounds ?? roundCount;
  static const polishDuration = Duration(seconds: 10);

  final FinishJudge? judge;

  GamePhase _phase = GamePhase.select;
  GamePhase get phase => _phase;

  VoiceProfile _voiceProfile = VoiceProfile.low;
  VoiceProfile get voiceProfile => _voiceProfile;

  void setVoiceProfile(VoiceProfile profile) {
    if (_phase != GamePhase.select || _voiceProfile == profile) return;
    _voiceProfile = profile;
    notifyListeners();
  }

  WorkMaterial? _material;
  WorkMaterial? get material => _material;
  int _round = 1;
  int get round => _round;
  int _remainingSeconds = polishDuration.inSeconds;
  int get remainingSeconds => _remainingSeconds;
  Duration get remainingPolishTime {
    if (_phase == GamePhase.result) return Duration.zero;
    final remaining = polishDuration - (_watch?.elapsed ?? Duration.zero);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  int _strokes = 0;
  int get strokes => _strokes;
  int _totalStrokes = 0;
  int get totalStrokes => _totalStrokes;
  double _value = 0;
  double get value => _value;
  double get progress => _material?.progressAt(_value) ?? 0;
  TargetFinish? get targetFinish => _material?.finishAt(_value);

  // The awarded result and the unfinished surface can differ. Keep the last
  // sensor-driven appearance until the player buffs the remaining metal.
  double? _handFinishProgress;

  double get surfaceProgress => _handFinishProgress ?? progress;
  bool get needsHandPolish => _handFinishProgress != null;

  /// Distance actually rubbed inside the medal, measured in medal diameters.
  void polishResult(double diameters) {
    final current = _handFinishProgress;
    if (_phase != GamePhase.result ||
        _paused ||
        current == null ||
        !diameters.isFinite ||
        diameters <= 0) {
      return;
    }
    const gainPerDiameter = .40;
    final next = current + diameters * gainPerDiameter;
    _handFinishProgress = next >= progress ? null : next;
    notifyListeners();
  }

  /// Available from material selection through the resulting finish.
  FinishStage get stage => _material!.stageAt(progress);
  bool get finishingWithFine =>
      _material != null &&
      stage != _material!.stages.last &&
      stage.polishing.containsKey(Grit.fine);
  Grit? _grit;
  Grit? get grit => _grit;

  /// The grit chosen in each round so far, in order.
  final _grits = <Grit>[];
  List<Grit> get grits => List.unmodifiable(_grits);
  VoiceSample? _sample;
  VoiceSample? get sample => _sample;
  String? _verdict;
  String? get verdict => _verdict;

  bool _paused = false;
  Timer? _timer;
  Stopwatch? _watch;

  void select(WorkMaterial material) {
    if (_phase != GamePhase.select && _phase != GamePhase.result) return;
    _clearSession();
    _material = material;
    _value = material.initialValue;
    _phase = GamePhase.voice;
    notifyListeners();
  }

  bool acceptVoice(VoiceSample sample) {
    if (_phase != GamePhase.voice || _paused) return false;
    final selected = classify(sample, profile: _voiceProfile);
    if (selected == null) return false;
    _sample = sample;
    _grit = selected;
    _grits.add(selected);
    _phase = GamePhase.ready;
    notifyListeners();
    return true;
  }

  void startPolishing() {
    if (_phase != GamePhase.ready || _paused) return;
    _phase = GamePhase.polishing;
    _watch = GestureBinding.instance.samplingClock.stopwatch()..start();
    _updateClock();
    notifyListeners();
  }

  HapticPulse? stroke() {
    if (_paused || _phase != GamePhase.polishing) return null;
    // Also guard the deadline here: a queued sensor event can arrive before
    // the timer callback has had a chance to dispatch.
    if (_watch!.elapsed >= polishDuration) {
      _endRound();
      return null;
    }
    final material = _material!;
    final grit = _grit!;
    _strokes++;
    _totalStrokes++;
    _value = material.valueAfterStroke(
      _value,
      grit,
      finalRound: _round == rounds,
    );
    if (material.id == 'kanji' && targetFinish == TargetFinish.over) {
      _finishGame();
      return null;
    }
    final pulse = pulseFor(grit, progress);
    notifyListeners();
    return pulse;
  }

  /// Only time with the game in the foreground counts toward the ten seconds.
  void setPaused(bool paused) {
    if (paused == _paused) return;
    _paused = paused;
    if (_phase != GamePhase.polishing) return;
    if (paused) {
      _timer?.cancel();
      _watch!.stop();
      if (_watch!.elapsed >= polishDuration) _endRound();
    } else {
      _watch!.start();
      _updateClock();
    }
  }

  void _updateClock() {
    final remaining = remainingPolishTime;
    if (remaining <= Duration.zero) {
      _endRound();
      return;
    }
    const microsPerSecond = Duration.microsecondsPerSecond;
    final seconds =
        (remaining.inMicroseconds + microsPerSecond - 1) ~/ microsPerSecond;
    final delay = remaining - Duration(seconds: seconds - 1);
    _timer = Timer(delay, _updateClock);
    if (seconds != _remainingSeconds) {
      _remainingSeconds = seconds;
      if (_round == rounds && seconds <= 1) _finishBeforeDeadline();
      notifyListeners();
    }
  }

  /// One second before the last round ends, a material with a guaranteed
  /// finish reaches it, so the result opens already finished.
  void _finishBeforeDeadline() {
    final material = _material!;
    final floor = material.finishAtLeast;
    if (floor == null || progress >= floor) return;
    _handFinishProgress = null;
    _value = material.initialValue - material.maxRemoval * floor;
  }

  void _endRound() {
    if (_round == rounds) {
      final material = _material!;
      final floor = material.finishAtLeast;
      if (floor != null && progress < floor) {
        if (material.id == 'medal') _handFinishProgress = progress;
        _value = material.initialValue - material.maxRemoval * floor;
      }
      _finishGame();
      return;
    }
    // Earlier rounds may hold the finish within a range (the medal's matte gold).
    final material = _material!;
    if (material.afterEarlierRounds case final hold?) {
      final held = progress.clamp(hold.min, hold.max);
      _value = material.initialValue - material.maxRemoval * held;
    }
    _stopClock();
    _round++;
    _remainingSeconds = polishDuration.inSeconds;
    _strokes = 0;
    _sample = null;
    _grit = null;
    _phase = GamePhase.voice;
    notifyListeners();
  }

  void _finishGame() {
    _stopClock();
    _remainingSeconds = 0;
    _phase = GamePhase.result;
    _verdict = judge?.call(_material!, _value);
    notifyListeners();
  }

  void _stopClock() {
    _timer?.cancel();
    _timer = null;
    _watch?.stop();
    _watch = null;
  }

  void _clearSession() {
    _handFinishProgress = null;
    _stopClock();
    _round = 1;
    _remainingSeconds = polishDuration.inSeconds;
    _strokes = 0;
    _totalStrokes = 0;
    _sample = null;
    _grit = null;
    _grits.clear();
    _verdict = null;
  }

  void reset() {
    _clearSession();
    _material = null;
    _value = 0;
    _phase = GamePhase.select;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopClock();
    super.dispose();
  }
}
