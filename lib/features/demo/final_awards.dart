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
    final topRankings = snapshot.rankings.where((entry) => entry.rank <= 3);
    final selfBelowTop = snapshot.rankings.where(
      (entry) => entry.participant.isSelf && entry.rank > 3,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const _AwardCharacters(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '今日のMVP',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  if (mvps.isEmpty) ...[
                    const Text('今回は該当者なし'),
                    const SizedBox(height: 4),
                    const Text(
                      'まだ交流結果がないため、MVPはいません。',
                      style: TextStyle(fontSize: 13),
                    ),
                  ] else
                    ...mvps.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              entry.participant.profile.nickname,
                              style: TextStyle(
                                fontSize: 22,
                                height: 1.3,
                                fontWeight: FontWeight.w500,
                                color: _teamColor(entry.participant.team),
                              ),
                            ),
                            Text(
                              'ちから ${entry.power}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'このルームのランキング',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        ...topRankings.map(
          (entry) => _RankingRow(
            key: ValueKey('ranking-${entry.participant.id}'),
            entry: entry,
          ),
        ),
        if (selfBelowTop.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text(
            'あなたの順位',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          ...selfBelowTop.map(
            (entry) => _RankingRow(
              key: ValueKey('ranking-${entry.participant.id}'),
              entry: entry,
            ),
          ),
        ],
      ],
    );
  }
}

Color _teamColor(Team team) =>
    team == Team.red ? TsunagunColors.red : TsunagunColors.blue;

class _AwardCharacters extends StatelessWidget {
  const _AwardCharacters();

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: 110,
      height: 104,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 10,
            right: 10,
            child: Image.asset(parentAsset, height: 80),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            child: Image.asset(normalFollowerAsset, width: 42, height: 34),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Image.asset(boneFollowerAsset, width: 42, height: 30),
          ),
        ],
      ),
    ),
  );
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({super.key, required this.entry});
  final RankEntry entry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 26),
          child: Text(
            '${entry.rank}',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w500,
              color: _teamColor(entry.participant.team),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 2,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '${entry.participant.profile.nickname}${entry.participant.isSelf ? '（あなた）' : ''}',
                    style: const TextStyle(
                      fontSize: 17,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    entry.participant.team.label,
                    style: TextStyle(
                      fontSize: 12,
                      color: _teamColor(entry.participant.team),
                    ),
                  ),
                  Text(
                    'ちから ${entry.power}',
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Wrap(
                spacing: 10,
                runSpacing: 2,
                children: [
                  _CountLine(
                    asset: normalFollowerAsset,
                    text:
                        '子分 ${entry.normalCount}匹 × 3pt = ${entry.normalCount * 3}pt',
                  ),
                  _CountLine(
                    asset: boneFollowerAsset,
                    text: '骨 ${entry.boneCount}匹 × 1pt = ${entry.boneCount}pt',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _CountLine extends StatelessWidget {
  const _CountLine({required this.asset, required this.text});
  final String asset;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Image.asset(asset, width: 22, height: 21, excludeFromSemantics: true),
      const SizedBox(width: 4),
      Flexible(
        child: Text(text, style: const TextStyle(fontSize: 13, height: 1.3)),
      ),
    ],
  );
}
