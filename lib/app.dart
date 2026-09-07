import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/conversation/conversation_screen.dart';
import 'features/profile/profile_input_screen.dart';
import 'features/profile/waiting_room_screen.dart';
import 'features/result/result_screen.dart';
import 'features/room/room_screen.dart';

class KaiwaApp extends StatelessWidget {
  const KaiwaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '会輪',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      builder: (context, child) =>
          _SmartphoneViewport(child: child ?? const SizedBox.shrink()),
      initialRoute: RoomScreen.routeName,
      routes: {
        RoomScreen.routeName: (_) => const RoomScreen(),
        ProfileInputScreen.routeName: (_) => const ProfileInputScreen(),
        WaitingRoomScreen.routeName: (_) => const WaitingRoomScreen(),
        ConversationScreen.routeName: (_) => const ConversationScreen(),
        ResultScreen.routeName: (_) => const ResultScreen(),
      },
    );
  }
}

/// 実機スマホでは画面全体を使い、幅の広いWeb/デスクトップでは
/// スマホ相当の縦長キャンバスを中央に表示する。
class _SmartphoneViewport extends StatelessWidget {
  const _SmartphoneViewport({required this.child});

  final Widget child;

  static const _phoneWidth = 390.0;
  static const _phoneHeight = 844.0;
  static const _wideScreenBreakpoint = 600.0;

  @override
  Widget build(BuildContext context) {
    final phoneBackground = Theme.of(context).scaffoldBackgroundColor;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= _wideScreenBreakpoint) {
          return child;
        }

        return ColoredBox(
          color: const Color(0xFFE7DDD2),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: _phoneWidth,
                maxHeight: _phoneHeight,
              ),
              child: AspectRatio(
                aspectRatio: _phoneWidth / _phoneHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: phoneBackground,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 28,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: LayoutBuilder(
                      builder: (context, phoneConstraints) {
                        final mediaQuery = MediaQuery.of(context);
                        return MediaQuery(
                          data: mediaQuery.copyWith(
                            size: Size(
                              phoneConstraints.maxWidth,
                              phoneConstraints.maxHeight,
                            ),
                            padding: EdgeInsets.zero,
                            viewPadding: EdgeInsets.zero,
                            viewInsets: EdgeInsets.zero,
                          ),
                          child: child,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
