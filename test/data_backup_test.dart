import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/core/native.dart';
import 'package:leandaily/core/sha256.dart';
import 'package:leandaily/data/backup.dart';
import 'package:leandaily/data/repository.dart';
import 'package:leandaily/data/prefs.dart';
import 'package:leandaily/data/plan_store.dart';
import 'package:leandaily/domain/records.dart';

import 'data_records_test.dart' show compare;
import 'plan_library_test.dart' show legacyDocs, legacyVariants;

class HashNative extends FakeNative {
  @override
  Future<PhotoData> photoRead(String path) async {
    final p = await super.photoRead(path);
    return PhotoData(bytes: p.bytes, size: p.size, sha256: sha256(p.bytes));
  }
}

void main() {
  test('SHA-256 FIPS vectors', () {
    expect(
      sha256([]),
      'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    );
    expect(
      sha256(utf8.encode('abc')),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
    expect(
      sha256(
        utf8.encode('abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq'),
      ),
      '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1',
    );
    expect(
      sha256(List.filled(1000000, 97)),
      'cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0',
    );
  });
  test('Web backup validation and integrity golden', () async {
    final g = jsonDecode(File('test/golden/backup.json').readAsStringSync());
    for (final c in g['cases']) {
      if (c['error'] != null) {
        await expectLater(
          validateBackup(c['input'], native: FakeNative()),
          throwsA(
            isA<DomainError>().having((e) => e.message, 'message', c['error']),
          ),
        );
      } else {
        compare(
          await validateBackup(c['input'], native: FakeNative()),
          c['expected'],
        );
      }
    }
    for (final c in g['integrity']) {
      if (c['error'] != null) {
        expect(
          () => checkIntegrity(c['input']),
          throwsA(
            isA<DomainError>().having((e) => e.message, 'message', c['error']),
          ),
        );
      } else {
        checkIntegrity(c['input']);
      }
    }
  });
  test(
    'export/import restores photos, clears credentials, retains opaque prefs',
    () async {
      final n = HashNative();
      final repo = Repository(n);
      await repo.load();
      final photo = await n.photoWrite(
        Uint8List.fromList([255, 216, 255, 224, 1, 2, 3]),
      );
      await repo.saveMeal(date: '2026-10-15', meal: '早餐', photoIds: [photo]);
      final pendingSave = repo.addSets(
        date: '2026-10-15',
        exercise: '卧推',
        rows: [
          {'weight': 40, 'reps': 10},
        ],
      );
      n.docs['fw-plan-v1'] = '{"opaque":true}';
      n.docs['fw-cache-v1'] = '{"outbox":[1]}';
      n.docs['android-meal-draft:x'] = '{}';
      final b = await exportBackup(n, repo);
      await pendingSave;
      expect(b['state']['sets'], isNotEmpty);
      await validateBackup(b, native: n);
      checkIntegrity(b);
      n.importData = n.exported;
      expect((await chooseBackup(n))['format'], 'leandaily-backup');
      await restoreBackup(n, repo, b);
      expect(n.docs['fw-plan-v1'], '{"opaque":true}');
      expect(n.docs['fw-cache-v1'], 'null');
      expect(n.secrets.modelKey, '');
      expect(repo.hasTrain('2026-10-15'), true);
      expect(repo.hasMeal('2026-10-15'), true);
      expect(repo.state['meals'].values.first['photo_ids'].first, isNot(photo));
      expect(repo.state['tasks'], isEmpty);
      expect(repo.state['revision'], 0);
    },
  );
  test(
    'new preference keys round trip as opaque strings in version 1 backup',
    () async {
      final n = FakeNative()..docs.addAll(legacyDocs());
      final plans = PlanStore(n);
      await plans.load('2026-10-15');
      await plans.add(id: 'p1', name: '新增', plan: legacyVariants()[1]);
      await plans.setActive('p1');
      n.docs['fw-profile-v1'] = '{"sex":"female","extension":[1,null]}';
      n.docs['fw-onboarded-v1'] = '1';
      n.docs['fw-progress-v1'] = '{"customProgress":3}';
      n.docs['fw-plan-day-v1'] = '{"2026-10-15":{"venue":"gym"}}';
      final repo = Repository(n);
      // The upgrade fixture uses intentionally short record IDs; keep this test
      // focused on preferences with an empty, valid repository state.
      final clean = FakeNative();
      final cleanRepo = Repository(clean);
      await cleanRepo.load();
      await repo.replaceState(Map<String, dynamic>.from(cleanRepo.state));
      final before = Map.of(n.docs);
      final backup = await exportBackup(n, repo);
      expect(backup['version'], 1);
      for (final key in [
        planLibraryKey,
        legacyPlanKey,
        legacySnapshotKey,
        'fw-profile-v1',
        'fw-onboarded-v1',
        'fw-progress-v1',
        'fw-plan-day-v1',
      ]) {
        expect(backup['preferences'][key], before[key]);
      }
      final target = FakeNative();
      final targetRepo = Repository(target);
      await targetRepo.load();
      await restoreBackup(target, targetRepo, backup);
      expect(target.docs[planLibraryKey], before[planLibraryKey]);
      expect(target.docs[legacySnapshotKey], before[legacySnapshotKey]);
      expect(target.docs['fw-profile-v1'], before['fw-profile-v1']);
      expect(target.docs['fw-onboarded-v1'], '1');
      final loaded = await PlanStore(target).load('2026-10-16');
      expect(loaded.activeId, 'p1');
      expect(loaded.activePlan, legacyVariants()[1]);
      final again = await exportBackup(target, targetRepo);
      for (final entry in (backup['preferences'] as Map).entries) {
        expect(again['preferences'][entry.key], entry.value);
      }
      // Existing backup behavior materializes absent preferences as JSON null.
      expect(again['preferences']['fw-goals-v1'], 'null');
    },
  );

  test(
    'old backup clears newer preferences then migrates restored legacy plan',
    () async {
      final source = FakeNative();
      source.docs[legacyPlanKey] = legacyDocs()[legacyPlanKey]!;
      source.docs['fw-progress-v1'] = '{"keepProgress":[1,2]}';
      source.docs['fw-plan-day-v1'] = '{"2026-10-15":{"skip":true}}';
      final repo = Repository(source);
      await repo.load();
      final backup = await exportBackup(source, repo);
      final prefs = backup['preferences'] as Map;
      for (final key in [
        planLibraryKey,
        legacySnapshotKey,
        'fw-profile-v1',
        'fw-onboarded-v1',
      ]) {
        expect(prefs.containsKey(key), false);
      }
      final target = FakeNative();
      final plans = PlanStore(target);
      await plans.add(id: 'stale', name: '旧库', plan: legacyVariants()[1]);
      target.docs[legacySnapshotKey] = '{"stale":true}';
      target.docs['fw-profile-v1'] = '{"stale":true}';
      target.docs['fw-onboarded-v1'] = '1';
      final targetRepo = Repository(target);
      await targetRepo.load();
      await restoreBackup(target, targetRepo, backup);
      expect(target.docs[planLibraryKey], 'null');
      expect(target.docs['fw-profile-v1'], 'null');
      expect(target.docs['fw-onboarded-v1'], 'null');
      final loaded = await plans.load('2026-10-15');
      expect(loaded.activeId, 'legacy');
      expect(loaded.activePlan, legacyVariants().first);
      expect(target.docs[legacyPlanKey], source.docs[legacyPlanKey]);
      expect((target.json(legacySnapshotKey) as Map)['progress'], {
        'keepProgress': [1, 2],
      });
      expect((target.json(legacySnapshotKey) as Map)['dayStates'], {
        '2026-10-15': {'skip': true},
      });
      expect(target.docs['fw-progress-v1'], source.docs['fw-progress-v1']);
      expect(target.docs['fw-plan-day-v1'], source.docs['fw-plan-day-v1']);
    },
  );

  test('preferences legacy, clamps, pruning and failed writes', () async {
    final n = FakeNative();
    final settings = Settings(n, deviceTz: 'UTC');
    expect((await settings.load())['tz'], 'UTC');
    await expectLater(
      settings.save({'tz': 'UTC', 'baseUrl': 'http://bad'}),
      throwsA(isA<DomainError>()),
    );
    final goals = GoalsStore(n);
    expect(await goals.load(), goalDefaults);
    expect(
      await goals.save({
        'sets': null,
        'meals': 99,
        'kcal': 'bad',
        'weekDays': 4.5,
      }),
      {'sets': 1, 'meals': 8, 'kcal': 1800, 'weekDays': 5},
    );
    n.docs['fw-rest-v1'] = '120';
    expect((await RestPrefsStore(n).load())['sec'], 120);
    final days = DayStatesStore(n);
    expect(
      await days.save({
        '2026-08-30': 1,
        '2026-08-31': 2,
        '2026-10-15': 3,
      }, '2026-10-15'),
      {'2026-08-31': 2, '2026-10-15': 3},
    );
    n.failNextPut = const NativeError('保存失败');
    await expectLater(goals.save({}), throwsA(isA<NativeError>()));
  });
}
