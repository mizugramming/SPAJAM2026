import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Room entry accepts a manual code; the camera is for game partners only.
enum QrPurpose { room, pair }

bool isTsunagunQr(String value, QrPurpose purpose) => switch (purpose) {
  QrPurpose.room => RegExp(r'^tsunagun:room:[A-F0-9]{12}$').hasMatch(value),
  QrPurpose.pair => RegExp(
    r'^tsunagun:pair:[A-F0-9]{12}:[A-F0-9]{8}$',
  ).hasMatch(value),
};

class SharedQrPanel extends StatelessWidget {
  const SharedQrPanel({
    super.key,
    required this.data,
    required this.code,
    required this.caption,
  });

  final String data;
  final String code;
  final String caption;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(caption, textAlign: TextAlign.center),
      const SizedBox(height: 12),
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 224),
          child: Semantics(
            label: '$caption QRコード',
            image: true,
            child: QrImageView(
              data: data,
              version: QrVersions.auto,
              backgroundColor: Colors.white,
              padding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      SelectableText(
        code.replaceAllMapped(RegExp(r'.{4}'), (m) => '${m[0]} ').trim(),
        key: const Key('share-code'),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 19, letterSpacing: 1.5),
      ),
    ],
  );
}

/// Returns only an expected app QR or a manually entered short code.
/// There is no URL navigation, external fetch or result embedded in a QR.
class QrInputPage extends StatefulWidget {
  const QrInputPage({
    super.key,
    required this.purpose,
    this.cameraInitiallyEnabled = true,
  });

  final QrPurpose purpose;
  final bool cameraInitiallyEnabled;

  @override
  State<QrInputPage> createState() => _QrInputPageState();
}

class _QrInputPageState extends State<QrInputPage> with WidgetsBindingObserver {
  final _code = TextEditingController();
  MobileScannerController? _camera;
  late bool _showCamera =
      widget.purpose == QrPurpose.pair && widget.cameraInitiallyEnabled;
  bool _accepted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_showCamera) _createCamera();
  }

  void _createCamera() {
    _camera ??= MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
  }

  Future<void> _quietCamera(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // A denied/disposed camera must never block manual code entry or Back.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final camera = _camera;
    if (camera == null || !camera.value.hasCameraPermission) return;
    if (state == AppLifecycleState.resumed && _showCamera && !_accepted) {
      unawaited(_quietCamera(camera.start));
    } else if (state != AppLifecycleState.resumed) {
      unawaited(_quietCamera(camera.stop));
    }
  }

  void _capture(BarcodeCapture capture) {
    if (_accepted) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value == null) continue;
      if (isTsunagunQr(value, widget.purpose)) {
        _accept(value);
        return;
      }
    }
    setState(
      () => _error = widget.purpose == QrPurpose.room
          ? 'ルームのQRを読み取ってください。'
          : '相手の「ツナがる」画面のQRを読み取ってください。',
    );
  }

  void _accept(String value) {
    if (_accepted) return;
    _accepted = true;
    final camera = _camera;
    if (camera != null) unawaited(_quietCamera(camera.stop));
    Navigator.of(context).pop(value);
  }

  void _submit() {
    final value = _code.text.trim();
    final code = value.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
    final length = widget.purpose == QrPurpose.room ? 12 : 8;
    final pairQr =
        widget.purpose == QrPurpose.pair && isTsunagunQr(value, QrPurpose.pair);
    if (!pairQr && !RegExp('^[A-F0-9]{$length}\$').hasMatch(code)) {
      setState(() => _error = '$length桁のコードを確かめてください。');
      return;
    }
    _accept(pairQr ? value : code);
  }

  void _manual() {
    final camera = _camera;
    if (camera != null) unawaited(_quietCamera(camera.stop));
    setState(() {
      _showCamera = false;
      _error = null;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _code.dispose();
    final camera = _camera;
    if (camera != null) unawaited(_quietCamera(camera.dispose));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.purpose == QrPurpose.room ? 'ルームに参加' : '相手とツナがる'),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_showCamera) ...[
            Text(
              widget.purpose == QrPurpose.room
                  ? '主催者のルームQRを読み取ろう。'
                  : '相手の「ツナがる」画面にカメラを向けよう。',
            ),
            const SizedBox(height: 16),
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: MobileScanner(
                  controller: _camera,
                  onDetect: _capture,
                  errorBuilder: (context, error) => const ColoredBox(
                    color: Color(0xFFF2F1EA),
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'カメラを使えません。\n端末の設定で許可するか、\nコードを入力して参加できます。',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: _manual, child: const Text('コードを入力する')),
          ] else ...[
            TextField(
              key: const Key('qr-manual-code'),
              controller: _code,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              maxLength: 100,
              decoration: InputDecoration(
                labelText: widget.purpose == QrPurpose.room
                    ? 'ルームコード'
                    : '相手のコード',
                helperText: widget.purpose == QrPurpose.room
                    ? '主催者から教えてもらった12桁のコードを入力してください。'
                    : '相手のQRの下にある8桁のコードを入力してください。',
                counterText: '',
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('submit-qr-code'),
              onPressed: _submit,
              child: Text(
                widget.purpose == QrPurpose.room ? 'ルームに参加する' : 'ツナがる',
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Semantics(liveRegion: true, child: Text(_error!)),
          ],
        ],
      ),
    ),
  );
}
