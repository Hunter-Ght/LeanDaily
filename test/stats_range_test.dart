import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/domain/muscles.dart';
import 'package:leandaily/domain/stats_range.dart';
import 'package:leandaily/ui/stats/progress_sections.dart';

Map<String, Map<String, dynamic>> _day(String date, String ex, String part) => {
  date: {
    'sets': [
      for (var i = 0; i < 3; i++)
        {
          'id': '$date-$i',
          'ts': dateMs(date, 10),
          'date': date,
          'part': part,
          'ex': ex,
          'w': 40,
          'reps': 10,
          'type': '正式',
        },
    ],
  },
};

void main() {
  const today = '2026-11-04';
  test('rangeWindow lengths', () {
    expect(rangeWindow(StatsRange.weeks4, today).days, 28);
    expect(rangeWindow(StatsRange.weeks12, today).days, 84);
    expect(rangeWindow(StatsRange.weeks12, today).from, '2026-08-13');
    expect(rangeWindow(StatsRange.all, today).days, 28);
    expect(
      rangeWindow(StatsRange.all, today, firstDate: '2026-01-01').days,
      308,
    );
    expect(
      rangeWindow(StatsRange.all, today, firstDate: '2026-10-30').days,
      28,
    );
  });

  test('summary follows the selected range', () {
    final days = {
      ..._day('2026-11-01', '杠铃卧推', '胸'),
      ..._day('2026-09-20', '杠铃卧推', '胸'),
      ..._day('2026-06-01', '杠铃卧推', '胸'),
    };
    final s4 = ProgressSummary.build(days, today);
    final s12 = ProgressSummary.build(days, today, StatsRange.weeks12);
    final all = ProgressSummary.build(days, today, StatsRange.all);
    expect(s4.trainDays, 1);
    expect(s12.trainDays, 2);
    expect(all.trainDays, 3);
    expect(s4.groupSets['chest'], 3);
    expect(s12.groupSets['chest'], 6);
    expect(all.groupSets['chest'], 9);
    expect(s12.heat.values.every((v) => v <= 1), isTrue);
  });
}
