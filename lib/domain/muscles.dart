import 'dart:math' as math;

import 'movements.dart';
export 'movements.dart' show MUSCLE;

// Names match the web model's public constants.
// ignore_for_file: constant_identifier_names
const HALF_LIFE_H = 36;
const RECOVERED_SETS = 1.2;
const REF_FLOOR = 6;
const REF_CAP = 14;
const REF_DAYS = 84;
const NOMINAL_HOUR = 18;
const _day = 86400000;
double _number(Object? v) {
  if (v == null || v == '') return 0;
  if (v is bool) return v ? 1 : 0;
  return v is num ? v.toDouble() : double.tryParse(v.toString()) ?? double.nan;
}

bool _truth(Object? v) => v != null && v != false && v != '' && v != 0;
double _e1(Map s) => _number(s['w']) * (1 + _number(s['reps']) / 30);
int dateMs(String iso, [int hour = NOMINAL_HOUR]) {
  final p = iso.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2], hour).millisecondsSinceEpoch;
}

double intensityOf(Map<String, dynamic> s, [num bestE1 = 0]) {
  final rpe = _number(s['rpe']);
  if (s['rpe'] != null &&
      s['rpe'] != '' &&
      rpe.isFinite &&
      rpe >= 1 &&
      rpe <= 10) {
    return (1.25 - 0.1 * (10 - rpe).clamp(0, 6)).clamp(0.65, 1.25);
  }
  if (_number(s['w']) > 0 && bestE1 > 0) {
    return (0.7 + 0.5 * math.min(1, _e1(s) / bestE1)).clamp(0.6, 1.2);
  }
  return 1;
}

List<Map<String, dynamic>> workSets(Map<String, Map<String, dynamic>>? days) {
  final out = <Map<String, dynamic>>[];
  for (final entry in (days ?? <String, Map<String, dynamic>>{}).entries) {
    for (final raw in entry.value['sets'] as List? ?? []) {
      if (raw == null) continue;
      final s = Map<String, dynamic>.from(raw as Map);
      if (!_truth(s['ex']) || _truth(s['deleted']) || s['type'] == '热身') {
        continue;
      }
      out.add({...s, 'date': _truth(s['date']) ? s['date'] : entry.key});
    }
  }
  return out;
}

Map<String, Map<String, dynamic>> emptyStatus() => {
  for (final m in MUSCLES)
    m['id']!: {
      ...m,
      'fatigue': 0.0,
      'ref': REF_FLOOR,
      'ratio': 0.0,
      'heat': 0.0,
      'recovered': true,
      'daysLeft': 0.0,
      'sets7': 0.0,
      'sets30': 0.0,
      'sets90': 0.0,
      'last': null,
      'daysSince': null,
      'from': <Map<String, dynamic>>[],
    },
};
Map<String, dynamic> muscleStatus(
  Map<String, Map<String, dynamic>> days,
  num nowMs,
) {
  final byMuscle = emptyStatus(), sets = workSets(days);
  final best = <String, double>{};
  for (final s in sets) {
    if (_number(s['w']) > 0) {
      best[s['ex'] as String] = math.max(best[s['ex']] ?? 0, _e1(s));
    }
  }
  final sessions = <String, Map<String, double>>{};
  final direct = {
    for (final g in GROUPS)
      g['id']!: <String, dynamic>{...g, 'sets7': 0, 'sets30': 0, 'sets90': 0},
  };
  for (final s in sets) {
    final mv = musclesOf(s['ex'], s['part'] as String?);
    if (mv == null) continue;
    final t = _number(s['ts']) > 0
        ? _number(s['ts'])
        : dateMs(s['date'] as String);
    if (t > nowMs + 3600000) continue;
    final hours = math.max(0, (nowMs - t) / 3600000), age = hours / 24;
    final load =
        (s['type'] == '递减' ? 0.75 : 1) * intensityOf(s, best[s['ex']] ?? 0);
    final decay = math.pow(0.5, hours / HALF_LIFE_H).toDouble();
    final dg = direct[mv['group']]!;
    for (final n in [7, 30, 90]) {
      if (age <= n) dg['sets$n'] = (dg['sets$n'] as num) + 1;
    }
    for (final e in (mv['muscles'] as Map<String, num>).entries) {
      final id = e.key, w = e.value, m = byMuscle[id]!, eff = load * w;
      m['fatigue'] = (m['fatigue'] as num) + eff * decay;
      for (final n in [7, 30, 90]) {
        if (age <= n) m['sets$n'] = (m['sets$n'] as num) + eff;
      }
      if (w >= 0.5 &&
          (m['last'] == null ||
              (s['date'] as String).compareTo(m['last'] as String) > 0)) {
        m['last'] = s['date'];
      }
      if (decay > 0.02) {
        final from = m['from'] as List<Map<String, dynamic>>;
        final i = from.indexWhere((f) => f['ex'] == s['ex']);
        if (i < 0) {
          from.add({'ex': s['ex'], 'sets': 1, 'load': eff * decay});
        } else {
          from[i]['sets'] = (from[i]['sets'] as int) + 1;
          from[i]['load'] = (from[i]['load'] as num) + eff * decay;
        }
      }
      if (t >= nowMs - REF_DAYS * _day) {
        final session = sessions.putIfAbsent(id, () => {});
        session[s['date'] as String] = (session[s['date']] ?? 0) + eff;
      }
    }
  }
  final today = DateTime.fromMillisecondsSinceEpoch(nowMs.toInt());
  final iso =
      '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
  for (final m in byMuscle.values) {
    final a = (sessions[m['id']] ?? {}).values.toList()..sort();
    m['ref'] =
        (a.isEmpty ? 0 : a[math.min(a.length - 1, (0.9 * a.length).floor())])
            .clamp(REF_FLOOR, REF_CAP);
    final fatigue = m['fatigue'] as num;
    m['ratio'] = fatigue / (m['ref'] as num);
    m['recovered'] = fatigue < RECOVERED_SETS;
    m['heat'] = m['recovered'] as bool
        ? 0.0
        : (m['ratio'] as num).clamp(0.2, 1.0);
    m['daysLeft'] = m['recovered'] as bool
        ? 0.0
        : HALF_LIFE_H / 24 * math.log(fatigue / RECOVERED_SETS) / math.ln2;
    (m['from'] as List<Map<String, dynamic>>).sort(
      (a, b) => (b['load'] as num).compareTo(a['load'] as num),
    );
    m['daysSince'] = m['last'] == null
        ? null
        : ((dateMs(iso, 12) - dateMs(m['last'] as String, 12)) / _day).round();
  }
  return {'byMuscle': byMuscle, 'groups': direct, 'setCount': sets.length};
}

double detrainLevel(num? daysSince) =>
    daysSince == null ? 1 : (daysSince / 42).clamp(0, 1);
