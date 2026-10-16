import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/domain/body_trend.dart';

void main() {
  final profile = {'weightKg': 80, 'bodyFatPct': 25};
  final targets = {
    'stage': 'cut',
    'goalBodyFat': 15,
    'bodyFat': {'value': 25},
  };
  test('empty and single measurement', () {
    expect(bodyTrend([], profile, targets, '2026-10-16')['latestMean'], isNull);
    final t = bodyTrend(
      [
        {'date': '2026-10-16', 'weightKg': 80},
      ],
      profile,
      targets,
      '2026-10-16',
    );
    expect(t['latestMean'], 80);
    expect(t['weekChange'], isNull);
    expect(t['estimatedBodyFat'], 25);
    expect(t['progress'], 0);
  });
  test('calendar moving means, weekly change, body-fat and progress', () {
    final entries = [
      for (var i = 0; i < 14; i++)
        {
          'date': DateTime(2026, 10, 3 + i).toIso8601String().substring(0, 10),
          'weightKg': i < 7 ? 80 : 78,
        },
    ];
    final t = bodyTrend(entries, profile, targets, '2026-10-16');
    expect(t['latestMean'], 78);
    expect(t['weekChange'], -2);
    expect((t['series'] as List)[7]['weightKg'], closeTo(558 / 7, 1e-8));
    expect(t['estimatedBodyFat'], closeTo(100 * (1 - 60 / 78), 1e-8));
    expect(t['progress'], greaterThan(0));
    expect(
      bodyTrend(
        [
          ...entries,
          {'date': '2026-10-17', 'weightKg': 100},
        ],
        profile,
        targets,
        '2026-10-16',
      )['latestMean'],
      78,
    );
  });
  for (final stage in ['bulk', 'youth']) {
    test('$stage gain range without fat progress', () {
      final entries = [
        {'date': '2026-10-08', 'weightKg': 70},
        {'date': '2026-10-16', 'weightKg': 70.3},
      ];
      final t = bodyTrend(entries, profile, {
        ...targets,
        'stage': stage,
      }, '2026-10-16');
      expect(t['gainInRange'], true);
      expect(t['progress'], isNull);
      entries.last['weightKg'] = 71;
      expect(
        bodyTrend(entries, profile, {
          'stage': stage,
        }, '2026-10-16')['gainInRange'],
        false,
      );
    });
  }
}
