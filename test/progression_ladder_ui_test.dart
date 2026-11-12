import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/domain/body.dart';
import 'package:leandaily/domain/format.dart';
import 'package:leandaily/domain/plan.dart' as plans;
import 'package:leandaily/domain/plan_upgrade.dart';
import 'package:leandaily/ui/sheets/template_browser_sheet.dart';

import 'support/harness.dart';

/// 今日页上的两张新建议卡：换更高阶方案、升级到下一级动作。
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> sets(
  Harness h,
  String date,
  String ex,
  int reps, {
  int count = 2,
}) => h.controller.repo.addSets(
  date: date,
  exercise: ex,
  rows: [
    {'weight': 0, 'reps': reps, 'count': count, 'type': '正式'},
  ],
);

/// 入门方案练满 8 周：计划从 2026-08-03 开始，每周一、周四各练一天。
Future<Harness> upgradeScene(
  WidgetTester tester, {
  bool dark = false,
  Locale locale = const Locale('zh', 'CN'),
}) async {
  final h = await Harness.pump(
    tester,
    empty: true,
    dark: dark,
    locale: locale,
    size: const Size(393, 1000),
  );
  final c = h.controller;
  await c.setProfile({...profileDefaults, 'venue': 'dumbbell'});
  await c.addTemplatePlan('full-2', activate: true);
  await c.updatePlan({...c.plan, 'startDate': '2026-08-03'});
  for (var w = 0; w < 11; w++) {
    for (final off in [0, 3]) {
      final date = shiftDate('2026-08-03', w * 7 + off);
      if (date.compareTo('2026-10-16') >= 0) continue;
      final day = jsonMap(jsonMap(c.plan['workouts'])[off == 0 ? 't1' : 't2']);
      for (final e in plans.exercisesFor(c.plan, day, date)) {
        // 每个动作按区间下限练满计划组数，不触发加量或升级建议。
        await sets(
          h,
          date,
          '${e['name']}',
          jsNumber(e['min']).toInt(),
          count: jsNumber(e['sets']).toInt(),
        );
      }
    }
  }
  // 这位用户前几天刚点过「先不」（减量提示），不让它盖住升级建议。
  await c.declineSuggestion({'key': 'deload'});
  // 各肌群刚加过组，不再有「加 1 组」的建议。
  for (final g in [
    'chest',
    'back',
    'shoulders',
    'abs',
    'quads',
    'hamstrings',
    'glutes',
    'arms',
    'calves',
  ]) {
    await c.acceptSuggestion({
      'accept': {'type': 'sets', 'exId': '-', 'group': g},
    });
  }
  await settle(tester);
  return h;
}

/// 自重计划里深蹲已经连续两次做满 15 次：建议升级到停顿深蹲。
Future<Harness> ladderScene(
  WidgetTester tester, {
  bool dark = false,
  Locale locale = const Locale('zh', 'CN'),
}) async {
  final h = await Harness.pump(
    tester,
    empty: true,
    dark: dark,
    locale: locale,
    size: const Size(393, 1000),
  );
  final c = h.controller;
  await c.setProfile({
    ...profileDefaults,
    'venue': 'bodyweight',
    'experience': 'new',
  });
  await c.addTemplatePlan('bodyweight-3', activate: true);
  await c.acceptSuggestion({
    'accept': {
      'type': 'anchor',
      'name': '深蹲',
      'date': '2026-10-01',
      'reps': 15,
      'weight': 0,
    },
  });
  for (final d in ['2026-10-05', '2026-10-09']) {
    await sets(h, d, '深蹲', 15);
  }
  await settle(tester);
  return h;
}

void main() {
  setUpAll(Harness.setUpAll);
  final dir = Platform.environment['LEANDAILY_SHOT_DIR'];

  testWidgets('稳定练满 8 周的入门方案：今日页出现升级建议，看看 / 先不', (tester) async {
    final h = await upgradeScene(tester);
    expect(h.controller.activeTemplateId, 'full-2');
    expect(find.text('稳定练了 8 周，可以换更高阶的方案了'), findsOneWidget);
    expect(find.text('看看'), findsOneWidget);
    if (dir != null) await h.shot(tester, 'upgrade-card-light');
    // 点「先不」：卡片消失，写入 28 天。
    await tester.tap(find.text('先不'));
    await settle(tester);
    expect(find.text('稳定练了 8 周，可以换更高阶的方案了'), findsNothing);
    expect(
      h.controller.progress['declined'][planUpgradeKey],
      h.controller.today,
    );
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('点「看看」直接进入推荐模板的预览，不改计划', (tester) async {
    final h = await upgradeScene(tester);
    final before = h.controller.plan;
    await tester.tap(find.text('看看'));
    await settle(tester);
    expect(find.byType(TemplateBrowserSheet), findsOneWidget);
    expect(find.text('使用这个方案'), findsOneWidget);
    expect(find.text('薄肌三练 · 推拉腿'), findsWidgets);
    if (dir != null) await h.shot(tester, 'upgrade-preview-light');
    expect(h.controller.plan, before);
  });

  testWidgets('有训练建议时不再叠加升级建议', (tester) async {
    final h = await upgradeScene(tester);
    // 疼痛红旗：今天起 14 天内不提示。
    await h.controller.repo.addSets(
      date: '2026-10-15',
      exercise: '高脚杯深蹲',
      rows: [
        {'weight': 0, 'reps': 8, 'type': '正式', 'flag': 'pain'},
      ],
    );
    await settle(tester);
    expect(find.text('稳定练了 8 周，可以换更高阶的方案了'), findsNothing);
  });

  testWidgets('深蹲做满：建议升级到停顿深蹲，接受后今日页换成新动作', (tester) async {
    final h = await ladderScene(tester);
    expect(find.text('升级到停顿深蹲'), findsOneWidget);
    expect(find.textContaining('连续两次做满 15 次'), findsWidgets);
    if (dir != null) await h.shot(tester, 'ladder-card-light');
    await tester.tap(find.text('升级到停顿深蹲'));
    await settle(tester);
    expect(find.text('记录会换成新的动作名，旧记录都保留。'), findsOneWidget);
    await tester.tap(find.text('确定'));
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));
    final stage = h.controller.plan['ladders']['squat']['stage'];
    expect(stage, 1);
    final c = plans.exercisesFor(
      h.controller.plan,
      jsonMap(
        plans.workoutFor(h.controller.plan, h.controller.today)['workout'],
      ),
      h.controller.today,
    );
    expect(c.map((e) => e['name']), contains('停顿深蹲'));
    if (dir != null) await h.shot(tester, 'ladder-after-light');
    await tester.pump(const Duration(seconds: 4));
  });

  if (dir != null) {
    for (final (name, dark, locale) in [
      ('dark', true, const Locale('zh', 'CN')),
      ('en', false, const Locale('en')),
    ]) {
      testWidgets('截图 $name', (tester) async {
        final h = await upgradeScene(tester, dark: dark, locale: locale);
        await h.shot(tester, 'upgrade-card-$name');
        await tester.tap(
          find.text(locale.languageCode == 'en' ? 'Take a look' : '看看'),
        );
        await settle(tester);
        await h.shot(tester, 'upgrade-preview-$name');
      });
      testWidgets('截图 ladder $name', (tester) async {
        final h = await ladderScene(tester, dark: dark, locale: locale);
        await h.shot(tester, 'ladder-card-$name');
      });
    }
  }
}
