import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mock/in_memory_match_backend.dart';
import 'mock/sample_course.dart';
import 'models/models.dart';
import 'repository/match_repository.dart';

/// モックのサーバー。Supabase 接続後は matchRepositoryProvider の中身だけを差し替える。
final mockBackendProvider = Provider<InMemoryMatchBackend>(
  (ref) => InMemoryMatchBackend(courses: const [sampleCourse]),
);

/// true の間は開発用のモック参加者パネルを表示する。
final usesMockBackendProvider = Provider<bool>((ref) => true);

/// 残り時間などの表示を1秒ごとに更新するための時刻。
final tickerProvider = StreamProvider<DateTime>(
  (ref) => Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
);

/// 端末のユーザーID。Supabase では匿名ログインのIDになる。
final currentUserIdProvider = Provider<String>((ref) => 'device-user');

final matchRepositoryProvider = Provider<MatchRepository>(
  (ref) => ref.watch(mockBackendProvider).repositoryFor(ref.watch(currentUserIdProvider)),
);

final coursesProvider = FutureProvider<List<Course>>((ref) => ref.watch(matchRepositoryProvider).listCourses());

/// ルームの状態。画面はこれを watch して描画する。
final roomSnapshotProvider = StreamProvider.family<RoomSnapshot, String>(
  (ref, roomId) => ref.watch(matchRepositoryProvider).watchRoom(roomId),
);
