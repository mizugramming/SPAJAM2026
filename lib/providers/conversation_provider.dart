import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/participant.dart';
import '../models/room.dart';
import '../models/round_record.dart';
import '../models/topic.dart';
import '../services/ai_topic_service.dart';

/// 会話スペース(画面3)の状態: ネタ一覧・現在開いているネタ・選出履歴を管理する。
/// 「誰が次に選ぶか」「部屋を何ラウンド進めるか」の実際の反映はConversationScreenが
/// RoomProviderと合わせて行い、ここでは純粋なロジックのみを提供する。
class ConversationProvider extends ChangeNotifier {
  ConversationProvider(this._aiTopicService);

  final AiTopicService _aiTopicService;
  final Random _random = Random();

  List<Topic> _topics = [];
  List<Topic> get topics => List.unmodifiable(_topics);

  Topic? _openedTopic;
  Topic? get openedTopic => _openedTopic;

  final List<RoundRecord> _history = [];
  List<RoundRecord> get history => List.unmodifiable(_history);

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  Future<void> initialize(List<Participant> participants) async {
    if (_isInitialized) return;
    _isInitialized = true;
    _topics = await _aiTopicService.generateTopics(participants: participants);
    notifyListeners();
  }

  /// 選択回数が最小の参加者群から、可能であれば直前セレクターを除外してランダムに選ぶ。
  /// (AGENTS.md セクション12: 選択回数が少ない人を優先 → 同数ならランダム → 直前の人は可能な限り避ける)
  Participant pickNextSelector(List<Participant> participants, {String? excludeId}) {
    final minCount = participants.map((p) => p.selectionCount).reduce((a, b) => a < b ? a : b);
    var candidates = participants.where((p) => p.selectionCount == minCount).toList();
    if (candidates.length > 1 && excludeId != null) {
      final withoutLast = candidates.where((p) => p.id != excludeId).toList();
      if (withoutLast.isNotEmpty) candidates = withoutLast;
    }
    return candidates[_random.nextInt(candidates.length)];
  }

  void openTopic(Topic topic) {
    _openedTopic = topic;
    notifyListeners();
  }

  void completeRound({required Room room, required String selectorId}) {
    final opened = _openedTopic;
    if (opened == null) return;

    final index = _topics.indexWhere((t) => t.id == opened.id);
    if (index != -1) {
      _topics[index] = opened.copyWith(used: true, usedInRound: room.currentRound);
    }
    _history.add(RoundRecord(round: room.currentRound, selectorId: selectorId, topicId: opened.id));
    _openedTopic = null;
    notifyListeners();
  }
}
