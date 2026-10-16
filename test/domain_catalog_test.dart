import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/domain/catalog.dart';
import 'package:leandaily/domain/plan.dart' as plans;
import 'package:leandaily/domain/guide.dart';
import 'package:leandaily/domain/movements.dart' show musclesOf;

import 'domain_stats_test.dart' show compare, jsonMap;

void main() {
  final golden =
      jsonDecode(File('test/golden/catalog.json').readAsStringSync()) as Map;
  test('catalog matches every Web prescription and insertion order', () {
    compare(catalog(), golden['catalog']);
    expect(catalog().keys.toList(), (golden['catalog'] as Map).keys.toList());
    for (final spec in catalog().values) {
      expect(
        musclesOf(spec['name'], spec['part'] as String)?['matched'],
        'exact',
      );
      expect(guideFor(spec), isNotNull);
    }
  });
  test('all muscle and venue lookups preserve stable Web sorting', () {
    for (final c in golden['lookups']) {
      compare(
        exercisesForMuscle(c['muscle'] as String, c['venue'] as String),
        c['expected'],
        '${c['muscle']} ${c['venue']}',
      );
    }
  });
  test('100 seeded Web plans: add/remove, weekly totals, slots and effect', () {
    for (final (i, c) in (golden['cases'] as List).indexed) {
      final plan = jsonMap(c['plan']), spec = jsonMap(c['spec']);
      final id = c['workoutId'] as String, venue = c['venue'] as String;
      final expected = c['expected'];
      final before = jsonEncode(plan);
      final added = addToPlan(
        plan,
        id,
        venue,
        spec,
        optional: c['optional'] as bool,
        createId: () => 'x${1792022400000.toRadixString(36)}i',
      );
      compare(
        whereInPlan(plan, spec['name'] as String),
        expected['where'],
        'where $i',
      );
      compare(added, expected['added'], 'add $i');
      compare(
        removeFromPlan(added, id, venue, spec['name'] as String),
        expected['removed'],
        'remove $i',
      );
      compare(plannedWeekly(plan), expected['weekly'], 'weekly $i');
      compare(
        recommendSlots(
          plan,
          c['status'] == null ? null : jsonMap(c['status']),
          c['muscle'] as String,
          venue,
          spec,
          c['today'] as String,
        ),
        expected['slots'],
        'slots $i',
      );
      compare(weeklyEffect(plan, spec, id), expected['effect'], 'effect $i');
      expect(
        jsonEncode(plan),
        before,
        reason: 'original plan mutated, case $i',
      );
    }
  });
  test('deep copies, no-op identity, gym creation and single removal', () {
    final plan = plans.defaultPlan('2026-10-12');
    final spec = catalog()['站姿提踵']!;
    final added = addToPlan(plan, 'w1', 'home', spec);
    expect(identical(added, plan), isFalse);
    expect(identical(addToPlan(added, 'w1', 'home', spec), added), isTrue);
    expect(identical(addToPlan(plan, 'missing', 'home', spec), plan), isTrue);
    expect(
      identical(removeFromPlan(plan, 'missing', 'gym', 'unknown'), plan),
      isTrue,
    );
    expect(
      identical(removeFromPlan(plan, 'w1', 'home', 'unknown'), plan),
      isTrue,
    );
    expect(
      (listOf(jsonMap(added['workouts']['w1']), 'home').last as Map)['id'],
      matches(RegExp(r'^x[0-9a-z]+$')),
    );
    added['workouts']['w1']['name'] = 'changed';
    expect(plan['workouts']['w1']['name'], isNot('changed'));
    final w = plan['workouts']['w1'] as Map;
    w.remove('gym');
    final gym = addToPlan(plan, 'w1', 'gym', spec);
    expect(gym['workouts']['w1']['gym']['tag'], '');
    expect(w.containsKey('gym'), isFalse);
    final list = listOf(jsonMap(gym['workouts']['w1']), 'gym');
    list.add({...jsonMap(list.first)});
    final removed = removeFromPlan(gym, 'w1', 'gym', spec['name'] as String);
    expect(listOf(jsonMap(removed['workouts']['w1']), 'gym').length, 1);
    expect(list.length, 2);
  });
  test('venue callback and unknown muscle preserve Web edge behavior', () {
    final plan = plans.defaultPlan();
    final allGym = plannedWeekly(plan, (_) => 'gym');
    plan['venues'] = {'1': 'gym', '3': 'gym', '5': 'gym'};
    expect(plannedWeekly(plan), allGym);
    expect(weeklyEffect(plan, {'name': '跑步机', 'part': '有氧'}, 'w1'), isNull);
  });
}
