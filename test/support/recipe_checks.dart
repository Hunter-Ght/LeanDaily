/// 按配方生成的方案的检查（不依赖 flutter_test，开发时也能直接用 dart 跑）。
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:leandaily/domain/movements.dart' show musclesOf;
import 'package:leandaily/domain/plan.dart' as plans;
import 'package:leandaily/domain/plan_recipe.dart';

const recipeVenues = ['bodyweight', 'dumbbell', 'gym', 'both'];
const recipeLevels = ['new', 'some', 'trained'];

/// 动作库之外，模板自带的三个动作。
const recipeTemplateOwn = {'硬拉', '引体向上', '反向划船'};

Map<String, dynamic> makeRecipe({
  required int days,
  required int minutes,
  required String focus,
  required String venue,
  required String experience,
  String? split,
  List<String> limits = const [],
  String? stage,
  String sex = 'male',
}) => {
  'days': days,
  'minutes': minutes,
  'focus': focus,
  'venue': venue,
  'experience': experience,
  'split': ?split,
  'limits': limits,
  'stage': stage,
  'sex': sex,
};

/// 配置的简短标签，失败信息里用。
String recipeLabel(Map<String, dynamic> r) =>
    '${r['days']}天/${r['minutes']}分/${r['focus']}/${r['venue']}/'
    '${r['experience']}/${r['split']}'
    '${(r['limits'] as List).isEmpty ? '' : '/限制${(r['limits'] as List).join()}'}'
    '${r['stage'] == null ? '' : '/${r['stage']}'}';

List<Map<String, dynamic>> _exercises(Map plan, String id, String venue) {
  final w = plan['workouts'][id] as Map;
  final list = venue == 'gym' ? (w['gym'] as Map)['exercises'] : w['exercises'];
  return [for (final e in list as List) Map<String, dynamic>.from(e as Map)];
}

/// 一个训练日的估算时长（和今日页同口径：含热身，取整到 5 分钟）。
int _estimate(Map plan, List<Map<String, dynamic>> list, String venue) =>
    plans.estimateMinutes(Map<String, dynamic>.from(plan), [
      for (final e in list) {...e, 'target': e['sets']},
    ], (plan[venue == 'gym' ? 'gymWarmup' : 'warmup']['minutes'] as num));

/// 每周每个部位的组数，口径同 weeklyVolume。
Map<String, double> _volume(Map plan, String venue) => {
  for (final e in weeklyVolume(Map<String, dynamic>.from(plan), venue: venue))
    e['group'] as String: (e['sets'] as num).toDouble(),
};

/// 部位 → 它在哪几个训练日出现过（有动作对该部位的参与度 >= 0.6）。
Map<String, int> _frequency(Map plan, String venue) {
  const muscles = {
    'shoulders': ['delt_side', 'delt_rear', 'delt_front'],
    'chest': ['chest', 'chest_up'],
    'back': ['lats', 'mid_back'],
    'abs': ['abs', 'obliques'],
    'glutes': ['glutes'],
    'quads': ['quads'],
  };
  final out = {for (final g in muscles.keys) g: 0};
  for (final id in plan['order'] as List) {
    final seen = <String>{};
    for (final e in _exercises(plan, '$id', venue)) {
      final m = musclesOf(e['name'], e['part'] as String?)?['muscles'] as Map;
      for (final g in muscles.entries) {
        if (g.value.any((x) => ((m[x] as num?) ?? 0) >= 0.6)) seen.add(g.key);
      }
    }
    for (final g in seen) {
      out[g] = out[g]! + 1;
    }
  }
  return out;
}

const _banned = <String, List<String>>{
  '膝': ['深蹲', '分腿蹲', '高脚杯深蹲', '腿举机', '腿屈伸机'],
  '腰': ['硬拉', '罗马尼亚硬拉', '弯腰双臂哑铃划船', '背部伸展', '超人式', '俄罗斯转体'],
  '肩': ['肩推', '上斜哑铃卧推', '上斜推胸机', '椅子臂屈伸', '脚抬高俯卧撑', '引体向上'],
  '腕': ['俯卧撑', '平板支撑', '侧平板支撑', '椅子臂屈伸'],
};

bool _isBanned(String limit, String name) =>
    _banned[limit]!.any((b) => name.contains(b));

/// 这个配方允许出现的例外（部位 → 门槛放宽到多少）。每条都在汇报里说明。
Map<String, double> recipeWaivers(Map<String, dynamic> r, String venue) {
  final limits = r['limits'] as List;
  final days = r['days'] as int;
  final minutes = r['minutes'] as int;
  final focus = focusGroups[r['focus']]!;
  final ppl3 = r['split'] == 'ppl' && days == 3;
  final out = <String, double>{};
  void set(String g, double need) {
    out[g] = math.min(out[g] ?? double.infinity, need);
  }

  for (final g in recipeGroups) {
    final isFocus = focus.contains(g);
    final small = g == 'arms' || g == 'hamstrings';
    // 每周 2 天、每次 20 分钟，一周只练 40 分钟：重点 3 组，其余 2 组，手臂和腘绳肌 1 组。
    if (days == 2 && minutes == 20) set(g, isFocus ? 3 : (small ? 1 : 2));
    // 每次 20 分钟、每周 3 天以上：重点部位放宽到 3 组。
    if (days >= 3 && minutes == 20 && isFocus) set(g, 3);
    // 推拉腿三天：胸、背、腿各只有一天，重点部位放宽到 4 组。
    if (ppl3 && minutes >= 35 && isFocus) set(g, 4);
  }
  // 居家无器械：腘绳肌只有臀桥类动作能练到（每组只算 0.4～0.5 组），重点放宽到 4 组；
  // 同一份方案的健身房版为了和居家版保持同样的结构，也略有损失（7.5 组）。
  if (r['venue'] == 'bodyweight' && focus.contains('hamstrings')) {
    set(
      'hamstrings',
      days == 2 && minutes == 20 ? 2 : (venue == 'home' ? 4 : 6),
    );
  }
  // 腰不方便：不安排硬拉类，腘绳肌只剩臀桥和腿弯举（健身房）。
  if (limits.contains('腰')) {
    set('hamstrings', focus.contains('hamstrings') ? (days == 2 ? 2.5 : 5) : 2);
  }
  // 膝和腰都不方便：腘绳肌只剩臀桥（和健身房的腿弯举），重点也只能到 2.5 组。
  if (limits.contains('膝') &&
      limits.contains('腰') &&
      focus.contains('hamstrings')) {
    set('hamstrings', 2.5);
  }
  // 膝盖不方便又居家无器械：腘绳肌只剩臀桥类。
  if (limits.contains('膝') && r['venue'] == 'bodyweight') {
    set('hamstrings', focus.contains('hamstrings') ? 2.5 : 2);
  }
  // 手腕不方便：推胸只剩哑铃和器械；肩不方便又居家无器械：没有椅子臂屈伸，胸只剩俯卧撑。
  if (limits.contains('腕') ||
      (limits.contains('肩') && r['venue'] == 'bodyweight')) {
    set('chest', 3);
  }
  // 居家无器械：肩或腕不方便时没有练手臂的动作，手臂只剩划船的间接组数。
  if (r['venue'] == 'bodyweight' &&
      (limits.contains('肩') || limits.contains('腕'))) {
    set('arms', 1.5);
  }
  // 膝盖不方便：不安排深蹲类，股四头不设门槛。
  if (limits.contains('膝')) out['quads'] = 0;
  // 居家无器械又手腕不方便：没有合适的推胸动作。
  if (limits.contains('腕') && r['venue'] == 'bodyweight') out['chest'] = 0;
  return out;
}

/// 估算时长的下限：每周 5 天、每次 50 分钟时各部位已接近每周 16 组的上限，动作位放不满。
int recipeFloor(Map<String, dynamic> r) {
  // 减脂路线（辅助动作固定 2 组）又限制了动作位：下限再降 10 分钟。
  if (r['stage'] == 'cut' && (r['limits'] as List).isNotEmpty) {
    return math.max(15, _baseFloor(r) - 10);
  }
  return _baseFloor(r);
}

int _baseFloor(Map<String, dynamic> r) {
  final minutes = r['minutes'] as int;
  if (r['days'] == 5 && minutes == 50) {
    return r['venue'] == 'bodyweight' && (r['limits'] as List).isNotEmpty
        ? 15
        : 25;
  }
  // 居家无器械又限制很多（肩、腕）：推、核心的动作位几乎没有，一天放不满。
  if (r['venue'] == 'bodyweight' &&
      minutes == 50 &&
      ((r['limits'] as List).contains('腕') ||
          (r['limits'] as List).contains('肩'))) {
    return 25;
  }
  return minutes == 20 ? 15 : minutes - 10;
}

/// 每周至少出现两个训练日的要求是否适用。
bool recipeNeedsFrequency(Map<String, dynamic> r) {
  final minutes = r['minutes'] as int;
  if (minutes == 20) return false; // 一天只有 3～4 个动作，放不下。
  if (r['split'] == 'ppl' && r['days'] == 3) return false; // 推拉腿各一天。
  if (r['days'] == 2 && (r['limits'] as List).isNotEmpty) {
    return false; // 动作位被限制去掉后，两天放不下。
  }
  if (r['days'] == 5 && minutes == 50 && r['venue'] == 'bodyweight') {
    return false;
  }
  return true;
}

/// 一份方案的全部检查，返回失败说明（空表示通过）。
List<String> recipeProblems(Map<String, dynamic> plan) {
  final bad = <String>[];
  final r = Map<String, dynamic>.from(plan['recipe'] as Map);
  final limits = (r['limits'] as List).cast<String>();
  final days = r['days'] as int;
  final minutes = r['minutes'] as int;
  final high = days >= 3 && minutes >= 35;
  final focus = focusGroups[r['focus']]!;
  for (final venue in ['home', 'gym']) {
    final waived = recipeWaivers(r, venue);
    // 时长。
    for (final id in plan['order'] as List) {
      final list = _exercises(plan, '$id', venue);
      final est = _estimate(plan, list, venue);
      final low = recipeFloor(r);
      if (est > minutes + 5 || est < low) {
        bad.add('$venue $id 估算$est分钟，不在 $low～${minutes + 5}');
      }
      final names = list.map((e) => e['name']).toList();
      if (names.toSet().length != names.length) {
        bad.add('$venue $id 有重复动作 $names');
      }
      for (final l in limits) {
        for (final e in list) {
          if (_isBanned(l, e['name'] as String)) {
            bad.add('$venue $id 出现被限制的动作 ${e['name']}（$l）');
          }
          for (final a in e['alts'] as List) {
            if (_isBanned(l, (a as Map)['name'] as String)) {
              bad.add('$venue $id 备选里有被限制的动作 ${a['name']}（$l）');
            }
          }
        }
      }
    }
    // 组数门槛与上限。
    final vol = _volume(plan, venue);
    for (final g in recipeGroups) {
      final need =
          waived[g] ??
          (focus.contains(g)
              ? (high ? 8.0 : 5.0)
              : (g == 'arms' || g == 'hamstrings')
              ? (high ? 3.0 : 2.0)
              : (high ? 4.0 : 3.0));
      // 减脂路线（辅助动作固定 2 组）又限制了动作位：每个部位门槛再降 2 组。
      final cutLimited =
          r['stage'] == 'cut' && (r['limits'] as List).isNotEmpty;
      final bar = cutLimited ? math.max(0.0, need - 2) : need;
      if (vol[g]! < bar - 1e-9) {
        bad.add('$venue $g 每周 ${vol[g]!.toStringAsFixed(1)} 组，不足 $bar');
      }
      if (vol[g]! > 16 + 1e-9) bad.add('$venue $g 每周 ${vol[g]} 组，超过 16');
    }
    // 频率。
    if (recipeNeedsFrequency(r)) {
      final freq = _frequency(plan, venue);
      for (final e in freq.entries) {
        if (waived[e.key] == 0) continue;
        if (e.value < 2) bad.add('$venue ${e.key} 只在 ${e.value} 个训练日出现');
      }
    }
  }
  bad.addAll(recipeStructure(plan));
  bad.addAll(recipeStructure(plan));
  return bad;
}

/// 数据形状和处方：训练日、动作 ID、组数、次数、休息、阶梯、有氧、说明。
List<String> recipeStructure(Map<String, dynamic> plan) {
  final bad = <String>[];
  final r = Map<String, dynamic>.from(plan['recipe'] as Map);
  final minutes = r['minutes'] as int;
  final cut = r['stage'] == 'cut';
  final order = (plan['order'] as List).cast<String>();
  if (order.length != r['days']) {
    bad.add('训练日数 ${order.length} 不等于 ${r['days']}');
  }
  for (final (i, id) in order.indexed) {
    if (id != 'r${i + 1}') bad.add('训练日 ID $id 不是 r${i + 1}');
    final w = plan['workouts'][id] as Map;
    if ((w['short'] as String).runes.length != 1) bad.add('$id short 不是一个字');
    for (final k in ['name', 'tag', 'note']) {
      if ((w[k] as String).isEmpty) bad.add('$id 缺少 $k');
    }
    if ((w['gym'] as Map)['note'] == '' || (w['gym'] as Map)['tag'] == '') {
      bad.add('$id 健身房版缺少说明');
    }
    for (final venue in ['home', 'gym']) {
      for (final (j, e) in _exercises(plan, id, venue).indexed) {
        final tag = '$id $venue ${e['name']}';
        if (e['id'] != '${id}_${venue}_${j + 1}') bad.add('$tag ID ${e['id']}');
        if (e['optional'] != false) bad.add('$tag optional 不是 false');
        final sets = e['sets'] as int;
        final core = e['core'] == true;
        if (core && sets != 3) bad.add('$tag 主项 $sets 组');
        if (!core && (sets < 2 || sets > 4)) bad.add('$tag 辅助 $sets 组');
        if (!core && cut && sets != 2) bad.add('$tag 减脂路线辅助 $sets 组');
        final rest = core ? (minutes == 20 ? 90 : 120) : 60;
        if (e['rest'] != rest) bad.add('$tag 休息 ${e['rest']}，应为 $rest');
        final lo = e['min'] as int;
        final hi = e['max'] as int;
        final ladder = e['ladder'];
        if (ladder != null) {
          final l = plan['ladders'][ladder] as Map?;
          if (l == null) {
            bad.add('$tag 阶梯 $ladder 不在方案里');
          } else {
            final step = (l['steps'] as List)[l['stage'] as int] as Map;
            if (step['min'] != lo || step['max'] != hi) {
              bad.add('$tag 次数 $lo～$hi 和阶梯不一致');
            }
          }
          if (venue == 'gym') bad.add('$tag 健身房版不该带阶梯');
        } else if (e['unit'] == 'sec') {
          if (lo != 20 || hi != 40) bad.add('$tag 计时 $lo～$hi 秒');
        } else if (core) {
          if (!((lo == 6 && hi == 10) || (lo == 8 && hi == 12))) {
            bad.add('$tag 主项 $lo～$hi 次');
          }
        } else if (lo != 10 || hi != 15) {
          bad.add('$tag 辅助 $lo～$hi 次');
        }
        for (final key in ['gear', 'tip', 'part', 'unit']) {
          if (e[key] is! String || (e[key] as String).isEmpty) {
            bad.add('$tag 缺少 $key');
          }
        }
      }
    }
  }
  final weekdays = (r['weekdays'] as List).cast<int>();
  final schedule = Map<String, dynamic>.from(plan['schedule'] as Map);
  if (schedule.length != weekdays.length ||
      [for (final d in weekdays) schedule['$d']].join(',') != order.join(',')) {
    bad.add('schedule $schedule 与 weekdays $weekdays、order $order 不一致');
  }
  final venues = Map<String, dynamic>.from(plan['venues'] as Map);
  if (r['venue'] == 'gym') {
    if (venues.length != weekdays.length ||
        venues.values.any((v) => v != 'gym')) {
      bad.add('gym 场地没有把训练日设为 gym');
    }
  } else if (venues.isNotEmpty) {
    bad.add('非 gym 场地不该设 venues');
  }
  final used = {
    for (final id in order)
      for (final e in _exercises(plan, id, 'home'))
        if (e['ladder'] != null) e['ladder'],
  };
  if (Set.of((plan['ladders'] as Map).keys).difference(used).isNotEmpty) {
    bad.add('方案里有没用到的阶梯');
  }
  final cardio = plan['cardio'];
  final expected = switch (r['stage']) {
    'cut' => {'perWeek': 2, 'minutes': 20},
    'recomp' => {'perWeek': 1, 'minutes': 20},
    _ => null,
  };
  if (expected == null
      ? plan.containsKey('cardio')
      : cardio.toString() != expected.toString()) {
    bad.add('有氧设置 $cardio 与路线 ${r['stage']} 不符');
  }
  final notes = plan['recipeNotes'];
  final limits = r['limits'] as List;
  if (notes is! List || (limits.isEmpty) != notes.isEmpty) {
    bad.add('recipeNotes $notes 与限制 $limits 不符');
  } else if (notes.any((n) => n is! String || !n.endsWith('。'))) {
    bad.add('recipeNotes 不是完整句子');
  }
  // 方案已经规范，再规范一次不变。
  final copy = jsonDecode(jsonEncode(plan));
  if (jsonEncode(plans.normalizePlan(copy, plan['startDate'] as String)) !=
      jsonEncode(plan)) {
    bad.add('不是 normalizePlan 的不动点');
  }
  return bad;
}

/// 方案里出现的所有动作名（居家版、健身房版、阶梯里的每一级）。
Set<String> recipeNames(Map<String, dynamic> plan) => {
  for (final id in plan['order'] as List)
    for (final venue in ['home', 'gym'])
      for (final e in _exercises(plan, '$id', venue)) e['name'] as String,
};
