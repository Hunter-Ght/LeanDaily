// ignore_for_file: constant_identifier_names
import 'dart:math' as math;

import 'format.dart';
import 'progress_options.dart';
import 'plan.dart';
import 'calendar.dart' show mondayOf, daysApart;
import 'movements.dart' show musclesOf, GROUPS;

const CFG = {
  'repConfirms': 2,
  'capConfirms': 2,
  'plateauExposures': 3,
  'minWeeksForSetUp': 5,
  'adherenceMin': 0.8,
  'setUpGapDays': 14,
  'maxAutoSets': 3,
  'tooEasyRir': 4,
  'returnGapDays': 14,
  'declineDays': 14,
  'bigStepPct': 0.1,
  'repCapExtended': 20,
  'secStep': 5,
};
const BUDGET = {
  'chest': {'lo': 8, 'hi': 12, 'cap': 12},
  'back': {'lo': 6, 'hi': 10, 'cap': 12},
  'shoulders': {'lo': 4, 'hi': 8, 'cap': 10},
  'abs': {'lo': 4, 'hi': 8, 'cap': 10},
  'quads': {'lo': 4, 'hi': 8, 'cap': 10},
  'hamstrings': {'lo': 2, 'hi': 6, 'cap': 10},
  'glutes': {'lo': 2, 'hi': 6, 'cap': 10},
  'arms': {'lo': 2, 'hi': 8, 'cap': 10},
  'calves': {'lo': 0, 'hi': 6, 'cap': 10},
};
String _unitOf(Map<String, dynamic> ex) => ex['unit'] == 'sec' ? 'sec' : 'reps';
int _stepOf(Map<String, dynamic> ex) => _unitOf(ex) == 'sec' ? 5 : 1;
bool _isLoaded(Map<String, dynamic> ex) =>
    jsTruthy(ex['machine']) || jsNumber(ex['weight']) > 0;
num _n(Object? v) {
  final n = jsNumber(v);
  return n.isNaN ? 0 : n;
}

num _sets(Map<String, dynamic> ex) =>
    jsTruthy(ex['sets']) ? jsNumber(ex['sets']) : 1;
num _max(Iterable<num> ns, [num floor = 0]) => ns.fold<num>(floor, math.max);
num _min(Iterable<num> ns) => ns.reduce(math.min);
String _s(Object? v) => jsString(v);
Map<String, dynamic> emptyProgress() => {
  'v': 1,
  'anchors': <String, dynamic>{},
  'steps': <String, dynamic>{},
  'declined': <String, dynamic>{},
  'setUps': <String, dynamic>{},
};
List<Map<String, dynamic>> sessionsOf(Map<String, dynamic>? days, String name) {
  final out = <Map<String, dynamic>>[];
  for (final entry in (days ?? <String, dynamic>{}).entries) {
    final sets = formalSets(jsonMap(entry.value), name);
    if (sets.isNotEmpty) out.add({'date': entry.key, 'sets': sets});
  }
  return out
    ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
}

num? _rirOf(Map<String, dynamic> s) =>
    s['rpe'] == null || s['rpe'] == '' || !jsNumber(s['rpe']).isFinite
    ? null
    : (10 - jsNumber(s['rpe'])).clamp(0, 10);
Map<String, dynamic> evaluate(
  Map<String, dynamic> ex,
  Map<String, dynamic> session,
  num target, [
  Object? ready,
  ProgressOptions? options,
]) {
  final need = math.max(1, _sets(ex));
  final sets = jsonRows(session['sets']);
  final reps = sets.take(need.toInt()).map((s) => _n(s['reps'])).toList();
  final rirs = sets.map(_rirOf).whereType<num>().toList();
  final flag = sets.any((s) => s['flag'] == 'pain')
      ? 'pain'
      : sets.any((s) => s['flag'] == 'form')
      ? 'form'
      : null;
  return {
    'date': session['date'],
    'complete': sets.length >= need,
    'met': sets.length >= need && reps.every((r) => r >= target),
    'minReps': reps.isEmpty ? 0 : _min(reps),
    'rirMin': rirs.isEmpty ? null : _min(rirs),
    'tooEasy':
        rirs.isNotEmpty &&
        _min(rirs) >= (options == null ? CFG['tooEasyRir']! : 3),
    'weight': _max(sets.map((s) => _n(s['w']))),
    'flag': flag,
    'neutral': options?.deloadActive == true
        ? 'deload'
        : ready == 'bad'
        ? 'bad'
        : ready == 'tired'
        ? 'tired'
        : null,
  };
}

Map<String, dynamic> targetFor(
  Map<String, dynamic> ex,
  Map<String, dynamic>? days, {
  Map<String, dynamic>? anchor,
  Map<String, dynamic> dayStates = const {},
  String today = '',
  bool include = false,
  Map<String, dynamic>? progress,
  ProgressOptions? options,
}) {
  final repConfirms = options?.repConfirms ?? CFG['repConfirms']!;
  final capConfirms = options?.capConfirms ?? CFG['capConfirms']!;
  final deloadWeek = jsonMap(progress?['deload'])['week'];
  bool isDeload(String date) =>
      options != null &&
      ((options.deloadActive &&
              today.isNotEmpty &&
              mondayOf(date) == mondayOf(today)) ||
          mondayOf(date) == deloadWeek ||
          (progress?['deloadWeeks'] as List? ?? const []).contains(
            mondayOf(date),
          ));
  final anch = anchor ?? jsonMap(progress?['anchors'])[ex['name']];
  final step = _stepOf(ex), all = sessionsOf(days, ex['name'] as String);
  final seen = all
      .where((s) => (s['date'] as String).compareTo(today) < (include ? 1 : 0))
      .toList();
  final list = seen
      .where(
        (s) =>
            anch == null ||
            (s['date'] as String).compareTo(anch['date'] as String) > 0,
      )
      .toList();
  final min = jsNumber(ex['min']), max = jsNumber(ex['max']);
  num target = jsNumber(anch?['reps'] ?? ex['min']).clamp(min, max);
  var streak = 0, cap = 0, stuck = 0, belowMin = 0;
  String? prev = anch?['date'] as String?;
  Map<String, dynamic>? last;
  var raised = false;
  final evals = <Map<String, dynamic>>[];
  for (final session in list) {
    final date = session['date'] as String;
    final gap = prev != null && daysApart(prev, date) >= CFG['returnGapDays']!;
    if (gap) {
      target = math.max(min, target - 2 * step);
      streak = 0;
      cap = 0;
      stuck = 0;
      belowMin = 0;
    }
    prev = date;
    final ev = evaluate(
      gap ? {...ex, 'sets': math.max(1, _sets(ex) - 1)} : ex,
      session,
      target,
      jsonMap(dayStates[date])['ready'],
      options?.forDeload(isDeload(date)),
    )..['target'] = target;
    if (jsTruthy(ev['neutral']) ||
        include &&
            date == today &&
            ev['complete'] != true &&
            !jsTruthy(ev['flag'])) {
      last = {...ev, 'skipped': true};
      evals.add(last);
      continue;
    }
    raised = false;
    if (jsTruthy(ev['flag'])) {
      streak = 0;
      cap = 0;
      stuck++;
      last = ev;
      evals.add(ev);
      continue;
    }
    if (options != null &&
        evals.reversed.take(2).any((e) => e['flag'] == 'pain')) {
      streak = 0;
      cap = 0;
      last = ev;
      evals.add(ev);
      continue;
    }
    if (ev['met'] == true) {
      stuck = 0;
      belowMin = 0;
      if (target >= max) {
        if (ev['rirMin'] == null || jsNumber(ev['rirMin']) >= 2) {
          cap++;
        } else if (options != null) {
          cap = 0;
        }
      } else {
        if (options?.level != 'trained' ||
            ev['rirMin'] == null ||
            jsNumber(ev['rirMin']) >= 1) {
          streak++;
        } else {
          streak = 0;
        }
        if (streak >= repConfirms) {
          target = math.min(max, target + step);
          streak = 0;
          raised = true;
        }
      }
    } else {
      streak = 0;
      cap = 0;
      stuck++;
      belowMin = jsNumber(ev['minReps']) < min ? belowMin + 1 : 0;
    }
    last = ev;
    evals.add(ev);
  }
  final counted = evals.where((e) => !jsTruthy(e['skipped'])).toList();
  final lastTwo = counted.skip(math.max(0, counted.length - 2)).toList();
  final tooEasy =
      lastTwo.length == 2 &&
      lastTwo.every(
        (e) =>
            e['tooEasy'] == true &&
            (options == null || e['met'] == true && !jsTruthy(e['flag'])),
      );
  final exceed =
      lastTwo.length == 2 &&
      lastTwo.every(
        (e) =>
            jsNumber(e['minReps']) >= jsNumber(e['target']) + 2 &&
            (options == null || e['met'] == true && !jsTruthy(e['flag'])),
      );
  num weight = anch?['weight'] as num? ?? _n(ex['weight']);
  for (final session in list.reversed) {
    if (isDeload(session['date'] as String)) continue;
    final w = _max(jsonRows(session['sets']).map((s) => _n(s['w'])));
    if (w > 0) {
      weight = w;
      break;
    }
  }
  final lastAny = all.isEmpty ? null : all.last['date'] as String;
  final returning =
      lastAny != null &&
      today.isNotEmpty &&
      daysApart(lastAny, today) >= CFG['returnGapDays']!;
  if (options != null && returning) target = math.max(min, target - 2 * step);
  final calibrate =
      _isLoaded(ex) &&
      all.isEmpty &&
      !jsTruthy(anch?['cal']) &&
      !(jsNumber(ex['weight']) > 0 && !jsTruthy(ex['machine']));
  final unit = _unitOf(ex) == 'sec' ? '秒' : '次';
  var reason = '';
  if (calibrate) {
    reason = '第一次做：先用较轻的重量，选一个能做 ${_s(ex['min'])} $unit、做完还能再做 2～3 次的。';
  } else if (seen.isEmpty && anch == null) {
    reason = '从区间下限 ${_s(target)} $unit开始，动作稳比次数多更重要。';
  } else if (returning) {
    reason = '隔了 ${daysApart(lastAny, today)} 天没练：这次每个动作少做 1 组，重量降一点，先找回感觉。';
  } else if (last?['flag'] == 'pain') {
    reason = '上次标记了不舒服：这次不加量，疼痛没消就停下，持续就去看医生。';
  } else if (last?['flag'] == 'form') {
    reason = '上次动作有点变形：这次保持 ${_s(target)} $unit，先把动作做标准。';
  } else if (last?['skipped'] == true) {
    reason = '上次状态不好，不算进度：目标还是 ${_s(target)} $unit。';
  } else if (raised) {
    reason = '连续 ${_s(repConfirms)} 次都做到了，这次每组加到 ${_s(target)} $unit。';
  } else if (last != null && last['met'] != true) {
    reason =
        '上次没做到 ${_s(last['target'])} $unit，这次继续 ${_s(target)} $unit，不用补偿加组。';
  } else if (target >= max && cap >= 1) {
    reason = '已经做满 ${_s(target)} $unit，再稳定 ${_s(capConfirms - cap)} 次就可以升级难度。';
  } else if (streak >= 1) {
    reason =
        '上次做到了 ${_s(target)} $unit，再稳定 ${_s(repConfirms - streak)} 次就加 1 $unit。';
  } else if (last != null) {
    reason = '保持 ${_s(target)} $unit。';
  }
  if (options?.youth == true && target >= max && cap >= 1) {
    reason = '已经做满 ${_s(target)} $unit，保持次数，先把动作做得更稳。';
  }
  if (options?.deloadActive == true) {
    final configured = jsonMap(progress?['steps'])[ex['name']];
    final increment = configured is num && configured > 0
        ? configured
        : loadStep(ex, weight, options!);
    weight = (weight * .9 / increment).round() * increment;
    reason = '本周减量：每个动作少 1 组、重量降约 10%';
  }
  return {
    'reps': target,
    'weight': weight,
    'sets': returning || options?.deloadActive == true
        ? math.max(1, _sets(ex) - 1)
        : _sets(ex),
    'streak': streak,
    'cap': cap,
    'stuck': stuck,
    'belowMin': belowMin,
    'tooEasy': tooEasy,
    'exceed': exceed,
    'returning': returning,
    'calibrate': calibrate,
    'last': last,
    'evals': counted,
    'sessions': all.length,
    'lastDate': lastAny,
    'reason': reason,
    'flag': last?['flag'],
  };
}

bool _declined(String key, Map<String, dynamic>? progress, String today) {
  final at = jsonMap(progress?['declined'])[key];
  return jsTruthy(at) && daysApart(at as String, today) < CFG['declineDays']!;
}

Map<String, dynamic> adherence(
  Map<String, dynamic> plan,
  Map<String, dynamic>? days,
  Map<String, dynamic>? dayStates,
  String today,
) {
  final from = shiftDate(today, -27),
      start =
          jsTruthy(plan['startDate']) &&
              (plan['startDate'] as String).compareTo(from) > 0
          ? plan['startDate'] as String
          : from;
  var planned = 0, done = 0;
  for (var d = start; d.compareTo(today) <= 0; d = shiftDate(d, 1)) {
    final slot = workoutFor(plan, d, jsonMap(dayStates?[d]));
    final did = jsonRows(jsonMap(days?[d])['sets'])
        .any((s) => s['type'] != '热身' && !jsTruthy(s['deleted']));
    if (slot['kind'] == 'train' || did) {
      if (d == today && !did) continue;
      planned++;
      if (did) done++;
    }
  }
  return {
    'planned': planned,
    'done': done,
    'rate': planned > 0 ? done / planned : 1,
  };
}

Map<String, dynamic> weeklyGroups(Map<String, dynamic>? days, String today) {
  final start = mondayOf(today), prev = shiftDate(mondayOf(today), -7);
  final out = <String, dynamic>{
    for (final g in GROUPS)
      g['id']!: {
        'id': g['id'],
        'name': g['name'],
        'week': 0,
        'last': 0,
        'band': BUDGET[g['id']],
      },
  };
  for (final e in (days ?? <String, dynamic>{}).entries) {
    if (e.key.compareTo(prev) < 0 || e.key.compareTo(today) > 0) continue;
    for (final s in jsonRows(jsonMap(e.value)['sets'])) {
      if (!jsTruthy(s['ex']) || jsTruthy(s['deleted']) || s['type'] == '热身') {
        continue;
      }
      final mv = musclesOf(s['ex'], s['part'] as String?);
      if (mv == null) continue;
      final key = e.key.compareTo(start) >= 0 ? 'week' : 'last';
      out[mv['group']][key] = (out[mv['group']][key] as int) + 1;
    }
  }
  return out;
}

bool recentRedFlag(
  Map<String, dynamic>? days,
  Map<String, dynamic>? dayStates,
  String today,
) {
  final from = shiftDate(today, -13);
  for (final e in (dayStates ?? <String, dynamic>{}).entries) {
    if (e.key.compareTo(from) >= 0 &&
        e.key.compareTo(today) <= 0 &&
        jsonMap(e.value)['ready'] == 'bad') {
      return true;
    }
  }
  for (final e in (days ?? <String, dynamic>{}).entries) {
    if (e.key.compareTo(from) < 0 || e.key.compareTo(today) > 0) continue;
    if (jsonRows(jsonMap(e.value)['sets'])
        .any((s) => s['flag'] == 'pain' && !jsTruthy(s['deleted']))) {
      return true;
    }
  }
  return false;
}

Map<String, dynamic>? suggest(
  Map<String, dynamic> ex,
  Map<String, dynamic> ctx, {
  ProgressOptions? options,
}) {
  final plan = jsonMap(ctx['plan']),
      days = jsonMap(ctx['days']),
      states = jsonMap(ctx['dayStates']);
  final progress = ctx['progress'] == null ? null : jsonMap(ctx['progress']);
  final today = ctx['today'] as String,
      review = ctx['review'] == null ? null : jsonMap(ctx['review']);
  final t = ctx['target'] == null
      ? targetFor(
          ex,
          days,
          dayStates: states,
          today: today,
          include: true,
          progress: progress,
          options: options,
        )
      : jsonMap(ctx['target']);
  final evals = jsonRows(t['evals']);
  final recentPain =
      options != null &&
      sessionsOf(days, ex['name'] as String)
          .where((s) => (s['date'] as String).compareTo(today) <= 0)
          .toList()
          .reversed
          .take(3)
          .any((s) => jsonRows(s['sets']).any((set) => set['flag'] == 'pain'));
  if (options?.deloadActive == true && !recentPain) return null;
  if (!recentPain && (t['calibrate'] == true || evals.isEmpty)) return null;
  final unit = _unitOf(ex) == 'sec' ? '秒' : '次', name = ex['name'] as String;
  Map<String, dynamic>? pick(String kind, Map<String, dynamic> body) =>
      _declined('$name:$kind', progress, today)
      ? null
      : {
          'kind': kind,
          'key': '$name:$kind',
          'ex': name,
          if (ex.containsKey('id')) 'exId': ex['id'],
          'lastDate': t['lastDate'],
          ...body,
          if (options?.stage == 'cut' && kind == 'ease')
            'body': '${body['body']} 热量缺口期偶尔做不到下限是正常的，先保持。',
        };
  final last = evals.isEmpty ? <String, dynamic>{} : evals.last;
  if (recentPain ||
      last['flag'] == 'pain' ||
      options != null &&
          evals.reversed.take(3).any((e) => e['flag'] == 'pain')) {
    return pick('pain', {
      'title': '$name：上次标了疼痛',
      'body': '先不要加量。疼痛一两天没消、或出现异常无力、肌肉剧痛、尿色很深，请停止训练并去看医生。',
      'info': true,
    });
  }
  if (options != null && recentRedFlag(days, states, today)) return null;
  final ladder = jsonMap(jsonMap(plan['ladders'])[ex['ladder']]);
  final ladderSteps = jsonRows(ladder['steps']),
      stage = _n(ladder['stage']).toInt();
  final steps = {
    if (options != null) ...jsonMap(plan['steps']),
    ...jsonMap(progress?['steps']),
  };
  if (jsNumber(t['belowMin']) >= 2) {
    if (ladder.isNotEmpty && stage > 0) {
      return pick('ease', {
        'title': '$name：连续两次没到 ${_s(ex['min'])} $unit',
        'body': '这个难度现在偏大，退回上一阶「${ladderSteps[stage - 1]['name']}」再练几次。',
        'accept': {
          'type': 'ladder',
          'ladderId': ex['ladder'],
          'stage': stage - 1,
          'date': t['lastDate'],
        },
        'acceptLabel': '退回上一阶',
      });
    }
    if (_isLoaded(ex) && jsNumber(t['weight']) > 0) {
      final stepKg = jsTruthy(steps[name])
          ? jsNumber(steps[name])
          : options != null
          ? loadStep(ex, jsNumber(t['weight']), options)
          : jsTruthy(ex['machine'])
          ? 2.5
          : 0.5;
      final next = math.max(
        0,
        options == null
            ? ((jsNumber(t['weight']) - stepKg) * 10 + 0.5).floor() / 10
            : jsNumber(t['weight']) - stepKg,
      );
      return pick('ease', {
        'title': '$name：连续两次没到 ${_s(ex['min'])} $unit',
        'body': '重量现在偏大。降到 ${_s(next)} kg，把 ${_s(ex['min'])} $unit做标准再往上加。',
        'accept': {
          'type': 'anchor',
          'name': name,
          'date': t['lastDate'],
          'reps': ex['min'],
          'weight': next,
        },
        'acceptLabel': '降到 ${_s(next)} kg',
      });
    }
    return pick('ease', {
      'title': '$name：连续两次没到 ${_s(ex['min'])} $unit',
      'body': '先把动作和控制做好；休息、睡眠、吃饭也看一下。目标不变，不补偿加组。',
      'info': true,
    });
  }
  if (jsNumber(t['cap']) >= (options?.capConfirms ?? CFG['capConfirms']!)) {
    if (options?.youth == true) {
      return pick('variant', {
        'title': '$name：保持动作质量',
        'body': '保持当前次数，做得更稳；需要时请教练指导变式。',
        'info': true,
      });
    }
    if (ladder.isNotEmpty && stage + 1 < ladderSteps.length) {
      final nx = ladderSteps[stage + 1];
      return pick('ladder', {
        'title':
            '$name：连续${options?.level == 'trained' ? '三' : '两'}次做满 ${_s(ex['max'])} $unit',
        'body': '动作标准的话，换更难的「${nx['name']}」，次数从 ${_s(nx['min'])} 次起步。',
        'accept': {
          'type': 'ladder',
          'ladderId': ex['ladder'],
          'stage': stage + 1,
          'date': t['lastDate'],
        },
        'acceptLabel': '升级到${nx['name']}',
      });
    }
    if (options == null
        ? jsTruthy(ex['machine']) || jsTruthy(steps[name])
        : adjustableLoad(ex, options)) {
      final stepKg = jsTruthy(steps[name])
          ? jsNumber(steps[name])
          : options == null
          ? 2.5
          : loadStep(ex, jsNumber(t['weight']), options);
      final next = options == null
          ? ((jsNumber(t['weight']) + stepKg) * 10 + 0.5).floor() / 10
          : jsNumber(t['weight']) + stepKg;
      final pct = jsNumber(t['weight']) > 0
          ? stepKg / jsNumber(t['weight'])
          : 0;
      final big = pct > CFG['bigStepPct']!;
      return pick('load', {
        'title':
            '$name：连续${options?.level == 'trained' ? '三' : '两'}次做满 ${_s(ex['max'])} $unit',
        'body': big
            ? '下一档 ${_s(next)} kg 涨幅约 ${(pct * 100 + 0.5).floor()}%，偏大。可以先再稳练一阵，或找更小的配重片；想试的话次数从 ${_s(ex['min'])} 次起。'
            : '动作没变形、还有余力的话，试 ${_s(next)} kg（+${stepKg == stepKg.roundToDouble()
                  ? stepKg.toInt()
                  : options == null
                  ? stepKg.toStringAsFixed(1)
                  : _s(stepKg)} kg），次数回到 ${_s(ex['min'])} $unit。',
        if (options == null || pct <= .15)
          'accept': {
            'type': 'anchor',
            'name': name,
            'date': t['lastDate'],
            'reps': ex['min'],
            'weight': next,
          },
        if (options != null && pct > .15) ...{
          'info': true,
          'body':
              '下一档 ${_s(next)} kg 涨幅约 ${(pct * 100 + 0.5).floor()}%，偏大。先找更小的配重，或改用合适的变式，当前重量先保持。',
        },
        'acceptLabel': big ? '还是试一档' : '试 ${_s(next)} kg',
        'step': jsTruthy(ex['machine']) ? stepKg : null,
      });
    }
    if (_isLoaded(ex)) {
      final max = math.min(CFG['repCapExtended']!, jsNumber(ex['max']) + 5);
      if (jsNumber(ex['max']) < CFG['repCapExtended']!) {
        return pick('cap', {
          'title':
              '$name：连续${options?.level == 'trained' ? '三' : '两'}次做满 ${_s(ex['max'])} $unit',
          'body':
              '固定重量没法再加了。余力还多的话，次数上限放到 ${_s(max)}；做满 ${_s(CFG['repCapExtended'])} 次还轻松，就该换更难的变式或可调哑铃了。',
          'accept': {
            'type': 'cap',
            'exId': ex['id'],
            'max': max,
            'date': t['lastDate'],
          },
          'acceptLabel': '上限放到 ${_s(max)}',
        });
      }
      return pick('gear', {
        'title': '$name：器材到顶了',
        'body':
            '${_s(ex['max'])} 次做满还是轻松。换更难的变式（单侧、放慢下降 3 秒、停顿），或者换可调重量的器材，别靠堆次数。',
        'info': true,
      });
    }
    return pick('variant', {
      'title':
          '$name：连续${options?.level == 'trained' ? '三' : '两'}次做满 ${_s(ex['max'])} $unit',
      'body': _unitOf(ex) == 'sec'
          ? '时间到顶了，质量比更久重要：换更难的变式，或保持时长、做得更稳。'
          : '先放慢下降（2～3 秒）、顶端停 1 秒，或换更难的变式，别靠堆次数。',
      'info': true,
    });
  }
  if ((options == null || !options.youth && options.level != 'new') &&
      (t['tooEasy'] == true || t['exceed'] == true) &&
      (options?.level != 'trained' ||
          evals.reversed
              .take(2)
              .every(
                (e) => e['rirMin'] == null || jsNumber(e['rirMin']) >= 1,
              ))) {
    final shown = _min(
      evals
          .skip(math.max(0, evals.length - 2))
          .map((e) => jsNumber(e['minReps'])),
    );
    final to = math.min(
      jsNumber(ex['max']),
      t['exceed'] == true ? shown : shown + 2 * _stepOf(ex),
    );
    if (to > jsNumber(t['reps'])) {
      return pick('jump', {
        'title': '$name：连续两次很轻松',
        'body':
            '最近两次都稳稳做到了 ${_s(shown)} $unit，目标可以直接提到 ${_s(to)} $unit，不用一次次慢慢加。',
        'accept': {
          'type': 'anchor',
          'name': name,
          'date': t['lastDate'],
          'reps': to,
          if (jsTruthy(t['weight'])) 'weight': t['weight'],
        },
        'acceptLabel': '目标提到 ${_s(to)} $unit',
      });
    }
  }
  final week = jsTruthy(plan['startDate'])
      ? (daysApart(plan['startDate'] as String, today) / 7).floor() + 1
      : 1;
  final mv = musclesOf(name, ex['part'] as String?);
  if (options?.youth != true &&
      options?.stage != 'cut' &&
      mv != null &&
      review != null &&
      jsNumber(t['stuck']) >= CFG['plateauExposures']! &&
      _sets(ex) < CFG['maxAutoSets']! &&
      week >= CFG['minWeeksForSetUp']!) {
    final group = mv['group'] as String,
        g = jsonMap(jsonMap(review['groups'])[mv['group']]),
        band = BUDGET[mv['group']]!;
    final avg = (_n(g['week']) + _n(g['last'])) / 2;
    final at = jsonMap(progress?['setUps'])[group];
    final gap = jsTruthy(at) ? daysApart(at as String, today) : 1000000000;
    if (jsNumber(jsonMap(review['adherence'])['rate']) >=
            CFG['adherenceMin']! &&
        !jsTruthy(review['redFlag']) &&
        avg < band['hi']! &&
        _n(g['week']) < band['cap']! &&
        gap >= CFG['setUpGapDays']!) {
      final groupName = GROUPS.firstWhere((g) => g['id'] == group)['name'];
      return pick('sets', {
        'title': '$name：连续 ${_s(t['stuck'])} 次卡在 ${_s(t['reps'])} $unit',
        'body':
            '出勤和恢复都正常，$groupName每周只有约 ${(avg + 0.5).floor()} 组。可以给这个动作加 1 组（${_s(ex['sets'])} → ${_s(jsNumber(ex['sets']) + 1)}），观察两周再说。',
        'accept': {
          'type': 'sets',
          'exId': ex['id'],
          'group': group,
          'date': t['lastDate'],
        },
        'acceptLabel': '加 1 组',
      });
    }
  }
  if (options != null && jsNumber(t['stuck']) >= 2) {
    return pick('variant', {
      'title': options.stage == 'cut' ? '减脂期保住力量就是成功' : '$name：先保持，练稳动作',
      'body': '目标先保持，留意睡眠和恢复，或尝试更适合的动作变式。',
      'info': true,
    });
  }
  return null;
}

Map<String, dynamic> applyAccept(
  Map<String, dynamic> plan,
  Map<String, dynamic>? progress,
  Map<String, dynamic> acc,
  String today,
) {
  final p = cloneJson(progress ?? emptyProgress()), next = cloneJson(plan);
  if (acc['type'] == 'deload') {
    p['deload'] = {'week': mondayOf(today), 'last': today};
    p['deloadWeeks'] = {
      ...(p['deloadWeeks'] as List? ?? const []),
      mondayOf(today),
    }.toList();
  } else if (acc['type'] == 'anchor') {
    p['anchors'][acc['name']] = {
      'date': jsTruthy(acc['date']) ? acc['date'] : today,
      'reps': acc['reps'],
      if (jsTruthy(acc['weight'])) 'weight': acc['weight'],
      'cal': true,
    };
  } else if (acc['type'] == 'ladder') {
    final ladder = next['ladders'][acc['ladderId']];
    ladder['stage'] = jsNumber(acc['stage'])
        .clamp(0, (ladder['steps'] as List).length - 1);
  } else if (acc['type'] == 'cap' || acc['type'] == 'sets') {
    for (final w in jsonMap(next['workouts']).values) {
      // Keep references into the cloned plan when mutating nested exercises.
      for (final e in [
        ...(w['exercises'] as List),
        ...(jsonMap(w['gym'])['exercises'] as List? ?? []),
      ]) {
        if (e['id'] != acc['exId']) continue;
        if (acc['type'] == 'cap') {
          e['max'] = math.max(jsNumber(e['max']), jsNumber(acc['max']));
        } else {
          e['sets'] = math.min(CFG['maxAutoSets']!, _sets(jsonMap(e)) + 1);
        }
      }
    }
    if (acc['type'] == 'sets') p['setUps'][acc['group']] = today;
  }
  return {'plan': next, 'progress': p};
}

Map<String, dynamic> decline(
  Map<String, dynamic>? progress,
  String key,
  String today,
) => cloneJson(progress ?? emptyProgress())..['declined'][key] = today;
bool isPersonalBest(
  Map<String, dynamic>? days,
  String name,
  Object? reps, [
  Object? weight = 0,
]) {
  num metric(Object? w, Object? r) =>
      jsNumber(w) > 0 ? jsNumber(w) * (1 + jsNumber(r) / 30) : jsNumber(r);
  num best = 0;
  var seen = false;
  for (final day in (days ?? {}).values) {
    for (final s in formalSets(jsonMap(day), name)) {
      seen = true;
      best = math.max(best, metric(s['w'], s['reps']));
    }
  }
  return seen && metric(weight, reps) > best + 1e-9;
}

Map<String, dynamic> weeklyReview(
  Map<String, dynamic> plan,
  Map<String, dynamic>? days,
  Map<String, dynamic>? dayStates,
  String today,
) {
  final a = adherence(plan, days, dayStates, today),
      groups = weeklyGroups(days, today);
  final low = groups.values
      .map(jsonMap)
      .where(
        (g) =>
            jsNumber(g['band']['lo']) > 0 &&
            jsNumber(g['week']) + jsNumber(g['last']) <
                jsNumber(g['band']['lo']) &&
            days != null &&
            days.isNotEmpty,
      )
      .toList();
  // Explicit stable sort: tied groups retain the Web GROUPS order.
  final ordered = low.indexed.toList()
    ..sort((x, y) {
      final c = (jsNumber(x.$2['week']) + jsNumber(x.$2['last'])).compareTo(
        jsNumber(y.$2['week']) + jsNumber(y.$2['last']),
      );
      return c == 0 ? x.$1.compareTo(y.$1) : c;
    });
  return {
    'adherence': a,
    'groups': groups,
    'redFlag': recentRedFlag(days, dayStates, today),
    'low': ordered.map((e) => e.$2).toList(),
  };
}
