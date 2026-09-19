import '../models/space_record.dart';

abstract interface class SpaceRepository {
  Future<List<SpaceRecord>> getAll();
  Future<void> save(SpaceRecord record);
  Future<void> deleteById(String id);
}
