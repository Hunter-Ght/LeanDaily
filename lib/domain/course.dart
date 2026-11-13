/// 12 周课程：给方案一条看得见的路线（打底 → 加量 → 冲刺 → 减量复测）。
///
/// 纯函数。方案带 `plan['course'] = {'v': 1, 'start': 'YYYY-MM-DD', 'weeks': 12}`
/// 才有课程；没有这个字段的方案（所有老方案）完全不受影响。
///
/// 第几周按「练了的周」算，不按日历：课程周 = 1 + 开始日所在周之后、本周之前、
/// 至少有一天正式训练（非热身组）的整周数，封顶 12。中途停一两周不会白白耗掉课程。
/// 已有 12 个练了的整周，课程完成。
library;

import 'dart:math' as math;

import 'calendar.dart' show mondayOf, shiftDate;
import 'e1rm.dart';
import 'format.dart' show jsNumber, jsTruthy, jsonMap, jsonRows;

/// 课程总周数。
const courseWeeks = 12;

enum CoursePhase { base, build, push, retest }

/// 每个阶段覆盖的课程周（含两端）。
const coursePhaseWeeks = <CoursePhase, (int, int)>{
  CoursePhase.base: (1, 4),
  CoursePhase.build: (5, 8),
  CoursePhase.push: (9, 11),
  CoursePhase.retest: (12, 12),
};

/// 阶段的界面名称（整句走翻译表）。
const coursePhaseNames = <CoursePhase, String>{
  CoursePhase.base: '打底期',
  CoursePhase.build: '加量期',
  CoursePhase.push: '冲刺期',
  CoursePhase.retest: '减量复测周',
};

/// 一句话指引（余力说法）。
const coursePhaseTips = <CoursePhase, String>{
  CoursePhase.base: '先学动作：每组留 3 次余力，动作做标准比做多更重要。',
  CoursePhase.build: '按方案的组数做，每组留 2～3 次余力。',
  CoursePhase.push: '组数不变，每组留 1～2 次余力，能加就加。',
  CoursePhase.retest: '这周每个动作少做 1 组，养足精神，再做一次小测试。',
};

/// 路线弹层里「这一段做什么」。
const coursePhaseDo = <CoursePhase, String>{
  CoursePhase.base: '组数 3 组以上的动作各少做 1 组，每组留 3 次余力。',
  CoursePhase.build: '按方案的组数做，每组留 2～3 次余力。',
  CoursePhase.push: '组数不变，每组留 1～2 次余力，能加次数或重量就加。',
  CoursePhase.retest: '每个动作少做 1 组，再做一次小测试，和第一次比比。',
};

/// 路线弹层里「为什么」。
const coursePhaseWhy = <CoursePhase, String>{
  CoursePhase.base: '刚开始的进步主要来自动作越来越熟练。练得轻一点，肌肉和关节有时间适应。',
  CoursePhase.build: '动作稳了，这时把训练量补足，肌肉才有长的理由。',
  CoursePhase.push: '再逼近一点，把前面攒下的底子用起来。',
  CoursePhase.retest: '少练一点让身体缓过来，状态好的时候测出来的数字才有可比性。',
};

CoursePhase phaseOfWeek(int week) {
  for (final e in coursePhaseWeeks.entries) {
    if (week >= e.value.$1 && week <= e.value.$2) return e.key;
  }
  return week < 1 ? CoursePhase.base : CoursePhase.retest;
}

final _dateRe = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// 方案里的课程设置（规范化）；没有课程或格式不对返回 null。
Map<String, dynamic>? courseOf(Map<String, dynamic>? plan) {
  final c = plan?['course'];
  if (c is! Map || c['v'] != 1) return null;
  final start = c['start'];
  if (start is! String || !_dateRe.hasMatch(start)) return null;
  final day = DateTime.tryParse('${start}T12:00:00Z');
  if (day == null || day.toIso8601String().substring(0, 10) != start) {
    return null;
  }
  return {'v': 1, 'start': start, 'weeks': courseWeeks};
}

/// 新一轮课程的设置，从 [start] 开始。
Map<String, dynamic> newCourse(String start) => {
  'v': 1,
  'start': start,
  'weeks': courseWeeks,
};

bool _formal(Map<String, dynamic> s) =>
    s['type'] != '热身' && !jsTruthy(s['deleted']);

/// 有正式训练的日期。
Set<String> trainedDatesOf(Map<String, dynamic>? days) => {
  for (final e in (days ?? const <String, dynamic>{}).entries)
    if (jsonRows(jsonMap(e.value)['sets']).any(_formal)) e.key,
};

/// 至少有一天正式训练的周（用周一的日期表示）。
Set<String> trainedWeeksOf(Map<String, dynamic>? days) => {
  for (final d in trainedDatesOf(days)) mondayOf(d),
};

/// 某天的课程状态。
class CourseState {
  const CourseState({
    required this.start,
    required this.week,
    required this.completedWeeks,
    required this.weekStart,
  });

  /// 课程开始日。
  final String start;

  /// 当前课程周（1–12）。
  final int week;

  /// 开始日所在周之后、当天所在周之前，练了的整周数（可以超过 12）。
  final int completedWeeks;

  /// 当前课程周是从哪天开始的（第 1 周是开始日，之后是前一个练了的周的下周一）。
  final String weekStart;

  /// 已经有 12 个练了的整周。
  bool get done => completedWeeks >= courseWeeks;

  /// 完成后不再有阶段。
  CoursePhase? get phase => done ? null : phaseOfWeek(week);
}

/// [date] 这天的课程状态；没有课程、或 [date] 早于开始日返回 null。
CourseState? courseState(
  Map<String, dynamic>? course,
  Set<String> trainedWeeks,
  String date,
) {
  if (course == null) return null;
  final start = course['start'] as String;
  if (date.compareTo(start) < 0) return null;
  final startMonday = mondayOf(start), dateMonday = mondayOf(date);
  final weeks =
      trainedWeeks
          .where(
            (w) => w.compareTo(startMonday) > 0 && w.compareTo(dateMonday) < 0,
          )
          .toList()
        ..sort();
  final week = math.min(courseWeeks, 1 + weeks.length);
  return CourseState(
    start: start,
    week: week,
    completedWeeks: weeks.length,
    weekStart: week == 1 ? start : shiftDate(weeks[week - 2], 7),
  );
}

/// 课程周对应的组数：打底期组数 ≥ 3 的动作少 1 组；复测周少 1 组（最少 1 组）；其余不变。
num courseSets(num planned, CoursePhase? phase) => switch (phase) {
  CoursePhase.base => planned >= 3 ? planned - 1 : planned,
  CoursePhase.retest => math.max(1, planned - 1),
  _ => planned,
};

/// 课程少做的组数（0 或 1）。
num courseSetsCut(num planned, CoursePhase? phase) =>
    planned - courseSets(planned, phase);

// ------------------------------------------------------------------ 总结

String _dateEnd(Set<String> weeks, String start) {
  final list = weeks.where((w) => w.compareTo(mondayOf(start)) > 0).toList()
    ..sort();
  return list.length >= courseWeeks
      ? shiftDate(list[courseWeeks - 1], 6)
      : '9999-12-31';
}

/// 课程完成后的总结数据。
///
/// - `days`：课程期间练了几天；
/// - `hitWeeks` / `weeks`：这 12 个练了的周里，练满方案每周天数的有几周；
/// - `top`：进步最大的几个动作（带重量的比估算极限，自重的比次数或秒数，口径同 `e1rm.dart`）。
///
/// 小测试的前后对比由 `benchmarks.dart` 的 `benchmarkRows` 给出，界面一起展示。
Map<String, dynamic> courseSummary({
  required Map<String, dynamic> course,
  required Map<String, dynamic> days,
  required int planDays,
  Set<String> timedNames = const {},
  int topCount = 3,
}) {
  final start = course['start'] as String;
  final weeks = trainedWeeksOf(days);
  final end = _dateEnd(weeks, start);
  final inWindow = [
    for (final e in days.entries)
      if (e.key.compareTo(start) >= 0 && e.key.compareTo(end) <= 0) e,
  ];
  final trainedDays = <String>{};
  final perWeek = <String, int>{};
  // 动作 -> 日期 -> 当天最好的成绩；是否带过重量。
  final best = <String, Map<String, num>>{};
  final loaded = <String>{};
  for (final e in inWindow) {
    final sets = jsonRows(jsonMap(e.value)['sets']).where(_formal).toList();
    if (sets.isEmpty) continue;
    trainedDays.add(e.key);
    perWeek.update(mondayOf(e.key), (n) => n + 1, ifAbsent: () => 1);
    for (final s in sets) {
      final name = '${s['ex']}';
      final w = jsNumber(s['w']), reps = jsNumber(s['reps']);
      if (name.isEmpty || !w.isFinite || !reps.isFinite || reps <= 0) continue;
      if (w > 0) loaded.add(name);
      final m = strengthMetric(w, reps);
      final byDate = best.putIfAbsent(name, () => {});
      byDate[e.key] = math.max(byDate[e.key] ?? 0, m);
    }
  }
  final need = math.max(1, planDays);
  final counted =
      (perWeek.keys.where((w) => w.compareTo(mondayOf(start)) > 0).toList()
            ..sort())
          .take(courseWeeks);
  final hitWeeks = counted.where((w) => perWeek[w]! >= need).length;
  final top = <Map<String, dynamic>>[];
  for (final e in best.entries) {
    final dates = e.value.keys.toList()..sort();
    if (dates.length < 2) continue;
    final first = e.value[dates.first]!;
    final peak = dates.skip(1).map((d) => e.value[d]!).reduce(math.max);
    if (first <= 0 || peak <= first) continue;
    final weighted = loaded.contains(e.key);
    num r(num v) => (v * 10).round() / 10;
    top.add({
      'name': e.key,
      'kind': weighted
          ? 'weight'
          : timedNames.contains(e.key)
          ? 'sec'
          : 'reps',
      'from': weighted ? r(first) : first.round(),
      'to': weighted ? r(peak) : peak.round(),
      'ratio': peak / first,
    });
  }
  top.sort((a, b) => (b['ratio'] as num).compareTo(a['ratio'] as num));
  return {
    'days': trainedDays.length,
    'hitWeeks': hitWeeks,
    'weeks': courseWeeks,
    'top': top.take(topCount).toList(),
  };
}
