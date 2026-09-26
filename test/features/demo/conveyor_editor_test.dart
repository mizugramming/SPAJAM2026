import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spajam2026/app/tsunagun_app.dart';
import 'package:spajam2026/data/conveyor_settings.dart';
import 'package:spajam2026/data/demo_controller.dart';
import 'package:spajam2026/domain/conveyor_layout.dart';
import 'package:spajam2026/domain/models.dart';
import 'package:spajam2026/features/demo/can_stage.dart';
import 'package:spajam2026/features/demo/conveyor_editor.dart';
import 'package:spajam2026/features/demo/factory_backdrop.dart';

const _previewKey = Key('conveyor-editor-preview');

Finder get _scene => find.byWidgetPredicate(
  (widget) => widget is CanStage && widget.key != _previewKey,
);

CanStage _actualStage(WidgetTester tester) => tester.widget<CanStage>(_scene);
ConveyorLayout _draft(WidgetTester tester) =>
    tester.widget<CanStage>(find.byKey(_previewKey)).conveyorLayout;

Rect _beltRect(WidgetTester tester) => tester.getRect(
  find.descendant(of: _scene, matching: find.byType(ConveyorPlatform)),
);

Future<void> _tap(WidgetTester tester, String key) async {
  final target = find.byKey(Key(key));
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _open(WidgetTester tester) async {
  await _tap(tester, 'demo-info');
  await _tap(tester, 'edit-conveyor');
  expect(find.byType(ConveyorEditor), findsOneWidget);
}

DemoController _home() => DemoController(autoTick: false)
  ..createRoom(const Duration(minutes: 3))
  ..setProfile(nickname: 'つな太郎', hobby: '散歩', comment: '一緒に遊ぼう')
  ..saveProfile()
  ..startEvent();

Future<({DemoController demo, ConveyorSettings settings})> _launch(
  WidgetTester tester,
  ConveyorLayoutStore store, {
  Size size = const Size(412, 900),
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final settings = ConveyorSettings(store: store);
  await settings.load();
  final demo = _home();
  addTearDown(settings.dispose);
  addTearDown(demo.dispose);
  await tester.pumpWidget(
    TsunagunApp(
      animateCharacters: false,
      controller: demo,
      conveyorSettings: settings,
    ),
  );
  await tester.pumpAndSettle();
  return (demo: demo, settings: settings);
}

class _FailOnceStore extends MemoryConveyorLayoutStore {
  _FailOnceStore({super.initialValue});

  int attempts = 0;

  @override
  Future<void> write(ConveyorLayout value) async {
    attempts++;
    if (attempts == 1) throw StateError('temporary storage failure');
    await super.write(value);
  }
}

void main() {
  testWidgets('DEMOからの変更は保存後に実画面へ反映し、新しいアプリでも同じ保存先から復元する', (tester) async {
    final store = MemoryConveyorLayoutStore();
    final app = await _launch(tester, store);
    final original = _actualStage(tester).conveyorLayout;
    final originalRect = _beltRect(tester);
    final profile = app.demo.self.profile;

    await _open(tester);
    await _tap(tester, 'conveyor-scale-plus');
    await _tap(tester, 'conveyor-x-plus');
    await _tap(tester, 'conveyor-y-minus');
    final draft = _draft(tester);
    expect(draft.scale, closeTo(1.05, .00001));
    expect(draft.offsetX, 1);
    expect(draft.offsetY, -1);
    expect(_actualStage(tester).conveyorLayout, original);
    expect(_beltRect(tester), originalRect);
    expect(await store.read(), isNull);

    await _tap(tester, 'save-conveyor-layout');
    expect(find.byType(ConveyorEditor), findsNothing);
    expect(app.settings.value, draft);
    expect(_actualStage(tester).conveyorLayout, draft);
    expect(_beltRect(tester).width, greaterThan(originalRect.width));
    expect(await store.read(), draft);
    expect(app.demo.phase, AppPhase.home);
    expect(app.demo.self.profile, profile);
    expect(app.demo.followers, isEmpty);

    // Destroy the whole app/controller/settings, then read the same store as a
    // fresh app does. This does not depend on retained widget state.
    await tester.pumpWidget(const SizedBox());
    final restored = await _launch(tester, store);
    expect(restored.settings.value, draft);
    expect(_actualStage(tester).conveyorLayout, draft);
    expect(_beltRect(tester).width, greaterThan(originalRect.width));
    expect(tester.takeException(), isNull);
  });

  testWidgets('編集中に期限を迎えてもdraftを保ち、取消しでは保存せず確定済みの最終場面へ戻る', (tester) async {
    const saved = ConveyorLayout(scale: .9, offsetX: 12, offsetY: -6);
    final store = MemoryConveyorLayoutStore(initialValue: saved);
    final app = await _launch(tester, store);
    await _open(tester);
    await _tap(tester, 'conveyor-x-minus');
    final draft = _draft(tester);
    expect(draft.offsetX, 11);
    expect(_actualStage(tester).conveyorLayout, saved);

    app.demo.advance(app.demo.remaining);
    await tester.pumpAndSettle();
    expect(app.demo.phase, AppPhase.finale);
    expect(find.byType(ConveyorEditor), findsOneWidget);
    expect(_draft(tester), draft);
    expect(app.settings.value, saved);
    expect(await store.read(), saved);

    await _tap(tester, 'cancel-conveyor-editor');
    expect(find.byType(ConveyorEditor), findsNothing);
    expect(app.demo.phase, AppPhase.finale);
    expect(find.text('綱引きスタート！'), findsOneWidget);
    expect(app.settings.value, saved);
    expect(await store.read(), saved);
    expect(tester.takeException(), isNull);
  });

  testWidgets('初期配置に戻す操作も保存するまではdraftだけを変える', (tester) async {
    const saved = ConveyorLayout(scale: 1.2, offsetX: -15, offsetY: 20);
    final store = MemoryConveyorLayoutStore(initialValue: saved);
    final app = await _launch(tester, store);
    await _open(tester);
    await _tap(tester, 'reset-conveyor-layout');
    expect(_draft(tester), const ConveyorLayout());
    expect(_actualStage(tester).conveyorLayout, saved);
    expect(await store.read(), saved);
    await _tap(tester, 'cancel-conveyor-editor');
    expect(_actualStage(tester).conveyorLayout, saved);

    await _open(tester);
    expect(_draft(tester), saved);
    await _tap(tester, 'reset-conveyor-layout');
    await _tap(tester, 'save-conveyor-layout');
    expect(app.settings.value, const ConveyorLayout());
    expect(_actualStage(tester).conveyorLayout, const ConveyorLayout());
    expect(await store.read(), const ConveyorLayout());
    expect(tester.takeException(), isNull);
  });

  testWidgets('スライダーで300%まで広げて保存し、再読込しても最大値を復元する', (tester) async {
    final store = MemoryConveyorLayoutStore();
    final app = await _launch(tester, store);
    await _open(tester);
    final slider = find.byKey(const Key('conveyor-scale-slider'));
    await tester.ensureVisible(slider);
    await tester.pumpAndSettle();
    await tester.drag(slider, const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(find.text('300%'), findsOneWidget);
    expect(_draft(tester).scale, 3);
    expect(app.settings.value.scale, 1);
    await _tap(tester, 'save-conveyor-layout');
    expect(_actualStage(tester).conveyorLayout.scale, 3);
    final restored = ConveyorSettings(store: store);
    addTearDown(restored.dispose);
    await restored.load();
    expect(restored.value.scale, 3);
    expect(restored.loadError, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('保存失敗では実画面と保存値を保ち、同じdraftを再試行できる', (tester) async {
    const saved = ConveyorLayout(offsetX: 5);
    final store = _FailOnceStore(initialValue: saved);
    final app = await _launch(tester, store);
    await _open(tester);
    await _tap(tester, 'conveyor-y-plus');
    final draft = _draft(tester);
    await _tap(tester, 'save-conveyor-layout');
    expect(find.byType(ConveyorEditor), findsOneWidget);
    expect(find.text(app.settings.error!), findsOneWidget);
    expect(_draft(tester), draft);
    expect(_actualStage(tester).conveyorLayout, saved);
    expect(app.settings.value, saved);
    expect(await store.read(), saved);
    expect(store.attempts, 1);

    await _tap(tester, 'save-conveyor-layout');
    expect(find.byType(ConveyorEditor), findsNothing);
    expect(app.settings.error, isNull);
    expect(app.settings.value, draft);
    expect(_actualStage(tester).conveyorLayout, draft);
    expect(await store.read(), draft);
    expect(store.attempts, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('設定値コピーは現在のdraftをJSONで渡し、保存値は変えない', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map<Object?, Object?>)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final store = MemoryConveyorLayoutStore();
    final app = await _launch(tester, store);
    await _open(tester);
    await _tap(tester, 'conveyor-scale-minus');
    await _tap(tester, 'conveyor-x-minus');
    final draft = _draft(tester);
    await _tap(tester, 'copy-conveyor-layout');
    expect(copied, isNotNull);
    expect(ConveyorLayout.decode(copied!), draft);
    expect(find.text('設定値をコピーしました'), findsOneWidget);
    expect(app.settings.value, const ConveyorLayout());
    expect(await store.read(), isNull);
    await _tap(tester, 'cancel-conveyor-editor');
    expect(_actualStage(tester).conveyorLayout, const ConveyorLayout());
    expect(tester.takeException(), isNull);
  });

  testWidgets('360幅・文字2倍でもプレビュー下へスクロールして全調整と保存に到達できる', (tester) async {
    final store = MemoryConveyorLayoutStore();
    final app = await _launch(
      tester,
      store,
      size: const Size(360, 640),
      textScale: 2,
    );
    await _open(tester);
    for (final key in [
      'conveyor-scale-plus',
      'conveyor-x-minus',
      'conveyor-y-plus',
    ]) {
      await _tap(tester, key);
      expect(tester.takeException(), isNull);
    }
    final draft = _draft(tester);
    expect(draft.scale, closeTo(1.05, .00001));
    expect(draft.offsetX, -1);
    expect(draft.offsetY, 1);
    final saveRect = tester.getRect(
      find.byKey(const Key('save-conveyor-layout')),
    );
    expect(saveRect.left, greaterThanOrEqualTo(0));
    expect(saveRect.right, lessThanOrEqualTo(360));
    expect(saveRect.top, greaterThanOrEqualTo(0));
    expect(saveRect.bottom, lessThanOrEqualTo(640));
    await _tap(tester, 'save-conveyor-layout');
    expect(app.settings.value, draft);
    expect(_actualStage(tester).conveyorLayout, draft);
    expect(await store.read(), draft);
    expect(tester.takeException(), isNull);
  });
}
