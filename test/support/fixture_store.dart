import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// Everything the spike screens need, straight from the web app's local-storage shape.
class AppData {
  AppData({
    required this.today,
    required this.now,
    required this.sets,
    required this.meals,
    required this.bodyPaths,
  });

  /// 'YYYY-MM-DD' of "today" in the fixture.
  final String today;

  /// The instant treated as "now" (local time).
  final DateTime now;

  /// All set rows, as in the web state: {id, ts, date, part, ex, no, w, reps, type, rpe, notes}.
  final List<Map<String, dynamic>> sets;

  /// All meal rows: {record_id, date, meal, time, items, kcal, protein, carbs, fat, ...}.
  final List<Map<String, dynamic>> meals;

  /// Body figure shapes (see assets/body_paths.json).
  final Map<String, dynamic> bodyPaths;

  /// {'YYYY-MM-DD': {'sets': [...]}} — the day map the domain functions take.
  Map<String, Map<String, dynamic>> get days {
    final out = <String, Map<String, dynamic>>{};
    for (final s in sets) {
      (out.putIfAbsent(
                s['date'] as String,
                () => {'sets': <Map<String, dynamic>>[]},
              )['sets']
              as List)
          .add(s);
    }
    return out;
  }

  Map<String, List<Map<String, dynamic>>> get mealsByDay {
    final out = <String, List<Map<String, dynamic>>>{};
    for (final m in meals) {
      out.putIfAbsent(m['date'] as String, () => []).add(m);
    }
    return out;
  }

  static AppData parse(String stateJson, String bodyJson) {
    final j = jsonDecode(stateJson) as Map<String, dynamic>;
    final st = j['state'] as Map<String, dynamic>;
    List<Map<String, dynamic>> rows(Object? m) => (m as Map<String, dynamic>)
        .values
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return AppData(
      today: j['today'] as String,
      now: DateTime.parse(j['now'] as String),
      sets: rows(st['sets']),
      meals: rows(st['meals']),
      bodyPaths: jsonDecode(bodyJson) as Map<String, dynamic>,
    );
  }

  static Future<AppData> load() async => parse(
    await rootBundle.loadString('assets/state.json'),
    await rootBundle.loadString('assets/body_paths.json'),
  );
}
