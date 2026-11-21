import 'package:flutter/services.dart';

import '../game/game.dart';

/// Android only sends measurements. The game decides how much a stroke removes.
class WorkshopDevice {
  WorkshopDevice({required this.simulated});

  final bool simulated;
  bool vibrationEnabled = true;
  static const _commands = MethodChannel('polish/device');
  static const _events = EventChannel('polish/strokes');
  late final Stream<int> strokes = simulated
      ? const Stream.empty()
      : _events.receiveBroadcastStream().cast<int>();

  Future<VoiceSample> capture(double demoPitch) async {
    if (simulated) {
      await Future<void>.delayed(const Duration(milliseconds: 450));
      return VoiceSample(
        demoPitch,
        demoPitch < 150 ? 0.30 : (demoPitch < 230 ? 0.55 : 0.80),
      );
    }
    final data = await _commands.invokeMapMethod<String, num?>('capture');
    return VoiceSample(
      data?['hz']?.toDouble(),
      data?['level']?.toDouble() ?? 0,
    );
  }

  Future<void> _command(String name, [Object? args]) async {
    if (!simulated) await _commands.invokeMethod<void>(name, args);
  }

  Future<void> startMotion() => _command('startMotion');
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

  Future<void> pulse(HapticPulse pulse, {bool followStroke = false}) =>
      _command('pulse', {
        'durationMs': pulse.durationMs,
        'amplitude': pulse.amplitude,
        if (followStroke) 'followStroke': true,
      });
}

String deviceMessage(Object error) {
  if (error is PlatformException) {
    return switch (error.code) {
      'permission' => 'マイクを許可して、もう一度声を出してください。許可画面が開かない場合は端末のアプリ設定を確認してください。',
      'microphone' => '採音できませんでした。マイクを確認して、もう一度声を出してください。',
      'sensor' => '動きを計測できませんでした。端末を静止させて、もう一度開始してください。',
      'vibrator' => 'この端末では振動を使えません。',
      'cancelled' => '採音を中断しました。もう一度声を出してください。',
      _ => error.message ?? '端末の入力を確認して、もう一度お試しください。',
    };
  }
  return '端末の機能を利用できません。Android実機で開き直してください。';
}
