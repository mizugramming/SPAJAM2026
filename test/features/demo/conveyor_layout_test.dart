import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spajam2026/domain/conveyor_layout.dart';
import 'package:spajam2026/domain/models.dart';
import 'package:spajam2026/features/demo/can_stage.dart';
import 'package:spajam2026/features/demo/factory_backdrop.dart';
import 'package:spajam2026/features/demo/parent_character.dart';

const _profile = Profile(nickname: 'つな', hobby: '写真と散歩', comment: 'いっしょに遊ぼう');
const _peer = Participant(id: 'peer', profile: _profile, team: Team.blue);

void _phone(WidgetTester tester, double width) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Widget _scene({
  ConveyorLayout layout = const ConveyorLayout(),
  AppPhase phase = AppPhase.home,
  double scale = 1,
  EncounterResult? result,
  VoidCallback? onReturnComplete,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CanStage(
              phase: phase,
              profile: _profile,
              team: Team.red,
              result: result,
              conveyorLayout: layout,
              onReturnComplete: onReturnComplete,
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('next-action'),
              onPressed: () {},
              child: const Text('次の操作'),
            ),
          ],
        ),
      ),
    ),
  ),
);

Finder _parent() => find.byWidgetPredicate(
  (widget) => widget is Image && widget.semanticLabel == '親分',
);

Finder _rewardImage() => find.byWidgetPredicate(
  (widget) =>
      widget is Image &&
      (widget.semanticLabel == '骨の子分' || widget.semanticLabel == '獲得・成長した子分'),
);

void main() {
  for (final settings in [
    (width: 412.0, textScale: 1.0),
    (width: 360.0, textScale: 2.0),
  ]) {
    testWidgets('コンベアの拡縮・位置の極値でも缶と親分が動かず、後続UIへはみ出さない（${settings.width}）', (
      tester,
    ) async {
      _phone(tester, settings.width);
      await tester.pumpWidget(_scene(scale: settings.textScale));
      await tester.pumpAndSettle();
      final can = tester.getRect(find.byType(TunaCan));
      final parent = tester.getRect(_parent());
      final originalStage = tester.getRect(find.byType(CanStage));
      final originalBelt = tester.getRect(find.byType(ConveyorPlatform));
      final originalButton = tester.getRect(
        find.byKey(const Key('next-action')),
      );
      expect(originalBelt.width, closeTo(can.width + 24, .1));
      expect(originalBelt.height * 3, closeTo(originalBelt.width, .1));
      expect(
        can.bottom,
        closeTo(originalBelt.top + originalBelt.height * .44, .1),
      );

      for (final zoom in [.6, 1.8]) {
        for (final x in [-100.0, 100.0]) {
          for (final y in [-100.0, 100.0]) {
            final layout = ConveyorLayout(scale: zoom, offsetX: x, offsetY: y);
            await tester.pumpWidget(
              _scene(layout: layout, scale: settings.textScale),
            );
            // Check the first updated frame, not only the eventual animation
            // endpoint: an animated bottom anchor used to move the can briefly.
            expect(tester.getRect(find.byType(TunaCan)), can);
            expect(tester.getRect(_parent()), parent);
            final belt = tester.getRect(find.byType(ConveyorPlatform));
            final stage = tester.getRect(find.byType(CanStage));
            final next = tester.getRect(find.byKey(const Key('next-action')));
            expect(belt.width, closeTo(originalBelt.width * zoom, .1));
            expect(belt.height * 3, closeTo(belt.width, .1));
            expect(
              belt.center.dx - can.center.dx,
              closeTo(x * can.width / 286, .1),
            );
            expect(
              belt.top + belt.height * .44 - can.bottom,
              closeTo(y * can.width / 286, .1),
            );
            expect(stage.topLeft, originalStage.topLeft);
            expect(stage.width, originalStage.width);
            expect(belt.bottom, lessThanOrEqualTo(stage.bottom + .1));
            expect(next.top, greaterThanOrEqualTo(belt.bottom + 11.9));
            expect(next.top, greaterThan(can.bottom));
            final clipFinder = find.byKey(const Key('conveyor-clip'));
            expect(tester.getRect(clipFinder), stage);
            final clip = tester.renderObject<RenderClipRect>(clipFinder);
            expect(clip.clipBehavior, isNot(Clip.none));
            expect(
              clip.describeApproximatePaintClip(clip.child!),
              Offset.zero & clip.size,
            );
            expect(
              find.descendant(of: clipFinder, matching: find.byType(TunaCan)),
              findsNothing,
            );
            expect(
              find.descendant(
                of: clipFinder,
                matching: find.byType(ParentCharacter),
              ),
              findsNothing,
            );
            await tester.pump(const Duration(milliseconds: 350));
            expect(tester.getRect(find.byType(TunaCan)), can);
            expect(tester.getRect(_parent()), parent);
            expect(tester.takeException(), isNull);
          }
        }
      }
      await tester.pumpWidget(_scene(scale: settings.textScale));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(CanStage)), originalStage);
      expect(tester.getRect(find.byType(ConveyorPlatform)), originalBelt);
      expect(
        tester.getRect(find.byKey(const Key('next-action'))),
        originalButton,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('保存形式から復元した配置値を維持し、サイズ1なら指定分だけベルトを動かす', (tester) async {
    _phone(tester, 360);
    await tester.pumpWidget(_scene());
    await tester.pumpAndSettle();
    final original = tester.getRect(find.byType(ConveyorPlatform));
    final can = tester.getRect(find.byType(TunaCan));
    const selected = ConveyorLayout(offsetX: -45, offsetY: 60);
    await tester.pumpWidget(
      _scene(layout: ConveyorLayout.decode(selected.encode())),
    );
    final moved = tester.getRect(find.byType(ConveyorPlatform));
    expect(moved.size, original.size);
    expect(moved.left - original.left, closeTo(-45 * can.width / 286, .1));
    expect(moved.top - original.top, closeTo(60 * can.width / 286, .1));
    await tester.pumpWidget(
      _scene(layout: ConveyorLayout.decode(selected.encode())),
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(ConveyorPlatform)), moved);
    expect(tester.getRect(find.byType(TunaCan)), can);
    expect(tester.takeException(), isNull);
  });

  for (final kind in FollowerKind.values) {
    testWidgets('文字2倍・配置変更中も帰還する${kind.name}子分の下端は缶底を越えない', (tester) async {
      _phone(tester, 360);
      final follower = Follower(
        id: 'follower',
        ownerId: 'self',
        peerId: _peer.id,
        profile: _profile,
        kind: kind,
        ordinal: 1,
      );
      final result = EncounterResult(
        outcome: kind == FollowerKind.normal ? Outcome.win : Outcome.loss,
        peer: _peer,
        newFollower: follower,
        delta: follower.power,
      );
      var completions = 0;
      var layout = const ConveyorLayout(scale: 1.8, offsetX: 100, offsetY: 100);
      Widget current(AppPhase phase) => _scene(
        phase: phase,
        layout: layout,
        result: result,
        scale: 2,
        onReturnComplete: () => completions++,
      );
      await tester.pumpWidget(current(AppPhase.result));
      await tester.pumpAndSettle();
      await tester.pumpWidget(current(AppPhase.returning));
      final initialCan = tester.getRect(find.byType(TunaCan));
      for (var elapsed = 0; elapsed <= 1800; elapsed += 100) {
        if (elapsed > 0) await tester.pump(const Duration(milliseconds: 100));
        if (elapsed == 900) {
          layout = const ConveyorLayout(
            scale: .6,
            offsetX: -100,
            offsetY: -100,
          );
          await tester.pumpWidget(current(AppPhase.returning));
        }
        final can = tester.getRect(find.byType(TunaCan));
        expect(can, initialCan);
        final image = tester.renderObject<RenderBox>(_rewardImage());
        final bottom =
            [
                  Offset.zero,
                  Offset(image.size.width, 0),
                  Offset(0, image.size.height),
                  Offset(image.size.width, image.size.height),
                ]
                .map(image.localToGlobal)
                .map((point) => point.dy)
                .reduce((a, b) => a > b ? a : b);
        expect(
          bottom,
          lessThanOrEqualTo(can.bottom + .1),
          reason: '${elapsed}ms',
        );
        final belt = tester.getRect(find.byType(ConveyorPlatform));
        expect(
          belt.bottom,
          lessThanOrEqualTo(tester.getRect(find.byType(CanStage)).bottom + .1),
        );
        expect(tester.takeException(), isNull);
      }
      await tester.pump(const Duration(milliseconds: 100));
      expect(completions, 1);
    });
  }
}
