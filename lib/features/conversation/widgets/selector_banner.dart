import 'package:flutter/material.dart';

/// 「次は○○さん！」「○○さんがネタを選んでいます」を表示するバナー。
class SelectorBanner extends StatelessWidget {
  const SelectorBanner({super.key, required this.isMyTurn, required this.selectorName});

  final bool isMyTurn;
  final String selectorName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isMyTurn ? const Color(0xFFFFF3C4) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(38), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Text(
        isMyTurn ? 'あなたの番です。\n好きなネタを一皿取ってください' : '$selectorName さんがネタを選んでいます\nスマホを置いて少々お待ちください',
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}
