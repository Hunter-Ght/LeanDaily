// Legacy names are intentionally confined here to verify upgrade compatibility.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/app/app_controller.dart';
import 'package:leandaily/core/native.dart';
import 'package:leandaily/data/backup.dart';
import 'package:leandaily/data/prefs.dart' show Settings, defaults;
import 'package:leandaily/data/repository.dart';

const legacySettings = {
  'tz': 'Asia/Shanghai',
  'model': 'vision',
  'baseUrl': 'https://example.test/v1',
  'appId': 'old-app',
  'appToken': 'old-token',
  'tableSets': 'old-sets',
  'tableDays': 'old-days',
  'tableMeals': 'old-meals',
  'feishuEnabled': true,
  'feishuTz': 'invalid-obsolete-zone',
  'feishuSecret': 'old-secret',
};

class CleanupNative extends FakeNative {
  CleanupNative({this.fail = false});
  final bool fail;
  final stored = {'modelKey': 'keep-model-key', 'feishuSecret': 'old-secret'};
  @override
  Future<void> pruneSecrets() async {
    await super.pruneSecrets();
    if (fail) throw const NativeError('unavailable');
    stored.removeWhere((key, _) => key != 'modelKey');
    secrets = Secrets.fromMap(stored);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final fail in [false, true]) {
    test('old settings boot and cleanup runs once; failure=$fail', () async {
      final n = CleanupNative(fail: fail)
        ..docs['android-settings'] = jsonEncode(legacySettings);
      final app = AppController(native: n);
      addTearDown(app.dispose);
      await app.boot();
      expect(app.booted, true);
      expect(app.bootError, isEmpty);
      await app.resume();
      await app.boot();
      expect(n.pruneSecretsCalls, 1);
      expect(app.settings.value.keys, unorderedEquals(defaults.keys));
      await app.settings.save(app.settings.value);
      final saved = jsonDecode(n.docs['android-settings']!) as Map;
      expect(saved.keys, unorderedEquals(defaults.keys));
      expect(saved['model'], 'vision');
      expect(n.httpLog, isEmpty);
      if (!fail) {
        expect(n.stored, {'modelKey': 'keep-model-key'});
        expect((await n.secretsGet()).modelKey, 'keep-model-key');
      }
    });
  }

  test(
    'version 1 backup restores old fields without exporting old settings',
    () async {
      final n = FakeNative();
      final repo = Repository(n);
      await repo.load();
      addTearDown(repo.dispose);
      final ids = await repo.addSets(
        date: '2026-10-15',
        exercise: '卧推',
        rows: [
          {'weight': 40, 'reps': 8},
        ],
      );
      final backup = await exportBackup(n, repo);
      backup['settings'] = legacySettings;
      backup['state']['sets'][ids.single].addAll({
        'feishuId': 'old-remote',
        'synced': true,
        'record_id': 'old-id',
      });
      await repo.replaceState(Map<String, dynamic>.from(backup['state'] as Map));
      final cleanExport = await exportBackup(n, repo);
      final exportedRow = cleanExport['state']['sets'][ids.single] as Map;
      expect(exportedRow.containsKey('feishuId'), false);
      expect(exportedRow.containsKey('synced'), false);
      expect(exportedRow.containsKey('record_id'), false);
      expect(repo.state['sets'][ids.single]['feishuId'], 'old-remote');
      await restoreBackup(n, repo, backup);
      expect(repo.day('2026-10-15')['sets'], hasLength(1));
      final settings = Settings(n);
      expect((await settings.load())['model'], 'vision');
      final exported = await exportBackup(n, repo);
      expect(exported['format'], 'leandaily-backup');
      expect(exported['version'], 1);
      expect(
        (exported['settings'] as Map).keys,
        unorderedEquals(defaults.keys),
      );
      expect(exported['state']['sets'][ids.single]['w'], 40);
      expect(exported['state']['tasks'], isEmpty);
      await repo.updateSet(ids.single, '2026-10-15', 42, 8, '正式', null);
      expect(repo.state['tasks'], isEmpty);
    },
  );
}
