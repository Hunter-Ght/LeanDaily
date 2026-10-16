import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/domain/calendar.dart';

void main() {
  test('calendar matches every web golden entry', () {
    final g = jsonDecode(
      File('test/golden/calendar.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    ({bool train, bool meal}) marks(String iso) => (
      train:
          int.parse(iso.substring(8)) % 10 == 3 ||
          int.parse(iso.substring(8)) % 10 == 0,
      meal: int.parse(iso.substring(8)) % 10 == 5,
    );
    for (final c in g['mondayOf']) {
      expect(mondayOf(c[0]), c[1]);
    }
    expect(
      weekDays(
        '2026-10-15',
        '2026-10-15',
        marks,
      ).map((c) => c.toJson()).toList(),
      g['weekDays'],
    );
    final grid = monthGrid('2026-10-15', '2026-10-15', marks);
    expect(grid.toJson(), g['monthGrid']);
    for (final c in g['rowOf']) {
      expect(rowOf(grid, c[0]), c[1]);
    }
    for (final c in g['stepWeek']) {
      expect(stepWeek(c[0], c[1], '2026-10-15'), c[2]);
    }
    for (final c in g['stepMonth']) {
      expect(stepMonth(c[0], c[1], c[2]), c[3]);
    }
    for (final c in g['shiftMonth']) {
      expect(shiftMonth(c[0], c[1]), c[2]);
    }
    for (final c in g['monthsApart']) {
      expect(monthsApart(c[0], c[1]), c[2]);
    }
    for (final c in g['daysApart']) {
      expect(daysApart(c[0], c[1]), c[2]);
    }
  });
}
