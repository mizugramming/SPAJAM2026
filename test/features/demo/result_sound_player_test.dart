import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:spajam2026/features/demo/result_sound_player.dart';

class ControlledBackend implements ResultAudioBackend {
  final calls = <String>[];
  final startedPreparing = Completer<void>();
  final startedPlaying = Completer<void>();
  Completer<void>? loading;
  Completer<void>? starting;
  bool failPrepare = false;
  bool failResume = false;

  @override
  Future<void> prepare() async {
    calls.add('prepare');
    if (!startedPreparing.isCompleted) startedPreparing.complete();
    if (failPrepare) throw StateError('asset unavailable');
    await loading?.future;
  }

  @override
  Future<void> resume() async {
    calls.add('resume');
    if (!startedPlaying.isCompleted) startedPlaying.complete();
    if (failResume) throw StateError('autoplay denied');
    await starting?.future;
  }

  @override
  Future<void> stop() async => calls.add('stop');
  @override
  Future<void> dispose() async => calls.add('dispose');
}

void main() {
  test(
    'preload is reused and each voice restarts from the beginning',
    () async {
      final backend = ControlledBackend();
      final sound = AssetResultSoundPlayer(backend: backend);
      await sound.prepare();
      await sound.prepare();
      expect(backend.calls, ['prepare']);
      await sound.playShobone();
      await sound.playShobone();
      expect(backend.calls, ['prepare', 'stop', 'resume', 'stop', 'resume']);
      await sound.dispose();
    },
  );

  test('leaving while loading cancels delayed playback', () async {
    final backend = ControlledBackend()..loading = Completer<void>();
    final sound = AssetResultSoundPlayer(backend: backend);
    final play = sound.playShobone();
    await backend.startedPreparing.future;
    final stop = sound.stop();
    backend.loading!.complete();
    await Future.wait([play, stop]);
    expect(backend.calls, ['prepare', 'stop']);
    await sound.dispose();
  });

  test('dispose during preload releases once without delayed voice', () async {
    final backend = ControlledBackend()..loading = Completer<void>();
    final sound = AssetResultSoundPlayer(backend: backend);
    final preload = sound.prepare();
    final play = sound.playShobone();
    await backend.startedPreparing.future;
    final dispose = sound.dispose();
    backend.loading!.complete();
    await Future.wait([preload, play, dispose, sound.dispose()]);
    await sound.playShobone();
    await sound.prepare();
    await sound.stop();
    expect(backend.calls, ['prepare', 'dispose']);
  });

  test(
    'leaving during plugin start stops the voice when start completes',
    () async {
      final backend = ControlledBackend()..starting = Completer<void>();
      final sound = AssetResultSoundPlayer(backend: backend);
      final play = sound.playShobone();
      await backend.startedPlaying.future;
      final stop = sound.stop();
      backend.starting!.complete();
      await Future.wait([play, stop]);
      expect(backend.calls, ['prepare', 'stop', 'resume', 'stop', 'stop']);
      await sound.dispose();
    },
  );

  test('load failure is contained and a later encounter can retry', () async {
    final backend = ControlledBackend()..failPrepare = true;
    final sound = AssetResultSoundPlayer(backend: backend);
    await expectLater(sound.playShobone(), completes);
    backend.failPrepare = false;
    await sound.playShobone();
    expect(backend.calls, ['prepare', 'prepare', 'stop', 'resume']);
    await sound.dispose();
  });

  test(
    'autoplay failure does not poison stop or subsequent playback',
    () async {
      final backend = ControlledBackend()..failResume = true;
      final sound = AssetResultSoundPlayer(backend: backend);
      await expectLater(sound.playShobone(), completes);
      await sound.stop();
      backend.failResume = false;
      await sound.playShobone();
      expect(backend.calls.where((call) => call == 'resume').length, 2);
      await sound.dispose();
      expect(backend.calls.last, 'dispose');
    },
  );
}
