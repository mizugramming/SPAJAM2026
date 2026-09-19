import 'package:flutter/material.dart';

enum EmotionType {
  joyful('joyful', 'うれしい', Color(0xFFFFD88A), Icons.wb_sunny_outlined),
  calm('calm', '穏やか', Color(0xFF9EDCCD), Icons.spa_outlined),
  neutral('neutral', 'ふつう', Color(0xFFDDDFEA), Icons.radio_button_unchecked),
  tired('tired', '疲れた', Color(0xFF94B8F5), Icons.nightlight_outlined),
  uneasy('uneasy', 'つらい・不安', Color(0xFFC1A0E9), Icons.cloud_outlined);

  const EmotionType(this.id, this.label, this.color, this.icon);
  final String id;
  final String label;
  final Color color;
  final IconData icon;
  static EmotionType fromId(String id) => values.firstWhere(
    (value) => value.id == id,
    orElse: () => throw const FormatException('未対応の感情IDです。'),
  );
}
