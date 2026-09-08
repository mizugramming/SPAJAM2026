import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class KaiwaTitleHero extends StatelessWidget {
  const KaiwaTitleHero({
    super.key,
    required this.compact,
    required this.hideCharacter,
  });

  final bool compact;
  final bool hideCharacter;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!hideCharacter)
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 430),
            height: compact ? 150 : 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: const Color(0xFFD7A449).withAlpha(135),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.darkBrown.withAlpha(35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      'assets/images/title_shop_background.png',
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      excludeFromSemantics: true,
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            AppTheme.darkBrown.withAlpha(18),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: compact ? -28 : -38,
                    child: Image.asset(
                      'assets/images/taishou.png',
                      height: compact ? 174 : 252,
                      fit: BoxFit.contain,
                      semanticLabel: '笑顔で迎える寿司職人',
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (!hideCharacter) SizedBox(height: compact ? 8 : 12),
        SizedBox(
          width: compact ? 132 : 156,
          height: compact ? 58 : 68,
          child: Image.asset(
            'assets/images/image.png',
            fit: BoxFit.contain,
            cacheWidth: 512,
            semanticLabel: '会輪',
          ),
        ),
        SizedBox(height: compact ? 4 : 6),
        SizedBox(
          width: compact ? 210 : 240,
          height: compact ? 54 : 62,
          child: Image.asset(
            'assets/images/tiitle.png',
            fit: BoxFit.contain,
            cacheWidth: 768,
            semanticLabel: 'ネタが回れば、会話が回る。',
          ),
        ),
      ],
    );
  }
}
