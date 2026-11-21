import 'dart:async';
import 'dart:ui' show Color, lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show GestureBinding;

enum GamePhase { select, voice, ready, polishing, result }

enum Grit {
  coarse('粗目', 3.5, 68, 245),
  medium('中目', 2.25, 47, 183),
  fine('細目', 1.25, 29, 124);

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

enum VoiceMode { pitch, volume }

/// Game thresholds around the typical speaking pitch of each selectable range.
enum VoiceProfile {
  male('男性用', 110, 135, [100, 120, 150]),
  female('女性用', 220, 270, [200, 240, 300]);

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
  const VoiceSample(this.hz, this.level);

  /// Null when the recording did not yield a stable fundamental frequency.
  final double? hz;

  /// Measured sound level, normalized from -60..0 dBFS to 0..1.
  final double level;
}

Grit? classify(
  VoiceSample sample,
  VoiceMode mode, {
  VoiceProfile profile = VoiceProfile.male,
}) {
  if (!sample.level.isFinite || sample.level < 0.15 || sample.level > 1) {
    return null;
  }
  if (mode == VoiceMode.volume) {
    if (sample.level < 0.45) return Grit.coarse;
    if (sample.level < 0.70) return Grit.medium;
    return Grit.fine;
  }
  final hz = sample.hz;
  if (hz == null || !hz.isFinite || hz <= 0) return null;
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
  }) : assert(maxRemoval > 0);

  final String id;
  final String name;
  final double initialValue;
  final double maxRemoval;
  final double? targetValue;
  final String? description;

  /// A stamped medallion by default, or a metal glyph such as 漢.
  final String? glyph;

  /// Ordered by increasing threshold, starting at zero.
  final List<FinishStage> stages;

  double progressAt(double value) =>
      ((initialValue - value) / maxRemoval).clamp(0.0, 1.0);

  FinishStage stageAt(double progress) => stages.lastWhere(
    (stage) => progress >= stage.threshold,
    orElse: () => stages.first,
  );

  double valueAfterStroke(
    double value,
    Grit grit, {
    int strokesToGold = GameController.defaultStrokesToGold,
  }) {
    assert(strokesToGold > 0);
    final polish = stageAt(progressAt(value)).polishing[grit];
    final limit = initialValue - maxRemoval * (polish?.limit ?? 1.0);
    if (value <= limit) return value;
    // Preserve the relative removal of each grit and each polishing stage.
    final coarseStep = _medalMaxRemoval * _goldThreshold / strokesToGold;
    final step =
        coarseStep * (polish?.amount ?? grit.removal) / Grit.coarse.removal;
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

const _medalMaxRemoval = 100.0;
const _goldThreshold = .50;

const materials = [
  WorkMaterial(
    id: 'medal',
    name: 'メダル磨き',
    description: '銅・銀・金の輝き',
    initialValue: 100,
    maxRemoval: _medalMaxRemoval,
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
        0.95,
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
    (grit.roughDurationMs * (1.0 - 0.50 * t)).round(),
    (grit.roughAmplitude * (1.0 - 0.60 * t)).round(),
  );
}

typedef FinishJudge = String? Function(WorkMaterial material, double value);

class GameController extends ChangeNotifier {
  GameController({this.judge});

  static const roundCount = 3;
  static const polishDuration = Duration(seconds: 10);
  static const minStrokesToGold = 5;
  static const maxStrokesToGold = 60;
  static const defaultStrokesToGold = 22;

  final FinishJudge? judge;

  GamePhase _phase = GamePhase.select;
  GamePhase get phase => _phase;
  int _strokesToGold = defaultStrokesToGold;
  int get strokesToGold => _strokesToGold;

  void setStrokesToGold(int count) {
    if (_phase != GamePhase.select ||
        count == _strokesToGold ||
        count < minStrokesToGold ||
        count > maxStrokesToGold) {
      return;
    }
    _strokesToGold = count;
    notifyListeners();
  }

  VoiceProfile _voiceProfile = VoiceProfile.male;
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

  /// Available from material selection through the resulting finish.
  FinishStage get stage => _material!.stageAt(progress);
  bool get finishingWithFine =>
      _material != null &&
      stage != _material!.stages.last &&
      stage.polishing.containsKey(Grit.fine);
  Grit? _grit;
  Grit? get grit => _grit;
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

  bool acceptVoice(VoiceSample sample, VoiceMode mode) {
    if (_phase != GamePhase.voice || _paused) return false;
    final selected = classify(sample, mode, profile: _voiceProfile);
    if (selected == null) return false;
    _sample = sample;
    _grit = selected;
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
      strokesToGold: strokesToGold,
    );
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
      notifyListeners();
    }
  }

  void _endRound() {
    _stopClock();
    if (_round == roundCount) {
      _remainingSeconds = 0;
      _phase = GamePhase.result;
      _verdict = judge?.call(_material!, _value);
    } else {
      _round++;
      _remainingSeconds = polishDuration.inSeconds;
      _strokes = 0;
      _sample = null;
      _grit = null;
      _phase = GamePhase.voice;
    }
    notifyListeners();
  }

  void _stopClock() {
    _timer?.cancel();
    _timer = null;
    _watch?.stop();
    _watch = null;
  }

  void _clearSession() {
    _stopClock();
    _round = 1;
    _remainingSeconds = polishDuration.inSeconds;
    _strokes = 0;
    _totalStrokes = 0;
    _sample = null;
    _grit = null;
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
