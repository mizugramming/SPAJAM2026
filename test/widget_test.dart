import 'package:flutter_test/flutter_test.dart';

import 'package:spajam2026/main.dart';

void main() {
  testWidgets('部屋作成/参加の入り口画面が表示される', (WidgetTester tester) async {
    await tester.pumpWidget(const AppRoot());
    await tester.pumpAndSettle();

    expect(find.text('会輪'), findsOneWidget);
    expect(find.text('部屋を作る'), findsOneWidget);
    expect(find.text('部屋に入る'), findsOneWidget);
  });
}
