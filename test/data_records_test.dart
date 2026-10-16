import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/domain/records.dart';
import 'package:leandaily/core/native.dart';
import 'package:leandaily/data/repository.dart';

void compare(Object? a, Object? b) {
  if (a is num && b is num) {
    expect(a, closeTo(b, 1e-6));
  } else if (a is Map && b is Map) {
    expect(a.keys.toSet(), b.keys.toSet());
    for (final k in a.keys) {
      compare(a[k], b[k]);
    }
  } else if (a is List && b is List) {
    expect(a.length, b.length);
    for (var i = 0; i < a.length; i++) {
      compare(a[i], b[i]);
    }
  } else {
    expect(a, b);
  }
}

void main() {
  test(
    'version gate, all-day history, empty failures and lane recovery',
    () async {
      final n = FakeNative();
      n.docs['android-state'] = '{"version":2}';
      final r = Repository(n);
      await expectLater(
        r.load(),
        throwsA(
          isA<DomainError>().having(
            (e) => e.message,
            'message',
            '数据版本不兼容，请更新 APP',
          ),
        ),
      );
      n.docs.clear();
      await r.load();
      await expectLater(
        r.addSets(
          date: '2025-02-29',
          exercise: 'x',
          rows: [
            {'weight': 0, 'reps': 1},
          ],
        ),
        throwsA(isA<DomainError>()),
      );
      await expectLater(
        r.addSets(
          date: '2026-10-15',
          exercise: ' ',
          rows: [
            {'weight': 0, 'reps': 1},
          ],
        ),
        throwsA(isA<DomainError>()),
      );
      await expectLater(
        r.saveMeal(date: '2026-10-15', meal: '早餐'),
        throwsA(isA<DomainError>()),
      );
      expect(r.revision, 0);
      expect(n.putCount, 0);
      await r.addSets(
        date: '2026-10-15',
        exercise: '卧推',
        part: '胸',
        rows: [
          {'weight': 10, 'reps': 5, 'type': '热身'},
        ],
      );
      await r.addSets(
        date: '2026-10-14',
        exercise: '卧推',
        part: '胸',
        rows: [
          {'weight': 20, 'reps': 8},
        ],
      );
      await r.setDayNote('2026-10-15', '好');
      expect(r.hasTrain('2026-10-15'), false);
      expect(r.allDays().keys.toSet(), {'2026-10-14', '2026-10-15'});
      expect(r.day('2026-10-15')['day_row'], {'体感备注': '好'});
      final recent = r.recentByExercise();
      expect(recent['last']['卧推']['date'], '2026-10-15');
      expect(recent['byPart'], {
        '胸': ['卧推'],
      });
      await expectLater(
        r.updateSet('missing', '2026-10-15', 1, 1, '正式', null),
        throwsA(isA<DomainError>()),
      );
      final reopened = Repository(n);
      await reopened.load();
      expect(reopened.state, r.state);
    },
  );
  test('Web records golden', () {
    final cases =
        jsonDecode(File('test/golden/records.json').readAsStringSync()) as List;
    for (final c in cases) {
      Object? run() {
        final i = c['input'] as List;
        switch (c['fn']) {
          case 'dayOf':
            return dayOf(Map<String, dynamic>.from(i[0]), i[1]);
          case 'mealsOf':
            return mealsOf(Map<String, dynamic>.from(i[0]), i[1]);
          case 'cleanItems':
            return cleanItems(i[0]);
          case 'sumItems':
            return sumItems(i[0]);
          case 'validateSets':
            validateSets(i[0]);
            return null;
          default:
            throw StateError('unknown');
        }
      }

      if (c.containsKey('error')) {
        expect(
          run,
          throwsA(
            isA<DomainError>().having((e) => e.message, 'message', c['error']),
          ),
        );
      } else {
        compare(run(), c['expected']);
      }
    }
  });
  test(
    'serial writes, rollback, readonly projections and meal semantics',
    () async {
      final n = FakeNative();
      final r = Repository(n);
      await r.load();
      Future<List<String>> add() => r.addSets(
        date: '2026-10-15',
        exercise: '卧推',
        part: '胸',
        unilateral: true,
        rows: [
          {'weight': 50, 'reps': 8, 'count': 2, 'flag': 'form', 'notes': '慢'},
        ],
      );
      final ids = (await Future.wait([add(), add()])).expand((e) => e).toList();
      expect((r.day('2026-10-15')['sets'] as List).map((s) => s['no']), [
        1,
        2,
        3,
        4,
      ]);
      expect(r.revision, 2);
      expect(r.hasTrain('2026-10-15'), true);
      final before = jsonEncode(r.state);
      n.failNextPut = const NativeError('磁盘已满');
      await expectLater(add(), throwsA(isA<NativeError>()));
      expect(jsonEncode(r.state), before);
      expect(() => r.state['sets']['x'] = 1, throwsUnsupportedError);
      expect(() => r.day('2026-10-15')['sets'].clear(), throwsUnsupportedError);
      await r.updateSet(ids.first, '2026-10-15', 60, 10, '正式', 9);
      await r.deleteSets('2026-10-15', ids);
      expect(r.hasTrain('2026-10-15'), false);
      final meal = await r.saveMeal(
        date: '2026-10-15',
        meal: '早餐',
        items: [
          {'name': '蛋', 'protein': 6},
        ],
      );
      await r.updateMeal(id: meal, date: '2026-10-15', meal: '午餐', note: '备注');
      expect(r.hasMeal('2026-10-15'), true);
      final old = jsonEncode(r.state);
      await expectLater(
        r.updateMeal(
          id: meal,
          date: '2026-10-15',
          meal: '午餐',
          note: '备注',
          photoIds: ['missing'],
          photosChanged: true,
        ),
        throwsA(isA<NativeError>()),
      );
      expect(jsonEncode(r.state), old);
      await r.deleteMeal('2026-10-15', meal);
      expect(r.hasMeal('2026-10-15'), false);
      await add();
      expect(r.revision, 8);
    },
  );
}
