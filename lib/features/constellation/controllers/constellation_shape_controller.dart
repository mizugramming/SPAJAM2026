import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kShapeOverridesKey = 'constellation_shape_overrides_v1';

class ConstellationShape {
  const ConstellationShape({required this.points, required this.connections});

  final List<Offset> points;
  final List<List<int>> connections;

  Map<String, dynamic> toJson() => {
    'points': points.map((p) => [p.dx, p.dy]).toList(),
    'connections': connections,
  };

  factory ConstellationShape.fromJson(Map<String, dynamic> json) {
    return ConstellationShape(
      points: (json['points'] as List)
          .map(
            (p) => Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()),
          )
          .toList(),
      connections: (json['connections'] as List)
          .map((c) => (c as List).map((v) => v as int).toList())
          .toList(),
    );
  }
}

final constellationShapeOverridesProvider =
    AsyncNotifierProvider<
      ConstellationShapeOverridesNotifier,
      Map<String, ConstellationShape>
    >(ConstellationShapeOverridesNotifier.new);

class ConstellationShapeOverridesNotifier
    extends AsyncNotifier<Map<String, ConstellationShape>> {
  @override
  Future<Map<String, ConstellationShape>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kShapeOverridesKey);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map(
      (id, value) => MapEntry(
        id,
        ConstellationShape.fromJson(value as Map<String, dynamic>),
      ),
    );
  }

  Future<void> save(String id, ConstellationShape shape) async {
    final current = Map<String, ConstellationShape>.of(state.value ?? const {});
    current[id] = shape;
    await _persist(current);
    state = AsyncData(current);
  }

  Future<void> reset(String id) async {
    final current = Map<String, ConstellationShape>.of(state.value ?? const {});
    if (current.remove(id) == null) return;
    await _persist(current);
    state = AsyncData(current);
  }

  Future<void> _persist(Map<String, ConstellationShape> data) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      data.map((id, shape) => MapEntry(id, shape.toJson())),
    );
    await prefs.setString(_kShapeOverridesKey, encoded);
  }
}
