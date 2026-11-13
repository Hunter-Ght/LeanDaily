import 'package:flutter/widgets.dart';

import '../../domain/benchmarks.dart';
import '../../domain/format.dart' show fmt;
import '../../domain/units.dart';
import '../../l10n/localized_text.dart';
import '../../theme/theme.dart';
import '../kit/app_icon.dart';
import '../kit/units_scope.dart';

/// 一次测试里某项的数字（带单位换算），例如 `12`、`45`、`12.5`。
String benchNumber(Units units, String item, Map<String, dynamic> side) {
  if (item == 'pull' && side['type'] == 'assisted') {
    return units.load(side['n'] as num);
  }
  return fmt(side[item == 'plank' ? 'sec' : 'n']);
}

/// 数字的单位。
String benchUnit(Units units, String item, Map<String, dynamic> side) =>
    switch (item) {
      'plank' => '秒',
      'pull' => side['type'] == 'assisted' ? units.weightUnit : '次',
      _ => '次',
    };

/// 做法：俯卧撑的标准 / 跪姿，拉的类型。平板支撑没有。
String? benchVariant(String item, Map<String, dynamic> side) => switch (item) {
  'pushup' => side['knee'] == true ? '跪姿' : '标准',
  'pull' => benchmarkPullLabels['${side['type']}'],
  _ => null,
};

/// 「第一次 → 最近一次」的行，进度页和课程总结共用。只说数字的变化，不做评价。
class BenchmarkRows extends StatelessWidget {
  const BenchmarkRows({super.key, required this.rows, this.dates = false});

  /// `benchmarkRows` 的结果。
  final List<Map<String, dynamic>> rows;

  /// 在名称下面写出两次测试的日期。
  final bool dates;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [for (final r in rows) _Row(row: r, dates: dates)],
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.row, required this.dates});
  final Map<String, dynamic> row;
  final bool dates;

  @override
  Widget build(BuildContext context) {
    final p = context.pal, units = context.units;
    final item = '${row['item']}';
    final first = Map<String, dynamic>.from(row['first'] as Map);
    final latest = row['latest'] == null
        ? null
        : Map<String, dynamic>.from(row['latest'] as Map);
    final comparable = row['comparable'] == true;
    final variant = benchVariant(item, first);
    // 同一种做法：做法写在名称里；换了做法：每个数字前各自标出。
    final label = item == 'pull' && comparable
        ? '$variant'
        : benchmarkItemLabels[item]!;
    final tag = item == 'pushup' && comparable && first['knee'] == true
        ? '$label · $variant'
        : label;
    final unit = benchUnit(units, item, latest ?? first);
    Widget value(Map<String, dynamic> side, {bool strong = true}) => Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        if (!comparable && benchVariant(item, side) != null) ...[
          LText(
            benchVariant(item, side)!,
            style: TextStyle(fontSize: 12, color: p.secondary),
          ),
          const SizedBox(width: 4),
        ],
        Text(
          benchNumber(units, item, side),
          style: AppText.num(
            p,
            strong ? 26 : 20,
            color: strong ? p.text : p.secondary,
          ),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LText(
                  tag,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: p.text,
                  ),
                ),
                if (dates)
                  Text(
                    latest == null
                        ? '${row['firstDate']}'
                        : '${row['firstDate']} → ${row['latestDate']}',
                    style: TextStyle(fontSize: 12, color: p.secondary),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (latest != null) ...[
            value(first, strong: false),
            const SizedBox(width: 6),
            AppIcon('right', size: 14, color: p.tertiary),
            const SizedBox(width: 6),
          ],
          value(latest ?? first),
          const SizedBox(width: 4),
          LText(unit, style: TextStyle(fontSize: 13, color: p.secondary)),
        ],
      ),
    );
  }
}
