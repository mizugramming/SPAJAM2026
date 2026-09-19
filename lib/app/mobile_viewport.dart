import 'package:flutter/material.dart';
import '../core/constants/design_tokens.dart';

/// Constrains the entire navigator, including dialogs and bottom sheets.
class MobileViewport extends StatelessWidget {
  const MobileViewport({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth <= 600) return child;

      return ColoredBox(
        color: DesignTokens.background,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430, maxHeight: 932),
            child: LayoutBuilder(
              builder: (context, viewport) => MediaQuery(
                data: MediaQuery.of(context).copyWith(size: viewport.biggest),
                child: ClipRect(child: child),
              ),
            ),
          ),
        ),
      );
    },
  );
}
