import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/providers.dart';
import '../core/supabase/supabase_match_repository.dart';
import 'app.dart';

/// 接続先。`--dart-define-from-file=config/supabase.json` で渡すと Supabase、なければモック。
abstract final class BackendConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static bool get usesSupabase => supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
}

Future<void> runMayoiQuest() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!BackendConfig.usesSupabase) {
    runApp(const ProviderScope(child: MayoiQuestApp()));
    return;
  }
  await Supabase.initialize(url: BackendConfig.supabaseUrl, publishableKey: BackendConfig.supabasePublishableKey);
  runApp(const _SupabaseGate());
}

/// 匿名ログインが済むまで待つ。オフラインで起動した場合は再試行できる。
class _SupabaseGate extends StatefulWidget {
  const _SupabaseGate();

  @override
  State<_SupabaseGate> createState() => _SupabaseGateState();
}

class _SupabaseGateState extends State<_SupabaseGate> {
  late Future<User> _user = _signIn();

  Future<User> _signIn() async {
    final auth = Supabase.instance.client.auth;
    // 端末に保存された匿名ユーザーがあれば同じIDで戻る（再起動後の復帰）。
    return auth.currentUser ?? (await auth.signInAnonymously()).user!;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<User>(
      future: _user,
      builder: (context, snap) {
        final user = snap.data;
        if (user != null) {
          return ProviderScope(
            overrides: [
              matchRepositoryProvider.overrideWithValue(SupabaseMatchRepository(Supabase.instance.client)),
              currentUserIdProvider.overrideWithValue(user.id),
              usesMockBackendProvider.overrideWithValue(false),
            ],
            child: const MayoiQuestApp(),
          );
        }
        return MaterialApp(
          home: Scaffold(
            body: SafeArea(
              child: Center(
                child: snap.hasError
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('サーバーに接続できませんでした'),
                          const SizedBox(height: 12),
                          OutlinedButton(onPressed: () => setState(() => _user = _signIn()), child: const Text('再接続')),
                        ],
                      )
                    : const CircularProgressIndicator(),
              ),
            ),
          ),
        );
      },
    );
  }
}
