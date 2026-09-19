import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spajam2026/core/repositories/local_space_repository.dart';
import '../helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('persists JSON, restores on recreation and deletes records', () async {
    final preferences = await SharedPreferences.getInstance();
    final repository = LocalSpaceRepository(preferences);
    expect(await repository.getAll(), isEmpty);
    await repository.save(record(1, note: '  ひと休み  '));
    final restored = LocalSpaceRepository(
      await SharedPreferences.getInstance(),
    );
    expect((await restored.getAll()).single.note, 'ひと休み');
    expect(
      preferences.getString(LocalSpaceRepository.storageKey),
      contains('workStudy'),
    );
    await restored.deleteById(record(1).id);
    expect(await repository.getAll(), isEmpty);
  });
  test('serializes concurrent writes and makes retries idempotent', () async {
    final repository = LocalSpaceRepository(
      await SharedPreferences.getInstance(),
    );
    await Future.wait(
      List.generate(12, (index) => repository.save(record(index))),
    );
    await repository.save(record(1, note: 'retry'));
    final records = await repository.getAll();
    expect(records, hasLength(12));
    expect(records[1].note, 'retry');
    await Future.wait([
      repository.deleteById(record(0).id),
      repository.save(record(15)),
    ]);
    expect(await repository.getAll(), hasLength(12));
  });
  test(
    'corrupt data is preserved and blocks writes rather than losing history',
    () async {
      SharedPreferences.setMockInitialValues({
        LocalSpaceRepository.storageKey: '[broken private note',
      });
      final prefs = await SharedPreferences.getInstance();
      final repository = LocalSpaceRepository(prefs);
      await expectLater(repository.getAll(), throwsFormatException);
      await expectLater(repository.save(record(1)), throwsFormatException);
      await expectLater(
        repository.deleteById(record(1).id),
        throwsFormatException,
      );
      expect(
        prefs.getString(LocalSpaceRepository.storageKey),
        '[broken private note',
      );
    },
  );
}
