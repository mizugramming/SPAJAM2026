import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'player_night_style.dart';

/// UI側だけの撮影境界。写真の保存・提出・判定は共通Repositoryが行う。
abstract interface class PlayerPhotoPicker {
  /// 撮影を取り消した場合はnull。
  Future<Uint8List?> capturePhoto();
}

final playerPhotoPickerProvider = Provider<PlayerPhotoPicker>((ref) => DevicePlayerPhotoPicker());

typedef PlayerQrScannerBuilder =
    Widget Function(BuildContext context, Future<void> Function(String) onCode, bool enabled);

final playerQrScannerBuilderProvider = Provider<PlayerQrScannerBuilder>(
  (ref) =>
      (context, onCode, enabled) => PlayerQrScanner(onCode: onCode, enabled: enabled),
);

class PlayerMediaException implements Exception {
  const PlayerMediaException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DevicePlayerPhotoPicker implements PlayerPhotoPicker {
  DevicePlayerPhotoPicker({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<Uint8List?> capturePhoto() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 80,
        requestFullMetadata: false,
      );
      return file == null ? null : await file.readAsBytes();
    } on PlatformException catch (error) {
      final permissionDenied =
          error.code.toLowerCase().contains('denied') || error.code.toLowerCase().contains('restricted');
      throw PlayerMediaException(
        permissionDenied
            ? 'カメラの利用が許可されていません。端末の設定でカメラを許可してから、もう一度撮影してください。'
            : 'カメラを開けませんでした。ほかのカメラアプリを閉じて、もう一度撮影してください。',
      );
    } on MissingPluginException {
      throw const PlayerMediaException('この環境では撮影できません。Android端末で確認してください。');
    } on UnsupportedError {
      throw const PlayerMediaException('この環境では撮影できません。Android端末で確認してください。');
    } on Exception {
      throw const PlayerMediaException('写真を読み込めませんでした。もう一度撮影してください。');
    }
  }
}

/// 読取のたびに停止し、同じQRの連続送信を避ける。検証はonCodeへ委ねる。
class PlayerQrScanner extends StatefulWidget {
  const PlayerQrScanner({super.key, required this.onCode, required this.enabled});

  final Future<void> Function(String) onCode;
  final bool enabled;

  @override
  State<PlayerQrScanner> createState() => _PlayerQrScannerState();
}

class _PlayerQrScannerState extends State<PlayerQrScanner> with WidgetsBindingObserver {
  final _controller = MobileScannerController(autoStart: false, formats: const [BarcodeFormat.qrCode]);
  Future<void> _cameraOperations = Future<void>.value();
  bool _foreground = true;
  bool _processing = false;
  bool _awaitingRetry = false;
  String? _cameraError;
  String? _readError;

  bool get _shouldRun => mounted && widget.enabled && _foreground && !_processing && !_awaitingRetry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_syncCamera());
    });
  }

  @override
  void didUpdateWidget(covariant PlayerQrScanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) unawaited(_syncCamera());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    unawaited(_syncCamera());
  }

  Future<void> _syncCamera() {
    // 権限ダイアログや短い画面切替でstartとstopを同時に呼ばない。
    _cameraOperations = _cameraOperations.then((_) async {
      if (!mounted) return;
      try {
        if (_shouldRun) {
          await _controller.start();
        } else {
          await _controller.stop();
        }
      } on Exception {
        if (mounted) {
          setState(() => _cameraError = 'カメラを利用できません。Android端末のカメラ設定を確認してください。');
        }
      } on UnsupportedError {
        if (mounted) {
          setState(() => _cameraError = 'この環境ではQRを読み取れません。Android端末で確認してください。');
        }
      }
    });
    return _cameraOperations;
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (!_shouldRun) return;
    String? code;
    for (final barcode in capture.barcodes) {
      final candidate = barcode.rawValue;
      if (candidate != null && candidate.trim().isNotEmpty) {
        code = candidate;
        break;
      }
    }
    if (code == null) return;
    setState(() {
      _processing = true;
      _awaitingRetry = true;
      _readError = null;
    });
    await _syncCamera();
    if (!mounted) return;
    try {
      await widget.onCode(code);
    } on Exception {
      if (mounted) setState(() => _readError = 'QRの確認に失敗しました。もう一度読み取ってください。');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _retry() {
    setState(() {
      _awaitingRetry = false;
      _cameraError = null;
      _readError = null;
    });
    unawaited(_syncCamera());
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _controller,
          useAppLifecycleState: false,
          onDetect: _onDetect,
          onDetectError: (_, _) {
            if (mounted && _shouldRun) {
              setState(() => _readError = 'QRを読み取れませんでした。明るい場所で、QR全体を枠に入れてください。');
            }
          },
          placeholderBuilder: (_) => const ColoredBox(
            color: PlayerNight.background,
            child: Center(child: Text('カメラを準備しています…')),
          ),
          errorBuilder: (_, error) => _ScannerMessage(
            message: switch (error.errorCode) {
              MobileScannerErrorCode.permissionDenied => 'カメラの利用が許可されていません。端末の設定でカメラを許可してから、もう一度お試しください。',
              MobileScannerErrorCode.unsupported => 'この環境ではQRを読み取れません。Android端末で確認してください。',
              _ => 'カメラを開けませんでした。ほかのカメラアプリを閉じて、もう一度お試しください。',
            },
            onRetry: widget.enabled && !_processing ? _retry : null,
          ),
        ),
        if (_cameraError case final error?)
          _ScannerMessage(message: error, onRetry: widget.enabled && !_processing ? _retry : null)
        else if (_awaitingRetry && !_processing && widget.enabled)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ElevatedButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('もう一度読み取る'),
              ),
            ),
          ),
        if (_readError case final error?)
          Align(
            alignment: Alignment.topCenter,
            child: Semantics(
              liveRegion: true,
              child: ColoredBox(
                color: PlayerNight.surface,
                child: Padding(padding: const EdgeInsets.all(12), child: Text(error)),
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // 進行中のstartが終わってから解放し、遅い権限応答でカメラが残らないようにする。
    unawaited(_releaseCamera());
    super.dispose();
  }

  Future<void> _releaseCamera() async {
    await _cameraOperations;
    try {
      await _controller.dispose();
    } on Exception {
      // 未対応・カメラなしの環境では、解放の失敗を画面破棄後へ通知しない。
    } on UnsupportedError {
      // 開始時と同様に未対応端末を許容する。
    }
  }
}

class _ScannerMessage extends StatelessWidget {
  const _ScannerMessage({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: PlayerNight.background,
    child: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Semantics(
          liveRegion: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.camera_alt_outlined, color: PlayerNight.cyan),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              if (onRetry != null) ...[
                const SizedBox(height: 12),
                OutlinedButton(onPressed: onRetry, child: const Text('カメラを再試行')),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
