import 'package:flutter_test/flutter_test.dart';
import 'package:spajam2026/models/participant.dart';
import 'package:spajam2026/models/room.dart';
import 'package:spajam2026/models/topic.dart';
import 'package:spajam2026/providers/conversation_provider.dart';
import 'package:spajam2026/services/ai_topic_service.dart';

void main() {
  const participant = Participant(
    id: 'participant-1',
    name: '山田 太郎',
    category: ParticipantCategory.student,
  );
  const topic = Topic(
    id: 'topic-1',
    text: '最近ハマっているもの',
    source: TopicSource.ai,
  );
  const room = Room(
    code: 'ABC234',
    expectedCount: 3,
    currentRound: 1,
    currentSelectorId: 'participant-1',
    participants: [participant],
  );

  test('完了したTopicは履歴に入り、再選択候補から除外される', () async {
    final provider = ConversationProvider(
      _QueuedAiTopicService([
        [topic],
      ]),
    );

    await provider.initialize([participant]);
    provider.openTopic(topic);
    provider.completeRound(room: room, selectorId: participant.id);

    expect(provider.history, hasLength(1));
    expect(provider.history.single.topicId, topic.id);
    expect(provider.availableTopics, isEmpty);

    provider.openTopic(topic);
    expect(provider.openedTopic, isNull);
  });

  test('Topic生成に失敗したあと再試行できる', () async {
    final provider = ConversationProvider(
      _QueuedAiTopicService([
        StateError('network error'),
        [topic],
      ]),
    );

    await provider.initialize([participant]);
    expect(provider.isInitialized, isFalse);
    expect(provider.initializationError, isNotNull);

    await provider.initialize([participant]);
    expect(provider.isInitialized, isTrue);
    expect(provider.initializationError, isNull);
    expect(provider.availableTopics, [topic]);
  });
}

class _QueuedAiTopicService implements AiTopicService {
  _QueuedAiTopicService(this._results);

  final List<Object> _results;
  var _index = 0;

  @override
  Future<List<Topic>> generateTopics({
    required List<Participant> participants,
    int count = 5,
  }) async {
    final result = _results[_index++];
    if (result is Error) throw result;
    return result as List<Topic>;
  }
}
