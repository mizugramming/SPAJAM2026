import 'package:flutter/material.dart';

/// A newline marks a preferred break in the Japanese copy. Short phrases
/// share a line whenever the available width allows it.
class PhraseText extends StatelessWidget {
  const PhraseText(this.text, {super.key, this.style, this.center = false});

  final String text;
  final TextStyle? style;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final phrases = text.split('\n');
    if (phrases.length == 1) {
      return Text(
        text,
        style: style,
        textAlign: center ? TextAlign.center : TextAlign.start,
      );
    }
    return Semantics(
      label: phrases.join(),
      excludeSemantics: true,
      child: Wrap(
        alignment: center ? WrapAlignment.center : WrapAlignment.start,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final phrase in phrases)
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(phrase, style: style, softWrap: false),
            ),
        ],
      ),
    );
  }
}
