import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mayoi_quest/app/app.dart';
import 'package:mayoi_quest/core/mock/in_memory_match_backend.dart';
import 'package:mayoi_quest/core/mock/sample_course.dart';
import 'package:mayoi_quest/core/providers.dart';

void main() {
  testWidgets('運営がルームを作り、参加者を待って一斉開始し、進行と写真を確認できる', (tester) async {
    final backend = InMemoryMatchBackend(courses: const [sampleCourse]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mockBackendProvider.overrideWithValue(backend),
          currentUserIdProvider.overrideWithValue('owner'),
          usesMockBackendProvider.overrideWithValue(false),
          tickerProvider.overrideWith((ref) => const Stream.empty()),
        ],
        child: const MayoiQuestApp(),
      ),
    );

    await tester.tap(find.text('運営としてルームを作る'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('サンプルコース（仮）'));
    await tester.pumpAndSettle();

    expect(find.text('参加者を待っています'), findsOneWidget);
    final start = find.widgetWithText(FilledButton, '全員一斉に開始');
    expect(tester.widget<FilledButton>(start).onPressed, isNull);

    // 別端末の参加者がモックサーバー経由で参加する。
    final room = (await backend
        .repositoryFor('owner')
        .findRoomByCode(tester.widget<SelectableText>(find.byType(SelectableText)).data!));
    final alice = backend.repositoryFor('alice');
    await tester.runAsync(() async {
      await alice.joinRoom(roomId: room.id, displayName: 'アリス');
      await alice.scanStart(roomId: room.id, qr: sampleCourse.startQr);
    });
    await tester.pumpAndSettle();
    expect(find.text('アリス'), findsOneWidget);
    expect(find.text('スタートQR読取済み'), findsOneWidget);

    await tester.tap(start);
    await tester.pumpAndSettle();
    expect(find.text('残り時間'), findsOneWidget);

    final cp = sampleCourse.checkpoints.first;
    await tester.runAsync(
      () => alice.submitPhoto(roomId: room.id, checkpointId: cp.id, photo: Uint8List.fromList([0])),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('${cp.points}点'), findsOneWidget);

    await tester.tap(find.text('アリス'));
    await tester.pumpAndSettle();
    expect(find.text('撮影写真とAI判定（新しい順）'), findsOneWidget);
    expect(find.text('合格'), findsOneWidget);
    expect(find.textContaining('モック判定'), findsOneWidget);
  });
}
