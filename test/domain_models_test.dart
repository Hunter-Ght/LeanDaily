import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/domain/movements.dart';
import 'package:leandaily/domain/muscles.dart';

void compare(dynamic actual, dynamic expected, [String path = '']) {
  if (expected is num) {
    expect(actual, closeTo(expected, 1e-6), reason: path);
  } else if (expected is Map) {
    expect((actual as Map).keys.toSet(), expected.keys.toSet(), reason: path);
    for (final k in expected.keys) {
      compare(actual[k], expected[k], '$path.$k');
    }
  } else if (expected is List) {
    expect((actual as List).length, expected.length, reason: path);
    for (var i = 0; i < expected.length; i++) {
      compare(actual[i], expected[i], '$path[$i]');
    }
  } else {
    expect(actual, expected, reason: path);
  }
}

void main() {
  test('movement catalog and all exact/keyword/part web cases', () {
    final g = jsonDecode(File('test/golden/movements.json').readAsStringSync());
    compare(MUSCLES, g['muscles']);
    compare(GROUPS, g['groups']);
    for (final c in g['cases']) {
      compare(musclesOf(c['name'], c['part']), c['result'], c['name']);
    }
    expect(catalogNames(), [
      for (final c in g['cases'])
        if (c['result']?['matched'] == 'exact') c['name'],
    ]);
  });
  test('every muscle status field matches web within 1e-6', () {
    final g = jsonDecode(File('test/golden/muscles.json').readAsStringSync());
    final days = {
      for (final e in (g['days'] as Map).entries)
        e.key as String: Map<String, dynamic>.from(e.value as Map),
    };
    final result = muscleStatus(days, g['nowMs']);
    final expected = g['expected'];
    compare(result['setCount'], expected['setCount']);
    for (final e in (expected['muscles'] as Map).entries) {
      for (final field in (e.value as Map).entries) {
        compare(
          result['byMuscle'][e.key][field.key],
          field.value,
          '${e.key}.${field.key}',
        );
      }
    }
    for (final e in (expected['groups'] as Map).entries) {
      for (final field in (e.value as Map).entries) {
        compare(
          result['groups'][e.key][field.key],
          field.value,
          '${e.key}.${field.key}',
        );
      }
    }
  });
  test('warmups, deleted sets, missing names and null rows are excluded', () {
    expect(
      workSets({
        '2026-10-15': {
          'sets': [
            null,
            {'ex': ''},
            {'ex': '深蹲', 'deleted': true},
            {'ex': '深蹲', 'type': '热身'},
            {'ex': '深蹲'},
          ],
        },
      }),
      [
        {'ex': '深蹲', 'date': '2026-10-15'},
      ],
    );
    expect(intensityOf({'rpe': 10}), 1.25);
    expect(intensityOf({'rpe': 1}), 0.65);
    expect(intensityOf({'rpe': '', 'w': 0}), 1);
    expect(detrainLevel(null), 1);
    expect(detrainLevel(-1), 0);
    expect(detrainLevel(21), 0.5);
  });
  test('nominal timestamp, one-hour future grace and reference cap', () {
    final now = dateMs('2026-10-15');
    Map<String, dynamic> set({num? ts, String type = '正式'}) => {
      'ex': '腿屈伸',
      'part': '腿',
      'date': '2026-10-15',
      'w': 0,
      'reps': 10,
      'type': type,
      'ts': ?ts,
    };
    final result = muscleStatus({
      '2026-10-15': {
        'sets': [
          set(),
          set(ts: now + 3600000),
          set(ts: now + 3600001),
          set(type: '递减'),
        ],
      },
    }, now);
    final q = result['byMuscle']['quads'];
    expect(result['setCount'], 4);
    expect(q['fatigue'], closeTo(2.75, 1e-9));
    expect(q['sets7'], 2.75);
    expect(q['ref'], 6);
    expect(q['from'], [
      {'ex': '腿屈伸', 'sets': 3, 'load': 2.75},
    ]);
    expect(result['groups']['quads']['sets7'], 3);
    final big = muscleStatus({
      '2026-10-15': {'sets': List.generate(20, (_) => set())},
    }, now);
    expect(big['byMuscle']['quads']['ref'], 14);
    final old = muscleStatus({
      '2026-07-22': {
        'sets': List.generate(20, (_) => {...set(), 'date': '2026-07-22'}),
      },
    }, now);
    expect(old['byMuscle']['quads']['ref'], 6);
    expect(old['byMuscle']['quads']['from'], isEmpty);
  });
  test(
    'intensity fallback uses historical estimated maximum and clamps RPE',
    () {
      expect(intensityOf({'rpe': '8'}), closeTo(1.05, 1e-9));
      expect(
        intensityOf({'rpe': 11, 'w': 30, 'reps': 10}, 80),
        closeTo(0.95, 1e-9),
      );
      expect(intensityOf({'w': 100, 'reps': 30}, 50), 1.2);
      expect(intensityOf({'rpe': 'bad', 'w': 0}), 1);
    },
  );
}
