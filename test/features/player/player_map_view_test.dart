import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mayoi_quest/features/player/player_map_view.dart';

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

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

TransformationController _transform(WidgetTester tester, String floor) =>
    tester.widget<InteractiveViewer>(find.byKey(ValueKey('playerMapViewer:$floor'))).transformationController!;

void main() {
  testWidgets('each floor keeps its viewport across shared progress updates', (tester) async {
    final selected = <String>[];
    Widget map({bool includeFirst = true, String progress = '1 / 3'}) => _host(
      PlayerMapView(
        courseName: '固定コース',
        remainingTimeLabel: '09:00',
        progressLabel: progress,
        floors: {
          if (includeFirst) '1F': const Center(child: Text('1F案内図')),
          '2F': const Center(child: Text('2F案内図')),
        },
        canScanGoal: false,
        onFloorChanged: selected.add,
      ),
    );
    await tester.pumpWidget(map());
    await _tap(tester, find.byKey(const ValueKey('playerMapZoomIn')));
    final firstScale = _transform(tester, '1F').value.getMaxScaleOnAxis();
    expect(firstScale, greaterThan(1));
    await _tap(tester, find.text('2F'));
    expect(_transform(tester, '2F').value.getMaxScaleOnAxis(), 1);
    await _tap(tester, find.byKey(const ValueKey('playerMapZoomIn')));
    final secondScale = _transform(tester, '2F').value.getMaxScaleOnAxis();
    await _tap(tester, find.text('1F'));
    expect(_transform(tester, '1F').value.getMaxScaleOnAxis(), firstScale);
    await tester.pumpWidget(map(progress: '2 / 3'));
    expect(_transform(tester, '1F').value.getMaxScaleOnAxis(), firstScale);

    // A removed floor falls back without pretending the player selected it.
    await tester.pumpWidget(map(includeFirst: false));
    expect(find.text('2F案内図'), findsOneWidget);
    expect(_transform(tester, '2F').value.getMaxScaleOnAxis(), secondScale);
    expect(selected, ['2F', '1F']);
    await tester.pumpWidget(map());
    await _tap(tester, find.text('1F'));
    expect(_transform(tester, '1F').value.getMaxScaleOnAxis(), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('zoom is bounded and full view resets scale and pan', (tester) async {
    await tester.pumpWidget(
      _host(
        const PlayerMapView(
          courseName: '固定コース',
          remainingTimeLabel: '09:00',
          progressLabel: '探索中',
          floors: {'1F': Center(child: Text('案内図'))},
          canScanGoal: false,
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await _tap(tester, find.byKey(const ValueKey('playerMapZoomIn')));
    }
    final controller = _transform(tester, '1F');
    expect(controller.value.getMaxScaleOnAxis(), 4);
    expect(tester.widget<OutlinedButton>(find.byKey(const ValueKey('playerMapZoomIn'))).onPressed, isNull);
    await tester.ensureVisible(find.byKey(const ValueKey('playerMapViewer:1F')));
    await tester.drag(find.byKey(const ValueKey('playerMapViewer:1F')), const Offset(-40, -20));
    await tester.pumpAndSettle();
    expect(controller.value.entry(0, 3), lessThan(0));
    await _tap(tester, find.byKey(const ValueKey('playerMapReset')));
    expect(controller.value, Matrix4.identity());
    expect(tester.widget<OutlinedButton>(find.byKey(const ValueKey('playerMapZoomOut'))).onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('goal availability comes only from the caller, even without map', (tester) async {
    var checkpoints = 0;
    var goals = 0;
    Widget map(bool allowed) => _host(
      PlayerMapView(
        courseName: '固定コース',
        remainingTimeLabel: '00:00',
        progressLabel: 'すべて達成',
        floors: const {},
        canScanGoal: allowed,
        goalStatusLabel: allowed ? 'ゴールできます' : '共通側の受付待ちです',
        onScanCheckpoint: () => checkpoints++,
        onScanGoal: () => goals++,
      ),
    );
    await tester.pumpWidget(map(false));
    expect(find.byType(InteractiveViewer), findsNothing);
    expect(find.textContaining('表示できるマップがありません'), findsOneWidget);
    expect(find.text('自由ミッション'), findsNothing);
    expect(find.text('ランキング'), findsNothing);
    await _tap(tester, find.text('チェックポイントQRを読み取る'));
    await _tap(tester, find.text('ゴールQRを読み取る'));
    expect([checkpoints, goals], [1, 0]);
    await tester.pumpWidget(map(true));
    await _tap(tester, find.text('ゴールQRを読み取る'));
    expect(goals, 1);
  });

  testWidgets('a directly supplied viewer retains sole gesture ownership', (tester) async {
    final injectedController = TransformationController();
    addTearDown(injectedController.dispose);
    await tester.pumpWidget(
      _host(
        PlayerMapView(
          courseName: '固定コース',
          remainingTimeLabel: '09:00',
          progressLabel: '探索中',
          floors: {
            '1F': InteractiveViewer(
              transformationController: injectedController,
              child: const Center(child: Text('親が操作を提供する案内図')),
            ),
          },
          canScanGoal: false,
        ),
      ),
    );
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(
      tester.widget<InteractiveViewer>(find.byType(InteractiveViewer)).transformationController,
      same(injectedController),
    );
    expect(find.byKey(const ValueKey('playerMapZoomIn')), findsNothing);
    expect(find.byKey(const ValueKey('playerMapReset')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uncontrolled supplied viewers do not share zoom across floors', (tester) async {
    await tester.pumpWidget(
      _host(
        PlayerMapView(
          courseName: '固定コース',
          remainingTimeLabel: '09:00',
          progressLabel: '探索中',
          floors: {
            for (final floor in ['1F', '2F'])
              floor: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: SizedBox(
                    key: ValueKey('mapMarker:$floor'),
                    width: 40,
                    height: 40,
                    child: const ColoredBox(color: Colors.blue),
                  ),
                ),
              ),
          },
          canScanGoal: false,
        ),
      ),
    );
    double sceneScale(String floor) => tester
        .renderObject<RenderBox>(find.byKey(ValueKey('mapMarker:$floor')))
        .getTransformTo(null)
        .getMaxScaleOnAxis();
    final viewer = find.byType(InteractiveViewer);
    await tester.ensureVisible(viewer);
    final center = tester.getCenter(viewer);
    final left = await tester.startGesture(center - const Offset(20, 0), pointer: 1);
    final right = await tester.startGesture(center + const Offset(20, 0), pointer: 2);
    await tester.pump();
    await left.moveTo(center - const Offset(60, 0));
    await right.moveTo(center + const Offset(60, 0));
    await tester.pump();
    await left.up();
    await right.up();
    await tester.pumpAndSettle();
    expect(sceneScale('1F'), greaterThan(1));

    await _tap(tester, find.text('2F'));
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(sceneScale('2F'), closeTo(1, 0.001));
    expect(tester.takeException(), isNull);
  });

  testWidgets('many floors and enlarged text keep map and actions reachable', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    try {
      var checkpoints = 0;
      var rankings = 0;
      var freeMissions = 0;
      await tester.pumpWidget(
        _host(
          PlayerMapView(
            courseName: 'とても長い固定コースの名称を表示します',
            remainingTimeLabel: '残り10分30秒',
            progressLabel: '指定されたチェックポイントを探して撮影してください',
            floors: {for (var i = 1; i <= 16; i++) '$i階': Center(child: Text('$i階の案内図'))},
            canScanGoal: false,
            onScanCheckpoint: () => checkpoints++,
            onOpenRanking: () => rankings++,
            onOpenFreeMissions: () => freeMissions++,
          ),
          textScale: 2,
        ),
      );
      await _tap(tester, find.text('16階'));
      expect(find.text('16階の案内図'), findsOneWidget);
      expect(find.semantics.byLabel('16階のマップを表示'), findsOne);
      await _tap(tester, find.byKey(const ValueKey('playerMapZoomIn')));
      expect(_transform(tester, '16階').value.getMaxScaleOnAxis(), 1.5);
      await _tap(tester, find.text('自由ミッション'));
      await _tap(tester, find.text('ランキング'));
      await _tap(tester, find.text('チェックポイントQRを読み取る'));
      expect([checkpoints, rankings, freeMissions], [1, 1, 1]);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
}
