import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mayoi_quest/features/player/player_ui.dart';

void main() {
  testWidgets('short pages paint the entire available body', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PlayerPage(title: '開始待ち', children: [Text('開始の合図を待っています')]),
        ),
      ),
    );
    expect(tester.getSize(find.byType(PlayerPage)), const Size(320, 800));
    expect(tester.takeException(), isNull);
  });

  testWidgets('player styling preserves the app font and stays inside its body', (tester) async {
    final appTheme = ThemeData(brightness: Brightness.light, fontFamily: 'AppJapanese');
    ThemeData? outsideTheme;
    ThemeData? insideTheme;
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              outsideTheme = Theme.of(context);
              return PlayerPage(
                title: '参加',
                children: [
                  Builder(
                    builder: (context) {
                      insideTheme = Theme.of(context);
                      return const Text('日本語の案内');
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    expect(outsideTheme!.brightness, Brightness.light);
    expect(insideTheme!.brightness, Brightness.dark);
    expect(insideTheme!.textTheme.bodyMedium!.fontFamily, 'AppJapanese');
    expect(tester.takeException(), isNull);
  });

  testWidgets('primary action stays reachable beside a long scrolling body', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayerPage(
            title: '画面タイトル',
            actions: ElevatedButton(onPressed: () {}, child: const Text('続ける')),
            children: const [SizedBox(height: 1500, child: Text('長い本文'))],
          ),
        ),
      ),
    );
    expect(find.text('続ける').hitTestable(), findsOneWidget);
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -500));
    await tester.pump();
    expect(find.text('続ける').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('short viewport and enlarged text put actions in scroll content', (tester) async {
    tester.view.physicalSize = const Size(320, 260);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: PlayerPage(
              title: '文字を大きくした状態の長いタイトル',
              description: 'キーボードや文字拡大で狭いときも下まで移動できます。',
              actions: ElevatedButton(onPressed: () => calls++, child: const Text('続ける')),
              children: const [SizedBox(height: 300)],
            ),
          ),
        ),
      ),
    );
    expect(find.ancestor(of: find.text('続ける'), matching: find.byType(SingleChildScrollView)), findsOneWidget);
    await tester.ensureVisible(find.text('続ける'));
    await tester.tap(find.text('続ける'));
    await tester.pump();
    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('status text is announced once with a semantic heading', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlayerPage(
              title: '接続状況',
              children: [PlayerNotice(message: '接続を確認しています', busy: true)],
            ),
          ),
        ),
      );
      expect(find.semantics.byLabel('接続状況'), findsOneWidget);
      expect(find.semantics.byLabel('接続を確認しています'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
}
