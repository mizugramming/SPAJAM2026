import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/app_routes.dart';
import '../core/utils/date_key.dart';
import '../features/home/pages/home_page.dart';
import '../features/space/pages/space_page.dart';
import '../features/space/pages/star_placement_editor_page.dart';
import '../features/constellation/pages/constellation_book_page.dart';
import '../features/constellation/pages/constellation_page.dart';
import '../features/constellation/pages/constellation_reveal_page.dart';
import '../features/settings/pages/ai_comment_settings_page.dart';
import '../features/universe/pages/universe_page.dart';
import '../features/history/pages/history_page.dart';
import 'app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(path: '/', redirect: (_, _) => AppRoutes.home),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: AppRoutes.home, builder: (_, _) => const HomePage()),
          GoRoute(
            path: AppRoutes.constellation,
            builder: (_, state) => ConstellationPage(
              date: parseDateKey(state.uri.queryParameters['date']),
            ),
          ),
          GoRoute(
            path: AppRoutes.universe,
            builder: (_, _) => const UniversePage(),
          ),
          GoRoute(
            path: AppRoutes.history,
            builder: (_, _) => const HistoryPage(),
          ),
        ],
      ),
      GoRoute(path: AppRoutes.space, builder: (_, _) => const SpacePage()),
      GoRoute(
        path: AppRoutes.starPlacementEditor,
        builder: (_, _) => const StarPlacementEditorPage(),
      ),
      GoRoute(
        path: AppRoutes.constellationReveal,
        builder: (_, state) => ConstellationRevealPage(
          date:
              parseDateKey(state.uri.queryParameters['date']) ??
              localDay(DateTime.now()),
        ),
      ),
      GoRoute(
        path: AppRoutes.constellationBook,
        builder: (_, _) => const ConstellationBookPage(),
      ),
      GoRoute(
        path: AppRoutes.aiCommentSettings,
        builder: (_, _) => const AiCommentSettingsPage(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () => context.go(AppRoutes.home),
          child: const Text('ホームへ戻る'),
        ),
      ),
    ),
  );
  ref.onDispose(router.dispose);
  return router;
});
