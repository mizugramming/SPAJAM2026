import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/conversation_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/room_provider.dart';
import 'services/ai_topic_service.dart';
import 'services/mock_ai_topic_service.dart';
import 'services/mock_room_service.dart';
import 'services/room_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // TODO(Firebase): flutterfire configure 実行後、ここで await Firebase.initializeApp()
  // を呼び、下のRoomService/AiTopicServiceをFirestore/Cloud Functions実装に差し替える。
  runApp(const AppRoot());
}

/// DI(サービス差し替え)と状態管理をまとめて注入するルートウィジェット。
class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<RoomService>(create: (_) => MockRoomService()),
        Provider<AiTopicService>(create: (_) => MockAiTopicService()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProxyProvider<RoomService, RoomProvider>(
          create: (context) => RoomProvider(context.read<RoomService>()),
          update: (context, roomService, previous) =>
              previous ?? RoomProvider(roomService),
        ),
        ChangeNotifierProxyProvider<AiTopicService, ConversationProvider>(
          create: (context) =>
              ConversationProvider(context.read<AiTopicService>()),
          update: (context, aiTopicService, previous) =>
              previous ?? ConversationProvider(aiTopicService),
        ),
      ],
      child: const KaiwaApp(),
    );
  }
}
