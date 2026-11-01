import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:mayoi_quest/features/player/player_media.dart';

class _PhotoPicker extends ImagePicker {
  XFile? result;
  PlatformException? failure;
  ImageSource? source;
  double? width;
  double? height;
  int? quality;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    this.source = source;
    width = maxWidth;
    height = maxHeight;
    quality = imageQuality;
    if (failure case final error?) throw error;
    return result;
  }
}

class _ScannerPlatform extends MobileScannerPlatform {
  int starts = 0;
  int stops = 0;
  int disposes = 0;
  StartOptions? options;
  MobileScannerException? failure;
  Completer<void>? starting;

  @override
  Stream<BarcodeCapture?> get barcodesStream => const Stream.empty();

  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();

  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();

  @override
  Widget buildCameraView() => const ColoredBox(color: Colors.black);

  @override
  Future<MobileScannerViewAttributes> start(StartOptions startOptions) async {
    starts++;
    options = startOptions;
    await starting?.future;
    if (failure case final error?) throw error;
    return const MobileScannerViewAttributes(
      cameraDirection: CameraFacing.back,
      currentTorchMode: TorchState.unavailable,
      size: Size(640, 480),
    );
  }

  @override
  Future<void> stop() async => stops++;

  @override
  Future<void> dispose() async => disposes++;
}

Widget _host({required bool enabled, required Future<void> Function(String) onCode}) => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      width: 320,
      height: 320,
      child: PlayerQrScanner(enabled: enabled, onCode: onCode),
    ),
  ),
);

BarcodeCapture _code(String? value) => BarcodeCapture(barcodes: [Barcode(rawValue: value)]);

void main() {
  test('camera capture uses bounded image options, preserves bytes and returns null on cancellation', () async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    final camera = _PhotoPicker()..result = XFile.fromData(bytes, mimeType: 'image/jpeg');
    final picker = DevicePlayerPhotoPicker(picker: camera);
    expect(await picker.capturePhoto(), bytes);
    expect(camera.source, ImageSource.camera);
    expect(camera.width, 1280);
    expect(camera.height, 1280);
    expect(camera.quality, 80);
    camera.result = null;
    expect(await picker.capturePhoto(), isNull);
  });

  test('camera permission failure returns an actionable Japanese message', () async {
    final camera = _PhotoPicker()..failure = PlatformException(code: 'camera_access_denied');
    expect(
      DevicePlayerPhotoPicker(picker: camera).capturePhoto(),
      throwsA(isA<PlayerMediaException>().having((error) => error.message, 'message', contains('端末の設定'))),
    );
  });

  group('QR device boundary', () {
    late MobileScannerPlatform previous;
    late _ScannerPlatform camera;

    setUp(() {
      previous = MobileScannerPlatform.instance;
      camera = _ScannerPlatform();
      MobileScannerPlatform.instance = camera;
    });

    tearDown(() => MobileScannerPlatform.instance = previous);

    testWidgets('ignores empty payload and suppresses duplicate events until explicit retry', (tester) async {
      final pending = Completer<void>();
      final received = <String>[];
      await tester.pumpWidget(
        _host(
          enabled: true,
          onCode: (value) {
            received.add(value);
            return pending.future;
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(camera.options!.formats, [BarcodeFormat.qrCode]);
      final detect = tester.widget<MobileScanner>(find.byType(MobileScanner)).onDetect!;
      detect(_code(null));
      detect(_code('  '));
      await tester.pump();
      expect(received, isEmpty);
      detect(_code('  actual-QR  '));
      detect(_code('duplicate'));
      await tester.pumpAndSettle();
      expect(received, ['  actual-QR  ']);
      expect(camera.stops, 1);
      pending.complete();
      await tester.pumpAndSettle();
      detect(_code('same-frame'));
      await tester.pump();
      expect(received.length, 1);
      await tester.tap(find.text('もう一度読み取る'));
      await tester.pumpAndSettle();
      expect(camera.starts, 2);
      detect(_code('retry-QR'));
      await tester.pumpAndSettle();
      expect(received, ['  actual-QR  ', 'retry-QR']);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(camera.disposes, 1);
    });

    testWidgets('disabled state and background stop scanning; foreground resumes only when enabled', (tester) async {
      var received = 0;
      Future<void> onCode(String _) async => received++;
      await tester.pumpWidget(_host(enabled: false, onCode: onCode));
      await tester.pumpAndSettle();
      expect(camera.starts, 0);
      tester.widget<MobileScanner>(find.byType(MobileScanner)).onDetect!(_code('disabled'));
      await tester.pump();
      expect(received, 0);
      await tester.pumpWidget(_host(enabled: true, onCode: onCode));
      await tester.pumpAndSettle();
      expect(camera.starts, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      expect(camera.stops, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(camera.starts, 2);
      await tester.pumpWidget(_host(enabled: false, onCode: onCode));
      await tester.pumpAndSettle();
      expect(camera.stops, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(camera.starts, 2);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(camera.disposes, 1);
    });

    testWidgets('late initialization is released after scanner removal', (tester) async {
      camera.starting = Completer<void>();
      await tester.pumpWidget(_host(enabled: true, onCode: (_) async {}));
      await tester.pump();
      expect(camera.starts, 1);
      await tester.pumpWidget(const SizedBox());
      expect(camera.disposes, 0);
      camera.starting!.complete();
      await tester.pumpAndSettle();
      expect(camera.disposes, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('late initialization stops after disablement and stays stopped on foreground return', (tester) async {
      camera.starting = Completer<void>();
      Future<void> onCode(String _) async {}
      await tester.pumpWidget(_host(enabled: true, onCode: onCode));
      await tester.pump();
      expect(camera.starts, 1);
      await tester.pumpWidget(_host(enabled: false, onCode: onCode));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      camera.starting!.complete();
      await tester.pumpAndSettle();
      expect(camera.stops, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(camera.starts, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(camera.disposes, 1);
    });

    testWidgets('permission denial shows settings guidance and permits deliberate retry', (tester) async {
      camera.failure = const MobileScannerException(errorCode: MobileScannerErrorCode.permissionDenied);
      await tester.pumpWidget(_host(enabled: true, onCode: (_) async {}));
      await tester.pumpAndSettle();
      expect(find.textContaining('端末の設定でカメラを許可'), findsOneWidget);
      camera.failure = null;
      await tester.tap(find.text('カメラを再試行'));
      await tester.pumpAndSettle();
      expect(camera.starts, 2);
      expect(find.textContaining('端末の設定でカメラを許可'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets('callback failure keeps QR paused and exposes retry without unhandled error', (tester) async {
      await tester.pumpWidget(_host(enabled: true, onCode: (_) async => throw Exception('offline')));
      await tester.pumpAndSettle();
      tester.widget<MobileScanner>(find.byType(MobileScanner)).onDetect!(_code('QR'));
      await tester.pumpAndSettle();
      expect(find.textContaining('QRの確認に失敗'), findsOneWidget);
      expect(find.text('もう一度読み取る'), findsOneWidget);
      expect(camera.starts, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  });
}
