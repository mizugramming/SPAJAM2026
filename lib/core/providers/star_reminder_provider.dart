import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'space_records_provider.dart';

const starReminderInterval = Duration(hours: 1);

// Ticks periodically (and on app resume) so starReminderDueProvider is
// re-evaluated without needing a real OS notification.
final _starReminderTickProvider = NotifierProvider<_StarReminderTickNotifier, int>(
  _StarReminderTickNotifier.new,
);

class _StarReminderTickNotifier extends Notifier<int> {
  @override
  int build() {
    final timer = Timer.periodic(const Duration(minutes: 1), (_) => state++);
    final listener = AppLifecycleListener(onResume: () => state++);
    ref.onDispose(timer.cancel);
    ref.onDispose(listener.dispose);
    return 0;
  }
}

final starReminderDueProvider = Provider<bool>((ref) {
  ref.watch(_starReminderTickProvider);
  final records = ref.watch(spaceRecordsProvider).value;
  if (records == null || records.isEmpty) return false;
  final last = records
      .map((r) => r.createdAt)
      .reduce((a, b) => a.isAfter(b) ? a : b);
  return DateTime.now().difference(last) >= starReminderInterval;
});
