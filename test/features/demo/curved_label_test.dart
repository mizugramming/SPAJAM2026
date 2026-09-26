import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spajam2026/features/demo/curved_label.dart';

void main() {
  testWidgets('長いプロフィールは文字2倍でも同じ幅で折り返し、一度だけ読み上げる', (tester) async {
    const nickname = 'つながる仲間と一緒に歩くプロフィール';
    const hobby = 'ABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final semantics = tester.ensureSemantics();

    Widget label(bool curved) {
      const content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(nickname, style: TextStyle(fontSize: 20)),
          Text(hobby, style: TextStyle(fontSize: 14)),
        ],
      );
      return MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 200,
                child: curved ? const CurvedLabel(child: content) : content,
              ),
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(label(false));
    final originalNickname = tester.getSize(find.text(nickname));
    final originalHobby = tester.getSize(find.text(hobby));
    final originalHeight = tester.getSize(find.byType(Column)).height;
    await tester.pumpWidget(label(true));

    expect(tester.getSize(find.text(nickname)), originalNickname);
    expect(tester.getSize(find.text(hobby)), originalHobby);
    expect(
      tester.getSize(find.byType(CurvedLabel)).height,
      originalHeight + CurvedLabel.defaultDrop,
    );
    expect(find.bySemanticsLabel(nickname), findsOneWidget);
    expect(find.bySemanticsLabel(hobby), findsOneWidget);
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('印刷の中央が下へ曲がり、最下行も予約した領域に収まる', (tester) async {
    const boundaryKey = Key('curved-print');
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(
            key: boundaryKey,
            child: SizedBox(
              width: 200,
              child: CurvedLabel(
                child: SizedBox(
                  height: 30,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: SizedBox(
                      height: 2,
                      width: double.infinity,
                      child: ColoredBox(color: Color(0xFFFF0000)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(boundaryKey),
    );
    final image = (await tester.runAsync(() => boundary.toImage()))!;
    addTearDown(image.dispose);
    final bytes = (await tester.runAsync(
      () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
    ))!;
    int firstPrintedRow(int x) {
      for (var y = 0; y < image.height; y++) {
        final alpha = bytes.getUint8((y * image.width + x) * 4 + 3);
        if (alpha > 128) return y;
      }
      return -1;
    }

    final edgeRow = firstPrintedRow(3);
    final centerRow = firstPrintedRow(100);
    expect(image.height, 37);
    expect(edgeRow, greaterThanOrEqualTo(28));
    expect(centerRow, greaterThan(edgeRow + 5));
    expect(centerRow, lessThan(image.height - 1));
    expect(firstPrintedRow(196), edgeRow);
    expect(tester.takeException(), isNull);
  });
}
