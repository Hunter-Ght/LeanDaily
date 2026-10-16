import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/domain/plan_insight.dart';
import 'package:leandaily/domain/templates.dart';

void main() {
  for (final t in templates) {
    test('${t['id']} weekly insight', () {
      final insight = planInsight(buildPlan(t['id'] as String));
      expect(insight['week'], hasLength(t['days'] as int));
      expect((insight['muscleLevels'] as Map).values, contains(3));
      expect(
        (insight['muscleLevels'] as Map).values.every((v) => v >= 0 && v <= 3),
        true,
      );
      expect(insight['minutes'], greaterThan(0));
    });
  }
  test('known labels and fallback', () {
    for (final entry in {
      'bochi-ppl-3': ['推', '拉', '腿'],
      'full-2': ['全', '全'],
      'ul-4': ['上', '下', '上', '下'],
    }.entries) {
      expect(
        (planInsight(buildPlan(entry.key))['week'] as List).map(
          (d) => d['label'],
        ),
        entry.value,
      );
    }
    final home = buildPlan('dumbbell-3');
    expect(planInsight(home, venue: 'gym'), planInsight(home));
  });
  test('three template volumes and bands checked by hand', () {
    final ppl = planInsight(buildPlan('bochi-ppl-3'));
    // Two sets each: shoulder presses 2*0.6*2, lateral raises 2*1*2,
    // reverse flies 2*0.2*2 => side delts 7.2 (weekly maximum).
    expect(ppl['muscleVolume']['delt_side'], closeTo(7.2, 1e-9));
    expect(ppl['muscleVolume']['chest'], 4);
    expect(ppl['muscleLevels']['delt_side'], 3);
    expect(ppl['muscleLevels']['chest'], 2);
    final full = planInsight(buildPlan('full-2'));
    // Goblet squat 1.2 + RDL 1.4 + bridge 2 => glutes 4.6 (maximum).
    expect(full['muscleVolume']['glutes'], closeTo(4.6, 1e-9));
    expect(full['muscleLevels']['glutes'], 3);
    expect(full['muscleLevels']['quads'], 2); // 2 + 0.3 = 2.3.
    final ul = planInsight(buildPlan('ul-4'));
    // Two lower days: (1.2 + 1.4 + 1.4 + 2) * 2 => glutes 12.
    expect(ul['muscleVolume']['glutes'], closeTo(12, 1e-9));
    expect(ul['muscleLevels']['glutes'], 3);
    expect(ul['muscleLevels']['chest'], 2); // Two upper days: 4 / 12.
    expect(ul['muscleLevels']['calves'], 0);
  });
  test('custom plan repeated days and hand calculated bands', () {
    // Four curl sets plus 0.5, 1, 2 or 3 calf sets: max 4,
    // thresholds 1 and 2.4. Scheduling twice doubles volume, not bands.
    for (final sets in [0.5, 1, 2, 3]) {
      final r = planInsight({
        'schedule': {'2': 'a', '0': 'a'},
        'workouts': {
          'a': {
            'name': '自定',
            'exercises': [
              {'name': '哑铃弯举', 'sets': 4},
              {'name': '站姿提踵', 'sets': sets},
            ],
          },
        },
      });
      expect((r['week'] as List).map((d) => d['dow']), [2, 0]);
      expect(r['muscleVolume']['biceps'], 8);
      expect(
        r['muscleLevels']['calves'],
        sets < 1
            ? 1
            : sets < 2.4
            ? 2
            : 3,
      );
    }
  });
  test('empty and matching', () {
    expect(planInsight({})['minutes'], 0);
    expect(planInsight({})['week'], isEmpty);
    expect(
      matchReasons({
        'daysPerWeek': 3,
        'venue': 'dumbbell',
        'experience': 'new',
      }, templates.first),
      ['每周 3 天', '在家有哑铃', '新手'],
    );
  });
}
