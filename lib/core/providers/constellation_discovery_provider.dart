import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/constellation_name.dart';
import '../utils/date_key.dart';
import '../utils/record_queries.dart';
import 'constellation_creation_provider.dart';
import 'space_records_provider.dart';

/// Constellation name -> the first day it was created on. Empty while the
/// records or creation history are still loading.
final discoveredConstellationsProvider = Provider<Map<String, DateTime>>((ref) {
  final records = ref.watch(spaceRecordsProvider).value;
  final creation = ref.watch(constellationCreationProvider).value;
  if (records == null || creation == null) return const {};
  final discovered = <String, DateTime>{};
  for (final key in creation.createdDateKeys.toList()..sort()) {
    final day = parseDateKey(key);
    if (day == null) continue;
    final stars = recordsOnDay(records, day);
    if (stars.isEmpty) continue;
    final name = createConstellationResult(stars).name;
    if (name.isEmpty) continue;
    discovered.putIfAbsent(name, () => day);
  }
  return discovered;
});
