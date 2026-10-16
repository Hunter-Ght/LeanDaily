import 'dart:math' as math;

class DomainError implements Exception {
  const DomainError(this.message);
  final String message;
  @override
  String toString() => message;
}

const defaultEx = <String, List<String>>{
  '胸': [
    '卧推',
    '哑铃卧推',
    '上斜卧推',
    '哑铃上斜卧推',
    '坐姿推胸机',
    '蝴蝶机夹胸',
    '龙门架夹胸',
    '双杠臂屈伸',
    '俯卧撑',
  ],
  '背': ['引体向上', '高位下拉', '坐姿划船', '杠铃划船', '单臂哑铃划船', 'T杠划船', '直臂下拉', '硬拉'],
  '腿': ['深蹲', '腿举', '罗马尼亚硬拉', '箭步蹲', '保加利亚分腿蹲', '腿屈伸', '腿弯举', '提踵', '臀推'],
  '肩': ['杠铃推举', '哑铃推举', '侧平举', '前平举', '反向飞鸟', '面拉', '器械推肩'],
  '手臂': ['杠铃弯举', '哑铃弯举', '锤式弯举', '绳索下压', '仰卧臂屈伸', '过头臂屈伸'],
  '核心': ['卷腹', '平板支撑', '悬垂举腿', '健腹轮', '俄罗斯转体'],
  '全身': ['壶铃摆荡', '波比跳', '农夫行走'],
  '有氧': ['跑步机', '椭圆机', '划船机', '单车'],
};
const meals = ['早餐', '午餐', '晚餐', '加餐'];
const types = ['热身', '正式', '递减'];
// Keep Web export names available to migration callers.
// ignore: constant_identifier_names
const DEFAULT_EX = defaultEx;
// ignore: constant_identifier_names
const MEALS = meals;
// ignore: constant_identifier_names
const TYPES = types;
// JS Number at the JSON boundary (including null, booleans and empty strings).
double number(Object? v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  if (v is bool) return v ? 1 : 0;
  final s = jsString(v).trim();
  if (s.isEmpty) return 0;
  if (RegExp(r'^0[xX][0-9a-fA-F]+$').hasMatch(s)) {
    return int.parse(s.substring(2), radix: 16).toDouble();
  }
  if (RegExp(r'^0[bB][01]+$').hasMatch(s)) {
    return int.parse(s.substring(2), radix: 2).toDouble();
  }
  if (RegExp(r'^0[oO][0-7]+$').hasMatch(s)) {
    return int.parse(s.substring(2), radix: 8).toDouble();
  }
  return double.tryParse(s) ?? double.nan;
}

bool truthy(Object? v) =>
    v != null && v != false && v != '' && v != 0 && !(v is num && v.isNaN);
String jsString(Object? v) {
  if (v == null) return 'null';
  if (v is Map) return '[object Object]';
  if (v is List) return v.map((x) => x == null ? '' : jsString(x)).join(',');
  if (v is num && v.isFinite && v == v.truncateToDouble()) {
    return v.toInt().toString();
  }
  return '$v';
}

String cut(Object? v, int n) {
  final s = jsString(v);
  return s.length > n ? s.substring(0, n) : s;
}

num r1(num n) => (n * 10 + .5).floor() / 10;
void validDate(Object? date) {
  final s = '$date';
  final d = DateTime.tryParse('${s}T12:00:00Z');
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s) ||
      d == null ||
      d.toIso8601String().substring(0, 10) != s) {
    throw const DomainError('日期无效');
  }
}

void validateSets(Object? sets) {
  if (sets is! List || sets.isEmpty || sets.length > 60) {
    throw const DomainError('每次填写 1–60 组');
  }
  for (final raw in sets) {
    final s = raw as Map;
    final w = s.containsKey('weight') ? number(s['weight']) : double.nan,
        reps = s.containsKey('reps') ? number(s['reps']) : double.nan;
    if (!w.isFinite || w < 0 || w > 1000) {
      throw const DomainError('重量应为 0–1000 kg');
    }
    if (!reps.isFinite ||
        reps != reps.truncateToDouble() ||
        reps < 1 ||
        reps > 500) {
      throw const DomainError('次数应为 1–500');
    }
    if (!types.contains(truthy(s['type']) ? s['type'] : '正式')) {
      throw const DomainError('组类型无效');
    }
    if (s['rpe'] != '' &&
        s['rpe'] != null &&
        !(number(s['rpe']) >= 1 && number(s['rpe']) <= 10)) {
      throw const DomainError('RPE 应为 1–10');
    }
    if (s['flag'] != null &&
        s['flag'] != '' &&
        !['form', 'pain'].contains(s['flag'])) {
      throw const DomainError('组标记无效');
    }
    if (s['count'] != null) {
      final c = number(s['count']);
      if (!c.isFinite || c != c.truncateToDouble() || c < 1 || c > 20) {
        throw const DomainError('组数应为 1–20');
      }
    }
  }
}

List<Map<String, dynamic>> cleanItems(Object? items) {
  if (items is! List) throw const DomainError('食物明细无效');
  final result = <Map<String, dynamic>>[];
  for (final raw in items.take(40)) {
    final i = raw as Map;
    if (jsString(truthy(i['name']) ? i['name'] : '').trim().isEmpty) continue;
    final out = <String, dynamic>{
      'name': cut(jsString(i['name']).trim(), 60),
      'portion': cut(truthy(i['portion']) ? i['portion'] : '', 40),
    };
    for (final k in ['kcal', 'protein', 'carbs', 'fat']) {
      final n = number(truthy(i[k]) ? i[k] : 0);
      if (!n.isFinite || n < 0 || n >= 100000) {
        throw const DomainError('营养数值无效');
      }
      out[k] = k == 'kcal' ? (n + .5).floor() : r1(n);
    }
    result.add(out);
  }
  return result;
}

Map<String, dynamic> sumItems(Iterable items) {
  final t = <String, dynamic>{'kcal': 0, 'protein': 0, 'carbs': 0, 'fat': 0};
  for (final i in items) {
    for (final k in t.keys) {
      final n = number((i as Map)[k]);
      t[k] = (t[k] as num) + (n.isNaN ? 0 : n);
    }
  }
  for (final k in t.keys) {
    t[k] = k == 'kcal' ? ((t[k] as num) + .5).floor() : r1(t[k]);
  }
  return t;
}

String weekday(String date) => [
  '周日',
  '周一',
  '周二',
  '周三',
  '周四',
  '周五',
  '周六',
][DateTime.parse('${date}T12:00:00').weekday % 7];
Map<String, dynamic> dayOf(Map<String, dynamic> state, String date) {
  final sets = <Map<String, dynamic>>[
    for (final s in (state['sets'] as Map).values)
      if (s['date'] == date && !truthy(s['deleted']))
        {...Map<String, dynamic>.from(s), 'dayDate': date},
  ];
  final work = sets.where((s) => s['type'] != '热身').toList();
  final best = <String, dynamic>{};
  for (final s in work) {
    best['${s['ex']}'] = math.max(
      (best['${s['ex']}'] ?? 0) as num,
      r1(number(s['w']) * (1 + number(s['reps']) / 30)),
    );
  }
  num volume(Iterable<Map<String, dynamic>> rows) =>
      r1(rows.fold<num>(0, (n, s) => n + number(s['w']) * number(s['reps'])));
  final note = (state['notes'] as Map)[date];
  return {
    'date': date,
    'sets': sets,
    'weekday': weekday(date),
    'totals': {
      '总训练量': volume(work),
      '含热身训练量': volume(sets),
      '正式组数': work.length,
      '部位': sets.map((s) => s['part']).where(truthy).toSet().toList(),
      'best_e1rm': best,
    },
    'day_row': truthy(note) ? {'体感备注': note} : null,
  };
}

Map<String, dynamic> mealsOf(Map<String, dynamic> state, String date) {
  final rows = <Map<String, dynamic>>[];
  for (final m in (state['meals'] as Map).values) {
    if (m['date'] != date || truthy(m['deleted'])) continue;
    final photos = m['photo_ids'] as List;
    rows.add({
      ...Map<String, dynamic>.from(m),
      'dayDate': date,
      'photos': photos.length,
      'local_photos': photos.length,
      'thumb': photos.isEmpty ? '' : photos.first,
    });
  }
  rows.sort((a, b) {
    final n = meals.indexOf(a['meal']) - meals.indexOf(b['meal']);
    return n != 0 ? n : (a['time'] as String).compareTo(b['time'] as String);
  });
  return {'date': date, 'meals': rows, 'totals': sumItems(rows)};
}
