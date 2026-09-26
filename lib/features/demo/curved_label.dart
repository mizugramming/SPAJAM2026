import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Prints a non-interactive label along the shallow curve of the can.
///
/// The original child still handles wrapping, text scaling, and semantics.
/// Painting uses its vector commands, without turning the text into an image.
/// [drop] logical pixels are reserved below the child for the curved baseline.
/// Keep animated/composited content outside this label; that content is painted
/// normally so its layers are never duplicated.
class CurvedLabel extends StatelessWidget {
  const CurvedLabel({super.key, required this.child, this.drop = defaultDrop})
    : assert(drop >= 0 && drop < double.infinity);

  static const double defaultDrop = 7;

  final Widget child;
  final double drop;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: Padding(
      padding: EdgeInsets.only(bottom: drop),
      child: _CurvedPrint(drop: drop, child: child),
    ),
  );
}

class _CurvedPrint extends SingleChildRenderObjectWidget {
  const _CurvedPrint({required this.drop, required super.child});

  final double drop;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderCurvedPrint(drop);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderCurvedPrint renderObject,
  ) {
    renderObject.drop = drop;
  }
}

class _RenderCurvedPrint extends RenderProxyBox {
  _RenderCurvedPrint(this._drop);

  double _drop;

  set drop(double value) {
    if (_drop == value) return;
    _drop = value;
    markNeedsPaint();
  }

  @override
  Rect get paintBounds => Offset.zero & Size(size.width, size.height + _drop);

  @override
  void paint(PaintingContext context, Offset offset) {
    final label = child;
    if (label == null) return;
    if (_drop == 0 || size.isEmpty || label.needsCompositing) {
      super.paint(context, offset);
      return;
    }

    // Record vector commands once, then reuse them in narrow, sheared strips.
    // Repainting the entire text subtree for every strip would be expensive.
    final handle = LayerHandle<ContainerLayer>(ContainerLayer());
    try {
      final recording = _LabelRecording(handle.layer!, label.paintBounds);
      recording.paintChild(label, Offset.zero);
      recording.finish();
      final pictureLayer = handle.layer!.firstChild;
      if (pictureLayer is! PictureLayer || pictureLayer.picture == null) return;

      final canvas = context.canvas;
      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      final strips = (size.width / 2).ceil();
      final stripWidth = size.width / strips;
      for (var i = 0; i < strips; i++) {
        final left = stripWidth * i;
        final right = math.min(left + stripWidth, size.width);
        final center = (left + right) / 2;
        final fraction = center / size.width;
        final down = 4 * _drop * fraction * (1 - fraction);
        final slope = 4 * _drop / size.width * (1 - 2 * fraction);
        final transform = Matrix4.identity()
          ..setEntry(1, 0, slope)
          ..setEntry(1, 3, down - slope * center);
        canvas.save();
        canvas.clipRect(
          Rect.fromLTRB(left, 0, right, size.height + _drop),
          doAntiAlias: false,
        );
        canvas.transform(transform.storage);
        canvas.drawPicture(pictureLayer.picture!);
        canvas.restore();
      }
      canvas.restore();
    } finally {
      // Disposes both the temporary layer and its recorded vector picture.
      handle.layer = null;
    }
  }
}

class _LabelRecording extends PaintingContext {
  _LabelRecording(super.containerLayer, super.estimatedBounds);

  void finish() => stopRecordingIfNeeded();
}
