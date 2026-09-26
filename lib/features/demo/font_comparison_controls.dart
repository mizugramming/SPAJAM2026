import 'package:flutter/material.dart';

import '../../app/tsunagun_typography.dart';

/// A demo-only control. Changing typography keeps the current app state intact.
class FontComparisonControls extends StatelessWidget {
  const FontComparisonControls({super.key});

  @override
  Widget build(BuildContext context) {
    final typography = TypographyScope.maybeOf(context);
    if (typography == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 12),
        const Text(
          'フォントを比べる',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        RadioGroup<TsunagunTypeface>(
          groupValue: typography.typeface,
          onChanged: (value) {
            if (value != null) typography.onChanged(value);
          },
          child: Column(
            children: [
              for (final typeface in TsunagunTypeface.values)
                RadioListTile<TsunagunTypeface>(
                  key: Key(
                    typeface == TsunagunTypeface.kaiseiTokumin
                        ? 'font-kaisei'
                        : 'font-rounded',
                  ),
                  value: typeface,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    typeface.label,
                    style: TextStyle(
                      fontFamily: typeface.fontFamily,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    'Medium 500 · ツナがる',
                    style: TextStyle(
                      fontFamily: typeface.fontFamily,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
