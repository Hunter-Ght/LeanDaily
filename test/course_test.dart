import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/core/native.dart';
import 'package:leandaily/data/backup.dart';
import 'package:leandaily/data/benchmark_store.dart';
import 'package:leandaily/data/repository.dart';
import 'package:leandaily/domain/benchmarks.dart';
import 'package:leandaily/domain/calendar.dart' as calendar;
import 'package:leandaily/domain/cardio.dart';
import 'package:leandaily/domain/course.dart';
import 'package:leandaily/domain/deload.dart';
import 'package:leandaily/domain/plan.dart' as plans;
import 'package:leandaily/domain/progress.dart' as p;
import 'package:leandaily/domain/progress_options.dart';
import 'package:leandaily/domain/records.dart' show DomainError;

/// 2026-10-21 是周三；开始日所在周的周一是 10-19。
const start = '2026-10-21';
final startMonday = calendar.mondayOf(start);
final course = newCourse(start);

Map<String, dynamic> day(
  String date, {
  String type = '正式',
  bool deleted = false,
  String ex = '哑铃卧推',
  num w = 20,
  num reps = 10,
  int sets = 2,
  num? rpe,
}) => {
  'sets': [
    for (var i = 0; i < sets; i++)
      {
        'ex': ex,
        'w': w,
        'reps': reps,
        'type': type,
        'rpe': ?rpe,
        if (deleted) 'deleted': true,
      },
  ],
};

/// 开始日所在周之后，第 [n] 个周一（n 从 1 起）。
String weekN(int n) => calendar.shiftDate(startMonday, 7 * n);

/// 在开始日之后的 [weeks] 个整周里各练一天（周三）。
Map<String, dynamic> trainedFor(Iterable<int> weeks) => {
  for (final n in weeks)
    calendar.shiftDate(weekN(n), 2): day(calendar.shiftDate(weekN(n), 2)),
};

CourseState? stateOn(Map<String, dynamic> days, String date) =>
    courseState(course, trainedWeeksOf(days), date);

void main() {
  group('课程设置', () {
    test('只有格式正确的 course 字段才算有课程', () {
      expect(courseOf({'course': course}), course);
      expect(
        courseOf({
          'course': {'v': 1, 'start': start, 'weeks': 8},
        }),
        course,
      );
      expect(courseOf({}), isNull);
      expect(courseOf(null), isNull);
      expect(
        courseOf({
          'course': {'v': 2, 'start': start},
        }),
        isNull,
      );
      expect(
        courseOf({
          'course': {'v': 1, 'start': '2026-02-30'},
        }),
        isNull,
      );
      expect(
        courseOf({
          'course': {'v': 1, 'start': 'x'},
        }),
        isNull,
      );
      expect(courseOf({'course': 'yes'}), isNull);
    });
  });

  group('第几周按练了的周算', () {
    test('开始日所在周永远是第 1 周，当周的训练不计', () {
      final days = {'2026-10-22': day('2026-10-22')};
      for (final d in ['2026-10-21', '2026-10-22', '2026-10-25']) {
        final s = stateOn(days, d)!;
        expect(s.week, 1);
        expect(s.phase, CoursePhase.base);
        expect(s.done, false);
        expect(s.weekStart, start);
      }
      // 开始日以前没有课程。
      expect(stateOn(days, '2026-10-20'), isNull);
    });

    test('练了的整周才推进；停练的周不计', () {
      // 第 1、2 个整周练了，第 3 个整周没练，第 4 个整周练了。
      final days = trainedFor([1, 2, 4]);
      expect(stateOn(days, calendar.shiftDate(weekN(1), 3))!.week, 1);
      expect(stateOn(days, calendar.shiftDate(weekN(2), 3))!.week, 2);
      expect(stateOn(days, calendar.shiftDate(weekN(3), 3))!.week, 3);
      // 第 3 个整周什么都没练：第 4 个整周仍是课程第 3 周。
      expect(stateOn(days, calendar.shiftDate(weekN(4), 0))!.week, 3);
      expect(stateOn(days, calendar.shiftDate(weekN(5), 0))!.week, 4);
      // 停练很久回来，课程周不变，也不会白白耗掉。
      final back = stateOn(days, calendar.shiftDate(weekN(20), 0))!;
      expect(back.week, 4);
      expect(back.weekStart, weekN(5));
    });

    test('热身组和已删除的记录不算练了', () {
      final days = {
        calendar.shiftDate(weekN(1), 2): day(
          calendar.shiftDate(weekN(1), 2),
          type: '热身',
        ),
        calendar.shiftDate(weekN(2), 2): day(
          calendar.shiftDate(weekN(2), 2),
          deleted: true,
        ),
      };
      expect(stateOn(days, calendar.shiftDate(weekN(3), 0))!.week, 1);
    });

    test('一周练几天都只算一周', () {
      final days = {
        for (var i = 0; i < 5; i++)
          calendar.shiftDate(weekN(1), i): day(calendar.shiftDate(weekN(1), i)),
      };
      expect(stateOn(days, weekN(2))!.week, 2);
    }, tags: const []);

    test('封顶 12；12 个练了的整周才算完成', () {
      final eleven = trainedFor(List.generate(11, (i) => i + 1));
      var s = stateOn(eleven, weekN(12))!;
      expect(s.week, 12);
      expect(s.done, false);
      expect(s.phase, CoursePhase.retest);
      expect(s.weekStart, weekN(12));
      // 第 12 个整周练完（进入下一周）才算完成。
      final twelve = trainedFor(List.generate(12, (i) => i + 1));
      s = stateOn(twelve, weekN(12))!;
      expect(s.week, 12);
      expect(s.done, false, reason: '第 12 周还在进行');
      s = stateOn(twelve, weekN(13))!;
      expect(s.week, 12);
      expect(s.done, true);
      expect(s.phase, isNull);
      // 之后再练多少周也封顶 12。
      final many = trainedFor(List.generate(20, (i) => i + 1));
      expect(stateOn(many, weekN(30))!.week, 12);
    });

    test('阶段按课程周划分', () {
      expect(
        [for (var w = 1; w <= 12; w++) phaseOfWeek(w)],
        [
          ...List.filled(4, CoursePhase.base),
          ...List.filled(4, CoursePhase.build),
          ...List.filled(3, CoursePhase.push),
          CoursePhase.retest,
        ],
      );
    });
  });

  group('各阶段的组数', () {
    test('打底期：3 组以上少 1 组，2 组以下不变', () {
      expect(courseSets(5, CoursePhase.base), 4);
      expect(courseSets(3, CoursePhase.base), 2);
      expect(courseSets(2, CoursePhase.base), 2);
      expect(courseSets(1, CoursePhase.base), 1);
    });
    test('加量期、冲刺期按方案的组数', () {
      for (final phase in [CoursePhase.build, CoursePhase.push]) {
        for (final n in [1, 2, 3, 4]) {
          expect(courseSets(n, phase), n);
        }
      }
    });
    test('复测周：每个动作少 1 组，最少 1 组', () {
      expect(courseSets(4, CoursePhase.retest), 3);
      expect(courseSets(2, CoursePhase.retest), 1);
      expect(courseSets(1, CoursePhase.retest), 1);
    });
    test('完成后（没有阶段）回到方案的组数', () {
      expect(courseSets(3, null), 3);
    });

    test('setsFor：不传课程周，或方案没有课程，行为不变', () {
      final ex = {'sets': 3};
      expect(plans.setsFor({}, ex), 3);
      expect(plans.setsFor({}, ex, '2026-10-22'), 3);
      expect(plans.setsFor({}, ex, '2026-10-22', 1), 3, reason: '没有课程');
      expect(plans.setsFor({'course': course}, ex, '2026-10-22'), 3);
      expect(plans.setsFor({'course': course}, ex, '2026-10-22', 1), 2);
      expect(plans.setsFor({'course': course}, ex, '2026-10-22', 6), 3);
      expect(plans.setsFor({'course': course}, ex, '2026-10-22', 12), 2);
      expect(plans.setsFor({'course': course}, {'sets': 1}, null, 12), 1);
    });

    test('exercisesFor 用调用方给的组数', () {
      final plan = {
        'course': course,
        'workouts': {
          'a': {
            'exercises': [
              {'id': 'x', 'name': '深蹲', 'sets': 3, 'min': 8, 'max': 12},
            ],
          },
        },
      };
      final workout = (plan['workouts'] as Map)['a'] as Map<String, dynamic>;
      expect(plans.exercisesFor(plan, workout, start).single['target'], 3);
      expect(
        plans
            .exercisesFor(
              plan,
              workout,
              start,
              false,
              (e) => plans.setsFor(plan, e, start, 1),
            )
            .single['target'],
        2,
      );
    });
  });

  group('进阶规则里的组数', () {
    final ex = {
      'id': 'e',
      'name': '哑铃卧推',
      'part': '胸',
      'sets': 3,
      'min': 8,
      'max': 12,
      'weight': 20,
    };
    final withCourse = ProgressOptions(course: course);
    const without = ProgressOptions();
    const today = '2026-10-28'; // 开始日的下一周，课程第 1 周

    int setsOf(
      Map<String, dynamic> e,
      ProgressOptions o, {
      String at = today,
      Map<String, dynamic> days = const {},
    }) => (p.targetFor(e, days, today: at, options: o)['sets'] as num).toInt();

    test('没有 course 字段：组数和以前完全一样', () {
      expect(setsOf(ex, without), 3);
      expect(setsOf(ex, ProgressOptions(course: null)), 3);
      expect(p.targetFor(ex, {}, today: today)['sets'], 3);
    });

    test('打底期少 1 组，之后按阶段', () {
      expect(setsOf(ex, withCourse), 2);
      expect(setsOf({...ex, 'sets': 2}, withCourse), 2);
      // 第 5 个课程周（4 个练了的整周之后）按方案，第 12 周少 1 组，完成后恢复。
      String at(int done) => weekN(done + 1);
      expect(
        setsOf(ex, withCourse, at: at(4), days: trainedFor([1, 2, 3, 4])),
        3,
      );
      expect(
        setsOf(
          ex,
          withCourse,
          at: at(11),
          days: trainedFor(List.generate(11, (i) => i + 1)),
        ),
        2,
      );
      expect(
        setsOf(
          ex,
          withCourse,
          at: at(12),
          days: trainedFor(List.generate(12, (i) => i + 1)),
        ),
        3,
      );
    });

    test('和减量周、断练回归叠加，但最少 1 组', () {
      const deload = ProgressOptions(deloadActive: true);
      final both = ProgressOptions(deloadActive: true, course: course);
      expect(setsOf(ex, deload), 2);
      expect(setsOf(ex, both), 1, reason: '3 组：课程 -1，减量 -1');
      expect(setsOf({...ex, 'sets': 2}, both), 1, reason: '2 组：只有减量 -1');
      expect(setsOf({...ex, 'sets': 1}, both), 1);
      // 第 12 周的复测 + 减量：2 组 -> 1 组，不会是 0。
      final days = trainedFor(List.generate(11, (i) => i + 1));
      expect(setsOf({...ex, 'sets': 2}, both, at: weekN(12), days: days), 1);
      expect(setsOf({...ex, 'sets': 1}, both, at: weekN(12), days: days), 1);
      // 断练回归（隔 14 天以上）+ 打底期：同样最少 1 组。
      final old = {'2026-10-21': day('2026-10-21', ex: '哑铃卧推', sets: 3)};
      expect(setsOf(ex, withCourse, at: '2026-11-18', days: old), 1);
    });

    test('课程少做的组数也算做完，不会被当成没达标', () {
      // 打底期 3 组的动作做了 2 组、次数达标。
      final days = {
        '2026-10-22': {
          'sets': [
            for (var i = 0; i < 2; i++)
              {'ex': '哑铃卧推', 'w': 20, 'reps': 8, 'type': '正式'},
          ],
        },
      };
      final withIt = p.targetFor(
        ex,
        days,
        today: today,
        options: ProgressOptions(experience: 'new', course: course),
      );
      expect((withIt['last'] as Map)['met'], true);
      expect(withIt['stuck'], 0);
      expect(withIt['reps'], 9, reason: '新手一次达标就 +1');
      final plain = p.targetFor(
        ex,
        days,
        today: today,
        options: const ProgressOptions(experience: 'new'),
      );
      expect((plain['last'] as Map)['met'], false);
      expect(plain['stuck'], 1);
    });

    test('加组建议：打底期和复测周不出现', () {
      Map<String, dynamic> ctx(String at, Map<String, dynamic> days) => {
        'plan': {
          'startDate': '2026-01-01',
          'workouts': {
            'a': {
              'exercises': [
                {...ex, 'sets': 2},
              ],
            },
          },
        },
        'days': days,
        'dayStates': <String, dynamic>{},
        'progress': {
          ...p.emptyProgress(),
          'anchors': {
            '哑铃卧推': {
              'date': calendar.shiftDate(
                (days.keys.toList()..sort()).first,
                -3,
              ),
              'reps': 10,
              'weight': 20,
            },
          },
        },
        'today': at,
        'review': {
          'adherence': {'rate': 1},
          'redFlag': false,
          'groups': {
            'chest': {'week': 0, 'last': 0},
          },
        },
      };
      final two = {...ex, 'sets': 2};
      // 连续 4 次卡在目标（9 次 < 10 次，但没低于区间下限）。
      Map<String, dynamic> stuck(String from) => {
        for (var i = 0; i < 4; i++)
          calendar.shiftDate(from, 7 * i): {
            'sets': [
              for (var s = 0; s < 2; s++)
                {'ex': '哑铃卧推', 'w': 20, 'reps': 9, 'type': '正式'},
            ],
          },
      };
      String? kind(ProgressOptions o, String at, Map<String, dynamic> days) =>
          p.suggest(two, ctx(at, days), options: o)?['kind'] as String?;
      // 没有课程：已经练满 5 周以上、卡住了，会建议加组。
      final old = stuck('2026-09-14');
      expect(kind(const ProgressOptions(), '2026-10-12', old), 'sets');
      // 同样的记录放进课程打底期：不出现（其他建议照旧）。
      final inBase = stuck('2026-10-22');
      expect(kind(const ProgressOptions(), '2026-11-14', inBase), 'sets');
      expect(
        kind(ProgressOptions(course: course), '2026-11-14', inBase),
        isNot('sets'),
      );
      // 加量期、冲刺期没有这个限制；复测周不出现。
      Map<String, dynamic> lateStuck(int firstWeek, int lastWeek) => {
        // 前面的整周练别的动作，只为把课程周推进到位。
        ...trainedFor([for (var n = 1; n < firstWeek; n++) n]),
        for (var n = firstWeek; n <= lastWeek; n++)
          calendar.shiftDate(weekN(n), 2): {
            'sets': [
              for (var s = 0; s < 2; s++)
                {'ex': '哑铃卧推', 'w': 20, 'reps': 9, 'type': '正式'},
            ],
          },
      };
      final build = lateStuck(6, 9); // 现在是课程第 10 周
      final at10 = calendar.shiftDate(weekN(10), 1);
      expect(
        courseState(course, trainedWeeksOf(build), at10)!.phase,
        CoursePhase.push,
      );
      expect(kind(ProgressOptions(course: course), at10, build), 'sets');
      final retest = lateStuck(8, 11); // 现在是课程第 12 周
      final at12 = calendar.shiftDate(weekN(12), 1);
      expect(
        courseState(course, trainedWeeksOf(retest), at12)!.phase,
        CoursePhase.retest,
      );
      expect(kind(const ProgressOptions(), at12, retest), 'sets');
      expect(
        kind(ProgressOptions(course: course), at12, retest),
        isNot('sets'),
      );
    });
  });

  group('减量建议', () {
    test('课程第 12 周不弹减量建议，其余时候照常', () {
      final today = '2026-10-16';
      final monday = calendar.mondayOf(today);
      // 连续 14 周、每周三个有 RPE 9 的正式组，触发「连续高强度」。
      final days = {
        for (var w = 1; w <= 13; w++)
          calendar.shiftDate(monday, -7 * w + 2): day(
            calendar.shiftDate(monday, -7 * w + 2),
            rpe: 9,
          ),
      };
      final plan = plans.defaultPlan('2026-01-01');
      Map<String, dynamic>? ask(Map<String, dynamic>? c) => deloadSuggestion(
        days: days,
        dayStates: const {},
        progress: p.emptyProgress(),
        plan: plan,
        today: today,
        options: ProgressOptions(course: c),
      );
      expect(ask(null), isNotNull);
      // 开始日在 13 周前：已有 12 个练了的整周，课程完成，不受影响。
      expect(ask(newCourse(calendar.shiftDate(monday, -7 * 14))), isNotNull);
      // 开始日在 12 周前的周一：之后有 11 个练了的整周，现在是第 12 周。
      final c12 = newCourse(calendar.shiftDate(monday, -7 * 12));
      expect(
        courseState(c12, trainedWeeksOf(days), today)!.phase,
        CoursePhase.retest,
      );
      expect(ask(c12), isNull);
      // 第 8 周：照常。
      expect(ask(newCourse(calendar.shiftDate(monday, -7 * 8))), isNotNull);
    });
  });

  group('课程总结', () {
    // 12 个整周，每周练 3 天（周一、周三、周五）；动作每周多一次。
    Map<String, dynamic> build({int perWeek = 3, int weeks = 12}) => {
      for (var w = 1; w <= weeks; w++)
        for (var d = 0; d < perWeek; d++)
          calendar.shiftDate(weekN(w), d * 2): {
            'sets': [
              {'ex': '哑铃卧推', 'w': 20 + w, 'reps': 10, 'type': '正式'},
              {'ex': '俯卧撑', 'w': 0, 'reps': 8 + w, 'type': '正式'},
              {'ex': '平板支撑', 'w': 0, 'reps': 30 + 2 * w, 'type': '正式'},
              {'ex': '深蹲', 'w': 0, 'reps': 15, 'type': '正式'},
              {'ex': '热身深蹲', 'w': 0, 'reps': 30, 'type': '热身'},
            ],
          },
    };

    test('练了几天、达标周数', () {
      final s = courseSummary(course: course, days: build(), planDays: 3);
      expect(s['days'], 36);
      expect(s['hitWeeks'], 12);
      expect(s['weeks'], 12);
      final fewer = courseSummary(
        course: course,
        days: build(perWeek: 2),
        planDays: 3,
      );
      expect(fewer['days'], 24);
      expect(fewer['hitWeeks'], 0);
    });

    test('进步最大的动作：带重量比估算极限，自重比次数，计时比秒，没进步的不列', () {
      final s = courseSummary(
        course: course,
        days: build(),
        planDays: 3,
        timedNames: {'平板支撑'},
      );
      final top = (s['top'] as List).cast<Map<String, dynamic>>();
      expect(top.length, lessThanOrEqualTo(3));
      expect(top.map((e) => e['name']), isNot(contains('深蹲')));
      expect(top.map((e) => e['name']), isNot(contains('热身深蹲')));
      final push = top.firstWhere((e) => e['name'] == '俯卧撑');
      expect(push['kind'], 'reps');
      expect(push['from'], 9);
      expect(push['to'], 20);
      final plank = top.firstWhere(
        (e) => e['name'] == '平板支撑',
        orElse: () => {},
      );
      if (plank.isNotEmpty) expect(plank['kind'], 'sec');
      final bench = top.firstWhere((e) => e['name'] == '哑铃卧推');
      expect(bench['kind'], 'weight');
      // 估算极限：21 kg x 10 次 -> 28，32 kg x 10 次 -> 42.7
      expect(bench['from'], 28);
      expect(bench['to'], closeTo(42.7, .05));
      // 按提升比例排序。
      final ratios = top.map((e) => e['ratio'] as num).toList();
      expect(ratios, [...ratios]..sort((a, b) => b.compareTo(a)));
    });

    test('只统计课程期间的训练', () {
      final days = {
        ...build(),
        '2026-09-01': day('2026-09-01', ex: '哑铃卧推', w: 5),
        calendar.shiftDate(weekN(20), 2): day(calendar.shiftDate(weekN(20), 2)),
      };
      final s = courseSummary(course: course, days: days, planDays: 3);
      expect(s['days'], 36);
    });
  });

  group('小测试', () {
    test('校验：三项都可跳过，但至少一项；数字有范围', () {
      expect(cleanBenchmark(date: '2026-10-21', pushup: '12', plank: '45'), {
        'date': '2026-10-21',
        'pushup': {'n': 12, 'knee': false},
        'plank': {'sec': 45},
      });
      expect(
        cleanBenchmark(date: '2026-10-21', pushup: 6, pushupKnee: true),
        containsPair('pushup', {'n': 6, 'knee': true}),
      );
      expect(
        cleanBenchmark(date: '2026-10-21', pullType: 'assisted', pull: '12.34'),
        containsPair('pull', {'type': 'assisted', 'n': 12.3}),
      );
      expect(
        cleanBenchmark(date: '2026-10-21', pullType: 'row', pull: 8),
        containsPair('pull', {'type': 'row', 'n': 8}),
      );
      DomainError? err(void Function() f) {
        try {
          f();
        } on DomainError catch (e) {
          return e;
        }
        return null;
      }

      expect(err(() => cleanBenchmark(date: '2026-10-21')), isNotNull);
      expect(
        err(() => cleanBenchmark(date: '2026-10-21', pushup: '')),
        isNotNull,
      );
      expect(
        err(() => cleanBenchmark(date: '2026-02-30', pushup: 1)),
        isNotNull,
      );
      expect(
        err(() => cleanBenchmark(date: '2026-10-21', pushup: -1)),
        isNotNull,
      );
      expect(
        err(() => cleanBenchmark(date: '2026-10-21', pushup: 1.5)),
        isNotNull,
      );
      expect(
        err(() => cleanBenchmark(date: '2026-10-21', plank: 4000)),
        isNotNull,
      );
      expect(
        err(() => cleanBenchmark(date: '2026-10-21', pull: 5, pullType: 'x')),
        isNotNull,
      );
      expect(err(() => cleanBenchmark(date: '2026-10-21', pushup: 0)), isNull);
    });

    test('第一次与最近一次的对比', () {
      final entries = [
        {
          'date': '2026-10-21',
          'pushup': {'n': 8, 'knee': true},
          'plank': {'sec': 30},
        },
        {
          'date': '2027-01-13',
          'pushup': {'n': 15, 'knee': true},
          'plank': {'sec': 55},
          'pull': {'type': 'row', 'n': 9},
        },
      ];
      final rows = benchmarkRows(entries);
      expect(rows.map((r) => r['item']), ['pushup', 'plank', 'pull']);
      expect(rows[0]['comparable'], true);
      expect(rows[0]['first'], {'n': 8, 'knee': true});
      expect(rows[0]['latest'], {'n': 15, 'knee': true});
      expect(rows[2].containsKey('latest'), false, reason: '拉的项目只测过一次');
      // 换了做法就不能直接比数字。
      final changed = benchmarkRows([
        entries.first,
        {
          'date': '2027-01-13',
          'pushup': {'n': 5, 'knee': false},
        },
      ]);
      expect(changed.first['comparable'], false);
      expect(benchmarkRows([]), isEmpty);
      expect(benchmarksSince(entries, '2027-01-01'), [entries.last]);
    });
  });

  group('有氧建议', () {
    test('读取方案里的有氧目标', () {
      expect(
        cardioGoalOf({
          'cardio': {'perWeek': 2, 'minutes': 20},
        }),
        (perWeek: 2, minutes: 20),
      );
      expect(
        cardioGoalOf({
          'cardio': {'perWeek': 3},
        }),
        (perWeek: 3, minutes: 20),
      );
      expect(cardioGoalOf({}), isNull);
      expect(
        cardioGoalOf({
          'cardio': {'perWeek': 0},
        }),
        isNull,
      );
      expect(
        cardioGoalOf({
          'cardio': {'perWeek': 2.5},
        }),
        isNull,
      );
      expect(cardioGoalOf(null), isNull);
    });
    test('本周已记录的次数（周一到周日）', () {
      final rows = [
        {'date': '2026-10-18'},
        {'date': '2026-10-19'},
        {'date': '2026-10-25'},
        {'date': '2026-10-26'},
      ];
      expect(cardioSessionsInWeek(rows, '2026-10-21'), 2);
      expect(cardioSessionsInWeek(rows, '2026-10-26'), 1);
    });
  });

  group('小测试 store 与备份', () {
    test('保存、同一天覆盖、读回', () async {
      final native = FakeNative(now: DateTime.parse('2026-10-21T09:00:00'));
      final store = BenchmarkStore(native, now: () => 1000);
      expect(await store.load(), isEmpty);
      await store.save(date: '2026-10-21', pushup: 8, pushupKnee: true);
      await store.save(
        date: '2027-01-13',
        plank: 60,
        pull: 5,
        pullType: 'pullup',
      );
      var rows = await store.load();
      expect(rows.map((r) => r['date']), ['2026-10-21', '2027-01-13']);
      expect(rows.first['pushup'], {'n': 8, 'knee': true});
      expect(rows.last['pull'], {'type': 'pullup', 'n': 5});
      expect(jsonDecode(native.docs[BenchmarkStore.key]!)['v'], 1);
      // 同一天再测：覆盖。
      await store.save(date: '2026-10-21', pushup: 10);
      rows = await store.load();
      expect(rows, hasLength(2));
      expect(rows.first['pushup'], {'n': 10, 'knee': false});
      await store.remove('2027-01-13');
      expect((await store.load()).single['date'], '2026-10-21');
      // 无效输入不写入。
      await expectLater(
        store.save(date: '2026-10-21'),
        throwsA(isA<DomainError>()),
      );
      expect((await store.load()).single['pushup'], {'n': 10, 'knee': false});
    });

    test('损坏的单条被跳过，整份损坏时可以继续写', () async {
      final native = FakeNative(now: DateTime.parse('2026-10-21T09:00:00'));
      native.docs[BenchmarkStore.key] = jsonEncode({
        'v': 1,
        'entries': [
          {
            'date': 'bad',
            'pushup': {'n': 1},
          },
          {
            'date': '2026-10-21',
            'pushup': {'n': 7, 'knee': false},
          },
        ],
      });
      final store = BenchmarkStore(native);
      expect((await store.load()).single['date'], '2026-10-21');
      native.docs[BenchmarkStore.key] = 'not json';
      await expectLater(store.load(), throwsA(isA<FormatException>()));
      await store.save(date: '2026-10-22', plank: 20);
      expect((await store.load()).single['date'], '2026-10-22');
      expect(native.docs['${BenchmarkStore.key}-corrupt'], 'not json');
    });

    test('随备份导出，导入后原样恢复；旧备份没有它也能导入', () async {
      final a = FakeNative(now: DateTime.parse('2026-10-21T09:00:00'));
      final store = BenchmarkStore(a, now: () => 1);
      await store.save(date: '2026-10-21', pushup: 9, plank: 33);
      final repoA = Repository(a);
      await repoA.load();
      final backupJson = await exportBackup(a, repoA);
      expect(
        (backupJson['preferences'] as Map).keys,
        contains(BenchmarkStore.key),
      );

      final b = FakeNative(now: DateTime.parse('2026-10-22T09:00:00'));
      final repoB = Repository(b);
      await repoB.load();
      await restoreBackup(
        b,
        repoB,
        jsonDecode(jsonEncode(backupJson)) as Map<String, dynamic>,
      );
      final rows = await BenchmarkStore(b).load();
      expect(rows.single['date'], '2026-10-21');
      expect(rows.single['pushup'], {'n': 9, 'knee': false});
      expect(rows.single['plank'], {'sec': 33});

      // 旧备份（没有这份文档）：恢复后没有测试记录。
      final old = jsonDecode(jsonEncode(backupJson)) as Map<String, dynamic>;
      (old['preferences'] as Map).remove(BenchmarkStore.key);
      await restoreBackup(b, repoB, old);
      expect(await BenchmarkStore(b).load(), isEmpty);
    });
  });
}
