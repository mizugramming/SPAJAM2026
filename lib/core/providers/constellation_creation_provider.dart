import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/date_key.dart';
import '../utils/record_queries.dart';
import 'space_records_provider.dart';

const _kCreatedDates = 'constellation_created_dates';
const _kPendingReveal = 'constellation_pending_reveal';

class ConstellationCreationState {
  const ConstellationCreationState({
    required this.createdDateKeys,
    this.pendingReveal,
  });
  final Set<String> createdDateKeys;
  final String? pendingReveal;

  bool isCreated(DateTime day) => createdDateKeys.contains(dateKey(day));

  ConstellationCreationState copyWith({
    Set<String>? createdDateKeys,
    String? pendingReveal,
    bool clearPendingReveal = false,
  }) => ConstellationCreationState(
    createdDateKeys: createdDateKeys ?? this.createdDateKeys,
    pendingReveal: clearPendingReveal
        ? null
        : (pendingReveal ?? this.pendingReveal),
  );
}

final constellationCreationProvider =
    AsyncNotifierProvider<
      ConstellationCreationNotifier,
      ConstellationCreationState
    >(ConstellationCreationNotifier.new);

class ConstellationCreationNotifier
    extends AsyncNotifier<ConstellationCreationState> {
  @override
  Future<ConstellationCreationState> build() async {
    final prefs = await SharedPreferences.getInstance();
    var createdDateKeys = (prefs.getStringList(_kCreatedDates) ?? const [])
        .toSet();
    var pendingReveal = prefs.getString(_kPendingReveal);

    // A day passed without an explicit creation: auto-create it now and
    // queue it to be introduced the next time the app is opened.
    final yesterday = localDay(
      DateTime.now(),
    ).subtract(const Duration(days: 1));
    final yesterdayKey = dateKey(yesterday);
    if (!createdDateKeys.contains(yesterdayKey)) {
      final records = await ref.watch(spaceRecordsProvider.future);
      if (recordsOnDay(records, yesterday).isNotEmpty) {
        createdDateKeys = {...createdDateKeys, yesterdayKey};
        pendingReveal = yesterdayKey;
        await prefs.setStringList(_kCreatedDates, createdDateKeys.toList());
        await prefs.setString(_kPendingReveal, pendingReveal);
      }
    }
    return ConstellationCreationState(
      createdDateKeys: createdDateKeys,
      pendingReveal: pendingReveal,
    );
  }

  Future<bool> createToday() async {
    final current = await future;
    final todayKey = dateKey(DateTime.now());
    if (current.createdDateKeys.contains(todayKey)) return false;
    final prefs = await SharedPreferences.getInstance();
    final updated = {...current.createdDateKeys, todayKey};
    await prefs.setStringList(_kCreatedDates, updated.toList());
    state = AsyncData(current.copyWith(createdDateKeys: updated));
    return true;
  }

  Future<void> clearPendingReveal() async {
    final current = await future;
    if (current.pendingReveal == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPendingReveal);
    state = AsyncData(current.copyWith(clearPendingReveal: true));
  }
}
