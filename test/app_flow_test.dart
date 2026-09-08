import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:spajam2026/features/conversation/widgets/sushi_capsule.dart';
import 'package:spajam2026/features/result/widgets/participant_profile_card.dart';
import 'package:spajam2026/main.dart';
import 'package:spajam2026/models/participant.dart';
import 'package:spajam2026/providers/conversation_provider.dart';
import 'package:spajam2026/providers/profile_provider.dart';
import 'package:spajam2026/providers/room_provider.dart';

void main() {
  testWidgets('PCプレビューではアプリ全体をスマホサイズに制限する', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const AppRoot());
    await tester.pump();

    expect(tester.getSize(find.byType(Scaffold)), const Size(390, 844));
    expect(tester.takeException(), isNull);
  });

  testWidgets('小型スマホでもRoom画面が崩れない', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const AppRoot());
    await tester.pump();

    expect(find.text('部屋を作る'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('結果カードのプロフィール部分は小型スマホでも横並びになる', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ParticipantProfileCard(
            participant: Participant(
              id: 'participant-1',
              name: '山田 太郎',
              category: ParticipantCategory.student,
              hobbies: ['ゲーム', '旅行', 'カフェ', '料理'],
              submittedTopic: '最近買ってよかったもの',
            ),
            selectedTopics: ['最近ハマっているもの', 'おすすめしたい作品'],
          ),
        ),
      ),
    );

    final initialCenter = tester.getCenter(find.text('山'));
    final nameCenter = tester.getCenter(find.text('山田 太郎'));
    final categoryCenter = tester.getCenter(find.text('学生'));

    expect(initialCenter.dx, lessThan(nameCenter.dx));
    expect(initialCenter.dx, lessThan(categoryCenter.dx));
    expect((initialCenter.dy - nameCenter.dy).abs(), lessThan(32));
    expect((initialCenter.dy - categoryCenter.dy).abs(), lessThan(32));
    expect(tester.takeException(), isNull);
  });

  testWidgets('スマホサイズでRoom作成からResult表示まで進める', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const AppRoot());
    await tester.pump();

    await tester.tap(find.text('部屋を作る'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '山田 太郎');
    await tester.tap(find.text('学生'));
    await tester.tap(find.text('ゲーム'));
    await tester.enterText(fields.at(1), '最近買ってよかったもの');
    await tester.tap(find.text('準備完了'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(find.text('部屋番号'), findsOneWidget);
    expect(tester.getSize(find.byType(AppBar)).width, 390);
    await tester.tap(find.byIcon(Icons.bolt));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();

    expect(find.byType(SushiCapsule), findsWidgets);
    final capsule = tester.widget<SushiCapsule>(
      find.byType(SushiCapsule).first,
    );
    final selectedTopic = capsule.topic.text;
    capsule.onTap();
    await tester.pump();

    await tester.tap(find.text('会輪を終了'));
    await tester.pump();
    await tester.tap(find.text('終了する'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('1 / 1人'), findsOneWidget);
    expect(find.text('山田 太郎'), findsOneWidget);
    expect(find.text(selectedTopic), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('タイトルへ戻る'));
    await tester.pumpAndSettle();

    expect(find.text('部屋を作る'), findsOneWidget);
    final titleContext = tester.element(find.text('部屋を作る'));
    expect(titleContext.read<RoomProvider>().room, isNull);
    expect(titleContext.read<ProfileProvider>().profile, isNull);
    expect(titleContext.read<ConversationProvider>().history, isEmpty);
  });
}
