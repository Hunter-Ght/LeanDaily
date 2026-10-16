import 'dart:math' as math;

import 'calendar.dart' as calendar;

typedef _Json = Map<String, dynamic>;
_Json _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};
List<dynamic> _list(Object? value) => value is List ? value : [];
bool _truth(Object? value) =>
    value != null &&
    value != false &&
    value != '' &&
    !(value is num && (value == 0 || value.isNaN));
num _number(Object? value) {
  if (value == null || value == '') return 0;
  if (value is num) return value;
  if (value is bool) return value ? 1 : 0;
  final text = value.toString().trim();
  return text.isEmpty ? 0 : num.tryParse(text) ?? double.nan;
}

num _round(num value) => value.isFinite ? (value + .5).floor() : value;
num _e1(Object? weight, Object? reps) =>
    _round(_number(weight) * (1 + _number(reps) / 30) * 10) / 10;
List<_Json> _workSets(Object? day) => [
  for (final s in _list(_map(day)['sets']))
    if (s is Map &&
        _truth(s['ex']) &&
        s['type'] != '热身' &&
        !_truth(s['pending']) &&
        !(s['id'] ?? '').toString().startsWith('pending-'))
      Map<String, dynamic>.from(s),
];
num _dayVolume(Object? day) {
  final total = _number(_map(_map(day)['totals'])['总训练量']);
  if (total.isFinite && total > 0) return total;
  return _workSets(day)
      .fold<num>(0, (sum, s) => sum + _number(s['w']) * _number(s['reps']));
}

/// Cache snapshots are explicit inputs; live values overwrite matching dates.
/// The first three arguments retain the Web buildStats calling convention.
Map<String, dynamic> buildStats(
  String? today,
  Map<String, dynamic>? liveDay,
  Map<String, dynamic>? liveMeals, {
  Map<String, dynamic> days = const {},
  Map<String, dynamic> meals = const {},
}) {
  final dayDb = {...days}, mealDb = {...meals};
  if (_truth(liveDay?['date'])) dayDb[liveDay!['date'] as String] = liveDay;
  if (_truth(liveMeals?['date'])) {
    mealDb[liveMeals!['date'] as String] = liveMeals;
  }
  final keys = dayDb.keys.toList()..sort();
  final start = calendar.mondayOf(
    today != null && today.isNotEmpty
        ? today
        : keys.isEmpty
        ? '2026-01-05'
        : keys.last,
  );
  final prev = _rangeWeek(calendar.shiftDate(start, -7), dayDb, mealDb);
  final todayMeal = _map(mealDb[today]);
  return {
    'today': {
      'sets': _workSets(dayDb[today]).length,
      'volume': _round(_dayVolume(dayDb[today])),
      'meals': _list(todayMeal['meals']).length,
      'kcal': _round(_number(todayMeal['totals']?['kcal'] ?? 0)),
    },
    'week': _rangeWeek(start, dayDb, mealDb),
    'prevVolume': prev['volume'],
    'prevTrainDays': prev['trainDays'],
    'bests': _bestsOf(dayDb),
    'exercises': _exercisesOf(dayDb),
  };
}

_Json _rangeWeek(String start, _Json days, _Json meals) {
  const labels = ['一', '二', '三', '四', '五', '六', '日'];
  final list = List.generate(7, (i) {
    final iso = calendar.shiftDate(start, i),
        sets = _workSets(days[calendar.shiftDate(start, i)]);
    final meal = _map(meals[iso]);
    return <String, dynamic>{
      'iso': iso,
      'label': labels[i],
      'train': sets.isNotEmpty,
      'volume': _round(_dayVolume(days[iso])),
      'sets': sets.length,
      'meals': _list(meal['meals']).length,
      'kcal': _round(_number(meal['totals']?['kcal'] ?? 0)),
    };
  });
  return {
    'start': start,
    'days': list,
    'trainDays': list.where((d) => d['train'] == true).length,
    for (final key in ['volume', 'sets', 'meals', 'kcal'])
      key: list.fold<num>(0, (sum, d) => sum + (d[key] as num)),
  };
}

List<_Json> _bestsOf(_Json days) {
  final map = <String, _Json>{};
  for (final entry in days.entries) {
    final iso = entry.key;
    for (final s in _workSets(entry.value)) {
      final ex = s['ex'] as String, value = _e1(s['w'], s['reps']);
      final cur = map[ex];
      final weight = _number(s['w']), reps = _number(s['reps']);
      final heavier =
          cur == null ||
          weight > (cur['weight'] as num) ||
          (weight == cur['weight'] && reps > (cur['reps'] as num));
      if (cur == null ||
          value > (cur['e1'] as num) ||
          (value == cur['e1'] && iso.compareTo(cur['date'] as String) > 0)) {
        map[ex] = {
          'ex': ex,
          'part': _truth(s['part']) ? s['part'] : cur?['part'] ?? '',
          'e1': value,
          'date': iso,
          'weight': weight,
          'reps': reps,
          'heavy': heavier ? weight : cur['weight'],
          'heavyReps': heavier ? reps : cur['heavyReps'],
          'heavyDate': heavier ? iso : cur['heavyDate'],
        };
      } else if (heavier) {
        cur['heavy'] = weight;
        cur['heavyReps'] = reps;
        cur['heavyDate'] = iso;
      }
    }
  }
  return _stableSort(
    map.values.toList(),
    (a, b) => (b['e1'] as num).compareTo(a['e1'] as num),
  );
}

List<_Json> _exercisesOf(_Json days) {
  final map = <String, List<_Json>>{};
  for (final entry in days.entries) {
    final byEx = <String, _Json>{};
    for (final s in _workSets(entry.value)) {
      final ex = s['ex'] as String, value = _e1(s['w'], s['reps']);
      if (byEx[ex] == null || value > (byEx[ex]!['e1'] as num)) {
        byEx[ex] = {
          'e1': value,
          'weight': _number(s['w']),
          'reps': _number(s['reps']),
        };
      }
    }
    for (final e in byEx.entries) {
      (map[e.key] ??= []).add({'iso': entry.key, ...e.value});
    }
  }
  final out = <_Json>[];
  for (final e in map.entries) {
    e.value.sort((a, b) => (a['iso'] as String).compareTo(b['iso'] as String));
    out.add({'ex': e.key, 'points': e.value});
  }
  return _stableSort(
    out,
    (a, b) => ((b['points'] as List).last['iso'] as String).compareTo(
      (a['points'] as List).last['iso'] as String,
    ),
  );
}

List<T> _stableSort<T>(List<T> list, int Function(T, T) compare) {
  final indexed = list.indexed.toList()
    ..sort((a, b) {
      final c = compare(a.$2, b.$2);
      return c == 0 ? a.$1.compareTo(b.$1) : c;
    });
  return indexed.map((e) => e.$2).toList();
}

String _jsNumber(num v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();
Map<String, dynamic> chartPoints(List<Map<String, dynamic>> points) {
  final list = points.skip(math.max(0, points.length - 16)).toList();
  if (list.isEmpty) return {'list': list, 'line': '', 'dots': <_Json>[]};
  final min = list.map((p) => p['e1'] as num).reduce(math.min);
  final max = list.map((p) => p['e1'] as num).reduce(math.max);
  final span = math.max(1, max - min);
  final dots = [
    for (var i = 0; i < list.length; i++)
      <String, dynamic>{
        ...list[i],
        'x': list.length == 1 ? 160 : 16 + (i / (list.length - 1)) * 288,
        'y': 118 - (((list[i]['e1'] as num) - min) / span) * 96,
      },
  ];
  return {
    'list': list,
    'min': min,
    'max': max,
    'line': dots
        .map((p) => '${_jsNumber(p['x'] as num)},${_jsNumber(p['y'] as num)}')
        .join(' '),
    'dots': dots,
  };
}
