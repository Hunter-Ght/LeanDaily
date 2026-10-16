import 'calendar.dart' show mondayOf, daysApart;
import 'format.dart';
import 'plan.dart';
import 'progress.dart' as progression;
import 'progress_options.dart';

/// A proposal only: callers persist an acceptance before changing any target.
Map<String, dynamic>? deloadSuggestion({
  required Map<String, dynamic> days,
  required Map<String, dynamic> dayStates,
  required Map<String, dynamic> progress,
  required Map<String, dynamic> plan,
  required String today,
  String? stage,
  ProgressOptions? options,
}) {
  if (options == null || options.deloadActive) return null;
  final last = jsonMap(progress['deload'])['last'];
  if (last is String && daysApart(last, today) < 42) return null;
  final declined = jsonMap(progress['declined'])['deload'];
  if (declined is String && daysApart(declined, today) < 14) return null;
  final weeks = <String>{}, intenseWeeks = <String>{};
  for (final entry in days.entries) {
    if (entry.key.compareTo(today) > 0) continue;
    if (jsonRows(jsonMap(entry.value)['sets'])
        .any((s) => s['type'] != '热身' && !jsTruthy(s['deleted']))) {
      weeks.add(mondayOf(entry.key));
      if (jsonRows(jsonMap(entry.value)['sets']).any(
        (s) =>
            s['type'] != '热身' &&
            !jsTruthy(s['deleted']) &&
            s['rpe'] != null &&
            jsNumber(s['rpe']) >= 8,
      )) {
        intenseWeeks.add(mondayOf(entry.key));
      }
    }
  }
  final monday = mondayOf(today);
  final recentWeeks = List.generate(6, (i) => shiftDate(monday, -7 * i));
  if (recentWeeks.where(weeks.contains).length < 5) return null;
  var continuous = 0;
  // An unfinished current week must not break a run of completed weeks.
  var cursor = weeks.contains(monday) ? monday : shiftDate(monday, -7);
  while (weeks.contains(cursor)) {
    continuous++;
    cursor = shiftDate(cursor, -7);
  }
  var highIntensity = 0;
  cursor = weeks.contains(monday) ? monday : shiftDate(monday, -7);
  while (intenseWeeks.contains(cursor)) {
    highIntensity++;
    cursor = shiftDate(cursor, -7);
  }
  final from = shiftDate(today, -13);
  var fatigue = 0;
  for (final entry in dayStates.entries) {
    if (entry.key.compareTo(from) >= 0 &&
        entry.key.compareTo(today) <= 0 &&
        ['tired', 'bad'].contains(jsonMap(entry.value)['ready'])) {
      fatigue++;
    }
  }
  final stalled = <String>{};
  for (final workout in jsonMap(plan['workouts']).values) {
    final w = jsonMap(workout);
    for (final raw in [
      ...jsonRows(w['exercises']),
      ...jsonRows(jsonMap(w['gym'])['exercises']),
    ]) {
      final ex = resolveEx(plan, raw);
      final target = progression.targetFor(
        ex,
        days,
        today: today,
        include: true,
        progress: progress,
        dayStates: dayStates,
        options: options,
      );
      final date = target['lastDate'];
      if (date is String &&
          date.compareTo(from) >= 0 &&
          date.compareTo(today) <= 0 &&
          (jsNumber(target['stuck']) >= 2 ||
              jsNumber(target['belowMin']) >= 1)) {
        stalled.add(ex['name'] as String);
      }
    }
  }
  if (stalled.length < 3 && fatigue < 3 && highIntensity < 8) return null;
  final pain = progression.recentRedFlag(days, dayStates, today);
  return {
    'kind': 'deload',
    'key': 'deload',
    'title': '这周可以减量一周',
    'body':
        '已连续训练 $continuous 周，${stalled.length} 个动作需要恢复，近两周有 $fatigue 天疲劳较多。'
        '本周每个动作少做 1 组、重量降约 10%，恢复一下再继续。'
        '${pain ? '有疼痛或身体不适时先停止相关训练，持续不适请就医，减量不能代替休息和诊疗。' : ''}',
    'accept': {'type': 'deload', 'week': monday},
    'acceptLabel': '这周减量',
    'info': false,
  };
}
