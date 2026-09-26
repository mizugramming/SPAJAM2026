import 'package:flutter/material.dart';

/// Both families are bundled as real Medium faces; no network font fetching.
enum TsunagunTypeface {
  kaiseiTokumin,
  mPlusRounded;

  String get fontFamily => switch (this) {
    kaiseiTokumin => 'KaiseiTokumin',
    mPlusRounded => 'MPlusRounded1c',
  };

  String get label => switch (this) {
    kaiseiTokumin => 'Kaisei Tokumin',
    mPlusRounded => 'M PLUS Rounded 1c',
  };
}

class TypographyScope extends InheritedWidget {
  const TypographyScope({
    super.key,
    required this.typeface,
    required this.onChanged,
    required super.child,
  });

  final TsunagunTypeface typeface;
  final ValueChanged<TsunagunTypeface> onChanged;

  static TypographyScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TypographyScope>();

  @override
  bool updateShouldNotify(TypographyScope oldWidget) =>
      typeface != oldWidget.typeface;
}
