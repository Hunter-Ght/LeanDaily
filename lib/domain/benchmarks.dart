/// 小测试：三项都可以跳过，只记「类型 + 数字」，用来在 12 周后和第一次比一比。
///
/// 一次测试是一条记录，按日期保存（同一天再测会覆盖）：
/// ```
/// {'date': '2026-10-20', 'pushup': {'n': 12, 'knee': false},
///  'plank': {'sec': 45}, 'pull': {'type': 'row', 'n': 8}}
/// ```
/// 三项都是可选的；`pull.type` 是 `row`（反向划船，次数）、`pullup`（引体向上，次数）
/// 或 `assisted`（辅助引体，数字是配重，单位 kg）。
library;

import 'records.dart' show DomainError, jsString, number;

const benchmarkItems = ['pushup', 'plank', 'pull'];
const benchmarkItemLabels = {'pushup': '俯卧撑', 'plank': '平板支撑', 'pull': '拉的动作'};
const benchmarkPullTypes = ['row', 'pullup', 'assisted'];
const benchmarkPullLabels = {
  'row': '反向划船',
  'pullup': '引体向上',
  'assisted': '辅助引体',
};

const benchmarkMaxCount = 500;
const benchmarkMaxSeconds = 3600;
const benchmarkMaxAssistKg = 200;

final _dateRe = RegExp(r'^\d{4}-\d{2}-\d{2}$');

int? _count(Object? v, int max) {
  if (v == null || jsString(v).trim().isEmpty) return null;
  final n = number(v);
  if (!n.isFinite || n != n.truncateToDouble() || n < 0 || n > max) {
    throw const DomainError('测试数字无效');
  }
  return n.toInt();
}

/// 校验并整理一次测试；三项都空时抛 [DomainError]。
Map<String, dynamic> cleanBenchmark({
  required String date,
  Object? pushup,
  bool pushupKnee = false,
  Object? plank,
  Object? pullType,
  Object? pull,
}) {
  final day = DateTime.tryParse('${date}T12:00:00Z');
  if (!_dateRe.hasMatch(date) ||
      day == null ||
      day.toIso8601String().substring(0, 10) != date) {
    throw const DomainError('日期无效');
  }
  final push = _count(pushup, benchmarkMaxCount);
  final sec = _count(plank, benchmarkMaxSeconds);
  Map<String, dynamic>? pullRow;
  if (pull != null && jsString(pull).trim().isNotEmpty) {
    if (!benchmarkPullTypes.contains(pullType)) {
      throw const DomainError('测试类型无效');
    }
    if (pullType == 'assisted') {
      final kg = number(pull);
      if (!kg.isFinite || kg < 0 || kg > benchmarkMaxAssistKg) {
        throw const DomainError('测试数字无效');
      }
      pullRow = {'type': pullType, 'n': (kg * 10).round() / 10};
    } else {
      pullRow = {'type': pullType, 'n': _count(pull, benchmarkMaxCount)!};
    }
  }
  if (push == null && sec == null && pullRow == null) {
    throw const DomainError('至少填一项');
  }
  return {
    'date': date,
    'pushup': ?(push == null ? null : {'n': push, 'knee': pushupKnee}),
    'plank': ?(sec == null ? null : {'sec': sec}),
    'pull': ?pullRow,
  };
}

/// 读取或导入时用：无效的整条丢掉。
Map<String, dynamic>? tryCleanBenchmark(Object? raw) {
  if (raw is! Map) return null;
  final push = raw['pushup'], plank = raw['plank'], pull = raw['pull'];
  try {
    final row = cleanBenchmark(
      date: jsString(raw['date']),
      pushup: push is Map ? push['n'] : null,
      pushupKnee: push is Map && push['knee'] == true,
      plank: plank is Map ? plank['sec'] : null,
      pullType: pull is Map ? pull['type'] : null,
      pull: pull is Map ? pull['n'] : null,
    );
    final ts = number(raw['ts']);
    return {...row, if (ts.isFinite && ts > 0) 'ts': ts.toInt()};
  } on DomainError {
    return null;
  }
}

/// 一项测试在一次记录里的数字；没测这项返回 null。
num? benchmarkValue(Map<String, dynamic> entry, String item) {
  final v = entry[item];
  if (v is! Map) return null;
  final n = switch (item) {
    'pushup' => v['n'],
    'plank' => v['sec'],
    _ => v['n'],
  };
  return n is num ? n : null;
}

/// 两次测试是不是同一种做法（俯卧撑的标准 / 跪姿、拉的类型），不同就不能直接比数字。
bool benchmarkComparable(
  String item,
  Map<String, dynamic> a,
  Map<String, dynamic> b,
) {
  final x = a[item], y = b[item];
  if (x is! Map || y is! Map) return false;
  return switch (item) {
    'pushup' => (x['knee'] == true) == (y['knee'] == true),
    'pull' => x['type'] == y['type'],
    _ => true,
  };
}

/// [since] 当天及以后的测试（不传就是全部），按日期升序。
List<Map<String, dynamic>> benchmarksSince(
  List<Map<String, dynamic>> entries, [
  String? since,
]) => [
  for (final e in entries)
    if (since == null || '${e['date']}'.compareTo(since) >= 0) e,
]..sort((a, b) => '${a['date']}'.compareTo('${b['date']}'));

/// 每项的「第一次 → 最近一次」。只测过一次的项，`latest` 为 null。
///
/// 每行：`item`、`first`（那次的项目内容）、`firstDate`、`latest`、`latestDate`、
/// `comparable`（两次是同一种做法，可以直接比数字）。没测过的项不出现。
List<Map<String, dynamic>> benchmarkRows(List<Map<String, dynamic>> entries) {
  final sorted = benchmarksSince(entries);
  final rows = <Map<String, dynamic>>[];
  for (final item in benchmarkItems) {
    final have = [
      for (final e in sorted)
        if (benchmarkValue(e, item) != null) e,
    ];
    if (have.isEmpty) continue;
    final first = have.first, last = have.last;
    final single = identical(first, last);
    rows.add({
      'item': item,
      'first': first[item],
      'firstDate': first['date'],
      if (!single) 'latest': last[item],
      if (!single) 'latestDate': last['date'],
      'comparable': single || benchmarkComparable(item, first, last),
    });
  }
  return rows;
}
