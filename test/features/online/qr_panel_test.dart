import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:spajam2026/features/online/qr_panel.dart';

void main() {
  test('QRは用途と長さを区別し、URLや資格情報を受け付けない', () {
    expect(isTsunagunQr('tsunagun:room:ABCDEF012345', QrPurpose.room), isTrue);
    expect(
      isTsunagunQr('tsunagun:pair:ABCDEF012345:1234ABCD', QrPurpose.pair),
      isTrue,
    );
    for (final value in [
      'https://example.com/tsunagun:room:ABCDEF012345',
      'tsunagun:room:ABCDEF012345?token=secret',
      'tsunagun:room:ABCDEF0123456',
      'tsunagun:pair:ABCDEF012345:1234ABCD',
    ]) {
      expect(isTsunagunQr(value, QrPurpose.room), isFalse);
    }
    expect(isTsunagunQr('tsunagun:room:ABCDEF012345', QrPurpose.pair), isFalse);
  });

  Future<void> open(
    WidgetTester tester,
    QrPurpose purpose,
    ValueChanged<String?> received,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => received(
                await Navigator.push<String>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QrInputPage(
                      purpose: purpose,
                      cameraInitiallyEnabled: false,
                    ),
                  ),
                ),
              ),
              child: const Text('開く'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('開く'));
    await tester.pumpAndSettle();
  }

  testWidgets('カメラなしの参加はコードを正規化して一度だけ返す', (tester) async {
    final received = <String?>[];
    await open(tester, QrPurpose.room, received.add);
    await tester.enterText(
      find.byKey(const Key('qr-manual-code')),
      'abcd ef01-2345',
    );
    await tester.tap(find.byKey(const Key('submit-qr-code')));
    await tester.pumpAndSettle();
    expect(received, ['ABCDEF012345']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('相手コードにはルームQRを使えず、入力を保持して直せる', (tester) async {
    final received = <String?>[];
    await open(tester, QrPurpose.pair, received.add);
    await tester.enterText(
      find.byKey(const Key('qr-manual-code')),
      'tsunagun:room:ABCDEF012345',
    );
    await tester.tap(find.byKey(const Key('submit-qr-code')));
    await tester.pump();
    expect(find.text('8桁のコードを確かめてください。'), findsOneWidget);
    expect(received, isEmpty);
    await tester.enterText(
      find.byKey(const Key('qr-manual-code')),
      'tsunagun:pair:ABCDEF012345:1234ABCD',
    );
    await tester.tap(find.byKey(const Key('submit-qr-code')));
    await tester.pumpAndSettle();
    expect(received, ['tsunagun:pair:ABCDEF012345:1234ABCD']);
  });

  testWidgets('読取を戻ると未入力のまま終了し、参加処理は要求しない', (tester) async {
    final received = <String?>[];
    await open(tester, QrPurpose.room, received.add);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(received, [null]);
  });

  testWidgets('入室画面は既定でもカメラを開かず、12桁コードだけを受け付ける', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: QrInputPage(purpose: QrPurpose.room)),
    );
    expect(find.byType(MobileScanner), findsNothing);
    expect(find.text('主催者から教えてもらった12桁のコードを入力してください。'), findsOneWidget);
    expect(find.textContaining('QR'), findsNothing);
    await tester.enterText(
      find.byKey(const Key('qr-manual-code')),
      'tsunagun:room:ABCDEF012345',
    );
    await tester.tap(find.byKey(const Key('submit-qr-code')));
    await tester.pump();
    expect(find.text('12桁のコードを確かめてください。'), findsOneWidget);
  });
}
