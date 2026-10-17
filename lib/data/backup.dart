import 'dart:convert';

import '../core/native.dart';
import '../core/sha256.dart';
import '../domain/records.dart';
import 'prefs.dart';
import 'repository.dart';
import 'state_doc.dart';

const _prefKeys = [
  'fw-goals-v1',
  'fw-rest-v1',
  'fw-plan-v1',
  'fw-plan-day-v1',
  'fw-progress-v1',
  'fw-plans-v1',
  'fw-profile-v1',
  'fw-onboarded-v1',
  'fw-plan-legacy-v1',
  'fw-targets-v1',
  'fw-body-v1',
  'fw-review-v1',
  'fw-hints-v1',
];
Never _error(String s) => throw DomainError(s);
Future<Map<String, dynamic>> validateBackup(
  Object? input, {
  required Native native,
}) async {
  final state = _validateBackupRecords(input);
  final b = input as Map;
  await native.clock('${b['settings']?['tz'] ?? defaults['tz']}');
  return state;
}

Map<String, dynamic> _validateBackupRecords(Object? input) {
  if (input is! Map ||
      (input['format'] != 'leandaily-backup' &&
          input['format'] != 'lianchiji-backup') ||
      input['version'] != 1 ||
      input['state'] is! Map ||
      input['state']['version'] != 1 ||
      input['photos'] is! Map) {
    _error('不是支持的薄肌日课备份');
  }
  final b = input, raw = b['state'] as Map, state = emptyState();
  final uuid = RegExp(
    r'^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$',
  );
  if (raw['sets'] is! Map || raw['meals'] is! Map) _error('备份记录不完整');
  for (final e in (raw['sets'] as Map).entries) {
    final id = '${e.key}', r = e.value as Map;
    if (!uuid.hasMatch(id) || r['id'] != id) _error('训练记录标识无效');
    validDate(r['date']);
    validateSets([
      {
        if (r.containsKey('w')) 'weight': r['w'],
        if (r.containsKey('reps')) 'reps': r['reps'],
        'type': r['type'],
        'rpe': r['rpe'],
        'flag': r['flag'],
      },
    ]);
    final no = r['no'];
    if (no is! num ||
        !no.isFinite ||
        no != no.truncate() ||
        no < 1 ||
        r['ex'] is! String ||
        (r['ex'] as String).trim().isEmpty) {
      _error('训练记录无效');
    }
    state['sets'][id] = {
      'id': id,
      if (number(r['ts']) > 0) 'ts': number(r['ts']),
      if (['form', 'pain'].contains(r['flag'])) 'flag': r['flag'],
      'date': r['date'],
      'ex': cut(r['ex'], 40),
      'part': cut(truthy(r['part']) ? r['part'] : '', 20),
      'no': no,
      'w': number(r['w']),
      'reps': number(r['reps']),
      'type': r['type'],
      'rpe': r['rpe'] == null ? null : number(r['rpe']),
      'notes': cut(truthy(r['notes']) ? r['notes'] : '', 100),
    };
  }
  var size = 0;
  for (final e in (raw['meals'] as Map).entries) {
    final id = '${e.key}', r = e.value as Map;
    if (!uuid.hasMatch(id) ||
        r['record_id'] != id ||
        !meals.contains(r['meal'])) {
      _error('饮食记录标识或餐次无效');
    }
    validDate(r['date']);
    if (r['photo_ids'] is! List ||
        (r['photo_ids'] as List).length > 8 ||
        (truthy(r['time']) &&
            !RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch('${r['time']}'))) {
      _error('饮食记录无效');
    }
    final items = cleanItems(r['items']);
    for (final photo in r['photo_ids'] as List) {
      final data = b['photos'][photo],
          hash = (b['photoHashes'] as Map?)?[photo];
      if (data is! String ||
          !RegExp(r'^/9j/[A-Za-z0-9+/]*={0,2}$').hasMatch(data) ||
          data.length > 16 * 1024 * 1024 ||
          hash is! String ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)) {
        _error('备份照片缺失或损坏');
      }
      size += data.length;
    }
    if (size > 100 * 1024 * 1024) _error('备份过大');
    state['meals'][id] = {
      'record_id': id,
      'date': r['date'],
      'meal': r['meal'],
      'time': truthy(r['time']) ? r['time'] : '',
      'note': cut(truthy(r['note']) ? r['note'] : '', 500),
      'source': ['AI识别', 'AI识别+手动修正', '手动填写', '待分析'].contains(r['source'])
          ? r['source']
          : '手动填写',
      'items': items,
      'photo_ids': r['photo_ids'],
      if (r['photo_phases'] is List && (r['photo_ids'] as List).isNotEmpty)
        'photo_phases': cleanPhases(
          r['photo_phases'],
          (r['photo_ids'] as List).length,
        ),
      if (truthy(r['after_skipped'])) 'after_skipped': true,
      if (truthy(r['basis'])) 'basis': cut(r['basis'], 20),
      ...sumItems(items),
    };
  }
  for (final e in ((raw['notes'] as Map?) ?? {}).entries) {
    validDate(e.key);
    if (e.value is! String) _error('备注无效');
    state['notes'][e.key] = cut(e.value, 500);
  }
  return state;
}

void checkIntegrity(Map<String, dynamic> b) {
  for (final photo in _photos(b['state'] as Map)) {
    final bytes = base64Decode(b['photos'][photo] as String);
    if (sha256(bytes) != b['photoHashes'][photo]) _error('照片校验失败，备份可能已损坏');
  }
}

Set<String> _photos(Map state) => {
  for (final m in (state['meals'] as Map).values)
    ...List<String>.from(m['photo_ids'] as List),
};
Future<Map<String, dynamic>> chooseBackup(Native native) async {
  final b = jsonDecode(await native.importDocument()) as Map<String, dynamic>;
  await validateBackup(b, native: native);
  checkIntegrity(b);
  return b;
}

Future<Map<String, dynamic>> exportBackup(
  Native native,
  Repository repository, {
  DateTime Function()? clock,
}) async {
  await repository.flush();
  final state = cloneJson(repository.state);
  state['idem'] = <String, dynamic>{};
  state['tasks'] = <String, dynamic>{};
  state['sync'] = {'lastSuccess': '', 'error': ''};
  // Export only local record fields; opaque metadata stays in on-device storage.
  const recordKeys = {
    'sets': {
      'id',
      'ts',
      'flag',
      'date',
      'ex',
      'part',
      'no',
      'w',
      'reps',
      'type',
      'rpe',
      'notes',
    },
    'meals': {
      'record_id',
      'date',
      'meal',
      'time',
      'note',
      'source',
      'items',
      'photo_ids',
      'photo_phases',
      'after_skipped',
      'basis',
      'kcal',
      'protein',
      'carbs',
      'fat',
    },
  };
  for (final kind in ['sets', 'meals']) {
    (state[kind] as Map).removeWhere((k, v) => truthy(v['deleted']));
    for (final row in (state[kind] as Map).values) {
      (row as Map).removeWhere((key, _) => !recordKeys[kind]!.contains(key));
    }
  }
  final photos = <String, String>{}, hashes = <String, String>{};
  var size = 0;
  for (final id in _photos(state)) {
    final image = await native.photoRead(id),
        encoded = base64Encode(image.bytes);
    size += encoded.length;
    if (size > 90 * 1024 * 1024) _error('照片备份超过第一版的100MB限制');
    if (sha256(image.bytes) != image.sha256) _error('照片校验失败，备份可能已损坏');
    photos[id] = encoded;
    hashes[id] = image.sha256;
  }
  final docs = await native.all();
  final settings = Settings(native);
  await settings.load();
  final b = <String, dynamic>{
    'format': 'leandaily-backup',
    'version': 1,
    'created': DateTime.fromMillisecondsSinceEpoch(
      (clock ?? DateTime.now)().millisecondsSinceEpoch,
      isUtc: true,
    ).toIso8601String(),
    'state': state,
    'photos': photos,
    'photoHashes': hashes,
    'preferences': {
      for (final k in _prefKeys)
        if (truthy(docs[k])) k: docs[k],
    },
    'settings': settings.value,
  };
  await native.exportDocument(
    jsonEncode(b),
    '薄肌日课备份-${(clock ?? DateTime.now)().millisecondsSinceEpoch}.json',
  );
  return b;
}

Future<void> restoreBackup(
  Native native,
  Repository repository,
  Map<String, dynamic> b,
) async {
  await repository.flush();
  final state = await validateBackup(b, native: native);
  checkIntegrity(b);
  final paths = <String, String>{};
  for (final old in _photos(state)) {
    paths[old] = await native.photoWrite(
      base64Decode(b['photos'][old] as String),
    );
  }
  for (final m in (state['meals'] as Map).values) {
    m['photo_ids'] = (m['photo_ids'] as List).map((p) => paths[p]!).toList();
  }
  await native.put('android-settings', jsonEncode(defaults));
  await native.secretsSet(const Secrets());
  await repository.replaceState(state);
  for (final key in (await native.all()).keys) {
    if (key.startsWith('android-meal-draft:') ||
        key == 'fw-cache-v1' ||
        key == 'android-rest') {
      await native.put(key, 'null');
    }
  }
  for (final key in _prefKeys) {
    await native.put(
      key,
      (b['preferences'] as Map?)?[key] as String? ?? 'null',
    );
  }
  final config = Map<String, dynamic>.of(defaults);
  for (final k in ['tz', 'model', 'baseUrl', 'protocol']) {
    if (b['settings']?[k] is String) config[k] = b['settings'][k];
  }
  await native.put('android-settings', jsonEncode(config));
  await native.secretsSet(const Secrets());
}
