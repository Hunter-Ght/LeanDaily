/// 稳定训练满 8 周后，建议从入门方案换到更高阶的方案。
///
/// 纯函数，只给建议，不改计划：用户点「看看」进入模板预览，点「先不」后 28 天内不再提示。
library;

import 'calendar.dart' show daysApart, mondayOf;
import 'format.dart';
import 'progress.dart' show recentRedFlag;
import 'progress_options.dart';
import 'template_data.dart' show templates;
import 'templates.dart' show recommend;

/// 入门级方案：练稳了才会提示换更高阶的。其余方案（含自己改过或自己建的）不提示。
const entryTemplateIds = {'full-2', 'bodyweight-3', 'dumbbell-3'};

/// 看过一遍「先不」之后多少天内不再提示。
const planUpgradeSnoozeDays = 28;

/// 统计的周数，以及其中至少几周要达标。
const planUpgradeWeeks = 8;
const planUpgradeMinGoodWeeks = 6;

/// 一周里练满计划天数的 80% 才算「达标周」。
const planUpgradeWeekRate = .8;

const planUpgradeKey = 'planUpgrade';

/// 计划里每周安排了几天训练（有对应训练日的才算）。
int plannedDaysPerWeek(Map<String, dynamic> plan) {
  final workouts = jsonMap(plan['workouts']);
  return jsonMap(plan['schedule']).values
      .where((id) => jsTruthy(workouts[id]))
      .length;
}

/// 本周之前最近 8 个整周（周一到周日）里，每周实际练了几天（有正式组才算一天）。
/// 下标 0 是最近的一周。
List<int> trainingDaysPerWeek(Map<String, dynamic> days, String today) {
  final monday = mondayOf(today);
  final counts = List.filled(planUpgradeWeeks, 0);
  for (final e in days.entries) {
    if (e.key.compareTo(today) > 0) continue;
    final back = daysApart(mondayOf(e.key), monday);
    if (back < 7 || back > planUpgradeWeeks * 7) continue;
    final did = jsonRows(jsonMap(e.value)['sets']).any(
      (s) => s['type'] != '热身' && !jsTruthy(s['deleted']) && jsTruthy(s['ex']),
    );
    if (did) counts[back ~/ 7 - 1]++;
  }
  return counts;
}

/// 近 8 个整周里达标的周数（练了计划天数的 80% 以上）。计划还没满 8 周时返回 0。
int stableWeeks(
  Map<String, dynamic> plan,
  Map<String, dynamic> days,
  String today,
) {
  final planned = plannedDaysPerWeek(plan);
  if (planned == 0) return 0;
  final start = plan['startDate'];
  if (start is String &&
      start.isNotEmpty &&
      daysApart(start, mondayOf(today)) < planUpgradeWeeks * 7) {
    return 0;
  }
  return trainingDaysPerWeek(
    days,
    today,
  ).where((n) => n >= planned * planUpgradeWeekRate).length;
}

/// 给入门方案的使用者推荐更高阶的方案：场地是硬条件，每周天数、经验、路线按
/// [recommend] 的得分排。没有合适的（例如只有徒手训练条件）返回 null。
Map<String, dynamic>? upgradeTarget({
  required String templateId,
  required Map<String, dynamic> profile,
  required Map<String, dynamic> targets,
}) {
  final ranked = recommend(profile, targets);
  for (final r in ranked) {
    final id = r['templateId'] as String;
    if (id == templateId ||
        entryTemplateIds.contains(id) ||
        id == 'legacy-home-gym-3') {
      continue;
    }
    return r;
  }
  return null;
}

/// 「可以换更高阶方案」的建议；条件不满足返回 null。
///
/// - [templateId]：当前使用的方案来自哪个模板（自己建的、改过来源的传 null）；
/// - 近 8 个整周里至少 6 周练到计划天数的 80%，并且这个计划已经用满 8 周；
/// - 近 14 天没有疼痛或「不舒服」，不在减量周；
/// - 28 天内点过「先不」就不再提示。
Map<String, dynamic>? planUpgradeSuggestion({
  required String? templateId,
  required Map<String, dynamic> plan,
  required Map<String, dynamic> days,
  required Map<String, dynamic> dayStates,
  required Map<String, dynamic>? progress,
  required String today,
  required Map<String, dynamic>? profile,
  Map<String, dynamic>? targets,
  ProgressOptions? options,
}) {
  if (templateId == null ||
      !entryTemplateIds.contains(templateId) ||
      profile == null ||
      options?.deloadActive == true) {
    return null;
  }
  if (options?.youth == true) return null;
  final declined = jsonMap(progress?['declined'])[planUpgradeKey];
  if (declined is String &&
      daysApart(declined, today) < planUpgradeSnoozeDays) {
    return null;
  }
  if (recentRedFlag(days, dayStates, today)) return null;
  final good = stableWeeks(plan, days, today);
  if (good < planUpgradeMinGoodWeeks) return null;
  final target = upgradeTarget(
    templateId: templateId,
    profile: profile,
    targets: targets ?? const {},
  );
  if (target == null) return null;
  final name = templates.firstWhere(
    (t) => t['id'] == target['templateId'],
  )['name'];
  return {
    'kind': 'planUpgrade',
    'key': planUpgradeKey,
    'title': '稳定练了 8 周，可以换更高阶的方案了',
    'body': '近 8 周里有 $good 周练满了计划天数，基础已经打稳。可以看看「$name」，先预览，不会改动你现在的方案。',
    'templateId': target['templateId'],
    'good': good,
  };
}
