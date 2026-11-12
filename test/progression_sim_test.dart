import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/domain/calendar.dart' show daysApart, mondayOf;
import 'package:leandaily/domain/deload.dart';
import 'package:leandaily/domain/format.dart';
import 'package:leandaily/domain/plan.dart' as plans;
import 'package:leandaily/domain/templates.dart' show buildPlan;
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

/// 居家自重新手：照「居家自重三练」每周一三五练，每次都做到目标次数、留 2 次余力；
/// 周日看一次建议，阶梯升级的建议一律接受。[painFromWeek] 之后深蹲每次都标疼痛。
class HomeBodyweightSimulation {
  HomeBodyweightSimulation({this.painFromWeek});
  final int? painFromWeek;
  static const start = '2026-01-05';
  static const options = ProgressOptions(
    experience: 'new',
    venue: 'bodyweight',
  );
  Map<String, dynamic> plan = buildPlan(
    'bodyweight-3',
    profile: {'experience': 'new', 'venue': 'bodyweight'},
    startDate: start,
  );
  Map<String, dynamic> progress = p.emptyProgress();
  final days = <String, dynamic>{};
  final proposals = <Map<String, dynamic>>[];

  /// 每周结束时各阶梯所在的级别：stages[阶梯][第几周]。
  final stages = <String, List<int>>{};

  /// 每次训练的目标：(第几周, 动作名, 目标次数, 组数)。
  final targets =
      <({int week, String ex, num reps, num sets, bool climbing})>[];

  int stage0(String id) => stages[id] == null
      ? 0
      : jsNumber(
          jsonMap(
            jsonMap(
              buildPlan('bodyweight-3', profile: {'experience': 'new'}),
            )['ladders'],
          )[id]?['stage'],
        ).toInt();

  int stageOf(String id) =>
      jsNumber(jsonMap(jsonMap(plan['ladders'])[id])['stage']).toInt();

  void run([int weeks = 26]) {
    for (var week = 0; week < weeks; week++) {
      for (final dow in const [1, 3, 5]) {
        final date = shiftDate(start, week * 7 + dow - 1);
        final slot = plans.workoutFor(plan, date);
        final sets = <Map<String, dynamic>>[];
        for (final ex in plans.exercisesFor(
          plan,
          jsonMap(slot['workout']),
          date,
        )) {
          final t = p.targetFor(
            ex,
            days,
            today: date,
            progress: progress,
            options: options,
          );
          targets.add((
            week: week,
            ex: '${ex['name']}',
            reps: jsNumber(t['reps']),
            sets: jsNumber(t['sets']),
            // 在阶梯上、而且不是最后一级：这样的动作不该长期停在同一个目标。
            climbing:
                ex['ladder'] != null &&
                jsNumber(ex['stage']) < jsNumber(ex['stages']) - 1,
          ));
          final pain =
              painFromWeek != null &&
              week >= painFromWeek! &&
              ex['ladder'] == 'squat';
          sets.addAll(
            jsonRows(
              session(
                {...ex, 'sets': t['sets']},
                date,
                jsNumber(t['reps']),
                rir: 2,
                flag: pain ? 'pain' : null,
              )['sets'],
            ),
          );
        }
        days[date] = {'sets': sets};
      }
      final sunday = shiftDate(start, week * 7 + 6);
      final review = p.weeklyReview(plan, days, const {}, sunday);
      final seen = <String>{};
      for (final w in jsonMap(plan['workouts']).values) {
        for (final raw in jsonRows(jsonMap(w)['exercises'])) {
          final ex = plans.resolveEx(plan, raw);
          if (!seen.add('${ex['name']}')) continue;
          final s = p.suggest(ex, {
            'plan': plan,
            'days': days,
            'dayStates': const <String, dynamic>{},
            'progress': progress,
            'today': sunday,
            'review': review,
          }, options: options);
          if (s == null) continue;
          proposals.add({...s, 'weekIndex': week});
          if (s['accept'] != null) {
            final r = p.applyAccept(
              plan,
              progress,
              jsonMap(s['accept']),
              sunday,
            );
            plan = jsonMap(r['plan']);
            progress = jsonMap(r['progress']);
          }
        }
      }
      for (final id in jsonMap(plan['ladders']).keys) {
        (stages[id] ??= []).add(stageOf(id));
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

  group('居家自重新手 26 周', () {
    test('四条阶梯都在推进：不会长期停滞，至少升到第 3 级，一次只升一级', () {
      final s = HomeBodyweightSimulation()..run();
      expect(s.stages.keys.toSet(), {
        'pushup',
        'squat',
        'row',
        'bridge',
        'core',
      });
      for (final entry in s.stages.entries) {
        final path = [s.stage0(entry.key), ...entry.value];
        for (var i = 1; i < path.length; i++) {
          expect(
            (path[i] - path[i - 1]).abs(),
            lessThanOrEqualTo(1),
            reason: '${entry.key} 第 $i 周一次跳了两级：$path',
          );
        }
      }
      // 深蹲、臀桥、俯卧撑从第 1 级起步：26 周内至少升到第 3 级（下标 2）。
      for (final id in ['squat', 'bridge', 'pushup']) {
        expect(s.stages[id]!.last, greaterThanOrEqualTo(2), reason: id);
      }
      // 反向划船、腹肌从第 2 级起步，至少再升一级。
      for (final id in ['row', 'core']) {
        expect(s.stages[id]!.last, greaterThan(s.stage0(id)), reason: id);
      }
      // 同一个动作、同一个目标次数，最多停留 3 周（认真练、每次做到目标）。
      final stay = <String, int>{};
      final lastKey = <String, String>{};
      final lastWeek = <String, int>{};
      var worst = 0;
      for (final t in s.targets.where((t) => t.climbing)) {
        final key = '${t.ex}:${t.reps}';
        if (lastKey[t.ex] == key) {
          if (lastWeek[t.ex] != t.week) {
            stay[t.ex] = (stay[t.ex] ?? 1) + 1;
          }
        } else {
          stay[t.ex] = 1;
        }
        lastKey[t.ex] = key;
        lastWeek[t.ex] = t.week;
        worst = math.max(worst, stay[t.ex]!);
        expect(stay[t.ex], lessThanOrEqualTo(3), reason: '$key 停了太久');
      }
      expect(worst, greaterThan(0));
      // 升级建议只出现在做满上限之后，而且都带着确认用的 accept。
      final ups = s.proposals.where((e) => e['kind'] == 'ladder');
      expect(ups.length, greaterThanOrEqualTo(8));
      for (final u in ups) {
        expect(jsonMap(u['accept'])['type'], 'ladder');
        expect('${u['title']}', contains('做满'));
      }
    });

    test('深蹲标疼痛之后不再升级，只提示疼痛', () {
      final s = HomeBodyweightSimulation(painFromWeek: 6)..run();
      final squat = s.stages['squat']!;
      // 疼痛出现的那一周周日可能已经接受过一次升级；之后一直保持不变。
      expect(squat.skip(7).toSet().length, 1, reason: '$squat');
      final after = s.proposals.where(
        (e) => (e['weekIndex'] as int) >= 6 && '${e['ex']}'.contains('蹲'),
      );
      expect(after, isNotEmpty);
      expect(after.map((e) => e['kind']), everyElement('pain'));
      // 身上有疼痛红旗时，所有动作都先不升级（和单个动作的疼痛规则一致）。
      expect(s.stages['bridge']!.skip(8).toSet().length, 1);
    });
  });
}
