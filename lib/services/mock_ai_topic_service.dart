import 'dart:math';

import '../models/participant.dart';
import '../models/topic.dart';
import 'ai_topic_service.dart';

class MockAiTopicService implements AiTopicService {
  MockAiTopicService({Random? random}) : _random = random ?? Random();

  final Random _random;
  int _nextId = 0;

  // AI API障害時にもデモを継続できるよう用意する固定Topic(AGENTS.md セクション25)。
  static const _fallbackTopics = [
    '最近ハマっているもの',
    '行ってみたい場所',
    '最近買ってよかったもの',
    'おすすめしたい作品',
    '休日の過ごし方',
    '今挑戦してみたいこと',
    '学生のうちにやりたいこと',
    'もし1日だけ何でもできるなら？',
  ];

  @override
  Future<List<Topic>> generateTopics({required List<Participant> participants, int count = 5}) async {
    await Future.delayed(const Duration(milliseconds: 400));

    final topics = <Topic>[];

    // User Topic: 各参加者が持ち込んだテーマ。
    for (final participant in participants) {
      if (participant.submittedTopic.trim().isEmpty) continue;
      topics.add(Topic(
        id: 'user-${participant.id}',
        text: participant.submittedTopic.trim(),
        source: TopicSource.user,
        contributedBy: participant.id,
      ));
    }

    // AI Topic: 現状は固定候補からのモック生成。実API接続後はここを差し替える。
    final pool = List<String>.from(_fallbackTopics)..shuffle(_random);
    for (final text in pool.take(count)) {
      _nextId += 1;
      topics.add(Topic(id: 'ai-$_nextId', text: text, source: TopicSource.ai));
    }

    topics.shuffle(_random);
    return topics;
  }
}
