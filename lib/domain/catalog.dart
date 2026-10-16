import 'dart:convert';
import 'dart:math' as math;

import 'plan.dart' as plan_logic;
import 'progress.dart' show BUDGET;
import 'movements.dart';
import 'calendar.dart' show shiftDate, daysApart;
export 'movements.dart' show MUSCLES, MUSCLE;

// Verbatim additional prescriptions from Web catalog.js.
const List<Map<String, dynamic>> _extra = [
  {
    "name": "锤式弯举",
    "part": "手臂",
    "venue": "both",
    "level": "easy",
    "sets": 2,
    "min": 8,
    "max": 12,
    "unit": "reps",
    "side": false,
    "weight": 5,
    "machine": false,
    "gear": "5 kg 哑铃",
    "tip": "拳眼朝上，肘贴身体，别甩腰。",
    "rest": 60,
  },
  {
    "name": "弹力带拉开",
    "part": "背",
    "venue": "home",
    "level": "easy",
    "sets": 2,
    "min": 12,
    "max": 20,
    "unit": "reps",
    "side": false,
    "weight": 0,
    "machine": false,
    "gear": "弹力带",
    "tip": "像把带子向两边\"扯开\"，用肩胛后侧发力，别耸肩；带子先握稳，不要松手弹到脸。",
    "rest": 60,
  },
  {
    "name": "俯身哑铃反向飞鸟",
    "part": "肩",
    "venue": "both",
    "level": "normal",
    "sets": 2,
    "min": 12,
    "max": 15,
    "unit": "reps",
    "side": false,
    "weight": 2,
    "machine": false,
    "gear": "轻哑铃或水瓶（按 2 kg 记）",
    "tip": "背平直，肘微屈向两侧抬到与肩同高，重量宁轻勿重。",
    "rest": 60,
  },
  {
    "name": "前平举",
    "part": "肩",
    "venue": "both",
    "level": "easy",
    "sets": 2,
    "min": 10,
    "max": 15,
    "unit": "reps",
    "side": false,
    "weight": 1,
    "machine": false,
    "gear": "水瓶或轻哑铃（按 1 kg 记）",
    "tip": "抬到与肩同高，不要借身体晃；前束肩平时推举已经练得不少，这是补充。",
    "rest": 60,
  },
  {
    "name": "弯腰双臂哑铃划船",
    "part": "背",
    "venue": "both",
    "level": "normal",
    "sets": 2,
    "min": 10,
    "max": 15,
    "unit": "reps",
    "side": false,
    "weight": 5,
    "machine": false,
    "gear": "5 kg 哑铃 × 2",
    "tip": "髋向后推、背平直，把哑铃拉向肚脐两侧，顶端夹紧肩胛。",
    "rest": 75,
  },
  {
    "name": "椅子臂屈伸",
    "part": "手臂",
    "venue": "home",
    "level": "normal",
    "sets": 2,
    "min": 6,
    "max": 12,
    "unit": "reps",
    "side": false,
    "weight": 0,
    "machine": false,
    "gear": "稳固、不带轮子的椅子或凳子",
    "tip": "下放到上臂接近水平就够，肩前侧不舒服立刻停。",
    "rest": 75,
  },
  {
    "name": "站姿哑铃臂屈伸",
    "part": "手臂",
    "venue": "both",
    "level": "normal",
    "sets": 2,
    "min": 10,
    "max": 15,
    "unit": "reps",
    "side": false,
    "weight": 5,
    "machine": false,
    "gear": "一只 5 kg 哑铃",
    "tip": "上臂贴近耳侧不动，只动肘部；太重就改用水瓶。",
    "rest": 75,
  },
  {
    "name": "哑铃臂后屈伸",
    "part": "手臂",
    "venue": "both",
    "level": "easy",
    "sets": 2,
    "min": 10,
    "max": 15,
    "unit": "reps",
    "side": true,
    "weight": 2,
    "machine": false,
    "gear": "轻哑铃或水瓶（按 2 kg 记）",
    "tip": "上臂贴身固定，只动前臂；每侧做完为一组。",
    "rest": 60,
  },
  {
    "name": "侧平板支撑",
    "part": "核心",
    "venue": "home",
    "level": "normal",
    "sets": 2,
    "min": 15,
    "max": 30,
    "unit": "sec",
    "side": true,
    "weight": 0,
    "machine": false,
    "gear": "垫子",
    "tip": "身体成一条直线，髋别下沉；每侧做完为一组，次数一栏记的是秒数。",
    "rest": 60,
  },
  {
    "name": "俄罗斯转体",
    "part": "核心",
    "venue": "home",
    "level": "normal",
    "sets": 2,
    "min": 12,
    "max": 20,
    "unit": "reps",
    "side": false,
    "weight": 0,
    "machine": false,
    "gear": "垫子",
    "tip": "转的是躯干不是手臂；左右各一次算 1 次。",
    "rest": 60,
  },
  {
    "name": "超人式",
    "part": "背",
    "venue": "home",
    "level": "easy",
    "sets": 2,
    "min": 10,
    "max": 15,
    "unit": "reps",
    "side": false,
    "weight": 0,
    "machine": false,
    "gear": "垫子",
    "tip": "抬到不痛的高度就行，顶端停 1～2 秒，下背刺痛就停。",
    "rest": 60,
  },
  {
    "name": "单腿臀桥",
    "part": "腿",
    "venue": "home",
    "level": "normal",
    "sets": 2,
    "min": 8,
    "max": 12,
    "unit": "reps",
    "side": true,
    "weight": 0,
    "machine": false,
    "gear": "垫子",
    "tip": "用臀部发力，别用腰顶；每侧做完为一组。",
    "rest": 75,
  },
  {
    "name": "站姿提踵",
    "part": "腿",
    "venue": "home",
    "level": "easy",
    "sets": 2,
    "min": 12,
    "max": 20,
    "unit": "reps",
    "side": false,
    "weight": 0,
    "machine": false,
    "gear": "一面墙扶着，可站台阶边缘",
    "tip": "慢上慢下，顶端停 1 秒；站在台阶边缘做拉伸更充分。",
    "rest": 60,
  },
  {
    "name": "脚抬高俯卧撑",
    "part": "胸",
    "venue": "home",
    "level": "hard",
    "sets": 2,
    "min": 4,
    "max": 10,
    "unit": "reps",
    "side": false,
    "weight": 0,
    "machine": false,
    "gear": "稳固的椅子",
    "tip": "练上胸的进阶动作。现在标准俯卧撑还没稳，先把「高位俯卧撑」往低台面练再来。",
    "rest": 90,
  },
  {
    "name": "弹力带夹胸",
    "part": "胸",
    "venue": "home",
    "level": "easy",
    "sets": 2,
    "min": 10,
    "max": 15,
    "unit": "reps",
    "side": false,
    "weight": 0,
    "machine": false,
    "gear": "弹力带（绕到背后稳固处）",
    "tip": "肘微屈，把手向身体前方合拢；带子要固定牢，别回弹。",
    "rest": 60,
  },
  {
    "name": "腿屈伸机",
    "part": "腿",
    "venue": "gym",
    "level": "easy",
    "sets": 2,
    "min": 10,
    "max": 15,
    "unit": "reps",
    "side": false,
    "weight": 0,
    "machine": true,
    "gear": "腿屈伸机",
    "tip": "膝盖对准机器转轴，顶端停 1 秒，别让配重片砸下去。",
    "rest": 75,
  },
  {
    "name": "绳索下压",
    "part": "手臂",
    "venue": "gym",
    "level": "easy",
    "sets": 2,
    "min": 10,
    "max": 15,
    "unit": "reps",
    "side": false,
    "weight": 0,
    "machine": true,
    "gear": "高位拉力器 + 绳索",
    "tip": "肘部始终贴身，只动前臂。",
    "rest": 75,
  },
  {
    "name": "绳索面拉",
    "part": "肩",
    "venue": "gym",
    "level": "normal",
    "sets": 2,
    "min": 12,
    "max": 15,
    "unit": "reps",
    "side": false,
    "weight": 0,
    "machine": true,
    "gear": "拉力器 + 绳索",
    "tip": "绳索拉向脸部两侧，肘向外打开；重量轻一点，别后仰。",
    "rest": 60,
  },
  {
    "name": "直臂下拉",
    "part": "背",
    "venue": "gym",
    "level": "normal",
    "sets": 2,
    "min": 10,
    "max": 15,
    "unit": "reps",
    "side": false,
    "weight": 0,
    "machine": true,
    "gear": "高位拉力器 + 横杆",
    "tip": "手臂近乎伸直，用背阔肌把横杆压到大腿前。",
    "rest": 75,
  },
  {
    "name": "反向蝴蝶机",
    "part": "肩",
    "venue": "gym",
    "level": "easy",
    "sets": 2,
    "min": 12,
    "max": 15,
    "unit": "reps",
    "side": false,
    "weight": 0,
    "machine": true,
    "gear": "蝴蝶机（反向）",
    "tip": "手臂微屈向后打开，肩胛向后夹，别耸肩。",
    "rest": 60,
  },
  {
    "name": "坐姿提踵机",
    "part": "腿",
    "venue": "gym",
    "level": "easy",
    "sets": 2,
    "min": 10,
    "max": 15,
    "unit": "reps",
    "side": false,
    "weight": 0,
    "machine": true,
    "gear": "坐姿提踵机",
    "tip": "慢下到有拉伸感，再用小腿发力抬到最高。",
    "rest": 60,
  },
  {
    "name": "背部伸展",
    "part": "背",
    "venue": "gym",
    "level": "normal",
    "sets": 2,
    "min": 10,
    "max": 15,
    "unit": "reps",
    "side": false,
    "weight": 0,
    "machine": false,
    "gear": "罗马椅",
    "tip": "从髋部折叠，抬到身体成一条直线就停，别过度后仰。",
    "rest": 75,
  },
  {
    "name": "轻哑铃罗马尼亚硬拉",
    "part": "腿",
    "venue": "both",
    "level": "normal",
    "sets": 2,
    "min": 10,
    "max": 15,
    "unit": "reps",
    "side": false,
    "weight": 5,
    "machine": false,
    "gear": "5 kg 哑铃 × 2",
    "tip": "髋向后推、背平直、膝微屈，哑铃沿大腿滑到膝下，大腿后侧有拉伸感再站起。",
    "rest": 75,
  },
];

Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : <String, dynamic>{};
List<dynamic> _list(Object? value) => value is List ? value : [];
bool _truth(Object? value) =>
    value != null &&
    value != false &&
    value != '' &&
    !(value is num && (value == 0 || value.isNaN));
Object _or(Object? value, Object fallback) => _truth(value) ? value! : fallback;
Map<String, Map<String, dynamic>>? _cache;

Map<String, dynamic> _base(
  Map<String, dynamic> parent,
  String name,
  Map<String, dynamic> from,
  bool alt,
) => {
  'name': name,
  'part': parent['part'],
  'level': 'normal',
  'sets': 2,
  'min': parent['min'],
  'max': parent['max'],
  'unit': parent['unit'],
  'side': _truth(from['side']),
  'weight': _or(from['weight'], 0),
  'machine': _truth(from['machine']),
  'gear': _or(from['gear'], ''),
  'tip': alt
      ? '替代「${parent['name']}」。${_or(parent['tip'], '')}'
      : _or(parent['tip'], ''),
  'rest': _or(parent['rest'], 0),
};

/// Insertion order, first-seen prescription and extra overrides match Web Map.
Map<String, Map<String, dynamic>> catalog() {
  if (_cache != null) return _cache!;
  final map = <String, Map<String, dynamic>>{};
  void put(Map<String, dynamic> spec, String venue) {
    final name = spec['name'] as String, old = map[spec['name']];
    map[name] = old != null
        ? {...old, 'venue': old['venue'] == venue ? venue : 'both'}
        : {...spec, 'venue': venue};
  }

  final plan = plan_logic.defaultPlan('2000-01-01');
  for (final value in _map(plan['workouts']).values) {
    final w = _map(value);
    for (final venue in ['home', 'gym']) {
      for (final value in listOf(w, venue)) {
        final e = _map(value);
        put(_base(e, e['name'] as String, e, false), venue);
        for (final value in _list(e['alts'])) {
          final a = _map(value);
          put(
            _base(e, a['name'] as String, {
              'machine': _truth(a['machine']),
              'weight': a['weight'] ?? 0,
              'side': a['side'] ?? e['side'],
              'gear': _or(a['gear'], ''),
            }, true),
            venue,
          );
        }
      }
    }
  }
  for (final e in _extra) {
    map[e['name'] as String] = {...e};
  }
  for (final name in [
    '臀桥',
    '单腿臀桥',
    '侧平板支撑',
    '俄罗斯转体',
    '超人式',
    '站姿提踵',
    '深蹲',
    '分腿蹲',
    '卷腹',
    '反向卷腹',
    '死虫式',
    '平板支撑',
  ]) {
    if (map[name] != null) map[name] = {...map[name]!, 'venue': 'both'};
  }
  return _cache = map;
}

List<Map<String, dynamic>> exercisesForMuscle(String muscleId, String venue) {
  const level = {'easy': 0, 'normal': 1, 'hard': 2};
  final out = <Map<String, dynamic>>[];
  for (final entry in catalog().entries) {
    final spec = entry.value;
    if (spec['venue'] != 'both' && spec['venue'] != venue) continue;
    final weight =
        musclesOf(entry.key, spec['part'] as String)?['muscles']?[muscleId]
            as num?;
    if (weight == null || weight < .25) continue;
    out.add({
      'name': entry.key,
      'spec': spec,
      'weight': weight,
      'role': weight >= .8 ? 'main' : 'assist',
      'level': spec['level'],
    });
  }
  return _stableSort(out, (a, b) {
    final role = (b['role'] == 'main' ? 1 : 0) - (a['role'] == 'main' ? 1 : 0);
    if (role != 0) return role;
    final difficulty = level[a['level']]! - level[b['level']]!;
    return difficulty != 0
        ? difficulty
        : (b['weight'] as num).compareTo(a['weight'] as num);
  });
}

List<dynamic> listOf(Map<String, dynamic> workout, String venue) =>
    venue == 'gym'
    ? _list(_map(workout['gym'])['exercises'])
    : _list(workout['exercises']);
List<Map<String, dynamic>> whereInPlan(Map<String, dynamic> plan, String name) {
  final out = <Map<String, dynamic>>[];
  for (final id in _list(plan['order'])) {
    final w = _map(_map(plan['workouts'])[id]);
    for (final venue in ['home', 'gym']) {
      if (listOf(w, venue).any((e) => _map(e)['name'] == name)) {
        out.add({'workoutId': id, 'venue': venue, 'workoutName': w['name']});
      }
    }
  }
  return out;
}

final _random = math.Random();
String _newId() {
  var fraction = _random.nextDouble(), suffix = '';
  for (var i = 0; i < 3 && fraction != 0; i++) {
    fraction *= 36;
    final digit = fraction.floor();
    suffix += digit.toRadixString(36);
    fraction -= digit;
  }
  return 'x${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}$suffix';
}

/// JSON deep copy, with original identity retained on a no-op.
/// createId provides a deterministic clock/random seam for parity tests.
Map<String, dynamic> addToPlan(
  Map<String, dynamic> plan,
  String workoutId,
  String venue,
  Map<String, dynamic> spec, {
  bool optional = false,
  String Function()? createId,
}) {
  final next = jsonDecode(jsonEncode(plan)) as Map<String, dynamic>;
  final w = _map(next['workouts'])[workoutId] as Map<String, dynamic>?;
  if (w == null) return plan;
  if (venue == 'gym' && !_truth(w['gym'])) {
    w['gym'] = {'tag': '', 'note': '', 'exercises': <dynamic>[]};
  }
  final list = listOf(w, venue);
  if (list.any((e) => _map(e)['name'] == spec['name'])) return plan;
  list.add({
    'id': (createId ?? _newId)(),
    for (final k in ['name', 'part', 'sets', 'min', 'max', 'unit']) k: spec[k],
    'side': _truth(spec['side']),
    'weight': _or(spec['weight'], 0),
    'core': false,
    'optional': optional,
    'machine': _truth(spec['machine']),
    'gear': _or(spec['gear'], ''),
    'tip': _or(spec['tip'], ''),
    'rest': _or(spec['rest'], 0),
    'alts': <dynamic>[],
    'img': '',
  });
  return next;
}

Map<String, dynamic> removeFromPlan(
  Map<String, dynamic> plan,
  String workoutId,
  String venue,
  String name,
) {
  final next = jsonDecode(jsonEncode(plan)) as Map<String, dynamic>;
  final w = _map(next['workouts'])[workoutId] as Map<String, dynamic>?;
  if (w == null) return plan;
  final list = listOf(w, venue),
      i = listOf(w, venue).indexWhere((e) => _map(e)['name'] == name);
  if (i < 0) return plan;
  list.removeAt(i);
  return next;
}

Map<String, num> plannedWeekly(
  Map<String, dynamic> plan, [
  String Function(int)? venueOfDay,
]) {
  final out = <String, num>{for (final group in GROUP.keys) group: 0};
  for (final e in _map(plan['schedule']).entries) {
    final w = _map(_map(plan['workouts'])[e.value]);
    if (w.isEmpty) continue;
    final venue =
        (venueOfDay?.call(int.parse(e.key)) ??
                    _map(plan['venues'])[e.key] ??
                    'home') ==
                'gym' &&
            _truth(w['gym'])
        ? 'gym'
        : 'home';
    for (final value in listOf(w, venue)) {
      final ex = _map(value);
      if (_truth(ex['optional'])) continue;
      final mv = musclesOf(ex['name'], ex['part'] as String?);
      if (mv != null) {
        final group = mv['group'] as String;
        out[group] = out[group]! + (_or(ex['sets'], 1) as num);
      }
    }
  }
  return out;
}

int _minutes(
  Map<String, dynamic> plan,
  Map<String, dynamic> w,
  String venue, [
  Map<String, dynamic>? extra,
]) {
  final list = <Map<String, dynamic>>[
    for (final value in listOf(w, venue))
      if (!_truth(_map(value)['optional']))
        {..._map(value), 'target': _map(value)['sets']},
    if (extra != null) {...extra, 'target': extra['sets']},
  ];
  return plan_logic.estimateMinutes(
    plan,
    list,
    _or(_map(plan[venue == 'gym' ? 'gymWarmup' : 'warmup'])['minutes'], 0)
        as num,
  );
}

List<Map<String, dynamic>> recommendSlots(
  Map<String, dynamic> plan,
  Map<String, dynamic>? status,
  String muscleId,
  String venue,
  Map<String, dynamic> spec,
  String today,
) {
  const wd = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
  final last = _map(_map(status?['byMuscle'])[muscleId])['last'];
  final mv = musclesOf(spec['name'], spec['part'] as String?),
      seen = <Object>{},
      out = <Map<String, dynamic>>[];
  for (var i = 0; i < 7; i++) {
    final iso = shiftDate(today, i),
        dow = DateTime.parse('${shiftDate(today, i)}T12:00:00').weekday % 7;
    final id = _map(plan['schedule'])['$dow'];
    if (!_truth(id) ||
        seen.contains(id) ||
        !_truth(_map(plan['workouts'])[id])) {
      continue;
    }
    seen.add(id!);
    final w = _map(_map(plan['workouts'])[id]),
        gap = _truth(last) ? daysApart(last as String, iso) : 60;
    final same = listOf(w, venue).where((value) {
      final ex = _map(value);
      return !_truth(ex['optional']) &&
          musclesOf(ex['name'], ex['part'] as String?)?['group'] ==
              mv?['group'];
    }).length;
    final before = _minutes(plan, w, venue),
        after = _minutes(plan, w, venue, spec);
    final score = math.min(gap, 30) - same * 4 - (after > 55 ? 6 : 0);
    final why = [
      _truth(last)
          ? '${wd[dow]}（${i == 0
                ? '今天'
                : i == 1
                ? '明天'
                : '$i 天后'}）离上次练到它 $gap 天'
          : '${wd[dow]}练，之前没练过这块肌肉',
      if (same > 0) '这天已有 $same 个练${GROUP[mv!['group']]!['name']}的动作',
      if (after > 55) '加完约 $after 分钟，偏长',
    ];
    out.add({
      'workoutId': id,
      'name': w['name'],
      'dow': dow,
      'iso': iso,
      'gap': gap,
      'same': same,
      'before': before,
      'after': after,
      'score': score,
      'why': why.join('；'),
    });
  }
  final sorted = _stableSort(
    out,
    (a, b) => (b['score'] as num).compareTo(a['score'] as num),
  );
  if (sorted.isNotEmpty) sorted.first['best'] = true;
  return sorted;
}

Map<String, dynamic>? weeklyEffect(
  Map<String, dynamic> plan,
  Map<String, dynamic> spec,
  String workoutId,
) {
  final mv = musclesOf(spec['name'], spec['part'] as String?);
  if (mv == null) return null;
  final times = math.max(
    1,
    _map(plan['schedule']).values.where((id) => id == workoutId).length,
  );
  final group = mv['group'] as String, now = plannedWeekly(plan)[group]!;
  return {
    'group': group,
    'name': GROUP[group]!['name'],
    'now': now,
    'next': now + (_or(spec['sets'], 2) as num) * times,
    'band': BUDGET[group],
  };
}

List<T> _stableSort<T>(List<T> list, int Function(T, T) compare) {
  final indexed = list.indexed.toList()
    ..sort((a, b) {
      final c = compare(a.$2, b.$2);
      return c == 0 ? a.$1.compareTo(b.$1) : c;
    });
  return indexed.map((e) => e.$2).toList();
}
