import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spajam2026/app/app.dart';
import 'package:spajam2026/app/router.dart';
import 'package:spajam2026/core/models/category_type.dart';
import 'package:spajam2026/core/models/emotion_type.dart';
import 'package:spajam2026/core/models/space_record.dart';
import 'package:spajam2026/core/providers/space_records_provider.dart';

// Run manually: flutter test tool/capture_screenshots.dart
// Uses mock storage only; no user data is read or changed.
void main() {
  testWidgets('capture app screens with bundled fonts and artwork', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // This file is a manually invoked flutter test, outside the normal suite.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('ja_JP');
    final originalShadows = debugDisableShadows;
    debugDisableShadows = false;
    await tester.runAsync(() async {
      final font = FontLoader('NotoSansJP')
        ..addFont(rootBundle.load('assets/common/fonts/NotoSansJP.ttf'));
      await font.load();
      final latin = FontLoader('Roboto')
        ..addFont(rootBundle.load('assets/common/fonts/Roboto.ttf'));
      await latin.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    });
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        child: RepaintBoundary(key: boundaryKey, child: const YohakuApp()),
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(YohakuApp));
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/common/night_sky.png'),
        context,
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(context);
    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        final file = File('docs/screenshots/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('home');
    final today = DateTime.now();
    for (var i = 0; i < 3; i++) {
      await container
          .read(spaceRecordsProvider.notifier)
          .save(
            SpaceRecord(
              id: '00000000-0000-4000-8000-00000000000$i',
              createdAt: DateTime(
                today.year,
                today.month,
                today.day,
                9 + 3 * i,
              ),
              emotion: [
                EmotionType.calm,
                EmotionType.tired,
                EmotionType.joyful,
              ][i],
              category: [
                CategoryType.dailyLife,
                CategoryType.workStudy,
                CategoryType.challenge,
              ][i],
              note: ['朝の空気が心地よかった。', '少し休んで、また明日。', '小さな一歩を踏み出せた。'][i],
            ),
          );
    }
    for (final page in ['constellation', 'universe', 'history']) {
      container.read(routerProvider).go('/$page');
      await capture(page);
    }
    container.read(routerProvider).go('/space');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // Capture the pause before its timed transition.
    await tester.runAsync(() async {
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      await File(
        'docs/screenshots/space.png',
      ).writeAsBytes(bytes.buffer.asUint8List());
      image.dispose();
    });
    await tester.pumpWidget(const SizedBox.shrink());
    debugDisableShadows = originalShadows;
    expect(tester.takeException(), isNull);
  });
}
