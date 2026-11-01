import 'package:flutter/material.dart';

import 'player_ui.dart';

/// 共通のQR読み取りWidgetと読取状態を受け取る、Scaffoldのbody用表示。
///
/// 読取値の検証・重複通知の抑止・カメラの停止と再開は、注入側で行う。
class PlayerQrView extends StatelessWidget {
  const PlayerQrView({
    super.key,
    required this.title,
    required this.instruction,
    required this.scanner,
    this.isProcessing = false,
    this.feedback,
    this.onRetry,
  });

  final String title;
  final String instruction;
  final Widget scanner;
  final bool isProcessing;
  final String? feedback;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = PlayerNight.themeOf(context);

    return PlayerPage(
      title: title,
      description: instruction,
      eyebrow: 'QR SCANNER',
      actions: onRetry == null
          ? null
          : OutlinedButton.icon(
              onPressed: isProcessing ? null : onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('もう一度読み取る'),
            ),
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: PlayerNight.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: PlayerNight.line),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(17),
            child: AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AbsorbPointer(
                    absorbing: isProcessing,
                    child: ExcludeSemantics(excluding: isProcessing, child: scanner),
                  ),
                  IgnorePointer(
                    child: ExcludeSemantics(
                      child: CustomPaint(painter: _QrTargetPainter(processing: isProcessing)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            ExcludeSemantics(
              child: Icon(isProcessing ? Icons.sync : Icons.qr_code_scanner, size: 16, color: PlayerNight.cyan),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isProcessing ? 'QRコードを照合中' : 'QRコードを枠の中央へ',
                style: theme.textTheme.labelLarge?.copyWith(color: PlayerNight.cyan),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (isProcessing)
          const PlayerNotice(message: 'QRコードを確認しています…', busy: true)
        else
          PlayerSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const ExcludeSemantics(child: Icon(Icons.center_focus_strong, size: 20, color: PlayerNight.cyan)),
                    const SizedBox(width: 10),
                    Expanded(child: Text('読み取りのコツ', style: theme.textTheme.titleSmall)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('QRコード全体を枠の中央に収めてください。読み取りにくいときは、少し離して明るい場所でお試しください。'),
              ],
            ),
          ),
        if (isProcessing) ...[const SizedBox(height: 12), const Text('確認が終わるまで次の読み取りをお待ちください。')],
        if (feedback != null && feedback!.isNotEmpty) ...[const SizedBox(height: 16), PlayerNotice(message: feedback!)],
      ],
    );
  }
}

/// Static targeting marks only. Scanner pixels and camera events stay untouched.
class _QrTargetPainter extends CustomPainter {
  const _QrTargetPainter({required this.processing});

  final bool processing;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: size.width * 0.72,
      height: size.height * 0.72,
    );
    final surround = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(frame, const Radius.circular(12)));
    canvas.drawPath(surround, Paint()..color = PlayerNight.background.withValues(alpha: 0.50));
    final paint = Paint()
      ..color = processing ? PlayerNight.lime : PlayerNight.cyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.square;
    final length = size.width * 0.075;
    for (final corner in [frame.topLeft, frame.topRight, frame.bottomLeft, frame.bottomRight]) {
      final horizontal = corner.dx == frame.left ? length : -length;
      final vertical = corner.dy == frame.top ? length : -length;
      canvas.drawPath(
        Path()
          ..moveTo(corner.dx + horizontal, corner.dy)
          ..lineTo(corner.dx, corner.dy)
          ..lineTo(corner.dx, corner.dy + vertical),
        paint,
      );
    }
    if (!processing) {
      canvas.drawLine(
        Offset(frame.left + 12, frame.center.dy),
        Offset(frame.right - 12, frame.center.dy),
        Paint()
          ..color = PlayerNight.cyan.withValues(alpha: 0.65)
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(_QrTargetPainter oldDelegate) => processing != oldDelegate.processing;
}
