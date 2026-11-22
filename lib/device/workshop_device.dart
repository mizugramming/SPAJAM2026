import 'package:flutter/services.dart';

import '../game/game.dart';

/// Android only sends measurements. The game decides how much a stroke removes.
class WorkshopDevice {
  WorkshopDevice({required this.simulated});

  final bool simulated;
  bool vibrationEnabled = true;
  static const _commands = MethodChannel('polish/device');
  static const _events = EventChannel('polish/strokes');
  static const strokeCompleted = 1;
  static const contactStarted = 2;
  static const contactEnded = -1;
  late final Stream<int> motionEvents = simulated
      ? const Stream.empty()
      : _events.receiveBroadcastStream().cast<int>();
  late final Stream<int> strokes = motionEvents.where(
    (event) => event == strokeCompleted,
  );

  Future<VoiceSample> capture(double demoPitch, {bool desk = false}) async {
    if (simulated) {
      await Future<void>.delayed(const Duration(milliseconds: 450));
      return VoiceSample(demoPitch);
    }
    final data = await _commands.invokeMapMethod<String, num?>(
      'capture',
      desk ? {'desk': true} : null,
    );
    return VoiceSample(data?['hz']?.toDouble());
  }

  Future<void> _command(String name, [Object? args]) async {
    if (!simulated) await _commands.invokeMethod<void>(name, args);
  }

  Future<void> startMotion({bool deskTrial = false}) =>
      _command('startMotion', deskTrial ? {'deskTrial': true} : null);
  Future<void> startPolishingMotion(
    Grit grit,
    double progress,
    Duration remaining, {
    required int sessionId,
  }) {
    final pulse = pulseFor(grit, progress);
    return _command('startMotion', {
      'grit': grit.name,
      'progress': progress,
      'durationMs': pulse.durationMs,
      'amplitude': pulse.amplitude,
      'vibrationEnabled': vibrationEnabled,
      'sessionId': sessionId,
      'remainingMs': (remaining.inMicroseconds + 999) ~/ 1000,
    });
  }

  Future<void> stopMotion() => _command('stopMotion');
  Future<void> cancelCapture() => _command('cancelCapture');
  Future<void> stopPulse() => _command('stopPulse');
  Future<bool?> hasAmplitudeControl() async {
    if (simulated) return null;
    try {
      return await _commands.invokeMethod<bool>('hasAmplitudeControl');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  Future<void> pulse(
    HapticPulse pulse, {
    bool followStroke = false,
    double? progress,
    int? sessionId,
  }) => _command('pulse', {
    'durationMs': pulse.durationMs,
    'amplitude': pulse.amplitude,
    if (followStroke) 'followStroke': true,
    'progress': ?progress,
    'sessionId': ?sessionId,
  });
}

String deviceMessage(Object error) {
  if (error is PlatformException) {
    return switch (error.code) {
      'permission' => 'マイクを許可して、\nもう一度声を出してください。\n許可画面が出ない場合は、\n端末のアプリ設定へ。',
      'microphone' => '採音できませんでした。\nマイクを確認して、\nもう一度声を出してください。',
      'sensor' => '動きを計測できませんでした。\n端末を静止させて、\nもう一度開始してください。',
      'vibrator' => 'この端末では\n振動を使えません。',
      'cancelled' => '採音を中断しました。\nもう一度\n声を出してください。',
      _ => error.message ?? '端末の入力を確認して、\nもう一度お試しください。',
    };
  }
  return '端末の機能を利用できません。\nAndroid実機で\n開き直してください。';
}
