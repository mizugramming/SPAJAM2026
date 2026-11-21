import 'dart:async';

import 'package:flutter/gestures.dart' show GestureBinding;
import 'package:flutter/material.dart';

import '../game/game.dart';
import 'workshop_device.dart';

enum _Trial {
  still('① 静止', false),
  motorOnly('② 振動のみ', true),
  hand('③ 手で往復', false),
  both('④ 往復＋振動', true);

  const _Trial(this.label, this.motor);
  final String label;
  final bool motor;
}

class DiagnosticsPage extends StatefulWidget {
  const DiagnosticsPage({super.key, required this.device});
  final WorkshopDevice device;
  @override
  State<DiagnosticsPage> createState() => _DiagnosticsPageState();
}

class _DiagnosticsPageState extends State<DiagnosticsPage>
    with WidgetsBindingObserver {
  VoiceMode _mode = VoiceMode.pitch;
  VoiceSample? _sample;
  Grit _grit = Grit.medium;
  _Trial _trial = _Trial.still;
  double _progress = 0.1;
  final _strokeTimes = <Duration>[];
  bool? _amplitudeControl;
  int _sent = 0;
  int _seconds = 10;
  int _trialId = 0;
  bool _running = false;
  bool _busy = false;
  String? _error;
  final _results = <String>[];
  late final StreamSubscription<int> _events;
  Timer? _pulses;
  Timer? _clock;
  final _elapsed = GestureBinding.instance.samplingClock.stopwatch();
  WorkshopDevice get device => widget.device;
  HapticPulse get pulse => pulseFor(_grit, _progress);
  bool get _locked => _busy || _running;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _readAmplitudeControl();
    _events = device.strokes.listen(
      (_) => _countStroke(),
      onError: (Object e) {
        if (mounted) _stop(message: deviceMessage(e));
      },
    );
  }

  Future<void> _readAmplitudeControl() async {
    final supported = await device.hasAmplitudeControl();
    if (mounted) setState(() => _amplitudeControl = supported);
  }

  void _countStroke() {
    final time = _elapsed.elapsed;
    if (_running && time < GameController.polishDuration) {
      setState(() => _strokeTimes.add(time));
    }
  }

  Future<void> _capture() async {
    if (_locked) return;
    final id = ++_trialId;
    setState(() {
      _busy = true;
      _error = null;
      _sample = null;
    });
    try {
      final sample = await device.capture(190);
      if (!mounted || id != _trialId) return;
      _sample = sample;
      final grit = classify(sample, _mode);
      if (grit != null) {
        _grit = grit;
      } else {
        _error = '判定できませんでした。声を取り直すか、音量判定を選んでください。';
      }
    } catch (e) {
      if (mounted && id == _trialId) _error = deviceMessage(e);
    } finally {
      if (mounted && id == _trialId) setState(() => _busy = false);
    }
  }

  Future<void> _sendPulse(int id) async {
    if (!_running ||
        id != _trialId ||
        _elapsed.elapsed >= GameController.polishDuration) {
      return;
    }
    try {
      await device.pulse(pulse);
      if (mounted && _running && id == _trialId) setState(() => _sent++);
    } catch (e) {
      if (mounted && id == _trialId) _stop(message: deviceMessage(e));
    }
  }

  Future<void> _start() async {
    if (_locked) return;
    final id = ++_trialId;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await device.startMotion(deskTrial: true);
      if (!mounted || id != _trialId) return;
      setState(() {
        _running = true;
        _busy = false;
        _strokeTimes.clear();
        _sent = 0;
        _seconds = 10;
      });
      _elapsed
        ..reset()
        ..start();
      _clock = Timer.periodic(const Duration(milliseconds: 100), (_) {
        final left = 10 - _elapsed.elapsed.inSeconds;
        if (left <= 0) {
          _stop(completed: true);
        } else if (_seconds != left) {
          setState(() => _seconds = left);
        }
      });
      if (_trial.motor) {
        _pulses = Timer.periodic(
          const Duration(milliseconds: 650),
          (_) => _sendPulse(id),
        );
        unawaited(_sendPulse(id));
      }
    } catch (e) {
      if (mounted && id == _trialId) _stop(message: deviceMessage(e));
    }
  }

  void _release() {
    _trialId++;
    _elapsed.stop();
    _pulses?.cancel();
    _clock?.cancel();
    unawaited(device.cancelCapture());
    unawaited(device.stopMotion());
    unawaited(device.stopPulse());
  }

  void _stop({bool completed = false, String? message}) {
    _release();
    setState(() {
      if (completed) {
        final times = _strokeTimes.map(
          (time) => (time.inMilliseconds / 1000).toStringAsFixed(3),
        );
        _results.insert(
          0,
          '${_trial.label}　${_strokeTimes.length}往復・振動指令$_sent回\n'
          '${_grit.label}／進捗${(_progress * 100).round()}%\n'
          '往復受付（秒）　${times.isEmpty ? '—' : times.join('、')}',
        );
        _seconds = 0;
      }
      _busy = false;
      _running = false;
      _error = message;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ((state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden) &&
        _locked) {
      _stop(message: '計測を中断しました。条件を確認して、もう一度開始してください。');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _release();
    _events.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sample = _sample;
    final measured = sample == null ? null : classify(sample, _mode);
    final titleStyle = Theme.of(context).textTheme.titleLarge;
    final strength = switch (_amplitudeControl) {
      true => '指定振幅 ${pulse.amplitude}/255',
      false => '端末の既定の強さ',
      null => '指定振幅 ${pulse.amplitude}/255（対応端末のみ）',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('端末の計測')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            if (device.simulated) const Text('疑似入力で表示中。実測はAndroid実機で開いてください。'),
            Text('声とやすり', style: titleStyle),
            Wrap(
              spacing: 6,
              children: [
                for (final mode in VoiceMode.values)
                  ChoiceChip(
                    label: Text(mode == VoiceMode.pitch ? '声の高さで判定' : '音量で判定'),
                    selected: _mode == mode,
                    onSelected: _locked
                        ? null
                        : (_) {
                            setState(() {
                              _mode = mode;
                              if (sample != null) {
                                _grit = classify(sample, mode) ?? _grit;
                              }
                            });
                          },
                  ),
              ],
            ),
            OutlinedButton(
              onPressed: _locked ? null : _capture,
              child: Text(_busy ? '計測中…' : '声を取る'),
            ),
            Text(
              '高さ ${sample?.hz == null ? '未判定' : '${sample!.hz!.toStringAsFixed(1)} Hz'}　音量 ${sample == null ? '—' : '${(sample.level * 100).round()}%'}　やすり ${measured?.label ?? '—'}',
            ),
            const Divider(height: 32),
            Text('動きと振動', style: titleStyle),
            const Text('端末を水平に持ち、手で動かす条件では10秒で10往復を目安にします。'),
            Wrap(
              spacing: 6,
              children: [
                for (final trial in _Trial.values)
                  ChoiceChip(
                    label: Text(trial.label),
                    selected: _trial == trial,
                    onSelected: _locked
                        ? null
                        : (_) => setState(() => _trial = trial),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('比較するやすりと仕上がり'),
            Wrap(
              spacing: 6,
              children: [
                for (final grit in Grit.values)
                  ChoiceChip(
                    label: Text(grit.label),
                    selected: _grit == grit,
                    onSelected: _locked
                        ? null
                        : (_) => setState(() => _grit = grit),
                  ),
              ],
            ),
            Wrap(
              spacing: 6,
              children: [
                for (final value in [0.1, 0.9])
                  ChoiceChip(
                    label: Text(value < 0.5 ? '前半 10%' : '後半 90%'),
                    selected: _progress == value,
                    onSelected: _locked
                        ? null
                        : (_) => setState(() => _progress = value),
                  ),
              ],
            ),
            Text(
              _trial.motor
                  ? '振動指令　${pulse.durationMs} ms・$strength（650 ms 間隔）'
                  : '振動指令　オフ',
            ),
            const SizedBox(height: 10),
            Text(
              '${_strokeTimes.length} 往復　／　${_running ? '残り $_seconds 秒' : '10秒計測'}',
              style: titleStyle,
            ),
            FilledButton(
              onPressed: _running
                  ? () => _stop(message: '計測を中断しました。')
                  : (_busy ? null : _start),
              child: Text(_running ? '計測を中断' : '計測を開始'),
            ),
            if (device.simulated && _running)
              OutlinedButton(
                onPressed: _countStroke,
                child: const Text('疑似入力で1往復'),
              ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (_results.isNotEmpty) ...[
              const Divider(height: 32),
              Text('今回の記録', style: titleStyle),
              for (final result in _results)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(result),
                ),
            ],
            const Divider(height: 32),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('ゲーム中の振動'),
              value: device.vibrationEnabled,
              onChanged: _locked
                  ? null
                  : (value) => setState(() => device.vibrationEnabled = value),
            ),
          ],
        ),
      ),
    );
  }
}
