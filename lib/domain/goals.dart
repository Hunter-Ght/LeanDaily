// ignore_for_file: constant_identifier_names
import 'format.dart';

const GOAL_DEFAULTS = {'sets': 12, 'meals': 3, 'kcal': 1800, 'weekDays': 0};
int _clamp(Map<String, dynamic> g, String k, int lo, int hi, int fallback) {
  if (!g.containsKey(k)) return fallback;
  final n = jsNumber(g[k]);
  return n.isFinite ? (n + 0.5).floor().clamp(lo, hi) : fallback;
}

Map<String, dynamic> clampGoals(Object? raw) {
  final g = jsonMap(raw);
  return {
    'sets': _clamp(g, 'sets', 1, 40, 12),
    'meals': _clamp(g, 'meals', 1, 8, 3),
    'kcal': _clamp(g, 'kcal', 200, 8000, 1800),
    'weekDays': _clamp(g, 'weekDays', 0, 7, 0),
  };
}

num weekTargetFromHistory(
  num savedWeekDays,
  num planDays,
  Map<String, dynamic>? days,
) {
  if (savedWeekDays > 0) return savedWeekDays;
  if (planDays > 0) return planDays;
  num n = 0;
  for (final day in (days ?? {}).values) {
    final v = jsNumber(jsonMap(jsonMap(day)['day_row'])['周目标天数']);
    if (v > 0) n = v;
  }
  return n == 0 ? 4 : n;
}
