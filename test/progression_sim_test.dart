import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/domain/calendar.dart' show daysApart, mondayOf;
import 'package:leandaily/domain/deload.dart';
import 'package:leandaily/domain/format.dart';
import 'package:leandaily/domain/progress.dart' as p;
import 'package:leandaily/domain/progress_options.dart';

import 'progression_options_test.dart' show exercise, session, testPlan;

/// Deterministic virtual user: Mon/Wed/Fri exposures, Sunday reviews, no RNG.
class Simulation {
  Simulation(
    this.options, {
    this.plateau = false,
    this.injured = false,
    this.breakWeeks = false,
    this.accept = true,
    this.adherence = 1,
  }) {
    ex = exercise(weight: 30);
    plan = {
      ...testPlan(ex),
      'startDate': '2026-01-05',
      'schedule': {'1': 'a', '3': 'a', '5': 'a'},
    };
    if (plateau) {
      progress['anchors'] = {
        ex['name']: {'date': '2026-01-01', 'reps': 10, 'weight': 30},
      };
    }
  }
  final ProgressOptions options;
  final bool plateau, injured, breakWeeks, accept;
  final double adherence;
  late Map<String, dynamic> ex, plan;
  Map<String, dynamic> progress = p.emptyProgress();
  final days = <String, dynamic>{}, states = <String, dynamic>{};
  final proposals = <Map<String, dynamic>>[],
      targets = <Map<String, dynamic>>[];

  ProgressOptions at(String date) =>
      options.forDeload(jsonMap(progress['deload'])['week'] == mondayOf(date));
  void run() {
    for (var week = 0; week < 26; week++) {
      for (var visit = 0; visit < 3; visit++) {
        if (breakWeeks && week >= 10 && week < 13 || visit / 3 >= adherence) {
          continue;
        }
        final date = shiftDate('2026-01-05', week * 7 + visit * 2);
        ex = jsonRows(jsonMap(jsonMap(plan['workouts'])['a'])['exercises'])
            .single;
        final o = at(date);
        final target = p.targetFor(
          ex,
          days,
          today: date,
          dayStates: states,
          progress: progress,
          options: o,
        );
        targets.add({...target, 'date': date, 'deload': o.deloadActive});
        expect(
          jsNumber(target['sets']),
          lessThanOrEqualTo(p.CFG['maxAutoSets']!),
        );
        final reps = plateau
            ? math.max(8, jsNumber(target['reps']) - 1)
            : jsNumber(target['reps']);
        days[date] = session(
          {...ex, 'sets': target['sets']},
          date,
          reps,
          weight: jsNumber(target['weight']),
          rir: 2,
          flag: injured && week >= 5 ? 'pain' : null,
        );
      }
      final date = shiftDate('2026-01-05', week * 7 + 6);
      final o = at(date);
      final review = p.weeklyReview(plan, days, states, date);
      final suggestion = p.suggest(ex, {
        'plan': plan,
        'days': days,
        'dayStates': states,
        'progress': progress,
        'today': date,
        'review': review,
      }, options: o);
      final deload = deloadSuggestion(
        days: days,
        dayStates: states,
        progress: progress,
        plan: plan,
        today: date,
        options: o,
      );
      for (final s in [deload, suggestion].whereType<Map<String, dynamic>>()) {
        proposals.add({...s, 'weekIndex': week});
        if (accept && s['accept'] != null) {
          final result = p.applyAccept(
            plan,
            progress,
            jsonMap(s['accept']),
            date,
          );
          plan = jsonMap(result['plan']);
          progress = jsonMap(result['progress']);
        }
      }
    }
  }
}

Map<String, dynamic>? deloadAt(
  String today,
  Map<String, dynamic> days, {
  Map<String, dynamic> states = const {},
  Map<String, dynamic>? progress,
  ProgressOptions? options = const ProgressOptions(),
  Map<String, dynamic>? plan,
}) => deloadSuggestion(
  days: days,
  dayStates: states,
  progress: progress ?? p.emptyProgress(),
  plan: plan ?? testPlan(exercise()),
  today: today,
  options: options,
);

void main() {
  test(
    '26 weeks diligent beginner progresses with bounded steps and spaced loads',
    () {
      final s = Simulation(
        const ProgressOptions(experience: 'new', venue: 'gym'),
      )..run();
      final ordinary = s.targets.where((t) => t['deload'] != true).toList();
      for (var i = 1; i < ordinary.length; i++) {
        final prev = ordinary[i - 1], next = ordinary[i];
        expect(
          jsNumber(next['weight']),
          greaterThanOrEqualTo(jsNumber(prev['weight'])),
        );
        if (next['weight'] == prev['weight']) {
          expect(
            jsNumber(next['reps']),
            greaterThanOrEqualTo(jsNumber(prev['reps'])),
          );
        }
      }
      final loads = s.proposals.where((p) => p['kind'] == 'load').toList();
      expect(loads.length, greaterThan(2));
      for (var i = 0; i < loads.length; i++) {
        final load = loads[i],
            weight = jsNumber(jsonMap(load['accept'])['weight']);
        final pct = 2 / (weight - 2);
        if (pct > .1) expect('${load['body']}', contains('偏大'));
        if (i > 0) {
          expect(
            (load['weekIndex'] as int) - (loads[i - 1]['weekIndex'] as int),
            greaterThan(1),
          );
        }
      }
    },
  );

  test(
    '26 weeks plateau accepts bounded sets or variants, never endless upgrades',
    () {
      final s = Simulation(const ProgressOptions(venue: 'gym'), plateau: true)
        ..run();
      expect(s.proposals, isNotEmpty);
      expect(
        s.proposals.map((s) => s['kind']),
        everyElement(isIn(['variant', 'sets', 'deload'])),
      );
      expect(
        s.proposals.where((s) => s['kind'] == 'sets').length,
        lessThanOrEqualTo(1),
      );
      expect(s.targets.map((t) => t['reps']), everyElement(10));
    },
  );

  test('26 weeks repeated pain never recommends load or sets after flag', () {
    final s = Simulation(
      const ProgressOptions(experience: 'new', venue: 'gym'),
      injured: true,
    )..run();
    final after = s.proposals.where((s) => (s['weekIndex'] as int) >= 5);
    expect(after.any((s) => s['kind'] == 'pain'), true);
    expect(after.map((s) => s['kind']), everyElement(isIn(['pain', 'deload'])));
    final targets = s.targets
        .where(
          (t) =>
              (t['date'] as String).compareTo('2026-02-09') >= 0 &&
              t['deload'] != true,
        )
        .toList();
    expect(targets.map((t) => t['reps']).toSet().length, 1);
    expect(targets.map((t) => t['weight']).toSet().length, 1);
  });

  test(
    '26 weeks three week interruption comes back two reps and one set lower',
    () {
      final s = Simulation(
        const ProgressOptions(venue: 'gym'),
        breakWeeks: true,
        accept: false,
      )..run();
      final before = s.targets.lastWhere(
        (t) => (t['date'] as String).compareTo('2026-03-16') < 0,
      );
      final back = s.targets.firstWhere(
        (t) => (t['date'] as String).compareTo('2026-04-06') >= 0,
      );
      expect(back['returning'], true);
      expect(back['sets'], jsNumber(before['sets']) - 1);
      expect(back['reps'], math.max(8, jsNumber(before['reps']) - 2));
    },
  );

  for (final youth in [false, true]) {
    test('26 weeks ${youth ? 'youth' : 'cut'} respects route protection', () {
      final s = Simulation(
        ProgressOptions(
          stage: youth ? 'youth' : 'cut',
          experience: 'new',
          venue: 'gym',
        ),
        plateau: !youth,
        adherence: 2 / 3,
      )..run();
      expect(s.proposals, isNotEmpty);
      expect(
        s.proposals.map((s) => s['kind']),
        everyElement(
          isNot(isIn(youth ? ['load', 'jump', 'sets', 'ladder'] : ['sets'])),
        ),
      );
    });
  }

  test(
    'deload five of six weeks, fatigue/stalls/eight weeks and red flags',
    () {
      final ex = exercise();
      final days = <String, dynamic>{
        for (var i = 0; i < 5; i++)
          shiftDate('2026-01-05', i * 7): session(ex, '', 8, rir: 2),
      };
      final states = {
        for (final d in ['2026-02-01', '2026-02-02', '2026-02-03'])
          d: {'ready': 'tired'},
      };
      expect(deloadAt('2026-02-08', days), isNull);
      expect(deloadAt('2026-02-08', days, states: states), isNotNull);
      expect(
        deloadAt('2026-02-08', days, states: states, options: null),
        isNull,
      );
      final sparse = {...days}..remove('2026-01-05');
      expect(deloadAt('2026-02-08', sparse, states: states), isNull);
      states['2026-02-03'] = {'ready': 'bad'};
      expect(
        deloadAt('2026-02-08', days, states: states)!['body'],
        contains('就医'),
      );
      final three = [
        exercise(name: '哑铃卧推'),
        exercise(name: '哑铃划船'),
        exercise(name: '哑铃深蹲'),
      ];
      for (final date in ['2026-02-04', '2026-02-06']) {
        days[date] = {
          'sets': [
            for (final e in three) ...jsonRows(session(e, '', 7)['sets']),
          ],
        };
      }
      expect(
        deloadAt(
          '2026-02-08',
          days,
          plan: {
            'workouts': {
              'a': {'exercises': three},
            },
          },
        ),
        isNotNull,
      );
      final eight = {
        for (var i = 0; i < 8; i++)
          shiftDate('2026-01-05', i * 7): session(ex, '', 8, rir: 2),
      };
      expect(deloadAt('2026-03-01', eight), isNotNull);
      final easyWeeks = {
        for (var i = 0; i < 8; i++)
          shiftDate('2026-01-05', i * 7): session(ex, '', 8, rir: 3),
      };
      expect(deloadAt('2026-03-01', easyWeeks), isNull);
    },
  );

  test(
    'deload accepted once, 42 day cooldown and 14 day decline boundaries',
    () {
      final ex = exercise(weight: 20, sets: 3);
      final days = {
        for (var i = 0; i < 16; i++)
          shiftDate('2026-01-05', i * 7): session(ex, '', 8, rir: 2),
      };
      final s = deloadAt('2026-03-01', days)!;
      final accepted = jsonMap(
        p.applyAccept(
          testPlan(ex),
          p.emptyProgress(),
          jsonMap(s['accept']),
          '2026-03-01',
        )['progress'],
      );
      for (var offset = 0; offset < 42; offset++) {
        final date = shiftDate('2026-03-01', offset);
        expect(deloadAt(date, days, progress: accepted), isNull, reason: date);
      }
      expect(deloadAt('2026-04-12', days, progress: accepted), isNotNull);
      final declined = p.decline(null, 'deload', '2026-03-01');
      expect(deloadAt('2026-03-14', days, progress: declined), isNull);
      expect(deloadAt('2026-03-15', days, progress: declined), isNotNull);
      expect(daysApart('2026-03-01', '2026-04-12'), 42);
    },
  );
}
