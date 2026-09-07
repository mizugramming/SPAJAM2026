import '../models/participant.dart';
import '../models/topic.dart';

/// 参加者情報から会話ネタを生成する窓口。実API(Cloud Functions経由)に差し替える際はこれを実装する。
abstract class AiTopicService {
  Future<List<Topic>> generateTopics({required List<Participant> participants, int count = 5});
}
