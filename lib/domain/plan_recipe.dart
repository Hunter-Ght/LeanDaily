/// 按「配方」生成训练方案：用户回答每周几天、每次多久、想重点练哪，
/// 加上资料里的场地、经验、体脂路线和不方便的部位，得到一份完整的方案。
///
/// 纯函数，不读存储，不读当前时间。生成的方案和模板方案是同一种 JSON
/// （见 plan.dart 的 normalizePlan），额外带 `plan['recipe']`，之后可以按
/// 新的配方重新生成。
library;

import 'movements.dart' show musclesOf;
import 'plan.dart' as plans;
import 'templates.dart' show buildPlan;

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

/// 这个天数下的默认排法。
String defaultSplit(int days, String experience) => switch (days) {
  4 => 'ul',
  5 => 'ppl',
  _ => 'full',
};

/// 这个天数下可以选的排法，第一个是默认。
List<String> splitsFor(int days, String experience) => switch (days) {
  2 => ['full'],
  3 => ['full', 'ppl'],
  4 => ['ul', 'full'],
  _ => ['ppl', 'ul'],
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
/// TODO(plan-recipe): 目前是占位实现，借用旧模板拼出同样天数的方案，
/// 只保证接口和数据形状正确；生成规则由后续提交替换。
Map<String, dynamic> buildRecipePlan(
  Map<String, dynamic> recipe, {
  String startDate = '',
}) {
  final r = normalizeRecipe(recipe);
  final days = r['days'] as int;
  final templateId = switch ((days, r['venue'], r['split'])) {
    (2, _, _) => 'full-2',
    (4, _, _) => 'ul-4',
    (5, _, _) => 'ppl-5',
    (_, 'bodyweight', _) => 'bodyweight-3',
    (_, _, 'ppl') => 'bochi-ppl-3',
    (_, 'dumbbell', _) => 'dumbbell-3',
    _ => 'bochi-ppl-3',
  };
  final plan = buildPlan(
    templateId,
    profile: {
      'experience': r['experience'],
      'sex': r['sex'],
      'venue': r['venue'],
    },
    startDate: startDate,
  );
  final order = (plan['order'] as List).cast<String>();
  final weekdays = (r['weekdays'] as List).cast<int>();
  final gym = r['venue'] == 'gym';
  plan['schedule'] = {
    for (final (i, d) in weekdays.indexed)
      if (i < order.length) '$d': order[i],
  };
  plan['venues'] = {
    if (gym)
      for (final d in weekdays) '$d': 'gym',
  };
  plan['recipe'] = r;
  return plans.normalizePlan(plan, startDate);
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
  return [
    for (final g in recipeGroups)
      {
        'group': g,
        'sets': _groupMuscles[g]!
            .map((m) => volume[m] ?? 0.0)
            .reduce((a, b) => a > b ? a : b),
        'low': 4,
        'high': 12,
        'focus': focus.contains(g),
      },
  ];
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
