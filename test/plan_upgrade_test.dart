import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/domain/format.dart';
import 'package:leandaily/domain/plan_upgrade.dart';
import 'package:leandaily/domain/progress.dart' as p;
import 'package:leandaily/domain/progress_options.dart';
import 'package:leandaily/domain/templates.dart';

/// 计划 2026-01-05（周一）开始；today 是第 9 周的周三。
const start = '2026-01-05';
const today = '2026-03-04';
final profile = {
  'venue': 'dumbbell',
  'daysPerWeek': 3,
  'experience': 'new',
  'sex': 'male',
};

Map<String, dynamic> plan([String id = 'full-2']) =>
    buildPlan(id, startDate: start);

/// weeks：每一周练几天（下标 0 = 计划第 1 周）。
Map<String, dynamic> daysFor(List<int> weeks) {
  final out = <String, dynamic>{};
  for (final (w, n) in weeks.indexed) {
    for (var d = 0; d < n; d++) {
      out[shiftDate(start, w * 7 + d * 2)] = {
        'sets': [
          {'ex': '深蹲', 'reps': 10, 'w': 0, 'type': '正式'},
        ],
      };
    }
  }
  return out;
}

Map<String, dynamic>? ask({
  String? templateId = 'full-2',
  Map<String, dynamic>? thePlan,
  required Map<String, dynamic> days,
  Map<String, dynamic> states = const {},
  Map<String, dynamic>? progress,
  Map<String, dynamic>? theProfile,
  String day = today,
  ProgressOptions? options = const ProgressOptions(experience: 'new'),
}) => planUpgradeSuggestion(
  templateId: templateId,
  plan: thePlan ?? plan(templateId ?? 'full-2'),
  days: days,
  dayStates: states,
  progress: progress,
  today: day,
  profile: theProfile ?? profile,
  options: options,
);

void main() {
  final good = daysFor(List.filled(14, 2)); // 第 1～14 周都练满 2 天

  test('满 8 周、至少 6 周达到计划天数的 80%：推荐更高阶的方案', () {
    final s = ask(days: good)!;
    expect(s['kind'], 'planUpgrade');
    expect(s['good'], 8);
    expect(s['templateId'], 'bochi-ppl-3');
    expect('${s['body']}', contains('薄肌三练'));
    expect(entryTemplateIds.contains(s['templateId']), false);
  });

  test('8 周里恰好 6 周达标够，5 周不够；练得少于 80% 的周不算', () {
    expect(ask(days: daysFor([2, 2, 1, 2, 2, 1, 2, 2]))?['good'], 6);
    expect(ask(days: daysFor([2, 2, 1, 2, 2, 1, 1, 2])), isNull);
    expect(ask(days: daysFor([2, 0, 0, 2, 2, 2, 2, 2])), isNotNull);
    expect(ask(days: daysFor([2, 0, 0, 0, 2, 2, 2, 2])), isNull);
  });

  test('只统计整周：本周的训练不算，计划不满 8 周不提示', () {
    final extra = {...good, '2026-03-02': good['2026-01-05']}; // 本周周一
    expect(ask(days: extra)!['good'], 8);
    // 计划第 8 周周三：只有 7 个整周。
    expect(ask(days: good, day: '2026-02-25'), isNull);
    // 第 9 周周一就满 8 个整周。
    expect(ask(days: good, day: '2026-03-02'), isNotNull);
  });

  test('3 天的计划要练满 3 天才算达标', () {
    final three = daysFor([3, 3, 3, 3, 3, 3, 3, 3]);
    final s = ask(
      templateId: 'bodyweight-3',
      days: three,
      theProfile: {...profile, 'venue': 'both'},
    );
    expect(s, isNotNull);
    final two = daysFor([2, 2, 2, 2, 2, 2, 2, 2]);
    expect(
      ask(
        templateId: 'bodyweight-3',
        days: two,
        theProfile: {...profile, 'venue': 'both'},
      ),
      isNull,
    );
  });

  test('只对入门方案提示；自己建的方案和已经是高阶的不提示', () {
    expect(ask(templateId: null, days: good), isNull);
    for (final id in ['bochi-ppl-3', 'ul-4', 'ppl-5', 'refine-3']) {
      expect(
        ask(templateId: id, days: good),
        isNull,
        reason: id,
      );
    }
    for (final id in entryTemplateIds) {
      expect(
        ask(
          templateId: id,
          thePlan: plan(id),
          days: daysFor([3, 3, 3, 3, 3, 3, 3, 3]),
          theProfile: {...profile, 'venue': 'both'},
        ),
        isNotNull,
        reason: id,
      );
    }
  });

  test('按场地和每周天数匹配：只有徒手条件时没有可推荐的；想练 4 天推上下肢', () {
    expect(
      ask(days: good, theProfile: {...profile, 'venue': 'bodyweight'}),
      isNull,
    );
    expect(
      ask(
        days: good,
        theProfile: {...profile, 'daysPerWeek': 4, 'experience': 'some'},
      )!['templateId'],
      'ul-4',
    );
    final gym = upgradeTarget(
      templateId: 'full-2',
      profile: {...profile, 'venue': 'gym'},
      targets: {},
    );
    expect(gym!['templateId'], 'bochi-ppl-3');
  });

  test('点「先不」后 28 天内不再提示，第 28 天起可以再提示', () {
    final declined = p.decline(null, planUpgradeKey, today);
    for (var i = 0; i < 28; i++) {
      expect(
        ask(days: good, progress: declined, day: shiftDate(today, i)),
        isNull,
        reason: '$i',
      );
    }
    expect(
      ask(days: good, progress: declined, day: shiftDate(today, 28)),
      isNotNull,
    );
  });

  test('近 14 天有疼痛或「不舒服」、减量周、成长期都不提示', () {
    expect(
      ask(
        days: good,
        states: {
          '2026-03-01': {'ready': 'bad'},
        },
      ),
      isNull,
    );
    expect(
      ask(
        days: good,
        states: {
          '2026-02-15': {'ready': 'bad'},
        },
      ),
      isNotNull,
    );
    final pain = {
      ...good,
      '2026-03-02': {
        'sets': [
          {'ex': '深蹲', 'reps': 8, 'w': 0, 'type': '正式', 'flag': 'pain'},
        ],
      },
    };
    expect(ask(days: pain), isNull);
    expect(
      ask(days: good, options: const ProgressOptions(deloadActive: true)),
      isNull,
    );
    expect(
      ask(
        days: good,
        options: const ProgressOptions(stage: 'youth'),
      ),
      isNull,
    );
  });

  test('热身组和已删除的组不算训练', () {
    final warm = {
      for (final e in good.entries)
        e.key: {
          'sets': [
            {'ex': '深蹲', 'reps': 10, 'type': '热身'},
          ],
        },
    };
    expect(ask(days: warm), isNull);
    expect(trainingDaysPerWeek(good, today).every((n) => n == 2), true);
  });
}
