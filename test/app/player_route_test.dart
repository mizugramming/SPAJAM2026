import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mayoi_quest/app/app.dart';
import 'package:mayoi_quest/app/player_shell.dart';
import 'package:mayoi_quest/features/player/player_join_view.dart';
import 'package:mayoi_quest/features/player/player_night_style.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('参加者の入口は PlayerShell の中に PlayerFlowPage（参加画面）を開く', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ProviderScope(child: MayoiQuestApp()));

    await tester.tap(find.text('参加者として参加する'));
    await tester.pumpAndSettle();

    expect(find.byType(PlayerShell), findsOneWidget);
    // 中身は松本担当の PlayerFlowPage。最初は参加画面。
    expect(find.byType(PlayerJoinView), findsOneWidget);
    final scaffold = tester.widget<Scaffold>(
      find.descendant(of: find.byType(PlayerShell), matching: find.byType(Scaffold)),
    );
    expect(scaffold.backgroundColor, PlayerNight.background);
    // 見出しは各 View が持つので、AppBar にタイトルは出さない。
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.title, isNull);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('運営としてルームを作る'), findsOneWidget);
  });
}
