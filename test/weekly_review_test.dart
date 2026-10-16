import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/domain/weekly_review.dart';

void main() {
  Map<String, dynamic>? review({
    String today = '2026-10-12',
    String done = '',
    String? stage = 'cut',
    double pct = 0,
    int mealCount = 4,
    int floor = 1500,
    int kcal = 2000,
    bool weights = true,
    int currentCount = 2,
    int previousCount = 2,
    bool onTarget = true,
    Map<String, Map<String, dynamic>> days = const {},
  }) => weeklyReview(
    today: today,
    done: done,
    stage: stage,
    kcalGoal: kcal,
    proteinGoal: 100,
    trainTarget: 3,
    kcalFloor: floor,
    days: days,
    meals: (date) =>
        int.parse(date.substring(8)) >= 5 &&
            int.parse(date.substring(8)) < 5 + mealCount
        ? {
            'meals': [{}],
            'totals': {'protein': 90, 'kcal': onTarget ? kcal : 10},
          }
        : {},
    bodyEntries: weights
        ? [
            for (var i = 0; i < previousCount; i++)
              {'date': '2026-09-${28 + i}', 'weightKg': 100},
            for (var i = 0; i < currentCount; i++)
              {'date': '2026-10-0${5 + i}', 'weightKg': 100 + pct},
          ]
        : [],
  );
  int? delta(Map<String, dynamic>? r) =>
      (r?['action'] as Map?)?['delta'] as int?;

  test('Monday through Thursday only; completed week and done gate', () {
    for (final day in [12, 13, 14, 15]) {
      final r = review(today: '2026-10-$day')!;
      expect(r['week'], '2026-10-05');
      expect(r['label'], '10月5日–10月11日');
    }
    for (final day in [16, 17, 18]) {
      expect(review(today: '2026-10-$day'), isNull);
    }
    expect(review(done: '2026-10-05'), isNull);
    expect(review(today: '2026-10-19'), isNull);
  });
  test('cut and trim boundaries and meal coverage', () {
    for (final stage in ['cut', 'trim']) {
      expect(delta(review(stage: stage, pct: -1)), 100);
      expect(delta(review(stage: stage, pct: -1.01)), 100);
      expect(delta(review(stage: stage, pct: -.99)), isNull);
      expect(review(stage: stage, pct: -.26)!['message'], contains('节奏很好'));
      expect(delta(review(stage: stage, pct: -.25)), -100);
      expect(delta(review(stage: stage, pct: 0)), -100);
      expect(delta(review(stage: stage, onTarget: false)), isNull);
      expect(
        review(stage: stage, mealCount: 3)!['message'],
        contains('饮食记录不多'),
      );
      expect(delta(review(stage: stage, mealCount: 3, pct: -2)), isNull);
    }
  });
  test('bulk boundaries', () {
    expect(delta(review(stage: 'bulk', pct: .09)), 150);
    expect(delta(review(stage: 'bulk', pct: .1)), isNull);
    expect(delta(review(stage: 'bulk', pct: .5)), isNull);
    expect(delta(review(stage: 'bulk', pct: .51)), -100);
  });
  test('recomp and refine boundaries including unspecified quiet interval', () {
    for (final stage in ['recomp', 'refine']) {
      for (final pct in [-.5, 0.0, .5]) {
        expect(review(stage: stage, pct: pct)!['message'], contains('体重稳定'));
      }
      expect(delta(review(stage: stage, pct: -.8)), isNull);
      expect(delta(review(stage: stage, pct: -.81)), 100);
      expect(delta(review(stage: stage, pct: .51)), -100);
    }
  });
  test('youth and absent stage never suggest kcal even with rapid changes', () {
    for (final stage in ['youth', null]) {
      for (final pct in [-2.0, 2.0]) {
        final r = review(stage: stage, pct: pct)!;
        expect(r['action'], isNull);
        expect(r['message'], contains('睡够'));
        expect(r['message'], isNot(contains('减脂')));
      }
    }
  });
  test('floor blocks whole reduction; exact floor remains valid', () {
    expect(delta(review(kcal: 1600)), -100);
    final r = review(kcal: 1599)!;
    expect(r['action'], isNull);
    expect(r['message'], contains('已经在安全下限，不建议再降'));
  });
  test(
    'missing weigh-ins stay unknown, single week mean is still available',
    () {
      for (final stage in ['cut', 'bulk', 'recomp']) {
        final r = review(stage: stage, weights: false)!;
        expect(r['weightAvg'], isNull);
        expect(r['weightChange'], isNull);
        expect(r['weightPct'], isNull);
        expect(r['action'], isNull);
        expect(r['message'], contains('记体重能让回顾更准'));
      }
      expect(review(currentCount: 1)!['weightAvg'], 100);
      expect(review(currentCount: 1)!['weightChange'], isNull);
      expect(review(previousCount: 1)!['weightChange'], isNull);
    },
  );
  test('three distinct days of any record, warmups not training days', () {
    expect(review(mealCount: 2, weights: false), isNull);
    final r = review(
      mealCount: 2,
      weights: false,
      days: {
        '2026-10-07': {
          'sets': [
            {'type': '热身'},
          ],
        },
        '2026-10-08': {
          'sets': [
            {'type': '正式'},
            {'type': '正式'},
          ],
        },
        '2026-10-12': {
          'sets': [
            {'type': '正式'},
          ],
        },
      },
    )!;
    expect(r['trainDays'], 1);
    expect(r['mealDays'], 2);
    expect(r['proteinDays'], 2);
    expect(r['kcalDays'], 2);
    expect(
      (r['message'] as String).split('。').where((s) => s.isNotEmpty),
      hasLength(2),
    );
    expect(r['message'], contains('这周练了 1/3 天'));
  });
  test(
    'protein 90 percent and kcal inclusive bounds, no missing dates as zero',
    () {
      final r = weeklyReview(
        today: '2026-01-01',
        done: '',
        stage: 'bulk',
        kcalGoal: 1000,
        proteinGoal: 100,
        trainTarget: 0,
        kcalFloor: 0,
        days: {},
        bodyEntries: [],
        meals: (iso) => switch (iso) {
          '2025-12-22' => {
            'meals': [{}],
            'totals': {'kcal': 900, 'protein': 90},
          },
          '2025-12-23' => {
            'meals': [{}],
            'totals': {'kcal': 1100, 'protein': 89},
          },
          '2025-12-24' => {
            'meals': [{}],
            'totals': {'kcal': 899, 'protein': 100},
          },
          '2025-12-25' => {
            'meals': [{}],
            'totals': {'kcal': 1101, 'protein': 100},
          },
          _ => {},
        },
      )!;
      expect(r['week'], '2025-12-22');
      expect(r['proteinDays'], 3);
      expect(r['kcalDays'], 2);
      expect(r['mealDays'], 4);
      expect(r['message'], contains('蛋白达标 3 天'));
    },
  );
}
