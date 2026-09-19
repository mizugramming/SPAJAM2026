import 'package:flutter/material.dart';

enum CategoryType {
  challenge(
    'challenge',
    '挑戦',
    '新しいこと、目標',
    Color(0xFFDFB075),
    Icons.auto_awesome_outlined,
  ),
  relationships(
    'relationships',
    '人間関係',
    '友人、家族、会話',
    Color(0xFFDC9BB0),
    Icons.people_outline,
  ),
  future('future', '将来', 'これからのこと', Color(0xFFAFA0E4), Icons.explore_outlined),
  workStudy(
    'workStudy',
    '学業・仕事',
    '学び、日々の仕事',
    Color(0xFF84B6D8),
    Icons.menu_book_outlined,
  ),
  self('self', '自分自身', '心、からだ、自分のこと', Color(0xFF92C8B3), Icons.person_outline),
  dailyLife(
    'dailyLife',
    '日常',
    '暮らしのひとこま',
    Color(0xFFE4C798),
    Icons.coffee_outlined,
  );

  const CategoryType(this.id, this.label, this.hint, this.color, this.icon);
  final String id;
  final String label;
  final String hint;
  final Color color;
  final IconData icon;
  static CategoryType fromId(String id) => values.firstWhere(
    (value) => value.id == id,
    orElse: () => throw const FormatException('未対応のテーマIDです。'),
  );
}
