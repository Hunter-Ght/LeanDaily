// 自由练：不按计划时，按肌肉恢复状态推荐“现在练什么”，器械被占时找同肌肉的替代动作。
// 只读 muscleStatus 的结果，不改计划、不落盘。
import 'dart:math' as math;

import 'equipment.dart';
import 'movements.dart' show GROUPS, MUSCLE, musclesOf;
import 'records.dart' show defaultEx;

/// 推荐里的一个动作。[equipment] 为空表示徒手或不依赖器械。
typedef FreeExercise = ({
  String name,
  String part,
  String primary,
  String? equipment,
  bool ready,
  bool done,
});

/// 一个可练的肌群及其候选动作。[daysSince] 为 null 表示从没练过。
typedef FreeGroup = ({
  String group,
  String name,
  num? daysSince,
  List<FreeExercise> exercises,
});

/// 还在恢复的肌群：[daysLeft] 为预计还要几天。
typedef RecoveringGroup = ({String group, String name, double daysLeft});

Map<String, num> _muscles(String name) {
  final mv = musclesOf(name, partOfExercise(name));
  return mv == null ? const {} : mv['muscles'] as Map<String, num>;
}

Map _m(Map status, String id) => (status['byMuscle'] as Map)[id] as Map;

/// 动作能不能练：权重 ≥ 0.5 的肌肉都已恢复。
bool exerciseReady(Map status, String name) {
  final mus = _muscles(name);
  if (mus.isEmpty) return false;
  return mus.entries
      .where((e) => e.value >= 0.5)
      .every((e) => _m(status, e.key)['recovered'] == true);
}

/// 动作在“我的健身房”里能不能做：没设置器械、徒手动作，或至少一台器械在列表里。
bool exerciseAvailable(String name, Set<String> owned) {
  if (owned.isEmpty) return true;
  final eq = equipmentFor(name);
  return eq.isEmpty || eq.any((e) => owned.contains(e.id));
}

/// 所有可推荐的力量动作（规范名），器械库动作在前。
List<String> freePool() {
  final pool = <String>{
    for (final e in equipmentList)
      if (e.kind != '有氧') ...e.exercises,
    for (final entry in defaultEx.entries)
      if (entry.key != '有氧') ...entry.value,
  };
  return [
    for (final name in pool)
      if (_muscles(name).isNotEmpty) name,
  ];
}

String? _equipmentName(String name, Set<String> owned) {
  final eq = equipmentFor(name);
  if (eq.isEmpty) return null;
  return (eq.where((e) => owned.contains(e.id)).firstOrNull ?? eq.first).name;
}

FreeExercise _entry(
  Map status,
  String name,
  Set<String> owned,
  Set<String> done,
) {
  final mv = musclesOf(name, partOfExercise(name))!;
  return (
    name: name,
    part: partOfExercise(name),
    primary: mv['primary'] as String,
    equipment: _equipmentName(name, owned),
    ready: exerciseReady(status, name),
    done: done.contains(name),
  );
}

/// 现在能练什么：已恢复的肌群，越久没练越靠前（没练过的最前），
/// 每个肌群给最多 [perGroup] 个动作：练过的、有器械的优先。
/// [done] 是用户记录过的动作名；[owned] 是“我的健身房”的器械 id，空表示不限。
List<FreeGroup> recommendNow(
  Map status, {
  Set<String> owned = const {},
  Set<String> done = const {},
  int perGroup = 3,
}) {
  final pool = freePool();
  final out = <FreeGroup>[];
  for (final g in GROUPS) {
    final id = g['id']!;
    final members = [
      for (final m in (status['byMuscle'] as Map).values)
        if (MUSCLE[m['id']]?['group'] == id) m as Map,
    ];
    // 只要有一个动作的主要发力肌肉都恢复了就推荐（下背累不影响高位下拉）。
    if (members.isEmpty) continue;
    final since = members
        .map((m) => m['daysSince'] as num?)
        .fold<num?>(null, (a, b) => b == null ? a : a == null ? b : math.min(a, b));
    final candidates = [
      for (final name in pool)
        if (exerciseAvailable(name, owned))
          _entry(status, name, owned, done),
    ].where((e) => e.ready && MUSCLE[e.primary]!['group'] == id).toList();
    if (candidates.isEmpty) continue;
    int rank(FreeExercise e) => (e.done ? 0 : 2) + (e.equipment != null ? 0 : 1);
    final indexed = candidates.indexed.toList()
      ..sort((a, b) {
        final r = rank(a.$2).compareTo(rank(b.$2));
        return r != 0 ? r : a.$1.compareTo(b.$1);
      });
    out.add((
      group: id,
      name: g['name']!,
      daysSince: since,
      exercises: [for (final e in indexed.take(perGroup)) e.$2],
    ));
  }
  // 没练过的最前，其余按距上次训练天数从久到近；同样时按 GROUPS 顺序。
  final order = {for (final (i, g) in GROUPS.indexed) g['id']: i};
  out.sort((a, b) {
    final da = a.daysSince ?? 1e9, db = b.daysSince ?? 1e9;
    final c = db.compareTo(da);
    return c != 0 ? c : order[a.group]!.compareTo(order[b.group]!);
  });
  return out;
}

/// 还在恢复、现在没有可推荐动作的肌群，快恢复的在前。
List<RecoveringGroup> recoveringGroups(
  Map status, {
  Set<String> owned = const {},
}) {
  final ready = {for (final g in recommendNow(status, owned: owned)) g.group};
  final out = <RecoveringGroup>[];
  for (final g in GROUPS) {
    if (ready.contains(g['id'])) continue;
    final left = [
      for (final m in (status['byMuscle'] as Map).values)
        if (MUSCLE[m['id']]?['group'] == g['id'] && m['recovered'] != true)
          (m['daysLeft'] as num).toDouble(),
    ];
    if (left.isNotEmpty) {
      out.add((group: g['id']!, name: g['name']!, daysLeft: left.reduce(math.max)));
    }
  }
  out.sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
  return out;
}

double _similarity(Map<String, num> a, Map<String, num> b) {
  var dot = 0.0, na = 0.0, nb = 0.0;
  for (final e in a.entries) {
    dot += e.value * (b[e.key] ?? 0);
    na += e.value * e.value;
  }
  for (final v in b.values) {
    nb += v * v;
  }
  return na == 0 || nb == 0 ? 0 : dot / math.sqrt(na * nb);
}

/// 器械被占时的替代：主练肌肉相同、换一台器械（或徒手）的动作，按发力相似度排序。
List<FreeExercise> alternativesFor(
  Map status,
  String exercise, {
  Set<String> owned = const {},
  Set<String> done = const {},
  int limit = 5,
}) {
  final name = exerciseAliases[exercise] ?? exercise;
  final mus = _muscles(name);
  if (mus.isEmpty) return const [];
  final primary = musclesOf(name, partOfExercise(name))!['primary'];
  final busy = {for (final e in equipmentFor(name)) e.id};
  final scored = <(FreeExercise, double)>[];
  for (final other in freePool()) {
    if (other == name || !exerciseAvailable(other, owned)) continue;
    final mv = musclesOf(other, partOfExercise(other))!;
    if (mv['primary'] != primary) continue;
    final eq = {for (final e in equipmentFor(other)) e.id};
    // 同一台器械上的动作不算替代（器械正被占着）；徒手动作总能做。
    if (eq.isNotEmpty && eq.difference(busy).isEmpty) continue;
    scored.add((
      _entry(status, other, owned, done),
      _similarity(mus, mv['muscles'] as Map<String, num>),
    ));
  }
  scored.sort((a, b) {
    final s = b.$2.compareTo(a.$2);
    if (s != 0) return s;
    return (a.$1.done ? 0 : 1).compareTo(b.$1.done ? 0 : 1);
  });
  return [for (final s in scored.take(limit)) s.$1];
}
