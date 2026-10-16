import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/ui/today/week_adherence.dart';

void main() {
  test('周计数排除热身和未来，保留连续达标周', () {
    final history = <String, dynamic>{
      for (final d in [
        '2026-09-28',
        '2026-09-30',
        '2026-10-05',
        '2026-10-07',
        '2026-10-12',
        '2026-10-20',
      ])
        d: {
          'sets': [
            {'type': '正式'},
            {'type': '正式'},
          ],
        },
      '2026-10-13': {
        'sets': [
          {'type': '热身'},
        ],
      },
    };
    expect(
      weekAdherence(
        today: '2026-10-16',
        history: history,
        savedDays: 2,
        planDays: 3,
      ),
      (count: 1, target: 2, streak: 2),
    );
    expect(
      weekAdherence(
        today: '2026-10-16',
        history: {},
        savedDays: 0,
        planDays: 3,
      ),
      (count: 0, target: 3, streak: 0),
    );
    expect(
      weekAdherence(
        today: '2026-10-16',
        history: {
          '2026-10-12': {
            'day_row': {'周目标天数': 5},
          },
        },
        savedDays: 0,
        planDays: 0,
      ).target,
      5,
    );
  });
}
