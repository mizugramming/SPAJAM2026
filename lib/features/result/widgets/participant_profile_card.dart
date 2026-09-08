import 'package:flutter/material.dart';

import '../../../models/participant.dart';

class ParticipantProfileCard extends StatelessWidget {
  const ParticipantProfileCard({
    super.key,
    required this.participant,
    required this.selectedTopics,
  });

  final Participant participant;
  final List<String> selectedTopics;

  static const _vermilion = Color(0xFFE04B36);
  static const _darkBrown = Color(0xFF3A2418);
  static const _mutedGold = Color(0xFFD7A449);
  static const _paper = Color(0xFFFFFCF5);

  String get _initial {
    final name = participant.name.trim();
    if (name.isEmpty) return '？';
    return String.fromCharCode(name.runes.first);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(7, 8, 7, 6),
      child: Align(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 610),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _paper,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: _vermilion, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: _darkBrown.withAlpha(35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  const Positioned(top: -42, right: -42, child: _PlateRing()),
                  const Positioned(bottom: -52, left: -48, child: _PlateRing()),
                  ListView(
                    shrinkWrap: true,
                    primary: false,
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
                    children: [
                      _ProfileHeader(
                        initial: _initial,
                        name: participant.name,
                        category: participant.category.label,
                      ),
                      const SizedBox(height: 17),
                      const _SectionTitle(label: '趣味'),
                      const SizedBox(height: 8),
                      _HobbyList(hobbies: participant.hobbies),
                      const SizedBox(height: 17),
                      const _SectionTitle(label: '持ち込んだネタ'),
                      const SizedBox(height: 8),
                      _SubmittedTopic(text: participant.submittedTopic),
                      const SizedBox(height: 17),
                      _SectionTitle(label: '${participant.name}さんが選んだネタ'),
                      const SizedBox(height: 8),
                      _SelectedTopicList(topics: selectedTopics),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.initial,
    required this.name,
    required this.category,
  });

  final String initial;
  final String name;
  final String category;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: ParticipantProfileCard._vermilion,
            shape: BoxShape.circle,
            border: Border.all(
              color: ParticipantProfileCard._mutedGold,
              width: 3,
            ),
          ),
          child: Text(
            initial,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              height: 1,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: ParticipantProfileCard._darkBrown,
                  fontSize: 23,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 7),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: ParticipantProfileCard._vermilion,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  category,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: ParticipantProfileCard._vermilion,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 9),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              color: ParticipantProfileCard._darkBrown,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Divider(color: ParticipantProfileCard._mutedGold),
        ),
      ],
    );
  }
}

class _HobbyList extends StatelessWidget {
  const _HobbyList({required this.hobbies});

  final List<String> hobbies;

  @override
  Widget build(BuildContext context) {
    if (hobbies.isEmpty) {
      return const _EmptyText('登録されていません');
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final hobby in hobbies)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: ParticipantProfileCard._vermilion),
            ),
            child: Text(
              hobby,
              style: const TextStyle(
                color: ParticipantProfileCard._darkBrown,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

class _SubmittedTopic extends StatelessWidget {
  const _SubmittedTopic({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final hasTopic = text.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ParticipantProfileCard._mutedGold, width: 2),
        boxShadow: [
          BoxShadow(
            color: ParticipantProfileCard._darkBrown.withAlpha(20),
            blurRadius: 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        hasTopic ? text : 'なし',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: hasTopic
              ? ParticipantProfileCard._darkBrown
              : Colors.brown.shade300,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SelectedTopicList extends StatelessWidget {
  const _SelectedTopicList({required this.topics});

  final List<String> topics;

  @override
  Widget build(BuildContext context) {
    if (topics.isEmpty) {
      return const _EmptyText('まだ選んだネタはありません');
    }

    return Column(
      children: [
        for (var index = 0; index < topics.length; index++) ...[
          _SelectedTopicRow(number: index + 1, text: topics[index]),
          if (index != topics.length - 1) const SizedBox(height: 9),
        ],
      ],
    );
  }
}

class _SelectedTopicRow extends StatelessWidget {
  const _SelectedTopicRow({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 10, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(220),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ParticipantProfileCard._vermilion.withAlpha(175),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: ParticipantProfileCard._vermilion,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: ParticipantProfileCard._darkBrown,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyText extends StatelessWidget {
  const _EmptyText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(color: Colors.brown.shade400),
    );
  }
}

class _PlateRing extends StatelessWidget {
  const _PlateRing();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: 118,
        height: 118,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: ParticipantProfileCard._mutedGold.withAlpha(38),
            width: 12,
          ),
        ),
      ),
    );
  }
}
