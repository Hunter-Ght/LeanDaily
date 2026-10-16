import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/domain/format.dart';
import 'package:leandaily/domain/plan.dart';
import 'package:leandaily/domain/progress.dart' as g;

import 'domain_plan_test.dart' show compareJson;

Map<String, dynamic> _find(Map<String, dynamic> plan, String id) {
  for (final w in jsonMap(plan['workouts']).values) {
    for (final e in [
      ...jsonRows(w['exercises']),
      ...jsonRows(w['gym']['exercises']),
    ]) {
      if (e['id'] == id) return resolveEx(plan, e);
    }
  }
  throw StateError(id);
}

dynamic _call(String fn, List<dynamic> a) {
  Map<String, dynamic> m(int i) => jsonMap(a[i]);
  String s(int i) => a[i] as String;
  switch (fn) {
    case 'emptyProgress':
      return g.emptyProgress();
    case 'sessionsOf':
      return g.sessionsOf(m(0), s(1));
    case 'evaluate':
      return g.evaluate(m(0), m(1), a[2] as num, a[3]);
    case 'targetFor':
      final o = m(2);
      return g.targetFor(
        m(0),
        m(1),
        anchor: o['anchor'] == null ? null : jsonMap(o['anchor']),
        dayStates: jsonMap(o['dayStates']),
        today: o['today'] as String,
        include: o['include'] == true,
        progress: o['progress'] == null ? null : jsonMap(o['progress']),
      );
    case 'adherence':
      return g.adherence(m(0), m(1), m(2), s(3));
    case 'weeklyGroups':
      return g.weeklyGroups(m(0), s(1));
    case 'recentRedFlag':
      return g.recentRedFlag(m(0), m(1), s(2));
    case 'suggest':
      return g.suggest(m(0), m(1));
    case 'applyAccept':
      return g.applyAccept(m(0), a[1] == null ? null : m(1), m(2), s(3));
    case 'decline':
      return g.decline(a[0] == null ? null : m(0), s(1), s(2));
    case 'isPersonalBest':
      return g.isPersonalBest(m(0), s(1), a[2], a[3]);
    case 'weeklyReview':
      return g.weeklyReview(m(0), m(1), m(2), s(3));
    default:
      throw StateError(fn);
  }
}

void main() {
  final data = jsonMap(
    jsonDecode(File('test/golden/progress.json').readAsStringSync()),
  );
  test('Web engine configuration', () {
    compareJson(g.CFG, data['CFG']);
    compareJson(g.BUDGET, data['BUDGET']);
  });
  for (final (i, c) in jsonRows(data['cases']).indexed) {
    test('Web progress direct $i ${c['fn']}', () {
      final args = c['args'] as List, before = jsonEncode(c['args']);
      compareJson(_call(c['fn'] as String, args), c['expected']);
      expect(jsonEncode(args), before, reason: 'do not mutate arguments');
    });
  }
  for (final run in jsonRows(data['runs'])) {
    test('Web replay ${run['id']} ${run['mode']} (48 sessions)', () {
      var plan = cloneJson(jsonMap(run['initialPlan'])),
          progress = cloneJson(jsonMap(run['initialProgress']));
      final days = <String, dynamic>{}, states = <String, dynamic>{};
      for (final (i, step) in jsonRows(run['steps']).indexed) {
        final date = step['date'] as String,
            ex = _find(plan, run['id'] as String),
            e = jsonMap(step['expected']);
        final snapshot = jsonEncode([plan, progress, days, states]);
        compareJson(
          g.targetFor(
            ex,
            days,
            today: date,
            dayStates: states,
            progress: progress,
          ),
          e['before'],
          'step $i before',
        );
        final sets = step['sets'] as List;
        final partialDays = <String, dynamic>{
          ...days,
          date: {'sets': sets.take(1).toList()},
        };
        compareJson(
          g.targetFor(
            ex,
            partialDays,
            today: date,
            include: true,
            dayStates: states,
            progress: progress,
          ),
          e['partial'],
          'step $i partial',
        );
        expect(jsonEncode([plan, progress, days, states]), snapshot);
        states[date] = step['dayState'];
        days[date] = {'sets': sets};
        final review = g.weeklyReview(plan, days, states, date);
        compareJson(review, e['review'], 'step $i review');
        compareJson(
          g.targetFor(
            ex,
            days,
            today: date,
            include: true,
            dayStates: states,
            progress: progress,
          ),
          e['target'],
          'step $i target',
        );
        final suggestion = g.suggest(ex, {
          'plan': plan,
          'days': days,
          'dayStates': states,
          'today': date,
          'progress': progress,
          'review': review,
        });
        compareJson(suggestion, e['suggestion'], 'step $i suggest');
        compareJson(
          g.sessionsOf(days, ex['name'] as String),
          e['sessions'],
          'step $i sessions',
        );
        compareJson(
          g.recentRedFlag(days, states, date),
          e['redFlag'],
          'step $i redFlag',
        );
        final first = jsonMap(sets.first);
        compareJson(
          g.isPersonalBest(
            days,
            ex['name'] as String,
            jsNumber(first['reps']) + 1,
            first['w'],
          ),
          e['pb'],
          'step $i PB',
        );
        final beforeAccept = jsonEncode([plan, progress]);
        if (step['action'] == 'accept') {
          final applied = g.applyAccept(
            plan,
            progress,
            jsonMap(suggestion!['accept']),
            date,
          );
          expect(jsonEncode([plan, progress]), beforeAccept);
          compareJson(applied, e['applied'], 'step $i applied');
          plan = jsonMap(applied['plan']);
          progress = jsonMap(applied['progress']);
        } else if (step['action'] == 'decline') {
          final next = g.decline(progress, suggestion!['key'] as String, date);
          expect(jsonEncode([plan, progress]), beforeAccept);
          compareJson(next, e['progress'], 'step $i declined');
          progress = next;
        }
      }
    });
  }
}
