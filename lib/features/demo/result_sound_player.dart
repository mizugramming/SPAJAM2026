import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Presentation only: callers never use playback to settle game results.
abstract interface class ResultSoundPlayer {
  Future<void> prepare();
  Future<void> playShobone();
  Future<void> stop();
  Future<void> dispose();
}

class SilentResultSoundPlayer implements ResultSoundPlayer {
  const SilentResultSoundPlayer();

  @override
  Future<void> prepare() async {}
  @override
  Future<void> playShobone() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

/// Small transport boundary for checking delayed loads without native plugins.
abstract interface class ResultAudioBackend {
  Future<void> prepare();
  Future<void> resume();
  Future<void> stop();
  Future<void> dispose();
}

class AssetResultSoundPlayer implements ResultSoundPlayer {
  AssetResultSoundPlayer({ResultAudioBackend? backend})
    : _backend = backend ?? _AudioplayersBackend();

  final ResultAudioBackend _backend;
  Future<void> _operations = Future<void>.value();
  bool _prepared = false;
  bool _disposed = false;
  int _generation = 0;

  // Serialize plugin operations, but invalidate pending playback immediately.
  // A slow asset load must not start a voice after leaving the result screen.
  Future<void> _enqueue(Future<void> Function() action) {
    return _operations = _operations.then((_) async {
      try {
        await action();
      } catch (error) {
        _prepared = false;
        debugPrint('Result sound unavailable: $error');
      }
    });
  }

  Future<void> _prepare() async {
    if (_prepared) return;
    await _backend.prepare();
    _prepared = true;
  }

  bool _current(int generation) => !_disposed && generation == _generation;

  @override
  Future<void> prepare() => _enqueue(() async {
    if (!_disposed) await _prepare();
  });

  @override
  Future<void> playShobone() {
    final generation = ++_generation;
    return _enqueue(() async {
      if (!_current(generation)) return;
      await _prepare();
      if (!_current(generation)) return;
      await _backend.stop();
      if (!_current(generation)) return;
      await _backend.resume();
      if (!_current(generation)) await _backend.stop();
    });
  }

  @override
  Future<void> stop() {
    _generation++;
    return _enqueue(() async {
      if (!_disposed) await _backend.stop();
    });
  }

  @override
  Future<void> dispose() {
    if (_disposed) return _operations;
    _disposed = true;
    _generation++;
    return _enqueue(_backend.dispose);
  }
}

class _AudioplayersBackend implements ResultAudioBackend {
  AudioPlayer? _player;

  @override
  Future<void> prepare() async {
    final player = _player ??= AudioPlayer();
    // Retain the short clip after completion; never loop or keep the app awake.
    await player.setReleaseMode(ReleaseMode.stop);
    await player.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.game,
          audioFocus: AndroidAudioFocus.none,
        ),
        iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
      ),
    );
    await player.setSource(AssetSource('audio/shobone.m4a'));
  }

  @override
  Future<void> resume() async => _player?.resume();
  @override
  Future<void> stop() async => _player?.stop();
  @override
  Future<void> dispose() async => _player?.dispose();
}
