/// 1ラウンド分の記録(誰が・どのネタを選んだか)。結果画面のプロフィールカードで使う。
class RoundRecord {
  const RoundRecord({
    required this.round,
    required this.selectorId,
    required this.topicId,
  });

  final int round;
  final String selectorId;
  final String topicId;
}
