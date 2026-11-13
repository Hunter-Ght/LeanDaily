/// 按「配方」生成训练方案：用户回答每周几天、每次多久、想重点练哪，
/// 加上资料里的场地、经验、体脂路线和不方便的部位，得到一份完整的方案。
///
/// 纯函数，不读存储，不读当前时间。生成的方案和模板方案是同一种 JSON
/// （见 plan.dart 的 normalizePlan），额外带 `plan['recipe']`，之后可以按
/// 新的配方重新生成。
library;

import 'dart:math' as math;

import 'format.dart' show cloneJson;
import 'ladders.dart';
import 'movements.dart' show musclesOf;
import 'plan.dart' as plans;
import 'templates.dart' show ladderStartingAt, templateExercise;

/// 每次训练的时长档位（分钟）。
const recipeMinutes = [20, 35, 50];

/// 重点方向。`balanced` 是均衡，其余每周给对应部位多排几组。
const recipeFocuses = [
  'balanced',
  'shoulders_back',
  'chest_shoulders',
  'glutes_legs',
  'core',
  'posture',
];

/// 排法：`full` 每次练全身；`ul` 上下肢分开；`ppl` 推、拉、腿分开。
const recipeSplits = ['full', 'ul', 'ppl'];

/// 界面上展示的 8 个部位，顺序即展示顺序。
const recipeGroups = [
  'shoulders',
  'chest',
  'back',
  'abs',
  'arms',
  'glutes',
  'quads',
  'hamstrings',
];

const _groupMuscles = <String, List<String>>{
  'shoulders': ['delt_side', 'delt_rear', 'delt_front'],
  'chest': ['chest', 'chest_up'],
  'back': ['lats', 'mid_back'],
  'abs': ['abs', 'obliques'],
  'arms': ['biceps', 'triceps'],
  'glutes': ['glutes'],
  'quads': ['quads'],
  'hamstrings': ['hamstrings'],
};

/// 每个重点方向多练的部位。
const focusGroups = <String, List<String>>{
  'balanced': [],
  'shoulders_back': ['shoulders', 'back'],
  'chest_shoulders': ['chest', 'shoulders'],
  'glutes_legs': ['glutes', 'quads', 'hamstrings'],
  'core': ['abs'],
  'posture': ['back', 'shoulders'],
};

/// 每周 [days] 天时默认排在星期几（0 是周日，1 是周一，与 plan.schedule 一致）。
List<int> defaultWeekdays(int days) => switch (days) {
  2 => [1, 4],
  4 => [1, 2, 4, 5],
  5 => [1, 2, 3, 5, 6],
  _ => [1, 3, 5],
};

/// 这个天数下的默认排法：2、3 天全身；4、5 天上下肢。
String defaultSplit(int days, String experience) => switch (days) {
  4 || 5 => 'ul',
  _ => 'full',
};

/// 这个天数下可以选的排法，第一个是默认。
List<String> splitsFor(int days, String experience) => switch (days) {
  2 => ['full'],
  3 => ['full', 'ppl'],
  4 => ['ul', 'full'],
  _ => ['ul', 'ppl'],
};

/// 把任意输入收拢成合法配方：缺的字段补默认值，越界的值拉回范围内。
Map<String, dynamic> normalizeRecipe(Map<String, dynamic> raw) {
  final days = raw['days'] is num
      ? (raw['days'] as num).toInt().clamp(2, 5)
      : 3;
  final experience =
      const ['new', 'some', 'trained'].contains(raw['experience'])
      ? raw['experience'] as String
      : 'new';
  final minutes = recipeMinutes.contains(raw['minutes'])
      ? raw['minutes'] as int
      : 35;
  final focus = recipeFocuses.contains(raw['focus'])
      ? raw['focus'] as String
      : 'balanced';
  final venue =
      const ['bodyweight', 'dumbbell', 'gym', 'both'].contains(raw['venue'])
      ? raw['venue'] as String
      : 'bodyweight';
  final splits = splitsFor(days, experience);
  final split = splits.contains(raw['split'])
      ? raw['split'] as String
      : splits.first;
  final picked = <int>{
    for (final d
        in raw['weekdays'] is List ? raw['weekdays'] as List : const [])
      if (d is num && d >= 0 && d <= 6) d.toInt(),
  };
  final weekdays = picked.length == days
      ? (picked.toList()..sort(_mondayFirst))
      : defaultWeekdays(days);
  return {
    'v': 1,
    'days': days,
    'minutes': minutes,
    'focus': focus,
    'split': split,
    'weekdays': weekdays,
    'venue': venue,
    'experience': experience,
    'sex': raw['sex'] == 'female' ? 'female' : 'male',
    'stage': raw['stage'] is String ? raw['stage'] : null,
    'limits': [
      for (final l in raw['limits'] is List ? raw['limits'] as List : const [])
        if (const ['膝', '腰', '肩', '腕'].contains(l)) l,
    ],
  };
}

int _mondayFirst(int a, int b) => ((a + 6) % 7).compareTo((b + 6) % 7);

/// 按资料给出默认配方：天数、场地、经验、性别、路线、不方便的部位都取自资料，
/// 时长默认 35 分钟，重点默认均衡。
Map<String, dynamic> defaultRecipe(
  Map<String, dynamic> profile, [
  Map<String, dynamic> targets = const {},
]) => normalizeRecipe({
  'days': profile['daysPerWeek'],
  'venue': profile['venue'],
  'experience': profile['experience'],
  'sex': profile['sex'],
  'limits': profile['limits'],
  'stage': targets['stage'],
});

/// 依次试几组贪心参数，取硬指标缺口最小的那份；缺口为 0 就不再试。
_Generator _generate(Map<String, dynamic> r) {
  _Generator? best;
  var bestGap = double.infinity;
  for (final v in _variants) {
    final gen = _Generator(r, v)..run();
    final gap = gen.shortfall();
    if (gap < bestGap) {
      best = gen;
      bestGap = gap;
    }
    if (gap == 0) break;
  }
  return best!;
}

/// 按配方生成完整方案。返回值已经过 normalizePlan，并带 `recipe` 字段。
///
/// 生成规则（纯函数，同样的配方永远得到同样的方案）：
/// 1. 按排法定出每个训练日的类型（全身、上肢、下肢、推、拉、腿）；
/// 2. 每天由「动作位」组成（水平推、垂直推、水平拉、垂直拉、蹲、髋主导、
///    侧平举、后束、核心、手臂……），按场地给每个动作位挑动作；
/// 3. 用贪心法逐个添加动作位：先补每周最缺的部位，再补重点方向，直到这一天的
///    估算时长用满所选时长，居家版和健身房版同时满足；
/// 4. 不方便的部位直接把对应动作从候选里去掉，把说明写进 `recipeNotes`。
Map<String, dynamic> buildRecipePlan(
  Map<String, dynamic> recipe, {
  String startDate = '',
}) {
  final r = normalizeRecipe(recipe);
  final gen = _generate(r);
  final plan = plans.defaultPlan(startDate);
  final workouts = <String, dynamic>{};
  final usedLadders = <String>{};
  for (final (i, day) in gen.days.indexed) {
    final id = 'r${i + 1}';
    List<Map<String, dynamic>> list(int tier) {
      final venue = tier == 0 ? 'home' : 'gym';
      final here = day.items.where((i) => i.picks[tier] != null);
      return [
        for (final (j, it) in here.indexed)
          gen.exerciseJson(
            '${id}_${venue}_${j + 1}',
            it,
            it.picks[tier]!,
            tier,
            usedLadders,
          ),
      ];
    }

    workouts[id] = <String, dynamic>{
      'name': day.def.name,
      'short': day.def.short,
      'tag': day.def.tag,
      'note': '先做前面的主项，时间不够就跳过最后一个辅助动作；每组留 2～3 次余力。',
      'exercises': list(0),
      'gym': <String, dynamic>{
        'tag': day.def.tag,
        'note': '同一天居家和健身房二选一，不要叠加。',
        'exercises': list(1),
      },
    };
  }
  final order = workouts.keys.toList();
  final weekdays = (r['weekdays'] as List).cast<int>();
  plan['workouts'] = workouts;
  plan['order'] = order;
  plan['schedule'] = {
    for (final (i, d) in weekdays.indexed)
      if (i < order.length) '$d': order[i],
  };
  plan['venues'] = {
    if (r['venue'] == 'gym')
      for (final d in weekdays) '$d': 'gym',
  };
  final pushup = Map<String, dynamic>.from(
    plans.defaultPlan()['ladders']['pushup'] as Map,
  );
  plan['ladders'] = <String, dynamic>{
    for (final id in usedLadders)
      id: id == 'pushup' ? cloneJson(pushup) : buildLadder(id),
  };
  plan['protein'] = <String, dynamic>{
    'goal': 130,
    'powder': <String, dynamic>{
      'name': '蛋白粉',
      'grams': 30,
      'protein': 22.6,
      'kcal': 124,
    },
  };
  plan['recipeNotes'] = gen.notes();
  switch (r['stage']) {
    case 'cut':
      plan['cardio'] = <String, dynamic>{'perWeek': 2, 'minutes': 20};
    case 'recomp':
      plan['cardio'] = <String, dynamic>{'perWeek': 1, 'minutes': 20};
  }
  plan['recipe'] = r;
  return plans.normalizePlan(plan, startDate);
}

// ---------------------------------------------------------------------------
// 动作位和候选动作
// ---------------------------------------------------------------------------

/// 主项（核心动作）的动作位；其余是辅助动作。
const _mainSlots = {'hpush', 'vpush', 'hpull', 'vpull', 'squat', 'hinge'};

/// 一天里动作的排列顺序：先主项，后辅助，核心放最后。
const _slotOrder = [
  'hpush',
  'vpush',
  'hpull',
  'vpull',
  'squat',
  'hinge',
  'hpush2',
  'squat2',
  'fly',
  'glute',
  'ham',
  'quad_iso',
  'lateral',
  'rear',
  'arms_bi',
  'arms_tri',
  'core',
  'core2',
  'calf',
];

/// 动作位属于哪一块：同一天同一块排太多会被降权，让一天里推、拉、腿都有。
const _slotRegion = {
  'hpush': 'push',
  'vpush': 'push',
  'fly': 'push',
  'hpush2': 'push',
  'squat2': 'lower',
  'arms_tri': 'push',
  'hpull': 'pull',
  'vpull': 'pull',
  'rear': 'pull',
  'arms_bi': 'pull',
  'squat': 'lower',
  'hinge': 'lower',
  'glute': 'lower',
  'ham': 'lower',
  'quad_iso': 'lower',
  'calf': 'lower',
  'lateral': 'delt',
  'core': 'core',
  'core2': 'core',
};

/// 各类训练日允许放的动作位。
const _daySlots = <String, List<String>>{
  'full': _slotOrder,
  'upper': [
    'hpush',
    'vpush',
    'hpull',
    'vpull',
    'hpush2',
    'fly',
    'lateral',
    'rear',
    'arms_bi',
    'arms_tri',
    'core',
  ],
  'lower': [
    'squat',
    'hinge',
    'squat2',
    'glute',
    'ham',
    'quad_iso',
    'calf',
    'core',
    'core2',
  ],
  'push': [
    'hpush',
    'vpush',
    'hpush2',
    'fly',
    'lateral',
    'rear',
    'arms_tri',
    'core',
    'core2',
  ],
  'pull': ['hpull', 'vpull', 'rear', 'lateral', 'arms_bi', 'core', 'core2'],
  'legs': [
    'squat',
    'hinge',
    'squat2',
    'glute',
    'ham',
    'quad_iso',
    'calf',
    'lateral',
    'rear',
    'core',
    'core2',
  ],
};

/// 各类训练日必须覆盖的区域（用主项覆盖）。
const _dayRegions = <String, List<String>>{
  'full': ['push', 'pull', 'lower'],
  'upper': ['push', 'pull'],
  'lower': ['lower'],
  'push': ['push'],
  'pull': ['pull'],
  'legs': ['lower'],
};

const _coreList = ['反向卷腹', '死虫式', '卷腹', '平板支撑', '侧平板支撑', '俄罗斯转体'];

/// 居家无器械。
const _bwSlots = <String, List<String>>{
  'hpush': ['高位俯卧撑'],
  'hpull': ['反向划船'],
  'squat': ['深蹲', '分腿蹲'],
  'squat2': ['分腿蹲', '深蹲'],
  'hinge': ['臀桥', '单腿臀桥'],
  'glute': ['单腿臀桥', '臀桥'],
  'ham': ['单腿臀桥', '臀桥'],
  'lateral': ['轻重量侧平举'],
  'rear': ['俯身哑铃反向飞鸟'],
  'arms_tri': ['椅子臂屈伸'],
  'core': _coreList,
  'calf': ['站姿提踵'],
};

/// 居家哑铃。
const _dbSlots = <String, List<String>>{
  'hpush': ['哑铃地板卧推', '高位俯卧撑'],
  'hpush2': ['高位俯卧撑', '哑铃地板卧推'],
  'vpush': ['哑铃肩推'],
  'hpull': ['单臂哑铃划船', '弯腰双臂哑铃划船', '反向划船'],
  'squat': ['高脚杯深蹲', '分腿蹲', '深蹲'],
  'squat2': ['分腿蹲', '深蹲', '高脚杯深蹲'],
  'hinge': ['轻哑铃罗马尼亚硬拉'],
  'glute': ['臀桥', '单腿臀桥'],
  'ham': ['轻哑铃罗马尼亚硬拉'],
  'lateral': ['轻重量侧平举'],
  'rear': ['俯身哑铃反向飞鸟'],
  'arms_bi': ['哑铃弯举', '锤式弯举'],
  'arms_tri': ['站姿哑铃臂屈伸', '哑铃臂后屈伸', '椅子臂屈伸'],
  'core': _coreList,
  'calf': ['站姿提踵'],
};

/// 健身房。
const _gymSlots = <String, List<String>>{
  'hpush': ['上斜哑铃卧推', '哑铃平板卧推', '上斜推胸机', '坐姿推胸机'],
  'hpush2': ['坐姿推胸机', '上斜推胸机', '哑铃平板卧推', '上斜哑铃卧推'],
  'vpush': ['坐姿肩推机', '轻哑铃坐姿肩推'],
  'fly': ['蝴蝶机夹胸', '拉力器高位向下夹胸'],
  'hpull': ['坐姿划船机', '单臂哑铃划船', '弯腰双臂哑铃划船'],
  'vpull': ['高位下拉', '辅助引体向上机', '直臂下拉'],
  'squat': ['腿举机', '高脚杯深蹲', '深蹲', '分腿蹲'],
  'squat2': ['分腿蹲', '高脚杯深蹲', '深蹲', '腿举机'],
  'quad_iso': ['腿屈伸机'],
  'hinge': ['轻哑铃罗马尼亚硬拉'],
  'ham': ['坐姿腿弯举'],
  'glute': ['臀桥', '单腿臀桥'],
  'lateral': ['轻哑铃侧平举', '拉力器单臂侧平举'],
  'rear': ['绳索面拉', '反向蝴蝶机', '俯身哑铃反向飞鸟'],
  'arms_bi': ['哑铃弯举', '二头弯举机', '锤式弯举'],
  'arms_tri': ['绳索下压', '站姿哑铃臂屈伸', '哑铃臂后屈伸'],
  'core': ['绳索卷腹', '卷腹机', '死虫式', '反向卷腹', '平板支撑', '卷腹'],
  'calf': ['坐姿提踵机', '站姿提踵'],
};

/// 主选动作被限制去掉之后，髋主导位改用臀桥。
const _hingeFallback = ['臀桥', '单腿臀桥'];

const _banKnee = ['深蹲', '分腿蹲', '腿举', '腿屈伸'];
const _banWaist = ['硬拉', '弯腰双臂哑铃划船', '背部伸展', '超人式', '俄罗斯转体'];
const _banShoulder = ['肩推', '上斜', '椅子臂屈伸', '脚抬高俯卧撑', '引体向上', '站姿哑铃臂屈伸'];
const _banWrist = ['俯卧撑', '平板支撑', '椅子臂屈伸'];

/// 居家无器械时，轻重量动作用水瓶或装书的背包。
const _bottleGear = {
  '轻重量侧平举': '装满水的水瓶（500 mL～1.5 L），或装了书的小背包拎在手里（重量按 1 kg 记）',
  '俯身哑铃反向飞鸟': '装满水的水瓶，或装了书的小背包拎在手里（按 2 kg 记）',
};

/// 一天最多放几个主项（时间有限，主项每个要 3 组、休息 2 分钟）。
const _maxMains = {20: 3, 35: 2, 50: 3};

/// 一天最多放几个动作。
const _maxExercises = {20: 4, 35: 6, 50: 8};

/// 任何部位每周的组数上限。
const _weeklyCap = 16.0;

/// 要求每周至少出现在两个不同训练日的部位。
const _spreadGroups = ['shoulders', 'chest', 'back', 'abs', 'glutes', 'quads'];

const _fullNames = ['全身 A', '全身 B', '全身 C', '全身 D'];

class _DayDef {
  const _DayDef(this.name, this.short, this.tag, this.type, this.v);
  final String name;
  final String short;
  final String tag;
  final String type;

  /// 变式序号：同一类型的 A/B/C 日用不同序号，挑出不同的动作。
  final int v;
}

class _Pick {
  const _Pick(this.name, this.ladder);
  final String name;
  final String? ladder;
}

class _Item {
  _Item(this.slot, this.sets, this.rest, this.picks);
  final String slot;
  int sets;
  final int rest;

  /// 居家版和健身房版各挑什么动作；某个版本没有合适的动作就是 null。
  final List<_Pick?> picks;
  bool get main => _mainSlots.contains(slot);
}

class _Day {
  _Day(this.def);
  final _DayDef def;
  final items = <_Item>[];
  bool has(String slot) => items.any((i) => i.slot == slot);
}

class _Goal {
  _Goal(
    this.group,
    this.key,
    this.goal,
    this.weight,
    this.hard, [
    this.bumpOk = false,
  ]) : muscles = group ? _groupMuscles[key]! : [key];

  /// true：按部位（取其下最高的一块肌肉）；false：按单块肌肉。
  final bool group;
  final String key;
  final double goal;
  final double weight;
  final bool hard;

  /// 加组（同一个动作多做一组）时是否算这个目标：硬指标和重点部位才加组。
  final bool bumpOk;

  /// 这个目标由哪几块肌肉决定（取最高的一块）。
  final List<String> muscles;
}

class _Cand {
  const _Cand(this.day, this.slot, this.item, this.bump, this.score);
  final int day;
  final String slot;
  final _Item? item;
  final bool bump;
  final double score;
}

final _specCache = <String, Map<String, dynamic>>{};
Map<String, dynamic> _spec(String name) =>
    _specCache.putIfAbsent(name, () => templateExercise(name));

final _muscleCache = <String, Map<String, double>>{};
Map<String, double> _muscles(String name) => _muscleCache.putIfAbsent(name, () {
  final m = musclesOf(name, _spec(name)['part'] as String?)?['muscles'] as Map?;
  return {
    for (final e in (m ?? {}).entries) '${e.key}': (e.value as num).toDouble(),
  };
});

/// 动作主要练到哪些部位（肌肉参与度 ≥ 0.6）。
final _presenceCache = <String, Set<String>>{};
Set<String> _presence(String name) => _presenceCache.putIfAbsent(name, () {
  final m = _muscles(name);
  return {
    for (final g in _spreadGroups)
      if (_groupMuscles[g]!.any((x) => (m[x] ?? 0) >= 0.6)) g,
  };
});

/// 贪心的几组参数。先用第一组；硬指标没达到就换下一组，取缺口最小的。
class _Variant {
  const _Variant(
    this.bump,
    this.mainBoost,
    this.costExp,
    this.spread,
    this.region20,
  );

  /// 加组的折扣（加组不如加动作）。
  final double bump;

  /// 一天里还没有的区域（推、拉、腿），主项的加成。
  final double mainBoost;

  /// 按「增量 / 时间的几次方」排序：1 偏爱省时间的小动作，0 偏爱增量大的动作。
  final double costExp;

  /// 每周两天出现的加成倍数。
  final double spread;

  /// 每次 20 分钟时也按区域加成。
  final bool region20;
}

const _variants = [
  _Variant(0.5, 2.8, 1, 1, false),
  _Variant(0.5, 2.8, 0.5, 1, false),
  _Variant(1, 1, 1, 0.3, false),
  _Variant(0.5, 2.8, 0, 1, false),
  _Variant(1, 2.8, 0.5, 2, true),
  _Variant(0.25, 1, 0, 0, false),
  _Variant(0.5, 4, 0.7, 1.5, true),
];

final _warmups = (
  (plans.defaultPlan()['warmup']['minutes'] as num).toInt(),
  (plans.defaultPlan()['gymWarmup']['minutes'] as num).toInt(),
);

final _pushupSteps =
    (plans.defaultPlan()['ladders']['pushup']['steps'] as List).first as Map;

class _Generator {
  _Generator(this.r, this.v)
    : dayCount = r['days'] as int,
      minutes = r['minutes'] as int,
      focus = r['focus'] as String,
      split = r['split'] as String,
      venue = r['venue'] as String,
      exp = r['experience'] as String,
      female = r['sex'] == 'female',
      stage = r['stage'] as String?,
      limits = {for (final l in r['limits'] as List) '$l'} {
    high = dayCount >= 3 && minutes >= 35;
    cut = stage == 'cut';
    bwHome = venue == 'bodyweight';
    _homeWarm = _warmups.$1;
    _gymWarm = _warmups.$2;
    cands = [_buildCands(0), _buildCands(1)];
    defs = _buildDefs();
    days = [for (final d in defs) _Day(d)];
    pres = [
      [for (final _ in defs) <String>{}],
      [for (final _ in defs) <String>{}],
    ];
    _buildGoals();
  }

  final Map<String, dynamic> r;
  final _Variant v;
  final int dayCount;
  final int minutes;
  final String focus;
  final String split;
  final String venue;
  final String exp;
  final bool female;
  final String? stage;
  final Set<String> limits;
  late final bool high;
  late final bool cut;
  late final bool bwHome;
  late final int _homeWarm;
  late final int _gymWarm;
  late final List<Map<String, List<String>>> cands;
  late final List<_DayDef> defs;
  late final List<_Day> days;
  late final List<List<Set<String>>> pres;
  final vol = <Map<String, double>>[{}, {}];
  final goals = <_Goal>[];

  // ---- 限制与候选 ----------------------------------------------------------

  bool allowed(String name) {
    if (limits.contains('膝') && _banKnee.any(name.contains)) return false;
    if (limits.contains('腰') && _banWaist.any(name.contains)) return false;
    if (limits.contains('肩') && _banShoulder.any(name.contains)) return false;
    if (limits.contains('腕') && _banWrist.any(name.contains)) return false;
    return true;
  }

  Map<String, List<String>> _buildCands(int tier) {
    final table = tier == 1
        ? _gymSlots
        : (venue == 'bodyweight' ? _bwSlots : _dbSlots);
    final out = <String, List<String>>{};
    for (final e in table.entries) {
      final list = [...e.value];
      if (tier == 1 && e.key == 'vpull' && exp == 'trained') {
        list.insert(1, '引体向上');
      }
      if (tier == 1 && e.key == 'hinge' && exp == 'trained') list.add('硬拉');
      var ok = [
        for (final n in list)
          if (allowed(n)) n,
      ];
      if (ok.isEmpty && e.key == 'hinge') {
        ok = [
          for (final n in _hingeFallback)
            if (allowed(n)) n,
        ];
      }
      out[e.key] = ok;
    }
    out['core2'] = out['core']!;
    return out;
  }

  _Pick? _pick(String slot, int tier, int v, Set<String> used) {
    final list = cands[tier][slot] ?? const <String>[];
    if (list.isEmpty) return null;
    final start = (slot == 'core2' ? v + 3 : v) % list.length;
    for (var i = 0; i < list.length; i++) {
      final n = list[(start + i) % list.length];
      if (used.contains(n)) continue;
      // 只有居家版的自重动作带进阶阶梯（俯卧撑、深蹲、反向划船、臀桥、腹肌）。
      final ladder = tier == 1
          ? null
          : n == '高位俯卧撑'
          ? 'pushup'
          : ladderStartingAt(n);
      return _Pick(n, ladder);
    }
    return null;
  }

  // ---- 训练日骨架 ----------------------------------------------------------

  List<_DayDef> _buildDefs() {
    const full = '全身练';
    const upper = '上肢练';
    const lower = '下肢练';
    switch (split) {
      case 'ppl':
        return [
          const _DayDef('推 · 胸肩', '推', '胸和肩为主', 'push', 0),
          const _DayDef('拉 · 背与后束', '拉', '背和肩后束为主', 'pull', 0),
          const _DayDef('腿 · 臀腿与核心', '腿', '臀腿和核心为主', 'legs', 0),
          if (dayCount >= 5) ...const [
            _DayDef('上肢', '上', upper, 'upper', 1),
            _DayDef('下肢', '下', lower, 'lower', 1),
          ],
        ];
      case 'ul':
        return [
          const _DayDef('上肢 A', '上', upper, 'upper', 0),
          const _DayDef('下肢 A', '下', lower, 'lower', 0),
          const _DayDef('上肢 B', '上', upper, 'upper', 1),
          const _DayDef('下肢 B', '下', lower, 'lower', 1),
          if (dayCount >= 5) const _DayDef('全身 · 补强', '全', '补强日', 'full', 2),
        ];
      default:
        return [
          for (var i = 0; i < dayCount; i++)
            _DayDef(_fullNames[i], '全', full, 'full', i),
        ];
    }
  }

  // ---- 目标 ---------------------------------------------------------------

  late final Map<String, int> hardGoals = _hardGoals();

  Map<String, int> _hardGoals() {
    final focusSet = focusGroups[focus]!;
    final out = <String, int>{};
    for (final g in recipeGroups) {
      out[g] = focusSet.contains(g)
          ? (high ? 8 : 5)
          : (g == 'arms' || g == 'hamstrings')
          ? (high ? 3 : 2)
          : (high ? 4 : 3);
    }
    if (limits.contains('膝')) out['quads'] = 0;
    if (limits.contains('腕') && venue == 'bodyweight') out['chest'] = 0;
    return out;
  }

  void _buildGoals() {
    final focusSet = focusGroups[focus]!;
    hardGoals.forEach((g, n) {
      if (n > 0) goals.add(_Goal(true, g, n.toDouble(), 4, true, true));
    });
    double softLevel(String g) {
      if (focusSet.contains(g)) return high ? 10 : 6;
      var base = (g == 'arms' || g == 'hamstrings')
          ? (high ? 4.0 : 3.0)
          : (high ? 6.0 : 4.0);
      if (focus == 'balanced' &&
          const ['shoulders', 'back', 'abs'].contains(g)) {
        base = high ? 8 : 5;
      }
      if (focus == 'posture' && g == 'abs') base = high ? 6 : 4;
      if (female && g == 'glutes') base = high ? 8 : 5;
      return base;
    }

    for (final g in recipeGroups) {
      goals.add(
        _Goal(
          true,
          g,
          softLevel(g),
          focusSet.contains(g) ? 1.5 : 1,
          false,
          focusSet.contains(g),
        ),
      );
      goals.add(_Goal(true, g, high ? 8 : 6, 0.3, false));
    }
    // 背：后束飞鸟也会算进「背」，所以另外要求背阔肌有真正的拉类动作。
    goals.add(
      _Goal(
        false,
        'lats',
        focus == 'posture' || focus == 'shoulders_back' ? 4 : 3,
        3,
        true,
      ),
    );
    final shoulderLove = focus == 'balanced' || focusSet.contains('shoulders');
    goals.add(
      _Goal(
        false,
        'delt_side',
        shoulderLove && high
            ? 6
            : high
            ? 4
            : 3,
        1.2,
        false,
      ),
    );
    goals.add(
      _Goal(
        false,
        'delt_rear',
        focus == 'posture' || focus == 'shoulders_back'
            ? (high ? 6 : 4)
            : (high ? 4 : 3),
        1.2,
        false,
      ),
    );
    if (focus == 'posture') {
      goals.add(_Goal(false, 'mid_back', high ? 6 : 4, 1.2, false));
      goals.add(_Goal(false, 'lats', high ? 4 : 3, 1.2, false));
    }
    if (high && (focus == 'balanced' || focus == 'chest_shoulders')) {
      goals.add(_Goal(false, 'chest_up', 3, 0.8, false));
    }
    if (high && minutes >= 50) {
      goals.add(_Goal(false, 'calves', 3, 0.25, false));
    }
  }

  // ---- 贪心 ---------------------------------------------------------------

  int _sets(String slot) =>
      _mainSlots.contains(slot) ? 3 : (cut || exp == 'new' ? 2 : 3);
  int _rest(String slot) =>
      _mainSlots.contains(slot) ? (minutes == 20 ? 90 : 120) : 60;
  int get _maxSets => cut ? 2 : (exp == 'new' ? 3 : 4);

  Set<String> _used(int d, int tier) => {
    for (final i in days[d].items)
      if (i.picks[tier] != null) i.picks[tier]!.name,
  };

  /// 一天在某个版本（0 居家、1 健身房）里的估算时长，口径同 plans.estimateMinutes：
  /// 含热身，每组按「休息 + 50 秒」算，取整到 5 分钟。
  int _estTier(List<_Item> items, int tier, [_Item? extra]) {
    var sec = 0;
    for (final i in items) {
      if (i.picks[tier] != null) sec += i.sets * (i.rest + 50);
    }
    if (extra != null && extra.picks[tier] != null) {
      sec += extra.sets * (extra.rest + 50);
    }
    return (((tier == 0 ? _homeWarm : _gymWarm) + sec / 60) / 5 + 0.5).floor() *
        5;
  }

  Map<String, double> _delta(_Pick pick, int sets) => {
    for (final e in _muscles(pick.name).entries) e.key: e.value * sets,
  };

  /// 居家版和健身房版各自加上 [deltas]（null 表示这个版本没有这个动作）之后，
  /// 达成目标的增量；两个版本都要达标，所以每个目标取两个版本里较差的那个。
  /// 任何部位超过每周上限就返回 null。
  double? _gain(
    List<Map<String, double>?> deltas,
    bool hardOnly, [
    bool bump = false,
    bool soft = false,
  ]) {
    for (final t in [0, 1]) {
      final delta = deltas[t];
      if (delta == null) continue;
      final v = vol[t];
      for (final g in recipeGroups) {
        var touched = false;
        var best = 0.0;
        for (final m in _groupMuscles[g]!) {
          final d = delta[m];
          if (d != null) touched = true;
          best = math.max(best, (v[m] ?? 0) + (d ?? 0));
        }
        // 补细节的阶段不把一个部位推过参考范围的上限；硬指标和兜底最多到 16 组。
        final top = soft
            ? _reference(g, focusGroups[focus]!.contains(g), high).$2
            : _weeklyCap;
        if (touched && best > top) return null;
      }
    }
    var s = 0.0;
    for (final g in goals) {
      if (hardOnly && !g.hard) continue;
      if (bump && !g.bumpOk) continue;
      var before = double.infinity;
      var after = double.infinity;
      var touched = false;
      for (final t in [0, 1]) {
        final delta = deltas[t];
        final v = vol[t];
        var now = 0.0;
        var next = 0.0;
        for (final m in g.muscles) {
          final d = delta?[m];
          if (d != null) touched = true;
          final x = v[m] ?? 0;
          now = math.max(now, x);
          next = math.max(next, x + (d ?? 0));
        }
        before = math.min(before, math.min(now, g.goal));
        after = math.min(after, math.min(next, g.goal));
      }
      if (touched) s += g.weight * (after - before);
    }
    return s;
  }

  int _daysWith(int tier, String group) =>
      pres[tier].where((s) => s.contains(group)).length;

  int _regionCount(int d, String region) =>
      days[d].items.where((i) => _slotRegion[i.slot] == region).length;

  bool _regionCovered(int d, String region) =>
      days[d].items.any((i) => i.main && _slotRegion[i.slot] == region);

  /// 每周两个训练日都出现：ppl 三天本来就不要求。
  bool _spreadWanted(String g) =>
      !(split == 'ppl' && dayCount == 3) && hardGoals[g]! > 0;

  /// 兜底补时间时优先补本周组数少的部位：动作练到的肌肉本周已经有多少组。
  double _crowding(List<_Pick?> picks) {
    var total = 0.0;
    for (final t in [0, 1]) {
      final pick = picks[t];
      if (pick == null) continue;
      for (final m in _muscles(pick.name).keys) {
        total += (vol[t][m] ?? 0) * 0.02;
      }
    }
    return total;
  }

  /// 这一天所有版本都放得下 [items]（不超过 [cap]）吗？
  bool _fits(List<_Item> items, int cap, [_Item? extra]) =>
      _estTier(items, 0, extra) <= cap && _estTier(items, 1, extra) <= cap;

  _Cand? _evalAdd(
    int d,
    String slot,
    int cap,
    bool hardOnly, [
    bool fill = false,
  ]) {
    final day = days[d];
    if (day.has(slot)) return null;
    final picks = [
      for (final t in [0, 1]) _pick(slot, t, day.def.v, _used(d, t)),
    ];
    if (picks[0] == null && picks[1] == null) return null;
    final isMain = _mainSlots.contains(slot);
    for (final t in [0, 1]) {
      if (picks[t] == null) continue;
      var count = 0, mains = 0;
      for (final i in day.items) {
        if (i.picks[t] == null) continue;
        count++;
        if (i.main) mains++;
      }
      if (count >= (_maxExercises[minutes] ?? 6)) return null;
      if (isMain && mains >= (_maxMains[minutes] ?? 2)) return null;
    }
    final item = _Item(slot, _sets(slot), _rest(slot), picks);
    if (!_fits(day.items, cap, item)) return null;
    final gain = _gain(
      [
        for (final t in [0, 1])
          picks[t] == null ? null : _delta(picks[t]!, item.sets),
      ],
      hardOnly,
      false,
      !hardOnly && !fill,
    );
    if (gain == null) return null;
    var spread = 0.0;
    for (final t in [0, 1]) {
      final pick = picks[t];
      if (pick == null) continue;
      for (final g in _presence(pick.name)) {
        if (!pres[t][d].contains(g) &&
            _daysWith(t, g) < 2 &&
            _spreadWanted(g)) {
          spread += (minutes == 20 ? 1.5 : 5) * v.spread;
        }
      }
    }
    var score = gain + spread;
    final region = _slotRegion[slot]!;
    score /= 1 + 0.6 * _regionCount(d, region);
    // 每次 20 分钟只有 3 个动作，推、拉、腿不强求每天都有，按每周缺什么补什么。
    if ((minutes > 20 || v.region20) &&
        (_dayRegions[day.def.type] ?? const []).contains(region) &&
        !_regionCovered(d, region)) {
      score *= item.main ? v.mainBoost : 1;
    }
    if (focus == 'posture' && slot == 'vpush') score *= 0.3;
    final cost = item.sets * (item.rest + 50) / 60;
    if (fill) score -= _crowding(picks);
    return _Cand(d, slot, item, false, score / math.pow(cost, v.costExp));
  }

  _Cand? _evalBump(
    int d,
    _Item item,
    int cap,
    bool hardOnly, [
    bool fill = false,
  ]) {
    if (item.main) return null;
    if (item.sets >= (fill && !cut ? 4 : _maxSets)) return null;
    final day = days[d];
    item.sets += 1;
    final fits = _fits(day.items, cap);
    item.sets -= 1;
    if (!fits) return null;
    final gain = _gain(
      [
        for (final t in [0, 1])
          item.picks[t] == null ? null : _delta(item.picks[t]!, 1),
      ],
      hardOnly,
      !fill,
    );
    if (gain == null) return null;
    // 加组不如加动作：多一个动作覆盖面更广。
    final score = v.bump * gain - (fill ? _crowding(item.picks) : 0);
    return _Cand(
      d,
      item.slot,
      item,
      true,
      score / math.pow((item.rest + 50) / 60, v.costExp),
    );
  }

  void _apply(_Cand c) {
    final item = c.item!;
    for (final t in [0, 1]) {
      final pick = item.picks[t];
      if (pick == null) continue;
      _delta(
        pick,
        c.bump ? 1 : item.sets,
      ).forEach((k, x) => vol[t][k] = (vol[t][k] ?? 0) + x);
      if (!c.bump) pres[t][c.day].addAll(_presence(pick.name));
    }
    if (c.bump) {
      item.sets += 1;
    } else {
      days[c.day].items.add(item);
    }
  }

  _Cand? _best(int cap, bool hardOnly) {
    _Cand? best;
    for (var d = 0; d < days.length; d++) {
      for (final slot in _slotOrder) {
        if (!_daySlots[days[d].def.type]!.contains(slot)) continue;
        final c = _evalAdd(d, slot, cap, hardOnly);
        if (c != null && (best == null || c.score > best.score)) best = c;
      }
      for (final item in days[d].items) {
        final c = _evalBump(d, item, cap, hardOnly);
        if (c != null && (best == null || c.score > best.score)) best = c;
      }
    }
    return best;
  }

  void run() {
    // 先补硬指标（每个部位的最低组数、每周出现的天数），按所选时长排；
    // 还缺的话最多放宽 5 分钟；然后在所选时长内补重点和细节。
    for (final (cap, hardOnly) in [
      (minutes, true),
      (minutes + 5, true),
      (minutes == 20 ? 25 : minutes, false),
    ]) {
      while (true) {
        final best = _best(cap, hardOnly);
        if (best == null || best.score <= 1e-9) break;
        _apply(best);
      }
    }
    // 兜底：某个版本的估算时长太短就继续补动作，补不动再给辅助动作加组。
    final floor = minutes == 20 ? 15 : minutes - 10;
    for (var d = 0; d < days.length; d++) {
      while (true) {
        final short = [
          for (final t in [0, 1])
            if (_estTier(days[d].items, t) < floor) t,
        ];
        if (short.isEmpty) break;
        _Cand? best;
        bool helps(_Item i) => short.any((t) => i.picks[t] != null);
        for (final slot in _slotOrder) {
          if (!_daySlots[days[d].def.type]!.contains(slot)) continue;
          final c = _evalAdd(d, slot, minutes + 5, false, true);
          if (c != null &&
              helps(c.item!) &&
              (best == null || c.score > best.score)) {
            best = c;
          }
        }
        if (best == null) {
          for (final item in days[d].items.where(helps)) {
            final c = _evalBump(d, item, minutes + 5, false, true);
            if (c != null && (best == null || c.score > best.score)) best = c;
          }
        }
        if (best == null) {
          // 限制多的时候这一类训练日的动作位不够，放宽到任何动作位，总比一天只有两三个动作强。
          for (final slot in _slotOrder) {
            final c = _evalAdd(d, slot, minutes + 5, false, true);
            if (c != null &&
                helps(c.item!) &&
                (best == null || c.score > best.score)) {
              best = c;
            }
          }
        }
        if (best == null) break;
        _apply(best);
      }
      days[d].items.sort(
        (a, b) =>
            _slotOrder.indexOf(a.slot).compareTo(_slotOrder.indexOf(b.slot)),
      );
    }
  }

  /// 硬指标的缺口：各部位组数不足的总和，加上每周出现天数不够、时长不在范围内的惩罚。
  double shortfall() {
    var gap = 0.0;
    final floor = minutes == 20 ? 15 : minutes - 10;
    for (final t in [0, 1]) {
      for (final g in recipeGroups) {
        var best = 0.0;
        for (final m in _groupMuscles[g]!) {
          best = math.max(best, vol[t][m] ?? 0);
        }
        gap += math.max(0, hardGoals[g]! - best);
      }
      if (minutes > 20) {
        for (final g in _spreadGroups) {
          if (_spreadWanted(g)) gap += math.max(0, 2 - _daysWith(t, g));
        }
      }
      for (final day in days) {
        final est = _estTier(day.items, t);
        if (est < floor) gap += 5;
        if (est > minutes + 5) gap += 5;
      }
    }
    return gap;
  }

  // ---- 输出 ---------------------------------------------------------------

  Map<String, dynamic> exerciseJson(
    String id,
    _Item it,
    _Pick pick,
    int tier,
    Set<String> usedLadders,
  ) {
    final spec = _spec(pick.name);
    final main = it.main;
    final ladderId = pick.ladder;
    final step = ladderId == null
        ? null
        : ladderId == 'pushup'
        ? _pushupSteps
        : ladderPreset(ladderId)!.steps[ladderPreset(ladderId)!.start];
    if (ladderId != null) usedLadders.add(ladderId);
    final timed = spec['unit'] == 'sec';
    final weighted = (spec['weight'] as num) > 0 || spec['machine'] == true;
    final (lo, hi) = step != null
        ? (step['min'] as int, step['max'] as int)
        : timed
        ? (20, 40)
        : main
        ? (weighted ? (6, 10) : (8, 12))
        : (10, 15);
    final stepOwns = ladderId != null && ladderId != 'pushup';
    return <String, dynamic>{
      'id': id,
      'name': pick.name,
      'part': spec['part'],
      'sets': it.sets,
      'min': lo,
      'max': hi,
      'unit': spec['unit'],
      'side': stepOwns ? step!['side'] : spec['side'],
      'weight': spec['weight'],
      'core': main,
      'optional': false,
      'machine': spec['machine'],
      'gear': stepOwns
          ? step!['gear']
          : tier == 0 && bwHome && _bottleGear.containsKey(pick.name)
          ? _bottleGear[pick.name]
          : spec['gear'],
      'tip': stepOwns ? step!['tip'] : spec['tip'],
      'rest': it.rest,
      'alts': [
        for (final a in spec['alts'] as List)
          if (allowed((a as Map)['name'] as String))
            cloneJson(Map<String, dynamic>.from(a)),
      ],
      'img': '',
      'ladder': ?ladderId,
    };
  }

  /// 不方便的部位：说明哪些动作换掉了。没有限制就是空列表。
  List<String> notes() {
    if (limits.isEmpty) return const [];
    return [
      if (limits.contains('膝'))
        bwHome
            ? '膝盖不方便：深蹲类换成了臀桥和单腿臀桥，大腿前侧的量会偏少。'
            : '膝盖不方便：深蹲类换成了臀桥、罗马尼亚硬拉和腿弯举，大腿前侧的量会偏少。',
      if (limits.contains('腰'))
        '腰部不方便：硬拉类、弯腰划船、背部伸展、超人式和俄罗斯转体都不安排，背部改用划船和下拉，臀腿改用臀桥。',
      if (limits.contains('肩'))
        '肩部不方便：肩推、上斜推胸、椅子臂屈伸、脚抬高俯卧撑和引体向上都不安排，肩用轻重量的侧平举和后束动作。',
      if (limits.contains('腕'))
        '手腕不方便：俯卧撑、平板支撑和椅子臂屈伸都不安排，推的动作改用哑铃或器械，核心改用死虫式和卷腹。',
      if (limits.contains('腕') && bwHome) '居家没有器械又手腕不方便，胸的动作安排不了，去健身房或有哑铃时再补上。',
      '以上只是一般的训练安排，不是医疗建议；疼痛没有缓解请先咨询医生。',
    ];
  }
}

/// 方案的名字，例如「每周 3 天 · 肩背多一点」。整句走翻译表，变量只有天数。
String recipeName(Map<String, dynamic> recipe) {
  final r = normalizeRecipe(recipe);
  final days = r['days'];
  return switch (r['focus']) {
    'shoulders_back' => '每周 $days 天 · 肩背多一点',
    'chest_shoulders' => '每周 $days 天 · 胸肩多一点',
    'glutes_legs' => '每周 $days 天 · 臀腿多一点',
    'core' => '每周 $days 天 · 腹部多一点',
    'posture' => '每周 $days 天 · 改善体态',
    _ => '每周 $days 天 · 全身均衡',
  };
}

/// 每个部位每周的组数和参考范围，按 [recipeGroups] 的顺序。
///
/// 组数按动作的肌肉参与度折算（主练算 1 组，协同按比例），与进度页同一口径；
/// 一个部位取它下面几块肌肉里最多的那块。`focus` 标出配方里要多练的部位。
List<Map<String, dynamic>> weeklyVolume(
  Map<String, dynamic> plan, {
  String venue = 'home',
}) {
  final schedule = plan['schedule'] as Map? ?? {};
  final workouts = plan['workouts'] as Map? ?? {};
  final volume = <String, double>{};
  for (final id in schedule.values) {
    final workout = workouts[id];
    if (workout is! Map) continue;
    final variant = venue == 'gym' && workout['gym'] is Map
        ? workout['gym'] as Map
        : workout;
    for (final ex in (variant['exercises'] as List? ?? []).whereType<Map>()) {
      if (ex['optional'] == true) continue;
      final muscles =
          musclesOf(ex['name'], ex['part'] as String?)?['muscles'] as Map? ??
          {};
      final sets = ex['sets'] is num ? (ex['sets'] as num).toDouble() : 0.0;
      for (final e in muscles.entries) {
        volume['${e.key}'] =
            (volume['${e.key}'] ?? 0) + sets * (e.value as num);
      }
    }
  }
  final recipe = plan['recipe'];
  final focus = focusGroups[recipe is Map ? recipe['focus'] : null] ?? const [];
  final high = _highLoad(recipe is Map ? recipe : const {});
  return [
    for (final g in recipeGroups)
      {
        'group': g,
        'sets': _groupMuscles[g]!
            .map((m) => volume[m] ?? 0.0)
            .reduce((a, b) => a > b ? a : b),
        'low': _reference(g, focus.contains(g), high).$1,
        'high': _reference(g, focus.contains(g), high).$2,
        'focus': focus.contains(g),
      },
  ];
}

/// 每周 3 天及以上、每次 35 分钟及以上，才按「足量」的口径要求每个部位。
bool _highLoad(Map recipe) {
  final days = recipe['days'] is num ? (recipe['days'] as num).toInt() : 3;
  final minutes = recipe['minutes'] is num
      ? (recipe['minutes'] as num).toInt()
      : 35;
  return days >= 3 && minutes >= 35;
}

/// 一个部位每周组数的参考范围（低、高）。重点部位 8～14 组，手臂和腘绳肌 3～8 组，
/// 其余 4～10 组；每周 2 天或每次 20 分钟时相应调低。
(int, int) _reference(String group, bool focus, bool high) {
  if (focus) return high ? (8, 14) : (5, 10);
  if (group == 'arms' || group == 'hamstrings') return high ? (3, 8) : (2, 6);
  return high ? (4, 10) : (3, 7);
}

/// 当前排法之外的另一种排法（同样的天数、时长和重点）；没有就返回 null。
Map<String, dynamic>? alternateRecipe(Map<String, dynamic> recipe) {
  final r = normalizeRecipe(recipe);
  final others = splitsFor(
    r['days'] as int,
    r['experience'] as String,
  ).where((s) => s != r['split']);
  return others.isEmpty ? null : {...r, 'split': others.first};
}
