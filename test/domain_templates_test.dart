import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/domain/catalog.dart' show catalog;
import 'package:leandaily/domain/guide.dart' show guideFor;
import 'package:leandaily/domain/movements.dart' show musclesOf;
import 'package:leandaily/domain/plan.dart' as p;
import 'package:leandaily/domain/templates.dart';

Map<String, dynamic> map(Object? value) =>
    Map<String, dynamic>.from(value as Map);
List<Map<String, dynamic>> rows(Object? value) =>
    (value as List).map(map).toList();

void main() {
  test('nine immutable versioned metadata entries', () {
    expect(templates.length, 9);
    expect(templates.map((t) => t['id']).toSet().length, 9);
    expect(templates.first['id'], defaultTemplateId);
    for (final t in templates) {
      for (final key in ['name', 'summary', 'for']) {
        expect(t[key], isA<String>());
        expect((t[key] as String).isNotEmpty, true);
      }
      expect(t['version'], 1);
      expect(t['tags'], isNotEmpty);
      expect(t['venues'], isNotEmpty);
      expect(t['level'], isNotEmpty);
    }
  });
  for (final template in templates) {
    final id = template['id'] as String;
    for (final experience in ['new', 'some', 'trained']) {
      for (final sex in [null, 'male', 'female']) {
        test('$id / $experience / ${sex ?? 'no profile'} invariants', () {
          final profile = sex == null
              ? null
              : <String, dynamic>{
                  'experience': experience,
                  'sex': sex,
                  'venue': 'gym',
                };
          final beforeProfile = jsonEncode(profile);
          final plan = buildPlan(id, profile: profile, startDate: '2026-10-12');
          final snapshot = jsonDecode(jsonEncode(plan));
          expect(
            p.normalizePlan(plan),
            snapshot,
          ); // Nested aliasing must not hide changes.
          expect(jsonEncode(profile), beforeProfile);
          expect(map(plan['protein'])['goal'], 130);
          expect(map(map(plan['protein'])['powder'])['name'], '蛋白粉');
          expect(plan['startDate'], '2026-10-12');
          final workouts = map(plan['workouts']);
          expect(workouts.length, template['days']);
          expect(map(plan['schedule']).length, template['days']);
          final homeOnly = ['bodyweight-3', 'dumbbell-3'].contains(id);
          for (final w in workouts.values.map(map)) {
            expect(w.containsKey('gym'), !homeOnly);
            for (final variant in [w, if (!homeOnly) map(w['gym'])]) {
              final exercises = rows(variant['exercises']);
              expect(exercises.length, greaterThanOrEqualTo(4));
              expect(
                exercises.map((e) => e['id']).toSet().length,
                exercises.length,
              );
              for (final e in exercises) {
                final name = e['name'] as String;
                expect(musclesOf(name)?['muscles'], isNotEmpty, reason: name);
                expect(
                  musclesOf(name)?['matched'],
                  isNot('part'),
                  reason: name,
                );
                expect(
                  catalog().containsKey(name) ||
                      ['硬拉', '引体向上', '反向划船'].contains(name),
                  true,
                );
                if (id != 'legacy-home-gym-3') {
                  expect(e['gear'], isNotEmpty, reason: name);
                }
                expect(e['tip'], isNotEmpty, reason: name);
                if (id == 'bodyweight-3' ||
                    sex == null ||
                    experience == 'new') {
                  expect(e['sets'], 2);
                } else if (id == 'legacy-home-gym-3' &&
                    sex == 'female' &&
                    e['part'] == '胸') {
                  expect(e['sets'], 2);
                } else {
                  expect(e['sets'], 3);
                }
              }
              final resolved = p.exercisesFor(plan, variant, '2026-10-12');
              expect(
                p.estimateMinutes(plan, resolved, 5),
                lessThanOrEqualTo(75),
              );
            }
          }
          var trainingDays = 0;
          for (var day = 12; day <= 18; day++) {
            final iso = '2026-10-$day';
            final result = p.workoutFor(plan, iso);
            if (result['kind'] == 'rest') {
              expect(result['workout'], isNull);
              continue;
            }
            trainingDays++;
            for (final venue in ['home', 'gym']) {
              final w = map(
                p.workoutFor(plan, iso, {'venue': venue})['workout'],
              );
              expect(rows(w['exercises']).length, greaterThanOrEqualTo(4));
              expect(w['venue'], homeOnly ? 'home' : venue);
              expect(
                p.estimateMinutes(
                  plan,
                  p.exercisesFor(plan, w, iso),
                  map(w['warmup'])['minutes'] as num,
                ),
                lessThanOrEqualTo(75),
              );
            }
          }
          expect(trainingDays, template['days']);
        });
      }
    }
  }
  test('PPL gym required core and accessory movements and rep ranges', () {
    final plan = buildPlan(defaultTemplateId, profile: {'experience': 'some'});
    final workouts = map(plan['workouts']).values.map(map).toList();
    List<Map<String, dynamic>> gym(int i) =>
        rows(map(workouts[i]['gym'])['exercises']);
    expect(gym(0).where((e) => e['core'] == true).map((e) => e['name']), [
      '上斜哑铃卧推',
      '哑铃平板卧推',
      '坐姿肩推机',
    ]);
    expect(gym(1).where((e) => e['core'] == true).map((e) => e['name']), [
      '硬拉',
      '引体向上',
      '坐姿划船机',
    ]);
    expect(
      gym(2).map((e) => e['name']),
      containsAll(['深蹲', '坐姿肩推机', '绳索面拉', '轻哑铃侧平举']),
    );
    for (var i = 0; i < 3; i++) {
      for (final e in gym(i)) {
        expect([e['min'], e['max']], e['core'] == true ? [4, 6] : [8, 12]);
      }
    }
  });
  test(
    'legacy preserves original selections, ladders, rules and reminders',
    () {
      final legacy = p.defaultPlan('2026-10-12');
      final generated = buildPlan('legacy-home-gym-3', startDate: '2026-10-12');
      for (final key in [
        'schedule',
        'order',
        'ladders',
        'warmup',
        'gymWarmup',
        'rules',
        'gymRules',
        'reminder',
      ]) {
        expect(generated[key], legacy[key]);
      }
      for (final id in map(legacy['workouts']).keys) {
        final a = map(map(legacy['workouts'])[id]);
        final b = map(map(generated['workouts'])[id]);
        for (final venue in ['home', 'gym']) {
          expect(
            rows(venue == 'home' ? b['exercises'] : map(b['gym'])['exercises'])
                .map((e) => e['name']),
            rows(venue == 'home' ? a['exercises'] : map(a['gym'])['exercises'])
                .map((e) => e['name']),
          );
        }
      }
    },
  );
  test('female profile reduces duplicate chest and adds glute work', () {
    List<String> pushNames(String sex) => rows(
      map(
        map(
          buildPlan(defaultTemplateId, profile: {'sex': sex})['workouts'],
        )['t1'],
      )['exercises'],
    ).map((e) => e['name'] as String).toList();
    expect(pushNames('male'), contains('哑铃地板卧推'));
    expect(pushNames('female'), isNot(contains('哑铃地板卧推')));
    expect(pushNames('female'), contains('臀桥'));
  });
  test('fresh plans, stable IDs, empty dates and unknown IDs', () {
    for (final t in templates) {
      final id = t['id'] as String;
      final a = buildPlan(id);
      expect(a['startDate'], '');
      final snapshot = jsonDecode(jsonEncode(a));
      expect(p.normalizePlan(a), snapshot);
      expect(buildPlan(id), snapshot);
      a['protein']['powder']['name'] = 'changed';
      a['workouts'].clear();
      expect(buildPlan(id), snapshot);
    }
    expect(() => buildPlan('missing'), throwsArgumentError);
  });
  test(
    'missing demonstrations are explicit and never use unrelated images',
    () {
      final plan = buildPlan(defaultTemplateId);
      final pull = map(map(plan['workouts'])['t2']);
      for (final e in rows(
        map(pull['gym'])['exercises'],
      ).where((e) => ['硬拉', '引体向上'].contains(e['name']))) {
        expect(guideFor(e), isNull);
        expect(e['img'], '');
        expect(e['alts'], isNotEmpty);
      }
    },
  );
  group('explainable recommendations', () {
    Map<String, dynamic> profile({
      String sex = 'male',
      String venue = 'gym',
      int days = 3,
      String experience = 'new',
    }) => {
      'sex': sex,
      'venue': venue,
      'daysPerWeek': days,
      'experience': experience,
    };
    String top(Map<String, dynamic> person, [String stage = 'recomp']) =>
        recommend(person, {'stage': stage}).first['templateId'] as String;
    test('male three-day gym beginner prefers default PPL', () {
      expect(top(profile()), defaultTemplateId);
      final plan = buildPlan(top(profile()), profile: profile());
      expect(map(plan['venues']).values.every((v) => v == 'gym'), true);
    });
    test('female three-day home prioritizes shoulder/back/glutes', () {
      final person = profile(sex: 'female', venue: 'dumbbell');
      expect(top(person), 'lean-female-3');
      final plan = buildPlan(top(person), profile: person);
      expect(map(plan['venues']), isEmpty);
      final exercises = map(plan['workouts']).values
          .expand((w) => rows(map(w)['exercises']));
      expect(exercises.where((e) => e['part'] == '胸').length, 1);
      expect(
        exercises.where((e) => e['name'] == '臀桥').length,
        greaterThanOrEqualTo(2),
      );
    });
    test('lean male prioritizes refine and underweight stage prioritizes bulk plans', () {
      expect(top(profile(experience: 'trained'), 'refine'), 'refine-3');
      expect(top(profile(), 'bulk'), 'full-2');
      expect(top(profile(days: 4, experience: 'some'), 'bulk'), 'ul-4');
      expect(top(profile(days: 2)), 'full-2');
    });
    test(
      'equipment hard filtering includes no dumbbells or gym for bodyweight',
      () {
        final result = recommend(profile(venue: 'bodyweight'), {
          'stage': 'bulk',
        });
        expect(result.map((r) => r['templateId']), ['bodyweight-3']);
        expect(recommend(profile(venue: 'unsupported'), {}), isEmpty);
        final gymIds = recommend(profile(), {}).map((r) => r['templateId']);
        expect(gymIds, isNot(contains('dumbbell-3')));
        expect(gymIds, isNot(contains('bodyweight-3')));
        expect(recommend(profile(venue: 'both'), {}).length, 9);
        expect(
          top(profile(sex: 'female', venue: 'bodyweight')),
          'bodyweight-3',
        );
      },
    );
    test(
      'days, experience, sex and stage produce visible independent reasons',
      () {
        final person = profile(sex: 'female', venue: 'dumbbell');
        final best = recommend(person, {'stage': 'trim'}).first;
        expect(
          best['score'],
          180,
        ); // 60 days + 25 venue + 15 experience + 80 female.
        expect((best['reasons'] as List).join(' '), contains('女性优先'));
        final newPpl5 = recommend(
          profile(days: 5),
          {},
        ).firstWhere((r) => r['templateId'] == 'ppl-5');
        final trainedPpl5 = recommend(
          profile(days: 5, experience: 'trained'),
          {},
        ).firstWhere((r) => r['templateId'] == 'ppl-5');
        expect((trainedPpl5['score'] as int) - (newPpl5['score'] as int), 40);
        for (final stage in [
          'youth',
          'bulk',
          'cut',
          'recomp',
          'trim',
          'refine',
        ]) {
          final input = jsonEncode(person);
          final target = <String, dynamic>{'stage': stage};
          final targetBefore = jsonEncode(target);
          final result = recommend(person, target);
          expect(result, recommend(person, target));
          expect(person, jsonDecode(input));
          expect(jsonEncode(target), targetBefore);
          for (var i = 0; i < result.length; i++) {
            expect(result[i].keys.toSet(), {'templateId', 'score', 'reasons'});
            expect(result[i]['reasons'], isNotEmpty);
            if (i > 0) {
              expect(
                result[i - 1]['score'] as int,
                greaterThanOrEqualTo(result[i]['score'] as int),
              );
            }
            // Every recommendation can actually be materialized and normalized.
            final built = buildPlan(
              result[i]['templateId'] as String,
              profile: person,
            );
            final snapshot = jsonDecode(jsonEncode(built));
            expect(p.normalizePlan(built), snapshot);
          }
        }
      },
    );
    test('missing profile preferences use deterministic beginner defaults', () {
      expect(top({}), defaultTemplateId);
    });
  });
}
