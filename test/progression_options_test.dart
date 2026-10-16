import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/domain/calendar.dart' show mondayOf;
import 'package:leandaily/domain/format.dart';
import 'package:leandaily/domain/progress.dart' as p;
import 'package:leandaily/domain/progress_options.dart';

Map<String, dynamic> exercise({
  String name = '哑铃卧推',
  num weight = 20,
  int sets = 2,
}) => {
  'id': 'e',
  'name': name,
  'part': '胸',
  'sets': sets,
  'min': 8,
  'max': 12,
  'weight': weight,
};
Map<String, dynamic> session(
  Map<String, dynamic> ex,
  String date,
  num reps, {
  num rir = 3,
  String? flag,
  num? weight,
}) => {
  'sets': List.generate(
    (ex['sets'] as num).toInt(),
    (_) => {
      'ex': ex['name'],
      'reps': reps,
      'w': weight ?? ex['weight'],
      'rpe': 10 - rir,
      'flag': ?flag,
    },
  ),
};
Map<String, dynamic> history(
  Map<String, dynamic> ex,
  int count, {
  num reps = 12,
  num rir = 3,
}) => {
  for (var i = 0; i < count; i++)
    shiftDate('2026-01-05', i * 3): session(ex, '', reps, rir: rir),
};
Map<String, dynamic> testPlan(Map<String, dynamic> ex) => {
  'startDate': '2025-10-01',
  'workouts': {
    'a': {
      'exercises': [ex],
    },
  },
  'ladders': <String, dynamic>{},
};
Map<String, dynamic>? suggestion(
  Map<String, dynamic> ex,
  Map<String, dynamic> days,
  ProgressOptions options, {
  Map<String, dynamic>? target,
  Map<String, dynamic>? plan,
}) => p.suggest(ex, {
  'days': days,
  'today': '2026-01-15',
  'plan': plan ?? testPlan(ex),
  if (days.isNotEmpty &&
      jsonRows(jsonMap(days.values.first)['sets'])
          .every((s) => jsNumber(s['reps']) >= jsNumber(ex['max'])))
    'progress': {
      ...p.emptyProgress(),
      'anchors': {
        ex['name']: {
          'date': '2026-01-01',
          'reps': ex['max'],
          'weight': ex['weight'],
        },
      },
    },
  'target': ?target,
}, options: options);

void main() {
  test('RIR 2/3 boundary opts in without altering legacy meaning', () {
    final ex = exercise();
    for (final rir in [2, 3]) {
      final s = {'date': '2026-01-05', ...session(ex, '', 8, rir: rir)};
      expect(p.evaluate(ex, s, 8)['tooEasy'], false);
      expect(
        p.evaluate(ex, s, 8, null, const ProgressOptions())['tooEasy'],
        rir == 3,
      );
    }
    final partial = history(ex, 2, reps: 7);
    expect(
      p.targetFor(
        ex,
        partial,
        today: '2026-01-10',
        options: const ProgressOptions(),
      )['tooEasy'],
      false,
    );
    final easy = history(ex, 2, reps: 8);
    expect(suggestion(ex, easy, const ProgressOptions())?['kind'], 'jump');
    expect(
      suggestion(ex, easy, const ProgressOptions(experience: 'new')),
      isNull,
    );
  });

  test('experience rep confirmations and trained recorded effort guard', () {
    final ex = exercise();
    for (final level in ['new', 'some', 'trained']) {
      final o = ProgressOptions(experience: level);
      expect(
        p.targetFor(
          ex,
          history(ex, 1, reps: 8),
          today: '2026-01-09',
          options: o,
        )['reps'],
        level == 'new' ? 9 : 8,
      );
      expect(
        p.targetFor(
          ex,
          history(ex, 2, reps: 8, rir: 0),
          today: '2026-01-10',
          options: o,
        )['reps'],
        level == 'trained' ? 8 : 9,
      );
      expect(
        suggestion(ex, history(ex, 2), o)?['kind'],
        level == 'trained' ? isNull : 'cap',
      );
      expect(suggestion(ex, history(ex, 3), o)?['kind'], 'cap');
    }
  });

  test(
    'gym dumbbell 1/2 kg, barbell machine cable 1.25/2.5 kg; home fixed',
    () {
      for (final name in ['哑铃卧推', '杠铃卧推', '器械推胸', '绳索下压']) {
        for (final weight in [8, 10, 19, 20, 30]) {
          final ex = exercise(name: name, weight: weight);
          const o = ProgressOptions(venue: 'gym');
          final step = name.contains('哑铃')
              ? (weight < 10 ? 1 : 2)
              : (weight < 20 ? 1.25 : 2.5);
          expect(loadStep(ex, weight, o), step);
          expect(suggestion(ex, history(ex, 2), o)?['kind'], 'load');
        }
      }
      for (final venue in ['bodyweight', 'dumbbell']) {
        final ex = exercise();
        expect(
          suggestion(
            ex,
            history(ex, 2),
            ProgressOptions(venue: venue),
          )?['kind'],
          'cap',
        );
        final capped = {...ex, 'max': 20};
        expect(
          suggestion(
            capped,
            history(capped, 2, reps: 20),
            ProgressOptions(venue: venue),
          )?['kind'],
          'gear',
        );
      }
    },
  );

  test('load 10% and 15% inclusive boundaries, over 15% no acceptance', () {
    final ex = exercise(weight: 20);
    for (final step in [2, 2.01, 3, 3.01]) {
      final s = suggestion(
        ex,
        history(ex, 2),
        const ProgressOptions(venue: 'gym'),
        plan: {
          ...testPlan(ex),
          'steps': {ex['name']: step},
        },
      )!;
      expect('${s['body']}'.contains('偏大'), step > 2);
      expect(s['accept'] != null, step <= 3);
      if (step > 2) expect(s['acceptLabel'], '还是试一档');
    }
  });

  test('youth stage and age guards ladder/load/jump/sets; ease allowed', () {
    final ex = exercise();
    for (final o in [
      const ProgressOptions(stage: 'youth', venue: 'gym'),
      const ProgressOptions(age: 17, venue: 'gym'),
    ]) {
      expect(suggestion(ex, history(ex, 2), o)?['kind'], 'variant');
      expect(suggestion(ex, history(ex, 2, reps: 7), o)?['kind'], 'ease');
      expect(suggestion(ex, history(ex, 2, reps: 8), o), isNull);
    }
  });

  test('cut keeps strength, no set increase; below minimum ease explains', () {
    final ex = exercise();
    const o = ProgressOptions(stage: 'cut');
    final s = suggestion(ex, history(ex, 2, reps: 7), o)!;
    expect(s['kind'], 'ease');
    expect(s['body'], contains('热量缺口期偶尔做不到下限是正常的，先保持'));
    final target = {
      'evals': [
        {'flag': null},
      ],
      'stuck': 3,
      'reps': 10,
    };
    expect(suggestion(ex, {}, o, target: target)?['title'], '减脂期保住力量就是成功');
  });

  test('deload acceptance pure, rounding, neutral history and restoration', () {
    final ex = exercise(weight: 30, sets: 3);
    final plan = testPlan(ex), progress = p.emptyProgress();
    final before = jsonEncode([plan, progress]);
    final result = p.applyAccept(plan, progress, {
      'type': 'deload',
    }, '2026-01-06');
    expect(jsonEncode([plan, progress]), before);
    final next = jsonMap(result['progress']);
    expect(jsonMap(next['deload']), {
      'week': mondayOf('2026-01-06'),
      'last': '2026-01-06',
    });
    final days = <String, dynamic>{};
    final t = p.targetFor(
      ex,
      days,
      today: '2026-01-06',
      progress: next,
      options: const ProgressOptions(deloadActive: true),
    );
    expect(t['sets'], 2);
    expect(t['weight'], 28); // nearest 2 kg increment
    expect(t['reps'], 8);
    expect(t['reason'], contains('本周减量'));
    days['2026-01-06'] = session({...ex, 'sets': 2}, '', 12, weight: 28);
    final restored = p.targetFor(
      ex,
      days,
      today: '2026-01-12',
      progress: next,
      options: const ProgressOptions(),
    );
    expect(restored['sets'], 3);
    expect(restored['weight'], 30);
    expect(restored['reps'], 8);
    expect(restored['evals'], isEmpty);
    expect(
      p.evaluate(
        ex,
        {'date': '2026-01-06', ...jsonMap(days['2026-01-06'])},
        8,
        null,
        const ProgressOptions(deloadActive: true),
      )['neutral'],
      'deload',
    );
  });

  test(
    'pain freezes next two exposures; three week return reduces reps and sets',
    () {
      final ex = exercise();
      const o = ProgressOptions(experience: 'new');
      final days = history(ex, 1, reps: 8);
      days['2026-01-08'] = session(ex, '', 9, flag: 'pain');
      for (final date in ['2026-01-11', '2026-01-14']) {
        expect(p.targetFor(ex, days, today: date, options: o)['reps'], 9);
        days[date] = session(ex, '', 9);
      }
      final t = p.targetFor(ex, days, today: '2026-02-04', options: o);
      expect(t['sets'], 1);
      expect(t['reps'], 8);
      expect(t['returning'], true);
    },
  );
  test(
    'trained exceed respects effort guard and missing effort is allowed',
    () {
      final ex = exercise();
      expect(
        suggestion(
          ex,
          history(ex, 2, reps: 10, rir: 0),
          const ProgressOptions(experience: 'trained'),
        ),
        isNull,
      );
      final days = history(ex, 2, reps: 8);
      for (final day in days.values) {
        for (final set in (day as Map)['sets'] as List) {
          (set as Map).remove('rpe');
        }
      }
      expect(
        p.targetFor(
          ex,
          days,
          today: '2026-01-10',
          options: const ProgressOptions(experience: 'trained'),
        )['reps'],
        9,
      );
    },
  );

  test('return subtracts two reps above minimum and exactly one set', () {
    final ex = exercise(sets: 3);
    final progress = {
      ...p.emptyProgress(),
      'anchors': {
        ex['name']: {'date': '2026-01-01', 'reps': 11, 'weight': 20},
      },
    };
    final days = history(ex, 1, reps: 11);
    final t = p.targetFor(
      ex,
      days,
      progress: progress,
      today: '2026-01-26',
      options: const ProgressOptions(),
    );
    expect(t['reps'], 9);
    expect(t['sets'], 2);
  });
  test('equipment description resolves dumbbell and active option alone skips this week', () {
    final ex = {...exercise(name: '卧推'), 'gear': '哑铃 × 2'};
    const o = ProgressOptions(venue: 'gym');
    expect(adjustableLoad(ex, o), true);
    expect(loadStep(ex, 20, o), 2);
    final active = p.targetFor(
      ex,
      history(ex, 2),
      today: '2026-01-09',
      options: const ProgressOptions(deloadActive: true),
    );
    expect(active['evals'], isEmpty);
    expect(active['reps'], 8);
  });

  test('youth ladder upgrade is blocked while easier stage is available', () {
    final ex = {...exercise(name: '高位俯卧撑', weight: 0), 'ladder': 'push'};
    final plan = {
      ...testPlan(ex),
      'ladders': {
        'push': {
          'stage': 1,
          'steps': [
            {'name': '墙壁俯卧撑', 'min': 8, 'max': 12},
            {'name': '高位俯卧撑', 'min': 8, 'max': 12},
            {'name': '跪姿俯卧撑', 'min': 8, 'max': 12},
          ],
        },
      },
    };
    const o = ProgressOptions(stage: 'youth');
    expect(suggestion(ex, history(ex, 2), o, plan: plan)?['kind'], 'variant');
    final ease = suggestion(ex, history(ex, 2, reps: 7), o, plan: plan)!;
    expect(ease['kind'], 'ease');
    expect(jsonMap(ease['accept'])['stage'], 0);
  });
  test('pain safety advice survives neutral deload records', () {
    final ex = exercise();
    final days = {'2026-01-13': session(ex, '', 8, flag: 'pain')};
    final tip = suggestion(ex, days, const ProgressOptions(deloadActive: true));
    expect(tip?['kind'], 'pain');
    expect(tip?['accept'], isNull);
  });
  test('partial sessions cannot trigger either easy or exceed jump', () {
    final ex = exercise();
    final days = history(ex, 2, reps: 12);
    for (final day in days.values) {
      (day as Map)['sets'] = (day['sets'] as List).take(1).toList();
    }
    const o = ProgressOptions();
    final target = p.targetFor(ex, days, today: '2026-01-10', options: o);
    expect(target['tooEasy'], false);
    expect(target['exceed'], false);
    expect(suggestion(ex, days, o)?['kind'], isNot('jump'));
  });
}
