import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mayoi_quest/app/home_page.dart';
import 'package:mayoi_quest/core/session/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> pumpHome(WidgetTester tester, {required Size size, double textScale = 1, bool resume = false}) async {
    SharedPreferences.setMockInitialValues(
      resume ? {'active_session.role': 'owner', 'active_session.room_id': 'room-1'} : {},
    );
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const HomePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('タイトルと参加者・運営の入口を表示する', (tester) async {
    await pumpHome(tester, size: const Size(390, 844));
    expect(find.text('まよい\nクエスト'), findsOneWidget);
    expect(find.text('参加者として参加する'), findsOneWidget);
    expect(find.text('運営としてルームを作る'), findsOneWidget);
    expect(find.text('続きから'), findsNothing);
  });

  testWidgets('小さい画面・文字2倍でもはみ出さず、スクロールで入口に届く', (tester) async {
    await pumpHome(tester, size: const Size(320, 568), textScale: 2, resume: true);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('運営としてルームを作る'), 200);
    expect(find.text('運営としてルームを作る').hitTestable(), findsOneWidget);
  });

  testWidgets('保存されたルームがあれば「続きから」を出す', (tester) async {
    await pumpHome(tester, size: const Size(390, 844), resume: true);
    expect(find.text('運営中のルームがあります'), findsOneWidget);
    expect(find.text('続きから'), findsOneWidget);

    await tester.tap(find.text('このルームの記録を消す'));
    await tester.pumpAndSettle();
    expect(find.text('続きから'), findsNothing);
    expect(await SessionStore().load(), isNull);
  });
}
