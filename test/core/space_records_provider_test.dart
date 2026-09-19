import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spajam2026/core/providers/space_records_provider.dart';
import '../helpers.dart';

void main() {
  test('save/delete updates shared state and can be reloaded', () async {
    final repository = MemoryRepository();
    final container = ProviderContainer(
      overrides: [
        spaceRepositoryProvider.overrideWith((ref) async => repository),
      ],
    );
    addTearDown(container.dispose);
    await container.read(spaceRecordsProvider.future);
    await Future.wait([
      container.read(spaceRecordsProvider.notifier).save(record(1)),
      container.read(spaceRecordsProvider.notifier).save(record(2)),
    ]);
    expect(container.read(spaceRecordsProvider).requireValue, hasLength(2));
    await container
        .read(spaceRecordsProvider.notifier)
        .deleteById(record(1).id);
    expect(
      container.read(spaceRecordsProvider).requireValue.single.id,
      record(2).id,
    );
    container.invalidate(spaceRecordsProvider);
    expect(await container.read(spaceRecordsProvider.future), hasLength(1));
  });
  test('failed mutations keep existing state and permit retry', () async {
    final repository = MemoryRepository([record(1)]);
    final container = ProviderContainer(
      overrides: [
        spaceRepositoryProvider.overrideWith((ref) async => repository),
      ],
    );
    addTearDown(container.dispose);
    await container.read(spaceRecordsProvider.future);
    repository.failSave = true;
    await expectLater(
      container.read(spaceRecordsProvider.notifier).save(record(2)),
      throwsStateError,
    );
    expect(container.read(spaceRecordsProvider).requireValue, hasLength(1));
    repository.failSave = false;
    await container.read(spaceRecordsProvider.notifier).save(record(2));
    repository.failDelete = true;
    await expectLater(
      container.read(spaceRecordsProvider.notifier).deleteById(record(2).id),
      throwsStateError,
    );
    expect(container.read(spaceRecordsProvider).requireValue, hasLength(2));
  });
}
