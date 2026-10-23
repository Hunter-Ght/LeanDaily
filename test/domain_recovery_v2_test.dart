import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/domain/muscles.dart';

/// 一天里做 [count] 组同一个动作（只记录 rpe，强度系数固定）。
Map<String, Map<String, dynamic>> day(String date, String ex, int count) => {
  date: {
    'sets': [
      for (var i = 0; i < count; i++)
        {'id': '$date-$i', 'date': date, 'ex': ex, 'reps': 10, 'type': '正式'},
    ],
  },
};

void main() {
  final now = dateMs('2026-10-16');
  test('每块肌肉的半衰期：下肢 48 小时、胸背 30 小时、小肌群 24 小时', () {
    expect(halfLifeHours('quads'), 48);
    expect(halfLifeHours('glutes'), 48);
    expect(halfLifeHours('lower_back'), 48);
    expect(halfLifeHours('chest'), 30);
    expect(halfLifeHours('lats'), 30);
    expect(halfLifeHours('delt_side'), 24);
    expect(halfLifeHours('triceps'), 24);
    expect(halfLifeHours('abs'), 24);
  });

  test('衰减按各自半衰期：同样 48 小时前的一组，股四头剩一半，胸剩得更少', () {
    final two = dateMs('2026-10-14');
    expect((now - two) / 3600000, 48);
    final legs = muscleStatus(day('2026-10-14', '深蹲', 1), now)['byMuscle'];
    final chest = muscleStatus(day('2026-10-14', '标准俯卧撑', 1), now)['byMuscle'];
    final fresh = muscleStatus(day('2026-10-16', '深蹲', 1), now)['byMuscle'];
    expect(
      legs['quads']['fatigue'],
      closeTo(fresh['quads']['fatigue'] * .5, 1e-9),
    );
    final chestFresh = muscleStatus(
      day('2026-10-16', '标准俯卧撑', 1),
      now,
    )['byMuscle'];
    expect(
      chest['chest']['fatigue'],
      closeTo(chestFresh['chest']['fatigue'] * math.pow(.5, 48 / 30), 1e-9),
    );
  });

  test('疲劳相同时，48 小时肌肉预计恢复天数是 24 小时肌肉的两倍', () {
    final status = muscleStatus(day('2026-10-16', '深蹲', 6), now)['byMuscle'];
    final quads = status['quads'];
    final expected = 48 / 24 * math.log(quads['fatigue'] / 1.2) / math.ln2;
    expect(quads['daysLeft'], closeTo(expected, 1e-9));
    expect(quads['daysLeft'], greaterThan(0));
  });

  test('单次训练每块肌肉最多计 12 组疲劳，组数统计照实计', () {
    final twelve = muscleStatus(day('2026-10-16', '深蹲', 12), now)['byMuscle'];
    final twenty = muscleStatus(day('2026-10-16', '深蹲', 20), now)['byMuscle'];
    // 深蹲对股四头的权重是 1：12 组正好封顶。
    expect(
      twenty['quads']['fatigue'],
      closeTo(twelve['quads']['fatigue'], 1e-9),
    );
    expect(twenty['quads']['sets7'], greaterThan(twelve['quads']['sets7']));
    expect(twenty['quads']['sets7'], closeTo(20, 1e-9));
  });

  test('不同日期分别封顶', () {
    final both = muscleStatus({
      ...day('2026-10-15', '深蹲', 20),
      ...day('2026-10-16', '深蹲', 20),
    }, now)['byMuscle'];
    final capped = muscleStatus({
      ...day('2026-10-15', '深蹲', 12),
      ...day('2026-10-16', '深蹲', 12),
    }, now)['byMuscle'];
    expect(both['quads']['fatigue'], closeTo(capped['quads']['fatigue'], 1e-9));
    expect(both['quads']['fatigue'], greaterThan(12));
  });
}
