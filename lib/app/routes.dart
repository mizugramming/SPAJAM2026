import 'package:flutter/material.dart';

import '../features/owner/pages/owner_create_room_page.dart';
import '../features/owner/pages/owner_participant_page.dart';
import '../features/owner/pages/owner_room_page.dart';
import 'home_page.dart';
import 'player_entry_placeholder_page.dart';
import 'player_shell.dart';

/// 画面のルート一覧。追加・変更は統合担当が行う。
abstract final class AppRoutes {
  static const home = '/';
  static const ownerCreateRoom = '/owner/create';

  /// arguments: String roomId
  static const ownerRoom = '/owner/room';

  /// arguments: OwnerParticipantArgs
  static const ownerParticipant = '/owner/participant';

  /// プレイヤー画面の入口。arguments: String?（再起動後に戻るルームID。新規参加なら null）
  /// 松本担当の PlayerFlowPage ができたら、仮表示と差し替える。
  static const playerEntry = '/player';

  static Route<void> onGenerateRoute(RouteSettings settings) {
    final Widget page = switch (settings.name) {
      ownerCreateRoom => const OwnerCreateRoomPage(),
      ownerRoom => OwnerRoomPage(roomId: settings.arguments! as String),
      ownerParticipant => OwnerParticipantPage(args: settings.arguments! as OwnerParticipantArgs),
      playerEntry => const PlayerShell(child: PlayerEntryPlaceholderPage()),
      _ => const HomePage(),
    };
    return MaterialPageRoute(builder: (_) => page, settings: settings);
  }
}
