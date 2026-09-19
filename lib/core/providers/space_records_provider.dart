import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/space_record.dart';
import '../repositories/local_space_repository.dart';
import '../repositories/space_repository.dart';
import '../utils/date_key.dart';

final spaceRepositoryProvider = FutureProvider<SpaceRepository>(
  (ref) async => LocalSpaceRepository(await SharedPreferences.getInstance()),
);
final spaceRecordsProvider =
    AsyncNotifierProvider<SpaceRecordsNotifier, List<SpaceRecord>>(
      SpaceRecordsNotifier.new,
    );

class SpaceRecordsNotifier extends AsyncNotifier<List<SpaceRecord>> {
  Future<void> _pending = Future<void>.value();
  @override
  Future<List<SpaceRecord>> build() async {
    final repository = await ref.watch(spaceRepositoryProvider.future);
    return List.unmodifiable(await repository.getAll());
  }

  Future<void> _mutate(Future<void> Function(SpaceRepository) operation) {
    final result = _pending.then((_) async {
      await future;
      final repository = await ref.read(spaceRepositoryProvider.future);
      await operation(repository);
      final records = await repository.getAll();
      if (ref.mounted) state = AsyncData(List.unmodifiable(records));
    });
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> save(SpaceRecord record) => _mutate((repo) => repo.save(record));
  Future<void> deleteById(String id) => _mutate((repo) => repo.deleteById(id));
}

// Refresh the local day at midnight and after returning to the app.
final todayProvider = NotifierProvider<TodayNotifier, DateTime>(
  TodayNotifier.new,
);

class TodayNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refresh(),
    );
    final listener = AppLifecycleListener(onResume: _refresh);
    ref.onDispose(timer.cancel);
    ref.onDispose(listener.dispose);
    return localDay(DateTime.now());
  }

  void _refresh() {
    final today = localDay(DateTime.now());
    if (state != today) state = today;
  }
}
