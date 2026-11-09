import 'dart:math' as math;

import 'calendar.dart' as calendar;
import 'format.dart';
import 'stats_range.dart';

/// 一个动作相对「范围起点」的变化类型。
enum StrengthChange {
  /// 只有一次记录。
  first,

  /// 比基准提高了。
  up,

  /// 比基准下降了。
  down,

  /// 与基准一样。
  flat,

  /// 范围内没练过这个动作（只在 4 周 / 12 周里出现）。
  idle,
}

/// 变化的对比基准。
enum StrengthBase {
  /// 所选范围的起点（4 周前 / 12 周前）。
  rangeStart,

  /// 范围起点之前没有记录：与这个动作的第一次记录相比（「全部」也是这样）。
  firstRecord,
}

/// 力量块里的一行：动作、最佳成绩、变化。
class StrengthRow {
  const StrengthRow({
    required this.best,
    required this.points,
    required this.bodyweight,
    required this.change,
    required this.base,
    required this.delta,
    required this.lastIso,
  });

  /// stats['bests'] 里这个动作的一项。
  final Map<String, dynamic> best;

  /// stats['exercises'] 里这个动作每次训练的估算极限，按日期升序。
  final List<Map<String, dynamic>> points;

  /// 纯自重动作：比较与展示都用次数。
  final bool bodyweight;
  final StrengthChange change;
  final StrengthBase base;

  /// 变化量的绝对值（保留 1 位小数）；[change] 为 up / down 时有意义。
  final num delta;
  final String lastIso;
  String get name => '${best['ex']}';
}

/// 把「个人最佳」和「估算极限曲线」合成力量块的行：进步的动作在前，其次按最近训练时间。
List<StrengthRow> strengthRows({
  required List<Map<String, dynamic>> exercises,
  required List<Map<String, dynamic>> bests,
  required String today,
  required StatsRange range,
}) {
  final windowDays = switch (range) {
    StatsRange.weeks4 => 28,
    StatsRange.weeks12 => 84,
    StatsRange.all => 0,
  };
  final edge = calendar.shiftDate(today, -windowDays);
  final recent = calendar.shiftDate(today, -(windowDays - 1));
  final rows = <StrengthRow>[];
  for (final b in bests) {
    final ex = exercises.where((e) => e['ex'] == b['ex']).firstOrNull;
    final points = ex == null
        ? <Map<String, dynamic>>[]
        : jsonRows(ex['points']);
    if (points.isEmpty) continue;
    final body = points.every((e) => jsNumber(e['weight']) == 0);
    num key(Map<String, dynamic> e) => jsNumber(body ? e['reps'] : e['e1']);
    final last = '${points.last['iso']}';
    var change = StrengthChange.first;
    var base = StrengthBase.rangeStart;
    num delta = 0;
    if (points.length > 1) {
      final before = range == StatsRange.all
          ? points.take(1)
          : points.where((e) => '${e['iso']}'.compareTo(edge) <= 0);
      final within = range == StatsRange.all
          ? points.skip(1)
          : points.where((e) => '${e['iso']}'.compareTo(recent) >= 0);
      if (within.isEmpty) {
        change = StrengthChange.idle;
      } else {
        Iterable<Map<String, dynamic>> from = before, to = within;
        if (before.isEmpty) {
          // 这个动作是范围内才开始练的：和它的第一次记录比。
          base = StrengthBase.firstRecord;
          from = points.take(1);
          to = points.skip(1);
        } else if (range == StatsRange.all) {
          base = StrengthBase.firstRecord;
        }
        final d = to.map(key).reduce(math.max) - from.map(key).reduce(math.max);
        delta = (d.abs() * 10).round() / 10;
        change = d.abs() < .05
            ? StrengthChange.flat
            : (d > 0 ? StrengthChange.up : StrengthChange.down);
      }
    }
    rows.add(
      StrengthRow(
        best: b,
        points: points,
        bodyweight: body,
        change: change,
        base: base,
        delta: delta,
        lastIso: last,
      ),
    );
  }
  rows.sort((a, b) {
    final au = a.change == StrengthChange.up ? 0 : 1;
    final bu = b.change == StrengthChange.up ? 0 : 1;
    if (au != bu) return au.compareTo(bu);
    return b.lastIso.compareTo(a.lastIso);
  });
  return rows;
}
