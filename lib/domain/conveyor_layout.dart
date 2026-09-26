import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Offsets use logical pixels at [baseCanWidth]; rendering scales them with
/// the can, independently of the common phone viewport.
@immutable
class ConveyorLayout {
  const ConveyorLayout({this.scale = 1, this.offsetX = 0, this.offsetY = 0})
    : assert(scale >= minScale && scale <= maxScale),
      assert(offsetX >= minOffset && offsetX <= maxOffset),
      assert(offsetY >= minOffset && offsetY <= maxOffset);

  static const schemaVersion = 1;
  static const baseCanWidth = 286.0;
  static const minScale = .6;
  static const maxScale = 1.8;
  static const minOffset = -100.0;
  static const maxOffset = 100.0;

  final double scale;
  final double offsetX;
  final double offsetY;

  bool get isValid =>
      scale.isFinite &&
      scale >= minScale &&
      scale <= maxScale &&
      offsetX.isFinite &&
      offsetX >= minOffset &&
      offsetX <= maxOffset &&
      offsetY.isFinite &&
      offsetY >= minOffset &&
      offsetY <= maxOffset;

  ConveyorLayout copyWith({double? scale, double? offsetX, double? offsetY}) =>
      ConveyorLayout(
        scale: scale ?? this.scale,
        offsetX: offsetX ?? this.offsetX,
        offsetY: offsetY ?? this.offsetY,
      );

  Map<String, Object> toJson() {
    // Constructors also assert in debug mode, but saved data must be valid in
    // release builds, where assertions are disabled.
    if (!isValid) throw StateError('コンベアの配置が範囲外です。');
    return {
      'schemaVersion': schemaVersion,
      'scale': scale,
      'offsetX': offsetX,
      'offsetY': offsetY,
    };
  }

  String encode() => jsonEncode(toJson());

  factory ConveyorLayout.decode(String encoded) {
    final data = jsonDecode(encoded);
    const keys = {'schemaVersion', 'scale', 'offsetX', 'offsetY'};
    if (data is! Map<String, dynamic> ||
        data.length != keys.length ||
        !data.keys.every(keys.contains)) {
      throw const FormatException('コンベアの設定形式が正しくありません。');
    }
    if (data['schemaVersion'] is! int ||
        data['schemaVersion'] != schemaVersion) {
      throw const FormatException('このコンベア設定のバージョンには対応していません。');
    }
    double number(String key, double min, double max) {
      final value = data[key];
      if (value is! num || !value.isFinite || value < min || value > max) {
        throw FormatException('コンベア設定の$keyが範囲外です。');
      }
      return value.toDouble();
    }

    return ConveyorLayout(
      scale: number('scale', minScale, maxScale),
      offsetX: number('offsetX', minOffset, maxOffset),
      offsetY: number('offsetY', minOffset, maxOffset),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ConveyorLayout &&
      scale == other.scale &&
      offsetX == other.offsetX &&
      offsetY == other.offsetY;

  @override
  int get hashCode => Object.hash(scale, offsetX, offsetY);
}
