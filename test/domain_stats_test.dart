import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/domain/stats.dart';

void compare(Object? actual, Object? expected, [String path = '']) {
  if (expected is num) {
    expect(actual, closeTo(expected, 1e-6), reason: path);
  } else if (expected is Map) {
    expect((actual as Map).keys.toSet(), expected.keys.toSet(), reason: path);
    for (final key in expected.keys) {
      compare(actual[key], expected[key], '$path.$key');
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

Map<String, dynamic> jsonMap(Object? value) =>
    Map<String, dynamic>.from(value as Map);
void main() {
  final golden =
      jsonDecode(File('test/golden/stats.json').readAsStringSync()) as Map;
  test('Web stats: empty, leap/year boundaries, a year of history, live overrides and heavy records', () {
    for (final c in golden['cases']) {
      final before = jsonEncode(c);
      compare(
        buildStats(
          c['today'] as String?,
          c['liveDay'] == null ? null : jsonMap(c['liveDay']),
          c['liveMeals'] == null ? null : jsonMap(c['liveMeals']),
          days: jsonMap(c['days']),
          meals: jsonMap(c['meals']),
        ),
        c['expected'],
        'stats ${c['today']}',
      );
      expect(jsonEncode(c), before, reason: 'input snapshots must not change');
    }
  });
  test('Web chart output includes exact SVG line text and last 16 points', () {
    for (final c in golden['charts']) {
      compare(
        chartPoints([for (final p in c['input']) jsonMap(p)]),
        c['expected'],
      );
    }
  });
}
