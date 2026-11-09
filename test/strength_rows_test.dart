import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/domain/stats_range.dart';
import 'package:leandaily/domain/strength_rows.dart';
import 'package:leandaily/domain/week_achievement.dart';

Map<String, dynamic> _pt(String iso, num weight, num reps) => {
  'iso': iso,
  'weight': weight,
  'reps': reps,
  'e1': weight * (1 + reps / 30),
};

Map<String, dynamic> _best(String ex, num weight, num reps) => {
  'ex': ex,
  'heavy': weight,
  'heavyReps': reps,
  'e1': weight * (1 + reps / 30),
};

List<StrengthRow> _rows(
  Map<String, List<Map<String, dynamic>>> data, [
  StatsRange range = StatsRange.weeks4,
]) => strengthRows(
  exercises: [
    for (final e in data.entries) {'ex': e.key, 'points': e.value},
  ],
  bests: [
    for (final e in data.entries)
      _best(
        e.key,
        e.value.map((p) => p['weight'] as num).reduce((a, b) => a > b ? a : b),
        e.value.last['reps'] as num,
      ),
  ],
  today: '2026-11-04',
  range: range,
);

void main() {
  group('strengthRows', () {
    test('single record is the first record', () {
      final r = _rows({
        '深蹲': [_pt('2026-11-01', 60, 8)],
      }).single;
      expect(r.change, StrengthChange.first);
      expect(r.bodyweight, isFalse);
    });

    test('improvement against the range start, in a 4 week window', () {
      final r = _rows({
        '卧推': [_pt('2026-09-20', 50, 10), _pt('2026-10-20', 60, 10)],
      }).single;
      expect(r.change, StrengthChange.up);
      expect(r.base, StrengthBase.rangeStart);
      expect(r.delta, closeTo(13.3, .01));
    });

    test('flat and down against the range start', () {
      final flat = _rows({
        '卧推': [_pt('2026-09-20', 60, 10), _pt('2026-10-20', 60, 10)],
      }).single;
      expect(flat.change, StrengthChange.flat);
      final down = _rows({
        '卧推': [_pt('2026-09-20', 60, 10), _pt('2026-10-20', 50, 10)],
      }).single;
      expect(down.change, StrengthChange.down);
      expect(down.delta, closeTo(13.3, .01));
    });

    test('started inside the range compares with the first record', () {
      final r = _rows({
        '卧推': [_pt('2026-10-20', 40, 10), _pt('2026-11-01', 45, 10)],
      }).single;
      expect(r.base, StrengthBase.firstRecord);
      expect(r.change, StrengthChange.up);
      expect(r.delta, closeTo(6.7, .01));
    });

    test('all range always compares with the first record', () {
      final r = _rows({
        '卧推': [_pt('2026-01-01', 40, 10), _pt('2026-11-01', 50, 10)],
      }, StatsRange.all).single;
      expect(r.base, StrengthBase.firstRecord);
      expect(r.change, StrengthChange.up);
    });

    test('not trained in the window is idle', () {
      final r = _rows({
        '卧推': [_pt('2026-06-01', 40, 10), _pt('2026-07-01', 50, 10)],
      }).single;
      expect(r.change, StrengthChange.idle);
    });

    test('bodyweight exercises compare repetitions', () {
      final r = _rows({
        '俯卧撑': [_pt('2026-09-20', 0, 10), _pt('2026-11-01', 0, 15)],
      }).single;
      expect(r.bodyweight, isTrue);
      expect(r.change, StrengthChange.up);
      expect(r.delta, 5);
    });

    test('improved exercises come first, then most recent', () {
      final rows = _rows({
        '老动作': [_pt('2026-10-01', 40, 10)],
        '新动作': [_pt('2026-11-02', 40, 10)],
        '进步': [_pt('2026-09-20', 40, 10), _pt('2026-10-10', 50, 10)],
      });
      expect(rows.map((r) => r.name), ['进步', '新动作', '老动作']);
    });
  });

  test('weekHits counts protein and kcal per day', () {
    final hits = weekHits(
      weekDays: [
        {'iso': '2026-11-02', 'train': true, 'kcal': 2000},
        {'iso': '2026-11-03', 'train': false, 'kcal': 2300},
        {'iso': '2026-11-04', 'train': false, 'kcal': 0},
      ],
      meals: {
        '2026-11-02': {
          'totals': {'protein': 130},
        },
        '2026-11-03': {
          'totals': {'protein': 90},
        },
      },
      proteinGoal: 120,
      kcalGoal: 2000,
    );
    expect(hits.map((h) => h.train), [true, false, false]);
    expect(hits.map((h) => h.protein), [true, false, false]);
    expect(hits.map((h) => h.kcal), [true, false, false]);
  });
}
