enum ParticipantCategory { student, worker, other }

extension ParticipantCategoryLabel on ParticipantCategory {
  String get label => switch (this) {
        ParticipantCategory.student => '学生',
        ParticipantCategory.worker => '社会人',
        ParticipantCategory.other => 'その他',
      };
}

class Participant {
  const Participant({
    required this.id,
    required this.name,
    required this.category,
    this.hobbies = const [],
    this.submittedTopic = '',
    this.ready = false,
    this.selectionCount = 0,
  });

  final String id;
  final String name;
  final ParticipantCategory category;
  final List<String> hobbies;
  final String submittedTopic;
  final bool ready;
  final int selectionCount;

  Participant copyWith({
    String? name,
    ParticipantCategory? category,
    List<String>? hobbies,
    String? submittedTopic,
    bool? ready,
    int? selectionCount,
  }) {
    return Participant(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      hobbies: hobbies ?? this.hobbies,
      submittedTopic: submittedTopic ?? this.submittedTopic,
      ready: ready ?? this.ready,
      selectionCount: selectionCount ?? this.selectionCount,
    );
  }
}
