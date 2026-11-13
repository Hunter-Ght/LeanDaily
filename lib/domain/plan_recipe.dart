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

/// 按配方生成完整方案。返回值已经过 normalizePlan，并带 `recipe` 字段。
///
/// 生成规则（纯函数，同样的配方永远得到同样的方案），骨架优先：
/// 1. 按排法定出每个训练日（全身 A～D、上肢 A/B、下肢 A/B、推、拉、腿、补强日）；
/// 2. 每种训练日是一张按优先级排好的「动作位」清单（带 * 的是主项），
///    时长档决定取前几个：每加一个动作都要在居家版和健身房版里放得下；
/// 3. 重点只能在骨架里微调：重点部位的位提前、该位多 1 组、时间有富余时在最后加 1 个；
/// 4. 不方便的部位直接把对应动作从候选里去掉，把说明写进 `recipeNotes`。
Map<String, dynamic> buildRecipePlan(
  Map<String, dynamic> recipe, {
  String startDate = '',
}) {
  final r = normalizeRecipe(recipe);
  final gen = _Generator(r)..run();
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
// 骨架：每种训练日是一张按优先级排好的动作位清单
// ---------------------------------------------------------------------------
//
// 动作位：hpush 水平推、ipush 上斜推、hpush2 第二个推、fly 夹胸、vpush 垂直推（肩推）、
// hpull 水平拉、hpull2 第二个水平拉、vpull 垂直拉、squat 蹲、lunge 分腿蹲、
// quad_iso 腿屈伸、hinge 髋主导、glute 臀、ham 腘绳、lateral 侧平举、rear 后束、
// bi 二头、tri 三头、core 腹、core2 第二个腹（只有腹部重点才用）、calf 小腿。
// 写法：`a|b` 是备选（前一个没有就用后一个）；末尾 `*` 是主项。

const _skeletons = <String, List<String>>{
  'fullA': [
    'hpush*',
    'hpull*',
    'squat|hinge*',
    'lateral',
    'core',
    'rear',
    'glute|hinge',
    'bi|tri',
  ],
  'fullB': [
    'hinge*',
    'vpush|ipush|hpush*',
    'vpull|hpull*',
    'core',
    'lateral',
    'lunge',
    'rear',
    'tri|bi',
  ],
  'fullC': [
    'squat|hinge*',
    'hpush*',
    'hpull*',
    'lateral',
    'rear',
    'core',
    'glute',
    'bi|tri',
  ],
  'upperA': [
    'hpush*',
    'hpull*',
    'vpush*',
    'vpull',
    'lateral',
    'rear',
    'bi',
    'tri',
  ],
  'upperB': [
    'ipush*',
    'vpull|hpull*',
    'hpull*',
    'lateral',
    'rear',
    'hpush2|fly',
    'tri',
    'bi',
  ],
  'lowerA': [
    'squat*',
    'hinge*',
    'ham|glute',
    'core',
    'calf',
    'lunge|quad_iso',
    'glute',
  ],
  'lowerB': [
    'hinge*',
    'squat*',
    'glute',
    'core',
    'quad_iso|lunge',
    'calf',
    'ham',
  ],
  'push': ['hpush*', 'vpush*', 'ipush|hpush2', 'lateral', 'tri', 'fly'],
  'pull': ['vpull|hpull*', 'hpull*', 'rear', 'core', 'bi', 'hpull2'],
  'legs': [
    'squat*',
    'hinge*',
    'lunge|quad_iso',
    'core',
    'ham',
    'glute',
    'calf',
  ],
  'boost': ['hpush*', 'vpull|hpull*', 'squat|hinge*'],
};

/// 重点方向：骨架里属于这些动作位的辅助动作提前、多 1 组，最后还可以再加 1 个。
const _focusSlots = <String, List<String>>{
  'balanced': ['lateral', 'rear', 'core'],
  'shoulders_back': ['lateral', 'rear', 'vpull', 'hpull2'],
  'chest_shoulders': ['lateral', 'hpush2', 'fly'],
  'glutes_legs': ['glute', 'ham', 'lunge', 'quad_iso'],
  'core': ['core'],
  'posture': ['rear', 'hpull2', 'vpull', 'core'],
};

/// 动作位练的是哪个部位：重点部位的辅助动作才能多 1 组。
const _slotGroup = {
  'hpush2': 'chest',
  'ipush': 'chest',
  'fly': 'chest',
  'lateral': 'shoulders',
  'rear': 'shoulders',
  'vpull': 'back',
  'hpull2': 'back',
  'glute': 'glutes',
  'lunge': 'quads',
  'quad_iso': 'quads',
  'ham': 'hamstrings',
  'core': 'abs',
  'core2': 'abs',
};

/// 动作的近亲：同一天同一类最多放一个（腹部重点时腹最多两个）。
String? _family(String name) {
  const bridge = {'臀桥', '单腿臀桥'};
  const core = {'卷腹', '反向卷腹', '卷腹机', '绳索卷腹', '死虫式', '平板支撑', '侧平板支撑', '俄罗斯转体'};
  const lateral = {'轻重量侧平举', '轻哑铃侧平举', '拉力器单臂侧平举'};
  const rear = {'俯身哑铃反向飞鸟', '绳索面拉', '反向蝴蝶机'};
  if (bridge.contains(name)) return 'bridge';
  if (core.contains(name)) return 'core';
  if (lateral.contains(name)) return 'lateral';
  if (rear.contains(name)) return 'rear';
  return null;
}

const _coreList = ['反向卷腹', '死虫式', '卷腹', '平板支撑', '侧平板支撑', '俄罗斯转体'];

/// 居家无器械。没有的位（垂直推、垂直拉、二头……）整个跳过，或由骨架里的备选顶上。
const _bwSlots = <String, List<String>>{
  'hpush': ['高位俯卧撑'],
  'ipush': ['高位俯卧撑'],
  'hpull': ['反向划船'],
  'squat': ['深蹲', '分腿蹲'],
  'lunge': ['分腿蹲'],
  'hinge': ['臀桥', '单腿臀桥'],
  'glute': ['单腿臀桥', '臀桥'],
  'lateral': ['轻重量侧平举'],
  'rear': ['俯身哑铃反向飞鸟'],
  'tri': ['椅子臂屈伸'],
  'core': _coreList,
  'core2': _coreList,
  'calf': ['站姿提踵'],
};

/// 居家哑铃。
const _dbSlots = <String, List<String>>{
  'hpush': ['哑铃地板卧推', '高位俯卧撑'],
  'ipush': ['高位俯卧撑', '哑铃地板卧推'],
  'hpush2': ['高位俯卧撑', '哑铃地板卧推'],
  'vpush': ['哑铃肩推'],
  'hpull': ['单臂哑铃划船', '弯腰双臂哑铃划船', '反向划船'],
  'hpull2': ['弯腰双臂哑铃划船', '反向划船', '单臂哑铃划船'],
  'squat': ['高脚杯深蹲', '分腿蹲'],
  'lunge': ['分腿蹲'],
  'hinge': ['轻哑铃罗马尼亚硬拉'],
  'glute': ['臀桥', '单腿臀桥'],
  'lateral': ['轻重量侧平举'],
  'rear': ['俯身哑铃反向飞鸟'],
  'bi': ['哑铃弯举', '锤式弯举'],
  'tri': ['站姿哑铃臂屈伸', '哑铃臂后屈伸', '椅子臂屈伸'],
  'core': _coreList,
  'core2': _coreList,
  'calf': ['站姿提踵'],
};

/// 健身房。
const _gymSlots = <String, List<String>>{
  'hpush': ['哑铃平板卧推', '坐姿推胸机'],
  'ipush': ['上斜哑铃卧推', '上斜推胸机'],
  'hpush2': ['坐姿推胸机', '哑铃平板卧推', '上斜推胸机'],
  'fly': ['蝴蝶机夹胸', '拉力器高位向下夹胸'],
  'vpush': ['坐姿肩推机', '轻哑铃坐姿肩推'],
  'hpull': ['坐姿划船机', '单臂哑铃划船', '弯腰双臂哑铃划船'],
  'hpull2': ['单臂哑铃划船', '弯腰双臂哑铃划船', '坐姿划船机'],
  'vpull': ['高位下拉', '辅助引体向上机', '直臂下拉'],
  'squat': ['腿举机', '高脚杯深蹲', '分腿蹲', '深蹲'],
  'lunge': ['分腿蹲', '高脚杯深蹲'],
  'quad_iso': ['腿屈伸机'],
  'hinge': ['轻哑铃罗马尼亚硬拉'],
  'glute': ['臀桥', '单腿臀桥'],
  'ham': ['坐姿腿弯举'],
  'lateral': ['轻哑铃侧平举', '拉力器单臂侧平举'],
  'rear': ['绳索面拉', '反向蝴蝶机', '俯身哑铃反向飞鸟'],
  'bi': ['哑铃弯举', '二头弯举机', '锤式弯举'],
  'tri': ['绳索下压', '站姿哑铃臂屈伸', '哑铃臂后屈伸'],
  'core': ['绳索卷腹', '卷腹机', '死虫式', '反向卷腹', '平板支撑', '卷腹'],
  'core2': ['卷腹机', '死虫式', '反向卷腹', '平板支撑', '卷腹', '绳索卷腹'],
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

/// 一天最多放几个动作。
const _maxExercises = {20: 4, 35: 6, 50: 8};

/// 任何部位每周的组数上限；腹和手臂（不是重点时）更低。
const _weeklyCap = 16.0;
const _softCap = 10.0;

const _fullNames = ['全身 A', '全身 B', '全身 C', '全身 D'];

class _DayDef {
  const _DayDef(this.name, this.short, this.tag, this.skeleton, this.v);
  final String name;
  final String short;
  final String tag;

  /// 用哪张骨架（`_skeletons` 的键）。
  final String skeleton;

  /// 变式序号：同一类型的 A/B/C 日用不同序号，挑出不同的动作。
  final int v;
}

class _Pick {
  const _Pick(this.name, this.ladder);
  final String name;
  final String? ladder;
}

class _Entry {
  const _Entry(this.slots, this.main);
  final List<String> slots;
  final bool main;

  factory _Entry.parse(String s) {
    final main = s.endsWith('*');
    return _Entry((main ? s.substring(0, s.length - 1) : s).split('|'), main);
  }

  bool inPool(Iterable<String> pool) => slots.any(pool.contains);
}

class _Item {
  _Item(this.main, this.sets, this.rest, this.picks, this.slots);

  /// 骨架里是不是主项（带 *）。
  final bool main;
  int sets;
  final int rest;

  /// 居家版和健身房版各挑什么动作；某个版本没有合适的动作就是 null。
  final List<_Pick?> picks;

  /// 居家版和健身房版各用了哪个动作位（备选可能不同）。
  final List<String?> slots;
}

class _Day {
  _Day(this.def);
  final _DayDef def;
  final items = <_Item>[];
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

final _warmups = (
  (plans.defaultPlan()['warmup']['minutes'] as num).toInt(),
  (plans.defaultPlan()['gymWarmup']['minutes'] as num).toInt(),
);

final _pushupSteps =
    (plans.defaultPlan()['ladders']['pushup']['steps'] as List).first as Map;

class _Generator {
  _Generator(this.r)
    : dayCount = r['days'] as int,
      minutes = r['minutes'] as int,
      focus = r['focus'] as String,
      split = r['split'] as String,
      venue = r['venue'] as String,
      exp = r['experience'] as String,
      stage = r['stage'] as String?,
      limits = {for (final l in r['limits'] as List) '$l'} {
    cut = stage == 'cut';
    bwHome = venue == 'bodyweight';
    cands = [_buildCands(0), _buildCands(1)];
    days = [for (final d in _buildDefs()) _Day(d)];
  }

  final Map<String, dynamic> r;
  final int dayCount;
  final int minutes;
  final String focus;
  final String split;
  final String venue;
  final String exp;
  final String? stage;
  final Set<String> limits;
  late final bool cut;
  late final bool bwHome;
  late final List<Map<String, List<String>>> cands;
  late final List<_Day> days;

  /// 每周已经排了多少组（按肌肉折算），居家版、健身房版各一份。
  final vol = <Map<String, double>>[{}, {}];

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
      if (tier == 0 && e.key == 'ipush' && bwHome && exp == 'trained') {
        list.add('脚抬高俯卧撑');
      }
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
    return out;
  }

  /// 给动作位挑动作：按变式序号轮换起点，跳过当天已有的动作和近亲。
  _Pick? _pick(
    String slot,
    int tier,
    int v,
    Set<String> used,
    Map<String, int> families,
  ) {
    final list = cands[tier][slot] ?? const <String>[];
    if (list.isEmpty) return null;
    // 垂直拉不轮换：高位下拉最适合做主项，其他变式留给引体向上（老手）。
    final start = slot == 'vpull' ? 0 : v % list.length;
    for (var i = 0; i < list.length; i++) {
      final n = list[(start + i) % list.length];
      if (used.contains(n)) continue;
      final fam = _family(n);
      if (fam != null) {
        final most = fam == 'core' && focus == 'core' ? 2 : 1;
        if ((families[fam] ?? 0) >= most) continue;
      }
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

  // ---- 训练日 ---------------------------------------------------------------

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
            _DayDef('上肢', '上', upper, 'upperB', 1),
            _DayDef('下肢', '下', lower, 'lowerB', 1),
          ],
        ];
      case 'ul':
        return [
          const _DayDef('上肢 A', '上', upper, 'upperA', 0),
          const _DayDef('下肢 A', '下', lower, 'lowerA', 0),
          const _DayDef('上肢 B', '上', upper, 'upperB', 1),
          const _DayDef('下肢 B', '下', lower, 'lowerB', 1),
          if (dayCount >= 5) const _DayDef('全身 · 补强', '全', '补强日', 'boost', 2),
        ];
      default:
        const skeletons = ['fullA', 'fullB', 'fullC', 'fullB'];
        return [
          for (var i = 0; i < dayCount; i++)
            _DayDef(_fullNames[i], '全', full, skeletons[i], i),
        ];
    }
  }

  /// 这一天的动作位清单：骨架 + 重点的微调（重点部位的辅助位提前）。
  List<_Entry> _entries(_DayDef def) {
    var list = [for (final s in _skeletons[def.skeleton]!) _Entry.parse(s)];
    if (def.skeleton == 'boost') {
      // 补强日：三个主项之后，按重点再加 2～3 个辅助。
      list = [
        ...list,
        for (final s in _focusSlots[focus]!.take(3)) _Entry.parse(s),
      ];
    }
    final pool = _focusSlots[focus]!;
    if (focus != 'balanced') {
      final mains = [
        for (final e in list)
          if (e.main) e,
      ];
      final rest = [
        for (final e in list)
          if (!e.main) e,
      ];
      // 腹不被重点挤掉：它在辅助动作里的位置不变，重点动作补到其他位置的前面。
      final found = rest.indexWhere((e) => e.slots.contains('core'));
      final coreAt = focus == 'core' ? 0 : found; // 腹部重点：腹提到第一个辅助
      final core = found >= 0 ? rest[found] : null;
      final movable = [
        for (final e in rest)
          if (e != core) e,
      ];
      final ordered = [
        ...movable.where((e) => e.inPool(pool)),
        ...movable.where((e) => !e.inPool(pool)),
      ];
      if (core != null) ordered.insert(math.min(coreAt, ordered.length), core);
      list = [...mains, ...ordered];
    }
    if (focus == 'core') {
      // 腹部重点：腹一天最多两个，第二个紧跟在第一个后面。
      final i = list.indexWhere((e) => e.slots.contains('core'));
      if (i >= 0) list.insert(i + 1, _Entry.parse('core2'));
    }
    return list;
  }

  bool _isFocusEntry(_Entry e) {
    final groups = focusGroups[focus]!;
    return e.slots.any((s) => groups.contains(_slotGroup[s]));
  }

  int _sets(_Entry e) {
    if (e.main) return 3;
    final base = cut || exp == 'new' ? 2 : 3;
    // 重点部位的辅助动作多 1 组（减脂路线辅助一律 2 组）。
    return !cut && _isFocusEntry(e) ? base + 1 : base;
  }

  int _rest(_Entry e) => e.main ? (minutes == 20 ? 60 : 120) : 60;

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
    final warm = tier == 0 ? _warmups.$1 : _warmups.$2;
    return ((warm + sec / 60) / 5 + 0.5).floor() * 5;
  }

  double _group(Map<String, double> v, String g) {
    var best = 0.0;
    for (final m in _groupMuscles[g]!) {
      best = math.max(best, v[m] ?? 0);
    }
    return best;
  }

  /// 试着把一个动作位清单项放进 [day]；放不下（没有动作、重复、超时、超周上限）就返回 false。
  bool _tryAdd(
    _Day day,
    _Entry e, {
    required List<Set<String>> present,
    required List<Set<String>> used,
    required List<Map<String, int>> families,
    required int cap,
    required int maxCount,
  }) {
    final picks = <_Pick?>[null, null];
    final slots = <String?>[null, null];
    for (final t in [0, 1]) {
      for (final slot in e.slots) {
        if (present[t].contains(slot)) continue;
        final pick = _pick(slot, t, day.def.v, used[t], families[t]);
        if (pick != null) {
          picks[t] = pick;
          slots[t] = slot;
          break;
        }
      }
    }
    if (picks[0] == null && picks[1] == null) return false;
    // 先按完整组数试；放不下就退回基础组数。每个版本各自判断放不放得下，
    // 放不下的版本这一项就跳过，另一个版本照常排。
    final fullSets = _sets(e);
    final baseSets = e.main ? 3 : (cut || exp == 'new' ? 2 : 3);
    _Item? best;
    for (final sets in {fullSets, baseSets}) {
      final fit = <_Pick?>[null, null];
      final item = _Item(e.main, sets, _rest(e), fit, slots);
      for (final t in [0, 1]) {
        final pick = picks[t];
        if (pick == null) continue;
        final count = day.items.where((i) => i.picks[t] != null).length;
        if (count >= maxCount) continue;
        fit[t] = pick;
        if (_estTier(day.items, t, item) > cap) {
          fit[t] = null;
          continue;
        }
        // 腹和手臂每周不超过 10 组（腹部重点时腹不限）；主项是骨架的核心，不受限制。
        if (e.main) continue;
        final after = {...vol[t]};
        _muscles(pick.name)
            .forEach((k, x) => after[k] = (after[k] ?? 0) + x * sets);
        if (recipeGroups.any((g) => _group(after, g) > _weeklyCap) ||
            (focus != 'core' && _group(after, 'abs') > _softCap) ||
            _group(after, 'arms') > _softCap) {
          fit[t] = null;
        }
      }
      final n = fit.where((p) => p != null).length;
      final bestN = best?.picks.where((p) => p != null).length ?? 0;
      if (n > bestN) best = item;
    }
    if (best == null) return false;
    final item = best;
    for (final t in [0, 1]) {
      if (item.picks[t] == null) item.slots[t] = null;
    }
    for (final t in [0, 1]) {
      final pick = item.picks[t];
      if (pick == null) continue;
      present[t].add(item.slots[t]!);
      used[t].add(pick.name);
      final fam = _family(pick.name);
      if (fam != null) families[t][fam] = (families[t][fam] ?? 0) + 1;
      _muscles(pick.name)
          .forEach((k, x) => vol[t][k] = (vol[t][k] ?? 0) + x * item.sets);
    }
    day.items.add(item);
    return true;
  }

  void run() {
    final cap = minutes + 5;
    final maxCount = _maxExercises[minutes] ?? 6;
    for (final day in days) {
      final present = [<String>{}, <String>{}];
      final used = [<String>{}, <String>{}];
      final families = [<String, int>{}, <String, int>{}];
      void add(_Entry e, int limit) => _tryAdd(
        day,
        e,
        present: present,
        used: used,
        families: families,
        cap: cap,
        maxCount: limit,
      );
      final entries = _entries(day.def);
      for (final e in entries) {
        add(e, maxCount);
      }
      // 重点部位：时间有富余时，在最后再加 1 个重点辅助（骨架里没有的位）。
      if (focus != 'balanced' && focus != 'core') {
        for (final slot in _focusSlots[focus]!) {
          final n = day.items.length;
          add(_Entry([slot], false), maxCount + 1);
          if (day.items.length > n) break;
        }
      }
      // 排序：主项在前，腹、小腿放最后。
      int rank(_Item i) {
        if (i.main) return 0;
        final s = i.slots[0] ?? i.slots[1]!;
        return s == 'calf'
            ? 3
            : (s == 'core' || s == 'core2')
            ? 2
            : 1;
      }

      final indexed = day.items.indexed.toList()
        ..sort((a, b) {
          final c = rank(a.$2).compareTo(rank(b.$2));
          return c != 0 ? c : a.$1.compareTo(b.$1);
        });
      day.items
        ..clear()
        ..addAll(indexed.map((e) => e.$2));
    }
    _trim();
  }

  /// 任何部位每周不超过 16 组（腹和手臂不是重点时不超过 10 组）：超了就从最后几天里
  /// 去掉对它贡献最大的辅助动作。
  void _trim() {
    for (var guard = 0; guard < 40; guard++) {
      var changed = false;
      for (final t in [0, 1]) {
        final v = <String, double>{};
        for (final day in days) {
          for (final i in day.items) {
            final p = i.picks[t];
            if (p == null) continue;
            _muscles(p.name).forEach((k, x) => v[k] = (v[k] ?? 0) + x * i.sets);
          }
        }
        for (final g in recipeGroups) {
          final limit = g == 'arms' || (g == 'abs' && focus != 'core')
              ? _softCap
              : _weeklyCap;
          if (_group(v, g) <= limit + 1e-9) continue;
          final top = _groupMuscles[g]!.reduce(
            (a, b) => (v[a] ?? 0) >= (v[b] ?? 0) ? a : b,
          );
          for (final day in days.reversed) {
            final hit = day.items.reversed.where(
              (i) =>
                  !i.main &&
                  i.picks[t] != null &&
                  (_muscles(i.picks[t]!.name)[top] ?? 0) >= 0.5,
            );
            if (hit.isEmpty) continue;
            final item = hit.first;
            // 先把重点多出来的那 1 组拿掉；已经是基础组数才去掉这个动作。
            final base = cut || exp == 'new' ? 2 : 3;
            if (item.sets > base) {
              item.sets -= 1;
              changed = true;
              break;
            }
            // 这个版本里不要这个动作了；两个版本都没有就整个去掉。
            final slots = item.slots;
            item.picks[t] = null;
            slots[t] = null;
            if (item.picks[0] == null && item.picks[1] == null) {
              day.items.remove(item);
            }
            changed = true;
            break;
          }
          if (changed) break;
        }
        if (changed) break;
      }
      if (!changed) return;
    }
  }

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
