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
