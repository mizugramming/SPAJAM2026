import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SessionRole { owner, player }

/// 再起動後に戻るための、参加中・運営中のルーム。対戦データ自体はサーバーが正本。
class ActiveSession {
  const ActiveSession({required this.role, required this.roomId});

  final SessionRole role;
  final String roomId;
}

class SessionStore {
  static const _roleKey = 'active_session.role';
  static const _roomKey = 'active_session.room_id';

  Future<ActiveSession?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final role = SessionRole.values.asNameMap()[prefs.getString(_roleKey)];
    final roomId = prefs.getString(_roomKey);
    if (role == null || roomId == null) return null;
    return ActiveSession(role: role, roomId: roomId);
  }

  Future<void> save(ActiveSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, session.role.name);
    await prefs.setString(_roomKey, session.roomId);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_roleKey);
    await prefs.remove(_roomKey);
  }
}

final sessionStoreProvider = Provider<SessionStore>((ref) => SessionStore());

/// 保存中のセッション。保存・削除したら invalidate して読み直す。
final activeSessionProvider = FutureProvider<ActiveSession?>((ref) => ref.watch(sessionStoreProvider).load());
