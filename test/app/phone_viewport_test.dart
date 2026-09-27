import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spajam2026/app/tsunagun_app.dart';

const _frame = Key('phone-frame');
const _safeContent = Key('safe-content');
const _target = Key('tap-target');

Rect paintedRect(WidgetTester tester, Finder finder) {
  final box = tester.renderObject<RenderBox>(finder);
  return Rect.fromPoints(
    box.localToGlobal(Offset.zero),
    box.localToGlobal(box.size.bottomRight(Offset.zero)),
  );
}

Future<void> mount(
  WidgetTester tester, {
  required Size size,
  TargetPlatform platform = TargetPlatform.windows,
  MediaQueryData Function(MediaQueryData)? media,
  required Widget home,
}) async {
  debugDefaultTargetPlatformOverride = platform;
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: media?.call(MediaQuery.of(context)) ?? MediaQuery.of(context),
        child: PhoneViewport(child: child!),
      ),
      home: home,
    ),
  );
  await tester.pumpAndSettle();
}

void viewportTest(String description, WidgetTesterCallback body) {
  testWidgets(description, (tester) async {
    try {
      await body(tester);
    } finally {
      // Flutter verifies foundation overrides before addTearDown callbacks run.
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

void main() {
  for (final scenario in const [
    (window: Size(1280, 720), visible: Size(329.6, 720)),
    (window: Size(480, 720), visible: Size(329.6, 720)),
    (window: Size(300, 900), visible: Size(300, 655.3398058252427)),
    (window: Size(412, 900), visible: Size(412, 900)),
    (window: Size(1440, 1200), visible: Size(412, 900)),
  ]) {
    viewportTest('PC ${scenario.window} fits the whole phone and maps taps', (
      tester,
    ) async {
      var taps = 0;
      late MediaQueryData inner;
      await mount(
        tester,
        size: scenario.window,
        media: (data) => data.copyWith(textScaler: TextScaler.linear(1.7)),
        home: Builder(
          builder: (context) {
            inner = MediaQuery.of(context);
            return Scaffold(
              key: _frame,
              body: Align(
                alignment: Alignment.bottomCenter,
                child: GestureDetector(
                  key: _target,
                  onTap: () => taps++,
                  child: const ColoredBox(
                    color: Colors.blue,
                    child: SizedBox(width: 140, height: 60),
                  ),
                ),
              ),
            );
          },
        ),
      );
      expect(tester.getSize(find.byKey(_frame)), const Size(412, 900));
      expect(inner.size, const Size(412, 900));
      expect(inner.textScaler.scale(10), 17);
      final visible = paintedRect(tester, find.byKey(_frame));
      expect(visible.width, closeTo(scenario.visible.width, .001));
      expect(visible.height, closeTo(scenario.visible.height, .001));
      expect(visible.center.dx, closeTo(scenario.window.width / 2, .001));
      expect(visible.center.dy, closeTo(scenario.window.height / 2, .001));
      expect(visible.left, greaterThanOrEqualTo(-.001));
      expect(visible.top, greaterThanOrEqualTo(-.001));
      expect(visible.bottom, lessThanOrEqualTo(scenario.window.height + .001));
      await tester.tapAt(paintedRect(tester, find.byKey(_target)).center);
      expect(taps, 1);
      if (visible.left > 0) {
        await tester.tapAt(Offset(visible.left / 2, visible.center.dy));
        expect(taps, 1);
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final platform in [TargetPlatform.linux, TargetPlatform.macOS]) {
    viewportTest('$platform also keeps the preview in narrow PC windows', (
      tester,
    ) async {
      await mount(
        tester,
        size: const Size(380, 600),
        platform: platform,
        home: const Scaffold(key: _frame),
      );
      expect(tester.getSize(find.byKey(_frame)), const Size(412, 900));
      expect(
        paintedRect(tester, find.byKey(_frame)).height,
        closeTo(600, .001),
      );
    });
  }

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final size in [const Size(360, 740), const Size(800, 500)]) {
      viewportTest(
        '$platform $size keeps real constraints, including on mobile web',
        (tester) async {
          late MediaQueryData supplied;
          late MediaQueryData inner;
          await mount(
            tester,
            size: size,
            platform: platform,
            media: (data) => supplied = data.copyWith(
              textScaler: TextScaler.linear(1.6),
              padding: const EdgeInsets.only(top: 24),
              viewPadding: const EdgeInsets.only(top: 24, bottom: 16),
              viewInsets: const EdgeInsets.only(bottom: 200),
              systemGestureInsets: const EdgeInsets.only(left: 12),
              highContrast: true,
            ),
            home: Builder(
              builder: (context) {
                inner = MediaQuery.of(context);
                return const Scaffold(key: _frame);
              },
            ),
          );
          expect(tester.getSize(find.byKey(_frame)), size);
          expect(paintedRect(tester, find.byKey(_frame)), Offset.zero & size);
          expect(inner, supplied);
          expect(find.byType(FittedBox), findsNothing);
        },
      );
    }
  }

  viewportTest(
    'PC keyboard and safe areas retain their visible physical overlap',
    (tester) async {
      late MediaQueryData inner;
      await mount(
        tester,
        size: const Size(800, 600),
        media: (data) => data.copyWith(
          padding: const EdgeInsets.only(top: 20, left: 24),
          viewPadding: const EdgeInsets.only(top: 20, left: 24, bottom: 30),
          viewInsets: const EdgeInsets.only(bottom: 180),
          systemGestureInsets: const EdgeInsets.only(left: 12, bottom: 12),
          textScaler: TextScaler.linear(1.6),
          highContrast: true,
        ),
        home: Builder(
          builder: (context) {
            inner = MediaQuery.of(context);
            return const Scaffold(
              key: _frame,
              body: SafeArea(child: SizedBox.expand(key: _safeContent)),
            );
          },
        ),
      );
      expect(inner.padding, const EdgeInsets.only(top: 30));
      expect(inner.viewPadding, const EdgeInsets.only(top: 30, bottom: 45));
      expect(inner.viewInsets, const EdgeInsets.only(bottom: 270));
      expect(inner.systemGestureInsets, const EdgeInsets.only(bottom: 18));
      expect(inner.textScaler.scale(10), 16);
      expect(inner.highContrast, isTrue);
      final content = paintedRect(tester, find.byKey(_safeContent));
      expect(content.top, closeTo(20, .001));
      expect(content.bottom, closeTo(420, .001));
      expect(tester.takeException(), isNull);
    },
  );

  viewportTest('system padding outside the PC canvas is not applied twice', (
    tester,
  ) async {
    late MediaQueryData inner;
    await mount(
      tester,
      size: const Size(1000, 1200),
      media: (data) => data.copyWith(
        padding: const EdgeInsets.all(24),
        viewPadding: const EdgeInsets.all(24),
      ),
      home: Builder(
        builder: (context) {
          inner = MediaQuery.of(context);
          return const Scaffold(
            key: _frame,
            body: SafeArea(child: SizedBox.expand(key: _safeContent)),
          );
        },
      ),
    );
    expect(inner.padding, EdgeInsets.zero);
    expect(inner.viewPadding, EdgeInsets.zero);
    expect(
      paintedRect(tester, find.byKey(_safeContent)),
      paintedRect(tester, find.byKey(_frame)),
    );
  });

  viewportTest(
    'a keyboard covering the entire centered PC canvas does not create negative layout',
    (tester) async {
      late MediaQueryData inner;
      await mount(
        tester,
        size: const Size(300, 900),
        media: (data) =>
            data.copyWith(viewInsets: const EdgeInsets.only(bottom: 800)),
        home: Builder(
          builder: (context) {
            inner = MediaQuery.of(context);
            return const Scaffold(
              key: _frame,
              body: SafeArea(child: SizedBox.expand(key: _safeContent)),
            );
          },
        ),
      );
      expect(inner.viewInsets.bottom, 900);
      expect(tester.getSize(find.byKey(_safeContent)).height, 0);
      expect(tester.takeException(), isNull);
    },
  );

  viewportTest(
    'dialogs and sheets stay inside the scaled phone and remain clickable',
    (tester) async {
      late BuildContext pageContext;
      late MediaQueryData dialogMedia;
      await mount(
        tester,
        size: const Size(480, 600),
        home: Builder(
          builder: (context) {
            pageContext = context;
            return const Scaffold(key: _frame);
          },
        ),
      );
      final phone = paintedRect(tester, find.byKey(_frame));
      unawaited(
        showDialog<void>(
          context: pageContext,
          builder: (context) {
            dialogMedia = MediaQuery.of(context);
            return AlertDialog(
              content: const Text('QRを読み込む'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('閉じる'),
                ),
              ],
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(dialogMedia.size, const Size(412, 900));
      final dialog = paintedRect(tester, find.byType(AlertDialog));
      expect(phone.inflate(.001).contains(dialog.topLeft), isTrue);
      expect(phone.inflate(.001).contains(dialog.bottomRight), isTrue);
      await tester.tapAt(paintedRect(tester, find.text('閉じる')).center);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      unawaited(
        showModalBottomSheet<void>(
          context: pageContext,
          builder: (context) => SizedBox(
            height: 180,
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('シートを閉じる'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final sheet = paintedRect(tester, find.byType(BottomSheet));
      expect(tester.getSize(find.byType(BottomSheet)).width, 412);
      expect(sheet.left, closeTo(phone.left, .001));
      expect(sheet.right, closeTo(phone.right, .001));
      expect(sheet.bottom, closeTo(phone.bottom, .001));
      await tester.tapAt(paintedRect(tester, find.text('シートを閉じる')).center);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
