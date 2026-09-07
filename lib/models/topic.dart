enum TopicSource { user, ai }

class Topic {
  const Topic({
    required this.id,
    required this.text,
    required this.source,
    this.contributedBy,
    this.used = false,
    this.usedInRound,
  });

  final String id;
  final String text;
  final TopicSource source;
  final String? contributedBy;
  final bool used;
  final int? usedInRound;

  Topic copyWith({bool? used, int? usedInRound}) {
    return Topic(
      id: id,
      text: text,
      source: source,
      contributedBy: contributedBy,
      used: used ?? this.used,
      usedInRound: usedInRound ?? this.usedInRound,
    );
  }
}
