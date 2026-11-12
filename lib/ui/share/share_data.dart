import 'dart:math' as math;

import '../../domain/calendar.dart' as calendar;
import '../../domain/format.dart';
import '../../domain/movements.dart' show muscleRoles, musclesOf;
import '../../domain/muscles.dart' show workSets;
import '../kit/body_figure.dart' show MuscleTone;

/// 一条新纪录。分享图上只放动作名；带重量的记录，重量默认不显示（预览里可以打开）。
class ShareRecord {
  const ShareRecord({required this.name, required this.detail, this.load});

  final String name;

  /// 不涉及重量的描述（如“12 次”），始终可显示。自重动作的纪录用它。
  final String detail;

  /// 带重量的描述（如“60 kg × 8”）；为 null 表示这条记录没有重量。只在用户打开“显示重量”时出现。
  final String? load;

  /// 当前开关下右侧要写的字；带重量且开关关闭时为 null（只写动作名）。
  String? shown(bool showWeight) =>
      load == null ? detail : (showWeight ? load : null);
}

/// 分享卡片的内容。只含训练信息：体重、体脂、腰围、热量、饮食从不进入这里。
sealed class ShareContent {
  const ShareContent();
}

/// 训练卡：练完后的小结。
class TrainShare extends ShareContent {
  const TrainShare({
    required this.iso,
    required this.title,
    required this.tones,
    required this.exercises,
    required this.sets,
    required this.minutes,
    this.records = const [],
  });

  final String iso;

  /// 今天练了哪里，例如“胸 · 背 · 腹”。
  final String title;
  final Map<String, MuscleTone> tones;
  final int exercises, sets, minutes;

  /// 最多 2 条。
  final List<ShareRecord> records;

  /// 标题：优先用计划里的训练名；没有名字时用今天练到的部位。
  static String titleOf(String workoutName, Iterable<String> parts) {
    final name = workoutName.trim();
    if (name.isNotEmpty && name != '训练') return name.replaceAll(' + ', ' · ');
    final seen = <String>[];
    for (final part in parts) {
      if (part.isNotEmpty && !seen.contains(part)) seen.add(part);
    }
    return seen.isEmpty ? '训练' : seen.take(4).join(' · ');
  }

  bool get hasRecords => records.isNotEmpty;
  bool get hasWeightedRecord => records.any((r) => r.load != null);
}

/// 周卡：一周的小结。
class WeekShare extends ShareContent {
  const WeekShare({
    required this.start,
    required this.end,
    required this.trained,
    required this.sets,
    required this.exercises,
    required this.streakWeeks,
    required this.heat,
  });

  /// 周一与周日（含）。
  final String start, end;

  /// 周一到周日，哪几天练了。
  final List<bool> trained;
  final int sets, exercises;

  /// 连续练了几周（本周算一周）。
  final int streakWeeks;

  /// 肌肉 id -> 0~1。
  final Map<String, double> heat;

  int get trainDays => trained.where((d) => d).length;

  /// 本周还没有任何正式组时返回 null（没有东西可分享）。
  static WeekShare? build(
    Map<String, Map<String, dynamic>> days,
    String today,
  ) {
    final start = calendar.mondayOf(today);
    final end = calendar.shiftDate(start, 6);
    final trained = List<bool>.filled(7, false);
    final weeks = <String>{};
    final names = <String>{};
    final raw = <String, double>{};
    var sets = 0;
    for (final s in workSets(days)) {
      if (jsTruthy(s['pending']) || '${s['id'] ?? ''}'.startsWith('pending-')) {
        continue;
      }
      final date = '${s['date']}';
      weeks.add(calendar.mondayOf(date));
      if (date.compareTo(start) < 0 || date.compareTo(end) > 0) continue;
      sets++;
      trained[calendar.daysApart(start, date)] = true;
      names.add('${s['ex']}');
      final mv = musclesOf(s['ex'], s['part'] as String?);
      if (mv == null) continue;
      for (final e in (mv['muscles'] as Map<String, num>).entries) {
        raw[e.key] = (raw[e.key] ?? 0) + e.value.toDouble();
      }
    }
    if (sets == 0) return null;
    // 分母至少 6：只练了一两组的一周不会被染成满色。
    final scale = math.max(raw.values.fold<double>(0, math.max), 6.0);
    var streak = 0;
    for (var cursor = start; weeks.contains(cursor); streak++) {
      cursor = calendar.shiftDate(cursor, -7);
    }
    return WeekShare(
      start: start,
      end: end,
      trained: trained,
      sets: sets,
      exercises: names.length,
      streakWeeks: streak,
      heat: {for (final e in raw.entries) e.key: e.value / scale},
    );
  }
}

/// 由今天的正式组（已去掉热身、只含今天计划里的动作）生成训练卡。
TrainShare trainShareFrom({
  required String iso,
  required String workoutName,
  required List<Map<String, dynamic>> rows,
  required int minutes,
  List<ShareRecord> records = const [],
}) {
  // 主练发力、辅助淡橙；同一块肌肉有主练就以主练为准。
  final tones = <String, MuscleTone>{};
  for (final row in rows) {
    for (final id in muscleRoles(row['ex'], '${row['part']}').main) {
      tones[id] = MuscleTone.effort;
    }
  }
  for (final row in rows) {
    for (final id in muscleRoles(row['ex'], '${row['part']}').assist) {
      tones.putIfAbsent(id, () => MuscleTone.assist);
    }
  }
  return TrainShare(
    iso: iso,
    title: TrainShare.titleOf(workoutName, [
      for (final r in rows) '${r['part']}',
    ]),
    tones: tones,
    exercises: {for (final r in rows) '${r['ex']}'}.length,
    sets: rows.length,
    minutes: math.max(1, minutes),
    records: records.take(2).toList(),
  );
}
