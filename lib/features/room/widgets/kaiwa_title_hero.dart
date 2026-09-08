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
        const Text(
          '会輪',
          style: TextStyle(
            color: AppTheme.darkBrown,
            fontSize: 34,
            height: 1,
            fontWeight: FontWeight.w800,
            letterSpacing: 6,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'ネタが回れば、会話が回る。',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.darkBrown.withAlpha(190),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
