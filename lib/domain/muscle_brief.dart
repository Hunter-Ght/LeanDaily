import 'calendar.dart' as calendar;
import 'movements.dart' show musclesOf;
import 'muscles.dart' show workSets;
import 'stats_range.dart';

/// 点热力人体图上一块肌肉后展开的小结：所选范围内的组数、上次练的日期、最常练的动作。
class MuscleBrief {
  const MuscleBrief({
    required this.sets,
    required this.lastDate,
    required this.daysSince,
    required this.top,
  });

  /// 所选范围内练到这块肌肉的正式组数（这块肌肉的参与度 ≥ 0.3 才算）。
  final int sets;

  /// 最近一次练到它的日期（不限范围）；从没练到过为 null。
  final String? lastDate;
  final int? daysSince;

  /// 范围内最常练的动作，最多 2 个。
  final List<String> top;
}

/// 动作对这块肌肉的参与度下限：和「主练 / 辅助」的划分一致（辅助 ≥ 0.3）。
const muscleBriefMinWeight = 0.3;

MuscleBrief muscleBrief(
  Map<String, Map<String, dynamic>> days,
  String muscleId,
  RangeWindow window,
  String today,
) {
  var sets = 0;
  String? last;
  final load = <String, double>{};
  final count = <String, int>{};
  final latest = <String, String>{};
  for (final s in workSets(days)) {
    final mv = musclesOf(s['ex'], s['part'] as String?);
    final w = (mv?['muscles'] as Map<String, num>?)?[muscleId];
    if (w == null || w < muscleBriefMinWeight) continue;
    final date = s['date'] as String;
    if (date.compareTo(today) > 0) continue;
    if (last == null || date.compareTo(last) > 0) last = date;
    if (!window.contains(date)) continue;
    sets++;
    final ex = '${s['ex']}';
    load[ex] = (load[ex] ?? 0) + w.toDouble();
    count[ex] = (count[ex] ?? 0) + 1;
    if ((latest[ex] ?? '').compareTo(date) < 0) latest[ex] = date;
  }
  final top = load.keys.toList()
    ..sort((a, b) {
      final c = load[b]!.compareTo(load[a]!);
      if (c != 0) return c;
      final d = latest[b]!.compareTo(latest[a]!);
      return d != 0 ? d : a.compareTo(b);
    });
  return MuscleBrief(
    sets: sets,
    lastDate: last,
    daysSince: last == null ? null : calendar.daysApart(last, today),
    top: top.take(2).toList(),
  );
}

/// 「多久没练」的短说法：今天 / N 天前 / N 周前 / N 个月前。
String sinceText(int days) {
  if (days <= 0) return '今天';
  if (days < 14) return '$days 天前';
  if (days < 70) return '${(days / 7).round()} 周前';
  return '${(days / 30).round()} 个月前';
}
