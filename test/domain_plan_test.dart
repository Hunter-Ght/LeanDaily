import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/domain/format.dart' as f;
import 'package:leandaily/domain/plan.dart' as p;
import 'package:leandaily/domain/goals.dart' as g;
import 'package:leandaily/domain/rest_prefs.dart' as r;

/// Compare key sets and array order too, with only the required float tolerance.
void compareJson(Object? actual, Object? expected, [String path = r'$']) {
  if (expected is num) {
    expect(actual, isA<num>(), reason: path);
    expect(
      (actual as num).toDouble(),
      closeTo(expected.toDouble(), 1e-6),
      reason: path,
    );
  } else if (expected is Map) {
    expect(actual, isA<Map>(), reason: path);
    final a = actual as Map;
    expect(a.keys.toSet(), expected.keys.toSet(), reason: path);
    for (final k in expected.keys) {
      compareJson(a[k], expected[k], '$path.$k');
    }
  } else if (expected is List) {
    expect(actual, isA<List>(), reason: path);
    final a = actual as List;
    expect(a.length, expected.length, reason: path);
    for (var i = 0; i < expected.length; i++) {
      compareJson(a[i], expected[i], '$path[$i]');
    }
  } else {
    expect(actual, expected, reason: path);
  }
}

dynamic runPlan(String fn, List<dynamic> a) {
  Map<String, dynamic> m(int i) => f.jsonMap(a[i]);
  String s(int i) => a[i] as String;
  switch (fn) {
    case 'defaultPlan':
      return a.isEmpty ? p.defaultPlan() : p.defaultPlan(s(0));
    case 'defaultGym':
      return p.defaultGym();
    case 'GYM_WARMUP':
      return p.GYM_WARMUP;
    case 'GYM_RULES':
      return p.GYM_RULES;
    case 'normalizePlan':
      return p.normalizePlan(a[0], s(1));
    case 'dow':
      return p.dow(s(0));
    case 'daysBetween':
      return p.daysBetween(s(0), s(1));
    case 'weekNumber':
      return p.weekNumber(m(0), s(1));
    case 'resolveEx':
      return p.resolveEx(m(0), m(1));
    case 'setupOf':
      return p.setupOf(m(0), m(1));
    case 'setsFor':
      return p.setsFor(m(0), m(1), s(2));
    case 'venueOf':
      return p.venueOf(m(0), s(1), m(2));
    case 'swapEx':
      return p.swapEx(m(0), s(1));
    case 'workoutFor':
      return p.workoutFor(m(0), s(1), m(2));
    case 'nextTraining':
      return p.nextTraining(m(0), s(1), m(2));
    case 'exercisesFor':
      return p.exercisesFor(m(0), m(1), s(2), a[3] as bool);
    case 'rangeText':
      return p.rangeText(m(0));
    case 'prescription':
      return p.prescription(m(0));
    case 'estimateMinutes':
      return p.estimateMinutes(m(0), f.jsonRows(a[1]));
    case 'formalSets':
      return p.formalSets(m(0), s(1));
    case 'dayProgress':
      return p.dayProgress(m(0), m(1), s(2), m(3), a[4] as bool);
    case 'lastSession':
      return p.lastSession(m(0), s(1), s(2));
    case 'upgradeLadder':
      return p.upgradeLadder(m(0), s(1), a.length > 2 ? a[2] as num : null);
    case 'missedWorkout':
      return p.missedWorkout(m(0), s(1), m(2), m(3));
    case 'weekPlan':
      return p.weekPlan(m(0), s(1), m(2), m(3));
    case 'buildReminders':
      final o = m(0);
      return p
          .buildReminders(
            plan: f.jsonMap(o['plan']),
            now: DateTime.parse(o['now'] as String),
            today: o['today'] as String,
            dayStates: f.jsonMap(o['dayStates']),
            todayDone: o['todayDone'] == true,
            powderToday: o['powderToday'] == true,
            days: o['days'] as int,
          )
          .map(
            (r) => <String, dynamic>{
              ...r,
              'at': (r['at'] as DateTime).millisecondsSinceEpoch,
            },
          )
          .toList();
    case 'shiftDate':
      return f.shiftDate(s(0), a[1] as int);
    case 'weekday':
      return f.weekday(s(0));
    case 'dateLabel':
      return f.dateLabel(s(0));
    case 'fmt':
      return f.fmt(a[0]);
    case 'effortWord':
      return f.effortWord(a[0]);
    case 'groupSets':
      return f.groupSets(a[0] as List);
    case 'workVolume':
      return f.workVolume(a[0] as List);
    case 'userNote':
      return f.userNote(m(0));
    case 'GOAL_DEFAULTS':
      return g.GOAL_DEFAULTS;
    case 'clampGoals':
      return g.clampGoals(a[0]);
    case 'weekTargetFromHistory':
      return g.weekTargetFromHistory(a[0] as num, a[1] as num, m(2));
    case 'restPrefs':
      return r.restPrefs(a[0] as String?);
    case 'normalizeRestPrefs':
      return r.normalizeRestPrefs(a[0]);
    default:
      throw StateError(fn);
  }
}

void main() {
  final cases =
      jsonDecode(File('test/golden/plan.json').readAsStringSync()) as List;
  for (final (i, raw) in cases.indexed) {
    final c = f.jsonMap(raw);
    test('Web plan $i ${c['fn']}', () {
      final args = c['args'] as List;
      final before = jsonEncode(args);
      compareJson(runPlan(c['fn'] as String, args), c['expected']);
      if (c['fn'] != 'normalizePlan') {
        expect(
          jsonEncode(args),
          before,
          reason: 'read-only helpers must not mutate input',
        );
      }
    });
  }
  test('plan callbacks and Web normalization aliasing', () {
    final plan = p.defaultPlan();
    final workout = f.jsonMap(plan['workouts']['w1']);
    final list = p.exercisesFor(plan, workout, '2026-10-12', false, (_) => 1);
    expect(list.every((e) => e['target'] == 1), true);
    final result = p.dayProgress(
      plan,
      workout,
      '2026-10-12',
      {},
      false,
      (_) => 1,
    );
    expect(result['totalSets'], 4);
    final normalized = p.normalizePlan(plan);
    normalized['workouts']['w1']['exercises'][0]['sets'] = 9;
    expect(plan['workouts']['w1']['exercises'][0]['sets'], 9);
  });
}
