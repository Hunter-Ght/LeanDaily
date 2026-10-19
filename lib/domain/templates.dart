/// Deterministic, fresh version-2 plan JSON. No storage or current-clock access.
library;

import 'catalog.dart' show catalog;
import 'guide.dart' show guideFor;
import 'plan.dart' as plans;
import 'template_data.dart';
export 'template_data.dart' show templates, defaultTemplateId;

Map<String, dynamic> _template(String id) => templates.firstWhere(
  (t) => t['id'] == id,
  orElse: () => throw ArgumentError.value(id, 'templateId', '未知训练模板'),
);

/// Uses the existing default plan only as the shared JSON envelope. Generated
/// workout IDs deliberately avoid w1/w2/w3, which normalizePlan auto-attaches.
Map<String, dynamic> buildPlan(
  String templateId, {
  Map<String, dynamic>? profile,
  String startDate = '',
}) {
  _template(templateId);
  final plan = plans.defaultPlan(startDate);
  final beginner =
      profile?['experience'] == null || profile?['experience'] == 'new';
  final female = profile?['sex'] == 'female' || templateId == 'lean-female-3';
  final bodyweight = templateId == 'bodyweight-3';
  if (templateId != 'legacy-home-gym-3') {
    final days = templateDays[templateId]!;
    final weekdays = switch (days.length) {
      2 => [1, 4],
      4 => [1, 2, 4, 5],
      5 => [1, 2, 3, 5, 6],
      _ => [1, 3, 5],
    };
    // 自重计划也带一套健身房版：没选场地的新用户默认拿到它，今日页仍能切到健身房。
    final homeOnly = templateId == 'dumbbell-3';
    final chestSeen = <String, bool>{};
    final workouts = <String, dynamic>{};
    final schedule = <String, dynamic>{};
    final venues = <String, dynamic>{};
    for (final (i, day) in days.indexed) {
      final id = 't${i + 1}';
      List<Map<String, dynamic>> list(List<String> names, String venue) {
        return [
          for (final (j, original) in names.indexed)
            (() {
              var name = original;
              // Reduce duplicate chest work in favour of glutes for women.
              if (female && catalog()[name]?['part'] == '胸') {
                if (chestSeen[venue] == true) {
                  name = names.contains('臀桥') ? '单腿臀桥' : '臀桥';
                }
                chestSeen[venue] = true;
              }
              if (female && templateId == 'refine-3' && name == '侧平板支撑') {
                name = '臀桥';
              }
              final ex = _exercise(name);
              final core = j < day.coreCount;
              return <String, dynamic>{
                ...ex,
                'id': '${id}_${venue}_${j + 1}',
                'sets': beginner || bodyweight ? 2 : 3,
                'min': ex['unit'] == 'sec'
                    ? 20
                    : core && !bodyweight
                    ? 4
                    : 8,
                'max': ex['unit'] == 'sec'
                    ? 40
                    : core && !bodyweight
                    ? 6
                    : 12,
                'core': core,
                'optional': false,
                'rest': core ? 120 : 60,
                if (name == '高位俯卧撑') 'ladder': 'pushup',
              };
            })(),
        ];
      }

      workouts[id] = <String, dynamic>{
        'name': day.name,
        'short': day.short,
        'tag': _template(templateId)['name'],
        'note': '每组留 2～3 次余力，不追求力竭',
        'exercises': list(day.home, 'home'),
        if (!homeOnly)
          'gym': <String, dynamic>{
            'tag': _template(templateId)['name'],
            'note': '同一天居家和健身房二选一，不要叠加。',
            'exercises': list(day.gym, 'gym'),
          },
      };
      schedule['${weekdays[i]}'] = id;
      if (!homeOnly && profile?['venue'] == 'gym') {
        venues['${weekdays[i]}'] = 'gym';
      }
    }
    plan['workouts'] = workouts;
    plan['schedule'] = schedule;
    plan['order'] = workouts.keys.toList();
    plan['venues'] = venues;
    // New templates use a 4–6 core prescription at every pushup stage.
    final ladder = plan['ladders']['pushup'] as Map<String, dynamic>;
    for (final step in ladder['steps'] as List) {
      step['min'] = bodyweight ? 8 : 4;
      step['max'] = bodyweight ? 12 : 6;
      step['hint'] = bodyweight
          ? '连续两次做满 12 次、动作不变形就升级；先增加标准次数，再用背包逐步加重。'
          : '连续两次做满 6 次、动作不变形就升级；每组留 2～3 次余力。';
    }
  } else {
    // Keep the legacy exercise selection, ladders and prescriptions; adapt only
    // starting volume and the explicitly requested generic protein defaults.
    for (final w in (plan['workouts'] as Map<String, dynamic>).values) {
      for (final variant in [w, w['gym']]) {
        for (final ex in variant['exercises'] as List) {
          ex['sets'] = beginner ? 2 : 3;
          if (female && ex['part'] == '胸') ex['sets'] = 2;
        }
      }
    }
    if (profile?['venue'] == 'gym') {
      plan['venues'] = <String, dynamic>{'1': 'gym', '3': 'gym', '5': 'gym'};
    }
  }
  if (templateId == 'legacy-home-gym-3') {
    for (final workout in (plan['workouts'] as Map).values) {
      final name = workout['name'] as String;
      workout['short'] = name.substring(0, 1);
    }
  }
  plan['protein'] = <String, dynamic>{
    'goal': 130,
    'powder': <String, dynamic>{
      'name': '蛋白粉',
      'grams': 30,
      'protein': 22.6,
      'kcal': 124,
    },
  };
  // Normalize once to fill all canonical fields, notably img on legacy specs.
  return plans.normalizePlan(plan);
}

Map<String, dynamic> _exercise(String name) {
  final spec = catalog()[name];
  if (spec != null) {
    final guide = guideFor({'name': name});
    return <String, dynamic>{
      ...spec,
      'gear': (spec['gear'] as String).isNotEmpty
          ? spec['gear']
          : name.contains('哑铃')
          ? (name.contains('平板') || name.contains('上斜') ? '哑铃和稳固训练凳' : '哑铃')
          : name,
      if (guide != null && (spec['tip'] as String).startsWith('替代'))
        'tip': (guide['steps'] as List).join('；'),
      'alts': <Map<String, dynamic>>[],
      'img': '',
    };
  }
  // Template-owned specs for names absent from catalog/guide. Muscle mappings
  // exist in movements.dart; no demonstration image is invented.
  final (part, gear, tip, alts) = switch (name) {
    '硬拉' => (
      '腿',
      '杠铃',
      '髋向后推、背保持自然平直，杠铃贴近腿；先用轻重量练动作，不要弓背硬拉。',
      <Map<String, dynamic>>[
        {'name': '轻哑铃罗马尼亚硬拉'},
      ],
    ),
    '引体向上' => (
      '背',
      '固定牢固的单杠',
      '肩胛先下沉，不甩腿；做不到目标次数时改辅助引体向上机。',
      <Map<String, dynamic>>[
        {'name': '辅助引体向上机', 'machine': true},
      ],
    ),
    '反向划船' => (
      '背',
      '稳固且能承重、不翻倒的桌子',
      '从桌下握稳边缘，把胸拉向桌边；桌子滑动、倾倒或握不牢就不要做，改超人式。',
      <Map<String, dynamic>>[
        {'name': '超人式'},
      ],
    ),
    _ => throw StateError('模板动作缺少 spec：$name'),
  };
  return <String, dynamic>{
    'name': name,
    'part': part,
    'unit': 'reps',
    'side': false,
    'weight': 0,
    'machine': false,
    'gear': gear,
    'tip': tip,
    'alts': alts,
    'img': '',
  };
}

/// Scores are additive and reasons expose every awarded component. Equipment
/// availability is a hard filter; days/experience are preferences, so e.g. a
/// two-day beginner plan remains available to someone with three free days.
List<Map<String, dynamic>> recommend(
  Map<String, dynamic> profile,
  Map<String, dynamic> targets,
) {
  final venue = profile['venue'] as String? ?? 'dumbbell';
  final days = profile['daysPerWeek'] is num
      ? (profile['daysPerWeek'] as num).toInt()
      : 3;
  final experience = profile['experience'] as String? ?? 'new';
  final stage = targets['stage'];
  final out = <Map<String, dynamic>>[];
  for (final t in templates) {
    if (!(t['venues'] as List).contains(venue)) continue;
    final id = t['id'] as String;
    var score = 0;
    final reasons = <String>[];
    void add(int points, String reason) {
      score += points;
      reasons.add(reason);
    }

    final count = t['days'] as int;
    if (count == days) {
      add(60, '每周 $days 天，与你的安排一致');
    } else {
      score -= (count - days).abs() * 15;
      reasons.add('每周 $count 天，与你的 $days 天安排不同');
    }
    add(25, switch (venue) {
      'bodyweight' => '无需哑铃或健身房器械',
      'gym' => '提供健身房练法',
      'both' => '符合你的可用场地',
      _ => '可以使用居家哑铃训练',
    });
    if ((t['level'] as List).contains(experience)) {
      add(15, '适合你的训练经验');
    } else {
      score -= 25;
      reasons.add('训练频率或经验要求较高，建议先建立基础');
    }
    if (id == defaultTemplateId) add(8, '肩、上胸、背阔与核心兼顾');
    if (profile['sex'] == 'female' && id == 'lean-female-3') {
      add(80, '女性优先，肩背臀腿比例更高');
    }
    if (stage == 'refine' && id == 'refine-3') add(90, '精修阶段优先肩背腹补强');
    if (stage == 'bulk' && (id == 'full-2' || id == 'ul-4')) {
      add(90, '增肌阶段优先全身或上下肢训练');
    }
    out.add({'templateId': id, 'score': score, 'reasons': reasons});
  }
  // Explicit catalog-order tie-break keeps the result deterministic.
  out.sort((a, b) {
    final byScore = (b['score'] as int).compareTo(a['score'] as int);
    return byScore != 0
        ? byScore
        : templates
              .indexWhere((t) => t['id'] == a['templateId'])
              .compareTo(
                templates.indexWhere((t) => t['id'] == b['templateId']),
              );
  });
  return out;
}

/// Compact, factual reasons for the recommendation card.
List<String> matchReasons(
  Map<String, dynamic> profile,
  Map<String, dynamic> template,
) => [
  if (profile['daysPerWeek'] == template['days']) '每周 ${template['days']} 天',
  if ((template['venues'] as List).contains(profile['venue']))
    switch (profile['venue']) {
      'bodyweight' => '在家无哑铃',
      'gym' => '健身房',
      'both' => '两边都会去',
      _ => '在家有哑铃',
    },
  if ((template['level'] as List).contains(profile['experience']))
    switch (profile['experience']) {
      'some' => '有基础',
      'trained' => '老手',
      _ => '新手',
    },
];

int templateLevel(Map<String, dynamic> template) {
  final levels = template['level'] as List? ?? [];
  return levels.contains('new')
      ? 1
      : levels.contains('some')
      ? 2
      : 3;
}
