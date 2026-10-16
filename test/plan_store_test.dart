import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/core/native.dart';
import 'package:leandaily/data/plan_store.dart';

import 'plan_library_test.dart' show legacyDocs, legacyVariants;

class FailingNative extends FakeNative {
  int? failAt;
  int calls = 0;
  final writes = <String>[];
  @override
  Future<void> put(String key, String value) async {
    writes.add(key);
    if (++calls == failAt) throw const NativeError('保存失败');
    await super.put(key, value);
  }
}

PlanStore store(FakeNative n) =>
    PlanStore(n, clock: () => DateTime.fromMillisecondsSinceEpoch(123456));

void main() {
  test('empty installation never creates a default plan or snapshot', () async {
    final n = FakeNative();
    final s = store(n);
    expect((await s.load('2026-10-15')).isEmpty, true);
    expect(n.docs, isEmpty);
    expect(s.activePlan, null);
  });

  test(
    'real legacy variants migrate without changing bytes or records',
    () async {
      for (final plan in legacyVariants()) {
        final n = FakeNative()..docs.addAll(legacyDocs());
        final raw = const JsonEncoder.withIndent('  ').convert(plan);
        n.docs[legacyPlanKey] = raw;
        n.docs['fw-progress-v1'] = '{"用户":{"stage":3}}';
        n.docs['fw-plan-day-v1'] = '{"2026-10-15":{"venue":"gym"}}';
        final before = Map.of(n.docs);
        final s = store(n);
        expect((await s.load('2026-10-15')).activePlan, plan);
        for (final entry in before.entries) {
          expect(n.docs[entry.key], entry.value);
        }
        expect(n.json(legacySnapshotKey), {
          'savedAt': 123456,
          'plan': plan,
          'progress': jsonDecode(before['fw-progress-v1']!),
          'dayStates': jsonDecode(before['fw-plan-day-v1']!),
        });
        final migrated = Map.of(n.docs);
        final writes = n.putCount;
        await s.load('2027-01-01');
        await store(n).load('2028-01-01');
        expect(n.docs, migrated);
        expect(n.putCount, writes);
        expect(n.docs.containsKey('fw-onboarded-v1'), false);
      }
    },
  );

  test('existing snapshot never overwritten even on migration retry', () async {
    final n = FailingNative()..docs.addAll(legacyDocs());
    n.failAt = 2; // snapshot succeeds, library commit fails
    final s = store(n);
    await expectLater(s.load('2026-10-15'), throwsA(isA<NativeError>()));
    expect(s.library.isEmpty, true);
    final snapshot = n.docs[legacySnapshotKey];
    n.docs[legacyPlanKey] = jsonEncode(legacyVariants()[1]);
    await s.load('2026-10-16');
    expect(n.docs[legacySnapshotKey], snapshot);
    expect(s.activePlan, legacyVariants()[1]);
    expect(n.writes.where((key) => key == legacySnapshotKey).length, 1);
  });

  test(
    'operations serialize across instances and keep compatibility plan',
    () async {
      final n = FakeNative()..docs.addAll(legacyDocs());
      final s = store(n);
      await s.load('2026-10-15');
      final snapshot = n.docs[legacySnapshotKey];
      final other = store(n);
      await Future.wait([
        s.duplicate('legacy', id: 'copy', name: '副本'),
        other.rename('copy', '改名'),
        s.setActive('copy'),
        other.update('copy', legacyVariants()[1]),
      ]);
      await s.load('2026-10-15');
      expect(s.library.items.last['name'], '改名');
      expect(s.activePlan, legacyVariants()[1]);
      expect(n.json(legacyPlanKey), s.activePlan);
      expect(n.docs[legacySnapshotKey], snapshot);
      await expectLater(s.remove('copy'), throwsStateError);
      await s.remove('legacy');
      await expectLater(s.remove('copy'), throwsStateError);
      final fresh = store(n);
      expect((await fresh.load('2026-10-15')).toJson(), s.library.toJson());
    },
  );

  test(
    'add first plan synchronizes old key and detaches queued input',
    () async {
      final n = FakeNative();
      final s = store(n);
      final plan = legacyVariants().first;
      final expected = jsonDecode(jsonEncode(plan));
      final pending = s.add(
        id: 'p1',
        name: '方案',
        plan: plan,
        source: 'template',
        templateId: 'full-2',
        templateVersion: 1,
      );
      plan['reminder']['time'] = '00:00';
      await pending;
      expect(s.activePlan, expected);
      expect(n.json(legacyPlanKey), expected);
      expect(n.docs.containsKey(legacySnapshotKey), false);
    },
  );

  test(
    'failure at each switch write rolls back disk and in-memory library',
    () async {
      for (final step in [1, 2]) {
        final n = FailingNative()..docs.addAll(legacyDocs());
        final s = store(n);
        await s.load('2026-10-15');
        await s.add(id: 'different', name: '不同', plan: legacyVariants()[1]);
        final before = Map.of(n.docs);
        final library = s.library.toJson();
        n.failAt = n.calls + step;
        await expectLater(
          s.setActive('different'),
          throwsA(isA<NativeError>()),
        );
        expect(n.docs, before);
        expect(s.library.toJson(), library);
        await s.setActive('different'); // failed queue remains usable
        expect(n.json(legacyPlanKey), legacyVariants()[1]);
      }
    },
  );

  test(
    'restore original plan progress and days without replacing snapshot',
    () async {
      final n = FakeNative()..docs.addAll(legacyDocs());
      n.docs['fw-progress-v1'] = '{"w1":{"n":2}}';
      n.docs['fw-plan-day-v1'] = '{"2026-10-15":{"skip":true}}';
      final s = store(n);
      await s.load('2026-10-15');
      final snapshot = n.docs[legacySnapshotKey];
      await s.add(id: 'other', name: '其他', plan: legacyVariants()[1]);
      await s.setActive('other');
      await s.remove('legacy');
      n.docs['fw-progress-v1'] = '{}';
      n.docs['fw-plan-day-v1'] = '{}';
      await s.restoreLegacySnapshot();
      expect(s.library.activeId, 'legacy');
      expect(s.activePlan, legacyVariants().first);
      expect(s.library.items.length, 2);
      expect(n.json('fw-progress-v1'), {
        'w1': {'n': 2},
      });
      expect(n.json('fw-plan-day-v1'), {
        '2026-10-15': {'skip': true},
      });
      expect(n.docs[legacySnapshotKey], snapshot);
      await s.update('legacy', legacyVariants()[1]);
      await s.restoreLegacySnapshot();
      expect(s.activePlan, legacyVariants().first);
      expect(s.library.items.length, 2);
    },
  );

  test(
    'restore rolls back every written document on any failed step',
    () async {
      for (final step in [1, 2, 3, 4]) {
        final n = FailingNative()..docs.addAll(legacyDocs());
        n.docs['fw-progress-v1'] = '{"old":1}';
        n.docs['fw-plan-day-v1'] = '{"old":2}';
        final s = store(n);
        await s.load('2026-10-15');
        await s.update('legacy', legacyVariants()[1]);
        n.docs['fw-progress-v1'] = '{"new":1}';
        n.docs['fw-plan-day-v1'] = '{"new":2}';
        final before = Map.of(n.docs);
        final memory = s.library.toJson();
        n.failAt = n.calls + step;
        await expectLater(
          s.restoreLegacySnapshot(),
          throwsA(isA<NativeError>()),
        );
        expect(n.docs, before);
        expect(s.library.toJson(), memory);
      }
    },
  );

  test(
    'invalid library or missing snapshot does not overwrite user data',
    () async {
      final n = FakeNative()..docs.addAll(legacyDocs());
      n.docs[planLibraryKey] = '{"v":99}';
      final before = Map.of(n.docs);
      await expectLater(store(n).load('2026-10-15'), throwsFormatException);
      await expectLater(
        store(n).restoreLegacySnapshot(),
        throwsFormatException,
      );
      expect(n.docs, before);
    },
  );
}
