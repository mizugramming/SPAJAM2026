import 'package:flutter/material.dart';

import '../../app/tsunagun_theme.dart';
import '../../domain/models.dart';
import 'can_stage.dart';

class FinalAwards extends StatelessWidget {
  const FinalAwards({super.key, required this.snapshot});
  final FinalSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final mvps = snapshot.rankings.where(
      (entry) => snapshot.mvpIds.contains(entry.participant.id),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '今日のMVP',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 14),
        ExcludeSemantics(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Image.asset(normalFollowerAsset, width: 52, height: 45),
              const SizedBox(width: 8),
              Flexible(child: Image.asset(parentAsset, height: 112)),
              const SizedBox(width: 8),
              Image.asset(boneFollowerAsset, width: 52, height: 38),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (mvps.isEmpty) ...[
          const Text('今回は該当者なし', textAlign: TextAlign.center),
          const SizedBox(height: 6),
          const Text('まだ交流結果がないため、MVPはいません。', textAlign: TextAlign.center),
        ] else
          ...mvps.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                children: [
                  Text(
                    entry.participant.profile.nickname,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 25,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                      color: entry.participant.team == Team.red
                          ? TsunagunColors.red
                          : TsunagunColors.blue,
                    ),
                  ),
                  Text(
                    'ちから ${entry.power}',
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 24),
        const Text(
          'このルームのランキング',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        ...snapshot.rankings.map(
          (entry) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 32,
                  child: Text(
                    '${entry.rank}',
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${entry.participant.profile.nickname}${entry.participant.isSelf ? '（あなた）' : ''}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(entry.participant.team.label),
                      const SizedBox(height: 6),
                      _CountLine(
                        asset: normalFollowerAsset,
                        text:
                            '子分 ${entry.normalCount}匹 × 3pt = ${entry.normalCount * 3}pt',
                      ),
                      _CountLine(
                        asset: boneFollowerAsset,
                        text:
                            '骨 ${entry.boneCount}匹 × 1pt = ${entry.boneCount}pt',
                      ),
                      Text(
                        'ちから ${entry.power}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CountLine extends StatelessWidget {
  const _CountLine({required this.asset, required this.text});
  final String asset;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Image.asset(asset, width: 27, height: 24, excludeFromSemantics: true),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 13, height: 1.5)),
        ),
      ],
    ),
  );
}
