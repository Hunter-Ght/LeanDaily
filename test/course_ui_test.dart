import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/app/routes.dart';
import 'package:leandaily/core/native.dart';
import 'package:leandaily/data/benchmark_store.dart';
import 'package:leandaily/data/state_doc.dart' show emptyState;
import 'package:leandaily/domain/calendar.dart' as calendar;
import 'package:leandaily/domain/course.dart';
import 'package:leandaily/domain/format.dart';
import 'package:leandaily/domain/plan.dart' as plans;
import 'package:leandaily/domain/plan_recipe.dart' as recipes;
import 'package:leandaily/l10n/app_messages.dart';
import 'package:leandaily/ui/course/course_widgets.dart' show CourseSummaryCard;
import 'package:leandaily/ui/kit/sheet.dart' show AppSheet;
import 'package:leandaily/ui/stats/benchmark_section.dart';
import 'package:leandaily/ui/today/today_model.dart';
import 'package:leandaily/ui/today/today_page.dart';
import 'package:leandaily/ui/training/training_mode.dart';

import 'support/harness.dart';
import 'today_page_test.dart' show tapVisible;
import 'today_sheets_test.dart' show loadExerciseImages;

/// 2026-10-16 是周五，计划里周五练 w3。
const friday = '2026-10-16T09:00:00';
const saturday = '2026-10-17T09:00:00';

/// 截图：只在设置了 LEANDAILY_SHOT_DIR 时出图，平时不写文件。
final shotsOn = Platform.environment['LEANDAILY_SHOT_DIR'] != null;

Future<void> settle(WidgetTester t) async {
  await t.pumpAndSettle();
  await t.pumpAndSettle();
}

/// 多次 pump，不等待永远循环的动画。
Future<void> soft(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

/// 把计划改成「带课程、周五练 3 组动作」。
void seedCourse(
  FakeNative native, {
  String? start = '2026-10-14',
  int sets = 3,
  Map<String, dynamic>? cardio,
  List<String> trained = const [],
}) {
  final plan = jsonDecode(native.docs['fw-plan-v1']!) as Map;
  plan['workouts']['w3']['exercises'] = [
    {
      'id': 'c-load',
      'name': '哑铃地板卧推',
      'part': '胸',
      'sets': sets,
      'min': 10,
      'max': 12,
      'weight': 5,
      'unit': 'reps',
      'core': true,
      'rest': 90,
    },
    {
      'id': 'c-body',
      'name': '反向卷腹',
      'part': '核心',
      'sets': sets,
      'min': 10,
      'max': 15,
      'weight': 0,
      'unit': 'reps',
      'core': true,
      'rest': 75,
    },
  ];
  if (start != null) plan['course'] = newCourse(start);
  if (cardio != null) plan['cardio'] = cardio;
  native.docs['fw-plan-v1'] = jsonEncode(plan);
  if (trained.isNotEmpty) {
    final state = emptyState();
    final rows = <String, dynamic>{};
    for (final (i, date) in trained.indexed) {
      final id = 'seed-$i';
      rows[id] = {
        'id': id,
        'date': date,
        'ts': DateTime.parse('${date}T09:00:00').millisecondsSinceEpoch,
        'ex': '哑铃地板卧推',
        'part': '胸',
        'no': 1,
        'w': 5 + i,
        'reps': 10,
        'type': '正式',
        'rpe': null,
        'notes': '',
      };
    }
    state['sets'] = rows;
    native.docs['android-state'] = jsonEncode(state);
  }
}

/// 周三为开始日，往后 [n] 个整周各练一天（周三）。
({String start, List<String> trained}) weeks(int n) {
  // 现在是 2026-10-16（周五，本周周一 10-12）：往前数 n 个整周。
  final monday = calendar.mondayOf('2026-10-16');
  final firstMonday = calendar.shiftDate(monday, -7 * n);
  return (
    start: calendar.shiftDate(firstMonday, -5), // 上一周的周三
    trained: [
      for (var i = 0; i < n; i++) calendar.shiftDate(firstMonday, 7 * i + 2),
    ],
  );
}

Future<Harness> pumpToday(
  WidgetTester t, {
  String at = friday,
  bool dark = false,
  Locale locale = const Locale('zh', 'CN'),
  void Function(FakeNative n)? seed,
}) => Harness.pump(
  t,
  empty: true,
  at: at,
  dark: dark,
  locale: locale,
  size: const Size(393, 852),
  seed: seed,
);

Future<void> openRoute(WidgetTester t, void Function(BuildContext) open) async {
  open(t.element(find.byType(TodayPage)));
  await settle(t);
}

void main() {
  setUpAll(() async {
    await Harness.setUpAll();
    await AppMessages.initialize();
  });

  group('今日页：课程行、阶段指引、组数一致', () {
    testWidgets('第 1 周：阶段行、打底期少 1 组，今日页、训练模式、预计时长一致', (t) async {
      final h = await pumpToday(t, seed: (n) => seedCourse(n));
      final app = h.controller;
      expect(app.course, isNotNull);
      expect(app.courseNow!.week, 1);
      expect(find.byKey(const ValueKey('course-line')), findsOneWidget);
      expect(find.text('第 1 周 / 共 12 周'), findsOneWidget);
      expect(find.text('打底期'), findsOneWidget);
      // 有课程时，页眉只写日期，不再写日历第几周。
      expect(find.textContaining('· 第'), findsNothing);
      // 阶段指引（余力说法）。
      expect(find.text('先学动作：每组留 3 次余力，动作做标准比做多更重要。'), findsOneWidget);
      // 3 组的动作，打底期少 1 组。
      final model = TodayModel(app);
      expect(model.all.map((e) => e['target']), [2, 2]);
      expect(find.text('2×10'), findsWidgets);
      // 预计时长用同一份组数。
      final expected = plans.estimateMinutes(
        app.plan,
        model.items.map((i) => jsonMap(i['ex'])).toList(),
        jsNumber(jsonMap(model.workout['warmup'])['minutes']),
      );
      final baseSets = plans.estimateMinutes(app.plan, [
        for (final e in model.all) {...e, 'target': 3},
      ], jsNumber(jsonMap(model.workout['warmup'])['minutes']));
      expect(expected, lessThan(baseSets));
      expect(find.text('$expected'), findsWidgets);
      expect(jsNumber(model.prog['totalSets']), 4);
      // 训练模式里的目标组数一样。
      openTrainingMode(t.element(find.byType(TodayPage)));
      await settle(t);
      expect(find.byType(TrainingMode), findsOneWidget);
      await t.tap(find.text('跳过热身'));
      await soft(t);
      expect(find.textContaining('目标 2 组'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 7));
    });

    testWidgets('没有 course 字段的方案：行为完全不变', (t) async {
      final h = await pumpToday(t, seed: (n) => seedCourse(n, start: null));
      final app = h.controller;
      expect(app.course, isNull);
      expect(app.courseNow, isNull);
      expect(app.courseSetsOf(app.today), isNull);
      expect(find.byKey(const ValueKey('course-line')), findsNothing);
      expect(find.textContaining('小测试'), findsNothing);
      expect(find.textContaining('· 第'), findsOneWidget);
      expect(TodayModel(app).all.map((e) => e['target']), [3, 3]);
      expect(find.text('3×10'), findsWidgets);
      expect(find.textContaining('余力，动作做标准'), findsNothing);
      expect(app.progressOptions.course, isNull);
    });

    testWidgets('第 5 周起按方案的组数，旧的「余力」规则只在没有课程时保留', (t) async {
      final w = weeks(4);
      final h = await pumpToday(
        t,
        seed: (n) => seedCourse(n, start: w.start, trained: w.trained),
      );
      expect(h.controller.courseNow!.week, 5);
      expect(find.text('加量期'), findsOneWidget);
      expect(TodayModel(h.controller).all.map((e) => e['target']), [3, 3]);
      expect(find.text('按方案的组数做，每组留 2～3 次余力。'), findsOneWidget);
    });

    testWidgets('预览按这一天的课程阶段给组数', (t) async {
      final h = await pumpToday(t, seed: (n) => seedCourse(n));
      final app = h.controller;
      final fn = app.courseSetsOf('2026-10-16')!;
      expect(fn({'sets': 3}), 2);
      expect(fn({'sets': 2}), 2);
      await loadExerciseImages(t);
      await openRoute(t, (c) => openDayPreview(c, '2026-10-16'));
      // 预览里 2 个动作共 4 组。
      expect(find.text('4'), findsWidgets);
    });

    testWidgets('点阶段行打开路线弹层，显示现在在哪、每段说明', (t) async {
      await pumpToday(t, seed: (n) => seedCourse(n));
      await t.tap(find.byKey(const ValueKey('course-line')));
      await settle(t);
      expect(find.text('12 周课程'), findsOneWidget);
      for (final name in ['打底期', '加量期', '冲刺期', '减量复测周']) {
        expect(find.text(name), findsWidgets);
      }
      expect(find.text('第 1～4 周'), findsOneWidget);
      expect(find.text('第 12 周'), findsOneWidget);
      expect(find.text('组数 3 组以上的动作各少做 1 组，每组留 3 次余力。'), findsOneWidget);
      expect(find.text('再来一轮'), findsNothing, reason: '还没完成');
      // 路线弹层里可以直接做小测试。
      await t.tap(find.text('小测试'));
      await settle(t);
      expect(find.text('做不了或不想测的项目直接留空，数字只用来和以前的自己比。'), findsOneWidget);
    });
  });

  group('小测试卡与弹层', () {
    testWidgets('第 1 周出现测试卡；点先不后本轮不再出现，重启后仍然如此', (t) async {
      final h = await pumpToday(t, seed: (n) => seedCourse(n));
      final app = h.controller;
      expect(find.text('花 3 分钟测个底，12 周后再比一次'), findsOneWidget);
      expect(find.text('现在测'), findsOneWidget);
      await t.tap(find.text('先不'));
      await settle(t);
      expect(find.text('花 3 分钟测个底，12 周后再比一次'), findsNothing);
      expect(app.courseCardDismissed('intro'), true);
      expect(app.courseCardDismissed('retest'), false);
      // 存进了 hints 文档（随备份），重新打开 App 仍然不出现。
      final hints = jsonDecode(h.native.docs['fw-hints-v1']!) as Map;
      expect((hints['courseCards'] as Map)['start'], '2026-10-14');
      await t.pumpWidget(const SizedBox());
      final again = await pumpToday(
        t,
        seed: (n) {
          seedCourse(n);
          n.docs['fw-hints-v1'] = h.native.docs['fw-hints-v1']!;
        },
      );
      expect(again.controller.courseCardDismissed('intro'), true);
      expect(find.text('花 3 分钟测个底，12 周后再比一次'), findsNothing);
    });

    testWidgets('现在测：填数字保存，卡片消失，进度页出现小测试', (t) async {
      final h = await pumpToday(t, seed: (n) => seedCourse(n));
      final app = h.controller;
      await t.tap(find.text('现在测'));
      await settle(t);
      expect(find.text('小测试'), findsOneWidget);
      // 什么都不填，保存给出提示。
      await t.tap(find.text('保存'));
      await settle(t);
      expect(find.text('至少填一项，或直接关掉'), findsOneWidget);
      expect(app.benchmarkEntries, isEmpty);
      await t.enterText(find.byType(EditableText).at(0), '12');
      await t.enterText(find.byType(EditableText).at(1), '45');
      await t.tap(find.text('跪姿'));
      await t.pump();
      await t.tap(find.text('保存'));
      await settle(t);
      final row = app.benchmarkEntries.single;
      expect(row['date'], '2026-10-16');
      expect(row['pushup'], {'n': 12, 'knee': true});
      expect(row['plank'], {'sec': 45});
      expect(row.containsKey('pull'), false);
      expect(
        jsonDecode(h.native.docs[BenchmarkStore.key]!)['entries'],
        hasLength(1),
      );
      expect(find.text('花 3 分钟测个底，12 周后再比一次'), findsNothing);
      await t.pump(const Duration(seconds: 3));
      // 进度页显示最近一次测试。
      app.setTab(2);
      await settle(t);
      expect(find.byKey(const ValueKey('benchmark-section')), findsOneWidget);
      expect(find.text('小测试'), findsOneWidget);
      expect(find.text('俯卧撑 · 跪姿'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
    });

    testWidgets('进度页：没有测试记录时不显示；两次测试显示对比', (t) async {
      final h = await pumpToday(t, seed: (n) => seedCourse(n));
      final app = h.controller;
      app.setTab(2);
      await settle(t);
      expect(find.byKey(const ValueKey('benchmark-section')), findsNothing);
      expect(BenchmarkSection.has(app), false);
      await app.benchmarkStore.save(date: '2026-10-14', pushup: 8, plank: 30);
      await app.saveBenchmark(date: '2027-01-06', pushup: 15, plank: 55);
      await settle(t);
      expect(find.byKey(const ValueKey('benchmark-section')), findsOneWidget);
      expect(find.text('2026-10-14 → 2027-01-06'), findsNWidgets(2));
      expect(find.text('8'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
    });

    testWidgets('第 12 周出现复测卡（本轮测过底才有），点先不后不再出现', (t) async {
      // 第 12 周：开始日在 12 个整周之前，之后有 11 个练了的整周。
      final w = weeks(11);
      final h = await pumpToday(
        t,
        seed: (n) {
          seedCourse(n, start: w.start, trained: w.trained);
          n.docs[BenchmarkStore.key] = jsonEncode({
            'v': 1,
            'entries': [
              {
                'date': w.start,
                'pushup': {'n': 8, 'knee': false},
                'ts': 1,
              },
            ],
          });
        },
      );
      expect(h.controller.courseNow!.week, 12);
      expect(find.text('减量复测周'), findsOneWidget);
      expect(find.text('12 周了，再测一次和第一次比比'), findsOneWidget);
      // 第 12 周少 1 组。
      expect(TodayModel(h.controller).all.map((e) => e['target']), [2, 2]);
      await t.tap(find.text('先不'));
      await settle(t);
      expect(find.text('12 周了，再测一次和第一次比比'), findsNothing);
      expect(h.controller.courseCardDismissed('retest'), true);
    });

    testWidgets('第 12 周没有测过底：不出现复测卡', (t) async {
      final w = weeks(11);
      final h = await pumpToday(
        t,
        seed: (n) => seedCourse(n, start: w.start, trained: w.trained),
      );
      expect(h.controller.courseNow!.week, 12);
      expect(find.text('12 周了，再测一次和第一次比比'), findsNothing);
      expect(find.text('花 3 分钟测个底，12 周后再比一次'), findsNothing);
    });
  });

  group('完成总结卡', () {
    testWidgets('12 个练了的整周之后出现总结卡，再来一轮从今天重新开始', (t) async {
      final w = weeks(12);
      final h = await pumpToday(
        t,
        seed: (n) {
          seedCourse(n, start: w.start, trained: w.trained);
          n.docs[BenchmarkStore.key] = jsonEncode({
            'v': 1,
            'entries': [
              {
                'date': w.start,
                'pushup': {'n': 8, 'knee': false},
                'plank': {'sec': 30},
                'ts': 1,
              },
              {
                'date': '2026-10-14',
                'pushup': {'n': 15, 'knee': false},
                'plank': {'sec': 55},
                'ts': 2,
              },
            ],
          });
        },
      );
      final app = h.controller;
      expect(app.courseNow!.done, true);
      // 完成后组数回到方案，阶段行变成「已完成」。
      expect(TodayModel(app).all.map((e) => e['target']), [3, 3]);
      expect(find.text('12 周课程已完成'), findsOneWidget);
      expect(find.text('12 周课程完成了'), findsOneWidget);
      expect(find.text('12 周里练了'), findsOneWidget);
      expect(find.text('进步最多的动作'), findsOneWidget);
      expect(find.text('小测试'), findsOneWidget);
      expect(find.text('再来一轮'), findsOneWidget);
      // 没有阶段指引。
      expect(find.textContaining('每组留'), findsNothing);
      await loadExerciseImages(t);
      await tapVisible(t, find.text('再来一轮'));
      expect(app.course!['start'], '2026-10-16');
      expect(app.courseNow!.week, 1);
      expect(app.courseNow!.done, false);
      expect(find.text('12 周课程完成了'), findsNothing);
      t
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(ListView).first,
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position
          .jumpTo(0);
      await settle(t);
      expect(find.text('第 1 周 / 共 12 周'), findsOneWidget);
      expect(TodayModel(app).all.map((e) => e['target']), [2, 2]);
      // 新的一轮从新的开始日算，也不会再被旧的「先不」挡住。
      expect(app.courseCardDismissed('summary'), false);
      // 方案库里的方案也带上新的课程。
      expect(app.library.activePlan!['course']['start'], '2026-10-16');
      await t.pump(const Duration(seconds: 7));
    });

    testWidgets('总结卡可以关闭，关掉后不再出现；路线弹层仍可再来一轮', (t) async {
      final w = weeks(12);
      final h = await pumpToday(
        t,
        seed: (n) => seedCourse(n, start: w.start, trained: w.trained),
      );
      await t.tap(find.bySemanticsLabel('关闭').first);
      await settle(t);
      expect(find.text('12 周课程完成了'), findsNothing);
      expect(h.controller.courseCardDismissed('summary'), true);
      await t.tap(find.text('12 周课程已完成'));
      await settle(t);
      expect(find.text('12 周完成了'), findsOneWidget);
      await t.tap(find.text('再来一轮'));
      await settle(t);
      expect(h.controller.courseNow!.week, 1);
      await t.pump(const Duration(seconds: 7));
    });
  });

  group('休息日有氧建议', () {
    testWidgets('本周有氧不够时出现，记够后消失；没有字段或训练日不显示', (t) async {
      final h = await pumpToday(
        t,
        at: saturday,
        seed: (n) => seedCourse(n, cardio: {'perWeek': 2, 'minutes': 20}),
      );
      final app = h.controller;
      expect(TodayModel(app).train, false);
      expect(find.text('今天适合走 20 分钟，本周还差 2 次有氧'), findsOneWidget);
      // 从这一行直接记有氧。
      await t.tap(find.text('记有氧'));
      await settle(t);
      expect(find.text('记有氧'), findsWidgets);
      await t.tap(find.text('记录').last);
      await settle(t);
      expect(app.cardioEntries, hasLength(1));
      expect(find.text('本周还差 1 次有氧'), findsOneWidget);
      expect(find.textContaining('今天适合走'), findsNothing);
      await t.pump(const Duration(seconds: 7));
      await app.saveCardio(date: '2026-10-13', type: 'walk', minutes: 30);
      await settle(t);
      expect(find.byKey(const ValueKey('cardio-hint')), findsNothing);
      expect(find.textContaining('次有氧'), findsNothing);
    });

    testWidgets('只数本周（周一到周日）的有氧', (t) async {
      final h = await pumpToday(
        t,
        at: saturday,
        seed: (n) {
          seedCourse(n, cardio: {'perWeek': 2, 'minutes': 25});
          n.docs['fw-cardio-v1'] = jsonEncode({
            'v': 1,
            'entries': [
              {
                'id': 'a',
                'date': '2026-10-11',
                'type': 'walk',
                'minutes': 30,
                'ts': 1,
              },
              {
                'id': 'b',
                'date': '2026-10-12',
                'type': 'walk',
                'minutes': 30,
                'ts': 2,
              },
            ],
          });
        },
      );
      expect(h.controller.cardioEntries, hasLength(2));
      expect(find.text('今天适合走 25 分钟，本周还差 1 次有氧'), findsOneWidget);
    });

    testWidgets('方案没有 cardio 字段：休息日不显示', (t) async {
      await pumpToday(t, at: saturday, seed: (n) => seedCourse(n));
      expect(find.byKey(const ValueKey('cardio-hint')), findsNothing);
      expect(find.textContaining('次有氧'), findsNothing);
    });

    testWidgets('训练日不显示有氧建议', (t) async {
      await pumpToday(
        t,
        seed: (n) => seedCourse(n, cardio: {'perWeek': 2, 'minutes': 20}),
      );
      expect(find.byKey(const ValueKey('cardio-hint')), findsNothing);
    });
  });

  group('控制器：按配方建方案带课程', () {
    testWidgets('配方生成的方案带课程，模板方案没有；调整方案保留课程进度', (t) async {
      final h = await pumpToday(t);
      final app = h.controller;
      expect(app.course, isNull);
      final recipe = recipes.normalizeRecipe({'days': 3});
      final id = await app.addRecipePlan(recipe);
      expect(app.activePlanId, id);
      expect(app.plan['course'], {'v': 1, 'start': '2026-10-16', 'weeks': 12});
      await settle(t);
      expect(find.byKey(const ValueKey('course-line')), findsOneWidget);
      // 模板方案不带课程。
      final tplId = await app.addTemplatePlan('bodyweight-3', activate: true);
      expect(app.activePlanId, tplId);
      expect(app.plan.containsKey('course'), false);
      expect(app.course, isNull);
      // 回到配方方案，改配方：课程开始日保留。
      await app.usePlan(id);
      final before = Map<String, dynamic>.from(app.plan['course'] as Map);
      await app.applyRecipe(recipes.normalizeRecipe({'days': 4}));
      expect(app.plan['course'], before);
      await t.pump(const Duration(seconds: 7));
    });
  });

  group('截图', () {
    for (final (name, dark, locale) in [
      ('zh-light', false, const Locale('zh', 'CN')),
      ('zh-dark', true, const Locale('zh', 'CN')),
      ('en-light', false, const Locale('en')),
      ('en-dark', true, const Locale('en')),
    ]) {
      testWidgets('今日页、阶段弹层、测试弹层 $name', (t) async {
        if (!shotsOn) return;
        final h = await pumpToday(
          t,
          dark: dark,
          locale: locale,
          seed: (n) => seedCourse(n),
        );
        await loadExerciseImages(t);
        await h.shot(t, 'today-week1-$name');
        await t.tap(find.byKey(const ValueKey('course-line')));
        await settle(t);
        await h.shot(t, 'phase-sheet-$name');
        Navigator.of(
          t.element(find.byType(AppSheet).first),
          rootNavigator: true,
        ).pop();
        await settle(t);
        await openRoute(t, openBenchmarkSheet);
        await t.enterText(find.byType(EditableText).at(0), '12');
        await t.enterText(find.byType(EditableText).at(1), '45');
        await t.pump();
        await h.shot(t, 'benchmark-sheet-$name');
        await t.pumpWidget(const SizedBox());
      });

      testWidgets('第 3 周与完成总结卡 $name', (t) async {
        if (!shotsOn) return;
        final w3 = weeks(2);
        final h3 = await pumpToday(
          t,
          dark: dark,
          locale: locale,
          seed: (n) {
            seedCourse(n, start: w3.start, trained: w3.trained);
            n.docs[BenchmarkStore.key] = jsonEncode({
              'v': 1,
              'entries': [
                {
                  'date': w3.start,
                  'pushup': {'n': 8, 'knee': false},
                  'ts': 1,
                },
              ],
            });
          },
        );
        await loadExerciseImages(t);
        expect(h3.controller.courseNow!.week, 3);
        await h3.shot(t, 'today-week3-$name');
        await t.pumpWidget(const SizedBox());

        final w = weeks(12);
        final h = await pumpToday(
          t,
          dark: dark,
          locale: locale,
          seed: (n) {
            seedCourse(n, start: w.start, trained: w.trained);
            n.docs[BenchmarkStore.key] = jsonEncode({
              'v': 1,
              'entries': [
                {
                  'date': w.start,
                  'pushup': {'n': 8, 'knee': false},
                  'plank': {'sec': 30},
                  'pull': {'type': 'row', 'n': 4},
                  'ts': 1,
                },
                {
                  'date': '2026-10-14',
                  'pushup': {'n': 15, 'knee': false},
                  'plank': {'sec': 55},
                  'pull': {'type': 'row', 'n': 9},
                  'ts': 2,
                },
              ],
            });
          },
        );
        await loadExerciseImages(t);
        await h.shot(t, 'today-done-top-$name');
        await t.ensureVisible(find.byType(CourseSummaryCard));
        await settle(t);
        await h.shot(t, 'summary-card-$name');
        t
            .state<ScrollableState>(
              find
                  .descendant(
                    of: find.byType(ListView).first,
                    matching: find.byType(Scrollable),
                  )
                  .first,
            )
            .position
            .jumpTo(0);
        await settle(t);
        await t.tap(find.byKey(const ValueKey('course-line')));
        await settle(t);
        await h.shot(t, 'phase-sheet-done-$name');
        await t.pumpWidget(const SizedBox());
      });

      testWidgets('休息日有氧建议与进度页 $name', (t) async {
        if (!shotsOn) return;
        final h = await pumpToday(
          t,
          at: saturday,
          dark: dark,
          locale: locale,
          seed: (n) => seedCourse(n, cardio: {'perWeek': 2, 'minutes': 20}),
        );
        await h.shot(t, 'rest-cardio-$name');
        await h.controller.saveBenchmark(
          date: '2026-10-14',
          pushup: 8,
          plank: 30,
          pullType: 'row',
          pull: 4,
        );
        await h.controller.saveBenchmark(
          date: '2026-10-16',
          pushup: 15,
          plank: 55,
          pullType: 'row',
          pull: 9,
        );
        h.controller.setTab(2);
        await settle(t);
        await t.ensureVisible(find.byKey(const ValueKey('benchmark-section')));
        await settle(t);
        await h.shot(t, 'stats-benchmark-$name');
        await t.pumpWidget(const SizedBox());
      });
    }
  });
}
