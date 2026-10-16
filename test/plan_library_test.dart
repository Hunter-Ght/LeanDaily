import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/domain/plan.dart';
import 'package:leandaily/domain/plan_library.dart';

Map<String, String> legacyDocs() => Map<String, String>.from(
  jsonDecode(File('test/fixtures/legacy_store.json').readAsStringSync()) as Map,
);

List<Map<String, dynamic>> legacyVariants() {
  Map<String, dynamic> fresh() =>
      jsonDecode(legacyDocs()['fw-plan-v1']!) as Map<String, dynamic>;
  final edited = fresh();
  final exercises = edited['workouts']['w1']['exercises'] as List;
  exercises.first['name'] = '哑铃卧推';
  exercises.first['sets'] = 5;
  exercises.removeLast();
  exercises.add({...exercises.first as Map, 'id': 'user-added', 'sets': 4});
  edited['reminder']['time'] = '06:35';
  edited['reminder']['proteinTime'] = '21:45';
  edited['protein']['goal'] = 135;
  edited['protein']['powder'] = {
    'name': '用户蛋白粉',
    'grams': 25,
    'protein': 19.5,
    'kcal': 103,
  };
  edited['venues'] = {'1': 'gym', '3': 'home', '5': 'gym'};
  final unnormalized = fresh();
  unnormalized['version'] = 1;
  unnormalized['startDate'] = '';
  unnormalized['rampWeeks'] = 7;
  unnormalized['userExtension'] = {
    'keep': [1, null, '原文'],
  };
  return [fresh(), edited, unnormalized, normalizePlan(fresh())];
}

void main() {
  test('migration preserves real legacy and edited JSON exactly', () {
    for (final plan in legacyVariants()) {
      final before = jsonEncode(plan);
      final library = migrateFromLegacy(plan, 123);
      expect(library.activeId, 'legacy');
      expect(library.activePlan, jsonDecode(before));
      expect(jsonEncode(plan), before);
      expect(library.items.single, containsPair('name', '我的原始方案'));
      expect(library.items.single, containsPair('source', 'legacy'));
      expect(
        library.items.single['needsNormalize'],
        library.activePlan != null &&
            !const DeepCollectionEqualityForTest().equal(
              normalizePlan(jsonDecode(before)),
              jsonDecode(before),
            ),
      );
      expect(PlanLibrary.fromJson(library.toJson()).toJson(), library.toJson());
    }
    expect(
      migrateFromLegacy(
        normalizePlan(legacyVariants().first),
        0,
      ).items.single['needsNormalize'],
      false,
    );
    expect(
      migrateFromLegacy(jsonEncode(legacyVariants().first), 0).activePlan,
      legacyVariants().first,
    );
  });

  test(
    'add rename duplicate switch update remove and immutable boundaries',
    () {
      final empty = PlanLibrary.empty();
      expect(empty.isEmpty, true);
      expect(empty.activePlan, null);
      final a = empty.add(
        id: 'a',
        name: 'A',
        plan: {
          'value': [1],
        },
        now: 1,
        source: 'template',
        templateId: 'full-2',
        templateVersion: 1,
      );
      final b = a.duplicate('a', id: 'b', name: 'B', now: 2);
      expect(a.items.length, 1);
      expect(b.items.last['source'], 'custom');
      expect(b.items.last['createdAt'], 2);
      expect(b.activeId, 'a');
      expect(b.rename('b', '新名', 3).items.last['name'], '新名');
      final c = b.setActive('b').update('b', {'value': 2}, 4);
      expect(c.activePlan, {'value': 2});
      expect(c.items.last['updatedAt'], 4);
      expect(c.remove('a').items.length, 1);
      expect(() => c.remove('b'), throwsStateError);
      expect(() => a.remove('a'), throwsStateError);
      expect(() => c.setActive('missing'), throwsArgumentError);
      expect(() => c.rename('missing', '', 0), throwsArgumentError);
      expect(() => c.update('missing', {}, 0), throwsArgumentError);
      expect(() => c.remove('missing'), throwsArgumentError);
      expect(
        () => c.add(id: 'a', name: '', plan: {}, now: 0),
        throwsArgumentError,
      );
      expect(
        () => c.add(id: '', name: '', plan: {}, now: 0),
        throwsArgumentError,
      );
      expect(
        () => c.add(id: 'c', name: '', source: 'unknown', plan: {}, now: 0),
        throwsArgumentError,
      );
      b.activePlan!['value'][0] = 99;
      b.items.first['plan']['value'][0] = 99;
      b.toJson()['items'].clear();
      expect(b.activePlan, {
        'value': [1],
      });
      expect(b.items.length, 2);
    },
  );

  test('reject invalid library rather than silently replacing user data', () {
    for (final raw in [
      <String, dynamic>{},
      {'v': 2, 'activeId': null, 'items': []},
      {'v': 1, 'activeId': 'missing', 'items': []},
      {
        'v': 1,
        'activeId': null,
        'items': [{}],
      },
    ]) {
      expect(() => PlanLibrary.fromJson(raw), throwsFormatException);
    }
    expect(() => migrateFromLegacy('null', 0), throwsFormatException);
  });
}

// JSON structural comparison without extra packages (map order is irrelevant).
class DeepCollectionEqualityForTest {
  const DeepCollectionEqualityForTest();
  bool equal(Object? a, Object? b) {
    if (a is Map && b is Map) {
      return a.length == b.length &&
          a.keys.every((k) => b.containsKey(k) && equal(a[k], b[k]));
    }
    if (a is List && b is List) {
      return a.length == b.length &&
          List.generate(a.length, (i) => i).every((i) => equal(a[i], b[i]));
    }
    return a == b;
  }
}
