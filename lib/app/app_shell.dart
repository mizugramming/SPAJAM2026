import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/app_routes.dart';
import '../core/constants/design_tokens.dart';
import '../core/widgets/space_background.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;
  static const paths = [
    AppRoutes.home,
    AppRoutes.constellation,
    AppRoutes.universe,
    AppRoutes.history,
  ];
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SpaceBackground(
      scenic: location == AppRoutes.home,
      child: SafeArea(bottom: false, child: child),
    ),
    floatingActionButton: location == AppRoutes.home
        ? null
        : FloatingActionButton.extended(
            heroTag: 'space',
            tooltip: 'SPACEをはじめる',
            backgroundColor: DesignTokens.accent,
            onPressed: () => context.push(AppRoutes.space),
            icon: const Icon(Icons.add, color: DesignTokens.background),
            label: const Text(
              'SPACE',
              style: TextStyle(color: DesignTokens.background),
            ),
          ),
    bottomNavigationBar: Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: DesignTokens.border, width: .5)),
      ),
      child: NavigationBar(
        selectedIndex: paths.indexOf(location).clamp(0, 3),
        onDestinationSelected: (index) => context.go(paths[index]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'ホーム',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: '今日',
          ),
          NavigationDestination(
            icon: Icon(Icons.public_outlined),
            selectedIcon: Icon(Icons.public),
            label: '宇宙',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: '振り返り',
          ),
        ],
      ),
    ),
  );
}
