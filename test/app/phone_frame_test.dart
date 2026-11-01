import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mayoi_quest/app/phone_frame.dart';

void main() {
  Size? seen;
  final probe = Builder(
    builder: (context) {
      seen = MediaQuery.sizeOf(context);
      return const SizedBox.expand();
    },
  );

  testWidgets('有効なときは中の画面にスマホの大きさを渡す', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(home: PhoneFrame(enabled: true, child: probe)));
    expect(seen, PhoneFrame.phoneSize);
  });

  testWidgets('窓が低いときは入る高さに縮める', (tester) async {
    tester.view.physicalSize = const Size(1400, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(home: PhoneFrame(enabled: true, child: probe)));
    expect(seen!.width, PhoneFrame.phoneSize.width);
    expect(seen!.height, lessThan(700));
  });

  testWidgets('無効なとき（Android）は何もしない', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(home: PhoneFrame(enabled: false, child: probe)));
    expect(seen, const Size(1400, 1000));
  });
}
