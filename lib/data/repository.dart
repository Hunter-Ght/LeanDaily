import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/native.dart';
import '../domain/records.dart' as records;
import 'state_doc.dart';

typedef Clock = DateTime Function();

class Repository extends ChangeNotifier {
  Repository(this.native, {Clock? clock}) : clock = clock ?? DateTime.now;
  final Native native;
  final Clock clock;
  Map<String, dynamic> _state = emptyState();
  Future<void> _lane = Future.value();
  final _days = <String, Map<String, dynamic>>{},
      _meals = <String, Map<String, dynamic>>{};
  // Changes only after a new in-memory record snapshot is installed. Unlike
  // the persisted revision, this also covers imports and non-sync mutations.
  Object _snapshotToken = Object();
  Object get snapshotToken => _snapshotToken;
  int get revision => (_state['revision'] as num).toInt();
  // Recursively frozen: callers cannot mutate rows or cached projections.
  Map<String, dynamic> get state => _freeze(_state) as Map<String, dynamic>;
  static Object? _freeze(Object? v) {
    if (v is Map) {
      return Map<String, dynamic>.unmodifiable(
        v.map((k, v) => MapEntry('$k', _freeze(v))),
      );
    }
    if (v is List) return List<Object?>.unmodifiable(v.map(_freeze));
    return v;
  }

  Future<void> flush() => _lane;

  Future<void> load() async {
    _state = parseState((await native.all())['android-state']);
    _invalidate();
    notifyListeners();
  }

  void _invalidate() {
    _snapshotToken = Object();
    _days.clear();
    _meals.clear();
  }

  Future<T> mutate<T>(
    FutureOr<T> Function(Map<String, dynamic>) change, {
    bool incrementRevision = false,
  }) {
    final pending = _lane.then((_) async {
      final next = cloneJson(_state);
      final result = await change(next);
      if (incrementRevision) next['revision'] = (next['revision'] as num) + 1;
      await native.put('android-state', jsonEncode(next));
      _state = next;
      _invalidate();
      notifyListeners();
      return result;
    });
    _lane = pending.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return pending;
  }

  Future<void> replaceState(Map<String, dynamic> next) => mutate((s) {
    if (next['version'] != 1) {
      throw const records.DomainError('数据版本不兼容，请更新 APP');
    }
    s.clear();
    s.addAll(cloneJson(next));
  });
  Map<String, dynamic> day(String date) => _days.putIfAbsent(
    date,
    () => _freeze(records.dayOf(_state, date)) as Map<String, dynamic>,
  );
  Map<String, dynamic> meals(String date) => _meals.putIfAbsent(
    date,
    () => _freeze(records.mealsOf(_state, date)) as Map<String, dynamic>,
  );
  Set<String> get _dates => {
    for (final kind in ['sets', 'meals'])
      for (final r in (_state[kind] as Map).values) r['date'] as String,
  };
  Map<String, dynamic> allDays() => {
    for (final date in _dates) date: day(date),
  };
  Map<String, dynamic> allMeals() => {
    for (final date in _dates) date: meals(date),
  };
  bool hasTrain(String date) =>
      (day(date)['sets'] as List).any((s) => s['type'] != '热身');
  bool hasMeal(String date) => (meals(date)['meals'] as List).isNotEmpty;
  Map<String, dynamic> get notes =>
      _freeze(_state['notes']) as Map<String, dynamic>;
  Map<String, dynamic> recentByExercise() {
    final rows =
        (_state['sets'] as Map).values
            .where((r) => !records.truthy(r['deleted']))
            .toList()
          ..sort(
            (a, b) => (a['date'] as String).compareTo(b['date'] as String),
          );
    final last = <String, dynamic>{}, byPart = <String, List<String>>{};
    for (final r in rows) {
      final ex = r['ex'] as String, part = r['part'] as String;
      if (last[ex] == null || last[ex]['date'] != r['date']) {
        last[ex] = {'date': r['date'], 'sets': <Map<String, dynamic>>[]};
      }
      (last[ex]['sets'] as List).add({
        'weight': r['w'],
        'reps': r['reps'],
        'type': r['type'],
        'rpe': r['rpe'],
        'notes': r['notes'],
      });
      final list = byPart.putIfAbsent(part, () => []);
      if (!list.contains(ex)) list.insert(0, ex);
    }
    return {'last': last, 'byPart': byPart};
  }

  Future<List<String>> addSets({
    required String date,
    String part = '',
    required String exercise,
    bool unilateral = false,
    String dayNote = '',
    required List<Map<String, dynamic>> rows,
  }) => mutate((s) {
    records.validDate(date);
    records.validateSets(rows);
    if (exercise.trim().isEmpty) throw const records.DomainError('请选择动作');
    var no = 0;
    for (final r in (s['sets'] as Map).values) {
      if (r['date'] == date &&
          r['ex'] == exercise &&
          !records.truthy(r['deleted']) &&
          records.number(r['no']) > no) {
        no = records.number(r['no']).toInt();
      }
    }
    final ids = <String>[];
    for (final row in rows) {
      final count = records.number(row['count'] ?? 1).toInt();
      for (var i = 0; i < count; i++) {
        final id = newId();
        ids.add(id);
        s['sets'][id] = {
          'id': id,
          'ts': clock().millisecondsSinceEpoch,
          if (['form', 'pain'].contains(row['flag'])) 'flag': row['flag'],
          'date': date,
          'part': part,
          'ex': records.cut(exercise, 40),
          'no': ++no,
          'w': records.number(row['weight']),
          'reps': records.number(row['reps']),
          'type': records.truthy(row['type']) ? row['type'] : '正式',
          'rpe': row['rpe'] == '' || row['rpe'] == null
              ? null
              : records.number(row['rpe']),
          'notes': records.cut(
            [
              if (unilateral) '单边',
              if (records.truthy(row['notes'])) row['notes'],
            ].join('；'),
            100,
          ),
        };
      }
    }
    if (dayNote.isNotEmpty) s['notes'][date] = records.cut(dayNote, 500);
    return ids;
  }, incrementRevision: true);
  Future<void> updateSet(
    String id,
    String date,
    Object? weight,
    Object? reps,
    String? type,
    Object? rpe,
  ) => mutate((s) {
    records.validDate(date);
    records.validateSets([
      {'weight': weight, 'reps': reps, 'type': type, 'rpe': rpe},
    ]);
    final r = s['sets'][id];
    if (r == null || records.truthy(r['deleted']) || r['date'] != date) {
      throw const records.DomainError('记录不存在');
    }
    (r as Map).addAll(<String, dynamic>{
      'w': records.number(weight),
      'reps': records.number(reps),
      'type': records.truthy(type) ? type : '正式',
      'rpe': rpe == '' || rpe == null ? null : records.number(rpe),
    });
  }, incrementRevision: true);
  Future<void> deleteSets(String date, List<String> ids) => mutate((s) {
    records.validDate(date);
    for (final id in ids) {
      if (s['sets'][id]?['date'] == date) {
        s['sets'][id]['deleted'] = true;
      }
    }
  }, incrementRevision: true);

  /// Restore the same row IDs so edit history stays consistent.
  Future<void> restoreSets(String date, List<String> ids) => mutate((s) {
    records.validDate(date);
    for (final id in ids) {
      if (s['sets'][id]?['date'] == date && s['sets'][id]?['deleted'] == true) {
        s['sets'][id]['deleted'] = false;
      }
    }
  }, incrementRevision: true);

  Future<String> saveMeal({
    required String date,
    required String meal,
    String time = '',
    String note = '',
    String source = '待分析',
    List items = const [],
    List<String> photoIds = const [],
  }) => _meal(
    date: date,
    meal: meal,
    time: time,
    note: note,
    source: source,
    items: items,
    photoIds: photoIds,
  );
  Future<String> updateMeal({
    required String id,
    required String date,
    required String meal,
    String time = '',
    String note = '',
    String source = '待分析',
    List items = const [],
    List<String> photoIds = const [],
    bool photosChanged = false,
  }) => _meal(
    id: id,
    date: date,
    meal: meal,
    time: time,
    note: note,
    source: source,
    items: items,
    photoIds: photoIds,
    photosChanged: photosChanged,
  );
  Future<String> _meal({
    String? id,
    required String date,
    required String meal,
    required String time,
    required String note,
    required String source,
    required List items,
    required List<String> photoIds,
    bool photosChanged = true,
  }) => mutate((s) async {
    records.validDate(date);
    if (!records.meals.contains(meal)) throw const records.DomainError('餐次无效');
    if (time.isNotEmpty &&
        !RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(time)) {
      throw const records.DomainError('时间无效');
    }
    final prev = id == null ? null : s['meals'][id];
    if (id != null && (prev == null || records.truthy(prev['deleted']))) {
      throw const records.DomainError('记录不存在');
    }
    final key = id ?? newId(), cleaned = records.cleanItems(items);
    final paths = id != null && !photosChanged
        ? List<String>.from(prev['photo_ids'] as List? ?? [])
        : photoIds.take(8).toList();
    if (cleaned.isEmpty && paths.isEmpty && note.trim().isEmpty) {
      throw const records.DomainError('请至少保存照片、食物或备注');
    }
    for (final path in paths) {
      await native.photoRead(path);
    }
    s['meals'][key] = {
      'record_id': key,
      'date': date,
      'meal': meal,
      'time': time,
      'note': records.cut(note, 500),
      'source': source.isEmpty ? '待分析' : source,
      'items': cleaned,
      'photo_ids': paths,
      ...records.sumItems(cleaned),
    };
    return key;
  }, incrementRevision: true);
  Future<void> deleteMeal(String date, String id) => mutate((s) {
    records.validDate(date);
    if (s['meals'][id]?['date'] == date) {
      s['meals'][id]['deleted'] = true;
    }
  }, incrementRevision: true);
  Future<void> setDayNote(String date, String note) => mutate((s) {
    records.validDate(date);
    s['notes'][date] = records.cut(note, 500);
  }, incrementRevision: true);
}
