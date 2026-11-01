import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mayoi_quest/core/models/course.dart';
import 'package:mayoi_quest/features/player/player_course_map.dart';
import 'package:mayoi_quest/features/player/player_map_view.dart';

Checkpoint _checkpoint(String id, {String floor = '1F', bool required = true, int points = 10}) => Checkpoint(
  id: id,
  name: '地点$id',
  floor: floor,
  qr: 'QR-$id',
  mission: '案内板を撮影する',
  points: points,
  required: required,
);

Widget _host(Widget child, {double textScale = 1}) => MaterialApp(
  home: Scaffold(
    body: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child,
      ),
    ),
  ),
);

void main() {
  testWidgets('floor list displays shared points and clear status without inventing map positions', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final checkpoints = [
        _checkpoint('A'),
        _checkpoint('B', required: false, points: 5),
        _checkpoint('C', floor: '2F'),
      ];
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 320,
            height: 480,
            child: PlayerCourseMap(floor: '1F', checkpoints: checkpoints, clearedCheckpointIds: const {'B'}),
          ),
        ),
      );
      expect(find.text('仮コース・地点一覧'), findsOneWidget);
      expect(find.textContaining('実際の館内図は未登録'), findsOneWidget);
      expect(find.text('地点C'), findsNothing);
      expect(find.semantics.byLabel('地点A、指定チェックポイント、10点、未達成'), findsOne);
      expect(find.semantics.byLabel('地点B、自由ミッション、5点、達成済み'), findsOne);

      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 320,
            height: 480,
            child: PlayerCourseMap(floor: '1F', checkpoints: checkpoints, clearedCheckpointIds: const {'A'}),
          ),
        ),
      );
      expect(find.semantics.byLabel('地点A、指定チェックポイント、10点、達成済み'), findsOne);
      expect(find.semantics.byLabel('地点B、自由ミッション、5点、未達成'), findsOne);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('empty floor has an explicit empty state', (tester) async {
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 320,
          height: 240,
          child: PlayerCourseMap(floor: '2F', checkpoints: [_checkpoint('A')], clearedCheckpointIds: const {}),
        ),
      ),
    );
    expect(find.text('このフロアの地点はありません。'), findsOneWidget);
    expect(find.text('地点A'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('many checkpoints remain reachable at enlarged text inside map viewport', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var scans = 0;
    final map = PlayerCourseMap(
      floor: '1F',
      checkpoints: [for (var i = 0; i < 30; i++) _checkpoint('$iの名前が長いチェックポイント')],
      clearedCheckpointIds: const {},
    );
    await tester.pumpWidget(
      _host(
        PlayerMapView(
          courseName: '仮コース',
          remainingTimeLabel: '20:00',
          progressLabel: '0 / 30',
          floors: {
            '1F': InteractiveViewer(panEnabled: false, scaleEnabled: false, minScale: 1, maxScale: 1, child: map),
          },
          canScanGoal: false,
          onScanCheckpoint: () => scans++,
        ),
        textScale: 2,
      ),
    );
    final list = find.descendant(of: find.byType(PlayerCourseMap), matching: find.byType(Scrollable));
    final viewport = find.byType(InteractiveViewer);
    await tester.ensureVisible(viewport);
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byKey(const ValueKey('playerMapZoomIn')), findsNothing);
    await tester.scrollUntilVisible(find.text('地点29の名前が長いチェックポイント'), 120, scrollable: list, maxScrolls: 150);
    expect(find.text('地点29の名前が長いチェックポイント').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('チェックポイントQRを読み取る'));
    await tester.tap(find.text('チェックポイントQRを読み取る'));
    await tester.pumpAndSettle();
    expect(scans, 1);
    expect(tester.takeException(), isNull);
  });
}
