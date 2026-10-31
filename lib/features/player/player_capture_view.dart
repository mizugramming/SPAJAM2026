import 'package:flutter/material.dart';

import 'player_ui.dart';

/// カメラ映像と撮影処理を共通側から受け取る、Scaffoldのbody用表示。
class PlayerCaptureView extends StatefulWidget {
  const PlayerCaptureView({
    super.key,
    required this.preview,
    required this.instruction,
    required this.cameraReady,
    required this.onCapture,
    this.errorMessage,
  });

  final Widget preview;
  final String instruction;
  final bool cameraReady;
  final Future<void> Function() onCapture;
  final String? errorMessage;

  @override
  State<PlayerCaptureView> createState() => _PlayerCaptureViewState();
}

class _PlayerCaptureViewState extends State<PlayerCaptureView> {
  bool _isCapturing = false;
  String? _operationError;
  int _operation = 0;

  @override
  void didUpdateWidget(covariant PlayerCaptureView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.instruction != oldWidget.instruction) {
      _operation++;
      _operationError = null;
    }
  }

  Future<void> _capture() async {
    if (_isCapturing || !widget.cameraReady) return;

    final operation = ++_operation;
    setState(() {
      _isCapturing = true;
      _operationError = null;
    });
    try {
      await widget.onCapture();
    } catch (_) {
      if (!mounted || operation != _operation) return;
      setState(() {
        _operationError = '撮影できませんでした。もう一度お試しください。';
      });
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = PlayerNight.themeOf(context);
    final errorMessage = widget.errorMessage ?? _operationError;
    final hasError = errorMessage != null && errorMessage.isNotEmpty;

    return PlayerPage(
      title: 'ミッションを撮影',
      description: 'お題を確認して、対象がはっきり写るように撮影してください。',
      eyebrow: 'MISSION CAMERA',
      actions: ElevatedButton.icon(
        onPressed: widget.cameraReady && !_isCapturing ? _capture : null,
        icon: const Icon(Icons.camera_alt_outlined),
        label: Text(_isCapturing ? '撮影中…' : '撮影する'),
      ),
      children: [
        PlayerSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const ExcludeSemantics(child: Icon(Icons.center_focus_strong, color: PlayerNight.lime, size: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('撮影するもの', style: theme.textTheme.titleSmall?.copyWith(color: PlayerNight.lime)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(widget.instruction, style: theme.textTheme.titleMedium),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const _CameraPanelLabel(icon: Icons.crop_free, label: '撮影プレビュー', caption: 'CAMERA'),
        const SizedBox(height: 8),
        _PhotoFrame(
          child: AbsorbPointer(absorbing: _isCapturing || !widget.cameraReady, child: widget.preview),
        ),
        const SizedBox(height: 16),
        if (_isCapturing)
          const PlayerNotice(message: '撮影しています。完了するまでお待ちください。', busy: true)
        else if (!widget.cameraReady)
          PlayerNotice(
            message: hasError ? 'カメラを利用できません。表示された案内を確認してください。' : 'カメラの準備ができるまでお待ちください。',
            icon: Icons.camera_alt_outlined,
          )
        else
          const PlayerNotice(message: '対象全体を画面に収め、明るさやピントを確認してから撮影してください。', icon: Icons.center_focus_strong),
        if (errorMessage != null && errorMessage.isNotEmpty) ...[
          const SizedBox(height: 16),
          PlayerNotice(message: errorMessage, isError: true),
        ],
      ],
    );
  }
}

/// 写真は注入側で保持し、失敗後も同じ写真で送信を再試行できる。
class PlayerPhotoReviewView extends StatefulWidget {
  const PlayerPhotoReviewView({
    super.key,
    required this.photo,
    required this.onSubmit,
    required this.onRetake,
    this.errorMessage,
  });

  final Widget photo;
  final Future<void> Function() onSubmit;
  final VoidCallback onRetake;
  final String? errorMessage;

  @override
  State<PlayerPhotoReviewView> createState() => _PlayerPhotoReviewViewState();
}

class _PlayerPhotoReviewViewState extends State<PlayerPhotoReviewView> {
  final _transformation = TransformationController();
  final _photoViewportKey = GlobalKey();
  bool _isSubmitting = false;
  String? _operationError;
  int _operation = 0;

  @override
  void didUpdateWidget(covariant PlayerPhotoReviewView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 写真にキーがある場合、その切替は別の写真として表示状態を初期化する。
    if (widget.photo.key != oldWidget.photo.key) {
      _operation++;
      _operationError = null;
      _transformation.value = Matrix4.identity();
    }
  }

  @override
  void dispose() {
    _transformation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    final operation = ++_operation;
    setState(() {
      _isSubmitting = true;
      _operationError = null;
    });
    try {
      await widget.onSubmit();
    } catch (_) {
      if (!mounted || operation != _operation) return;
      setState(() {
        _operationError = '写真を送信できませんでした。もう一度お試しください。';
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _retake() {
    if (_isSubmitting) return;
    setState(() => _operationError = null);
    _transformation.value = Matrix4.identity();
    widget.onRetake();
  }

  void _zoom(double factor) {
    if (_isSubmitting) return;
    final size = _photoViewportKey.currentContext?.size;
    if (size == null || size.isEmpty) return;
    final scale = _transformation.value.getMaxScaleOnAxis();
    final nextScale = (scale * factor).clamp(1.0, 4.0).toDouble();
    final center = Offset(size.width / 2, size.height / 2);
    final sceneCenter = _transformation.toScene(center);
    _transformation.value = Matrix4.identity()
      ..setEntry(0, 0, nextScale)
      ..setEntry(1, 1, nextScale)
      ..setEntry(0, 3, (center.dx - sceneCenter.dx * nextScale).clamp(size.width * (1 - nextScale), 0.0).toDouble())
      ..setEntry(1, 3, (center.dy - sceneCenter.dy * nextScale).clamp(size.height * (1 - nextScale), 0.0).toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final errorMessage = widget.errorMessage ?? _operationError;

    return PlayerPage(
      title: '写真を確認',
      description: 'お題に合うものが、はっきり写っているか確認してください。',
      eyebrow: 'PHOTO REVIEW',
      actions: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _submit,
            icon: const Icon(Icons.check),
            label: Text(_isSubmitting ? '送信中…' : 'この写真で判定する'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isSubmitting ? null : _retake,
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('撮り直す'),
          ),
        ],
      ),
      children: [
        const _CameraPanelLabel(icon: Icons.photo_outlined, label: '判定に使う写真', caption: 'REVIEW'),
        const SizedBox(height: 8),
        _PhotoFrame(
          key: _photoViewportKey,
          child: AbsorbPointer(
            absorbing: _isSubmitting,
            child: InteractiveViewer(
              transformationController: _transformation,
              minScale: 1,
              maxScale: 4,
              panEnabled: !_isSubmitting,
              scaleEnabled: !_isSubmitting,
              child: SizedBox.expand(child: widget.photo),
            ),
          ),
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<Matrix4>(
          valueListenable: _transformation,
          builder: (context, transform, _) {
            final scale = transform.getMaxScaleOnAxis();
            return Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton.icon(
                  onPressed: _isSubmitting || scale >= 4 ? null : () => _zoom(2),
                  icon: const Icon(Icons.zoom_in),
                  label: const Text('拡大する'),
                ),
                TextButton.icon(
                  onPressed: _isSubmitting || scale <= 1 ? null : () => _zoom(0.5),
                  icon: const Icon(Icons.zoom_out),
                  label: const Text('縮小する'),
                ),
                TextButton.icon(
                  onPressed: _isSubmitting ? null : () => _transformation.value = Matrix4.identity(),
                  icon: const Icon(Icons.fit_screen),
                  label: const Text('全体表示'),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        if (_isSubmitting)
          const PlayerNotice(message: '写真を送信しています。完了するまで撮り直しはできません。', busy: true)
        else
          const PlayerNotice(message: '写真を拡大して細部を確認できます。拡大しても提出する写真は変わりません。', icon: Icons.zoom_in),
        if (errorMessage != null && errorMessage.isNotEmpty) ...[
          const SizedBox(height: 16),
          PlayerNotice(message: errorMessage, isError: true),
        ],
      ],
    );
  }
}

class _PhotoFrame extends StatelessWidget {
  const _PhotoFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: PlayerNight.surface, child: child),
            const IgnorePointer(
              child: ExcludeSemantics(child: CustomPaint(painter: _CameraFramePainter())),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraPanelLabel extends StatelessWidget {
  const _CameraPanelLabel({required this.icon, required this.label, required this.caption});

  final IconData icon;
  final String label;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = PlayerNight.themeOf(context);
    return Row(
      children: [
        ExcludeSemantics(child: Icon(icon, color: PlayerNight.cyan, size: 18)),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: theme.textTheme.labelLarge)),
        const SizedBox(width: 8),
        ExcludeSemantics(
          child: Text(
            caption,
            style: theme.textTheme.labelSmall?.copyWith(color: PlayerNight.muted, letterSpacing: 1.5),
          ),
        ),
      ],
    );
  }
}

class _CameraFramePainter extends CustomPainter {
  const _CameraFramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final frame = (Offset.zero & size).deflate(1);
    canvas.drawRRect(
      RRect.fromRectAndRadius(frame, const Radius.circular(13)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = PlayerNight.line,
    );
    final cornerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = PlayerNight.cyan;
    final cornerFrame = frame.deflate(10);
    const length = 20.0;
    for (final corner in [cornerFrame.topLeft, cornerFrame.topRight, cornerFrame.bottomLeft, cornerFrame.bottomRight]) {
      final horizontal = corner.dx == cornerFrame.left ? length : -length;
      final vertical = corner.dy == cornerFrame.top ? length : -length;
      canvas.drawPath(
        Path()
          ..moveTo(corner.dx + horizontal, corner.dy)
          ..lineTo(corner.dx, corner.dy)
          ..lineTo(corner.dx, corner.dy + vertical),
        cornerPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_CameraFramePainter oldDelegate) => false;
}
