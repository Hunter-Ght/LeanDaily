import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/domain/format.dart';
import 'package:leandaily/domain/progress.dart' as progress;
import 'package:leandaily/ui/today/today_model.dart';
import 'package:leandaily/ui/kit/grouped.dart';
import 'package:leandaily/ui/kit/segments.dart';
import 'package:leandaily/ui/training/training_mode.dart';
import 'package:leandaily/ui/today/today_tip_card.dart';
import 'package:leandaily/ui/today/today_nutrition_strip.dart';
import 'package:leandaily/ui/today/guide_body.dart';
import 'package:leandaily/ui/sheets/guide_content.dart';

import 'support/harness.dart';
import 'today_four_test.dart' show fourProfile;
import 'today_sheets_test.dart' show loadExerciseImages;

Future<void> settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  final scrollable = find
      .descendant(
        of: find.byType(ListView).first,
        matching: find.byType(Scrollable),
      )
      .first;
  if (finder.evaluate().isEmpty) {
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await settle(tester);
  }
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, 300, scrollable: scrollable);
  }
  await tester.ensureVisible(finder);
  await settle(tester);
  await tester.tap(finder);
  await settle(tester);
}

void todayTest(String name, WidgetTesterCallback callback) {
  testWidgets(name, (tester) async {
    try {
      await callback(tester);
    } finally {
      await tester.pump(const Duration(seconds: 4));
      debugDisableShadows = true;
    }
  });
}

void main() {
  setUpAll(Harness.setUpAll);
  for (final accept in [true, false]) {
    todayTest('进度建议${accept ? '接受' : '暂缓'}落盘并重新计算', (tester) async {
      final h = await Harness.pump(tester, size: const Size(393, 2300));
      final s = TodayModel(h.controller).suggestions.first;
      final expected = accept
          ? progress.applyAccept(
              h.controller.plan,
              h.controller.progress,
              jsonMap(s['accept']),
              h.controller.today,
            )
          : {
              'progress': progress.decline(
                h.controller.progress,
                '${s['key']}',
                h.controller.today,
              ),
            };
      await tapVisible(
        tester,
        find.text(accept ? '${s['acceptLabel']}' : '先保持'),
      );
      expect(
        jsonDecode(h.native.docs['fw-progress-v1']!),
        expected['progress'],
      );
      if (accept) {
        expect(jsonDecode(h.native.docs['fw-plan-v1']!), expected['plan']);
      }
      expect(
        TodayModel(h.controller).suggestions.where((v) => v['key'] == s['key']),
        isEmpty,
      );
      await tester.pump(const Duration(seconds: 4));
    });
  }
  todayTest('今日页启动后进入训练模式，动作清单不再展开逐组输入', (tester) async {
    final h = await Harness.pump(tester, empty: true);
    await tapVisible(tester, find.text('开始训练'));
    expect(h.controller.dayStates[h.controller.today]['started'], isTrue);
    expect(find.byType(TrainingMode), findsOneWidget);
    expect(
      tester.widget<TrainingMode>(find.byType(TrainingMode)).exerciseId,
      TodayModel(h.controller).firstOpen,
    );
    expect(h.native.awake, isTrue);
    await tester.tap(find.bySemanticsLabel('关闭'));
    await settle(tester);
    expect(h.native.awake, isFalse);
  });

  todayTest('调整面板保存状态、精简与覆盖，恢复不删除记录', (tester) async {
    final h = await Harness.pump(tester);
    final originalSets = jsonRows(
      h.controller.repo.day(h.controller.today)['sets'],
    ).length;
    await tapVisible(tester, find.text('调整今天的训练 ›'));
    final segments = find.byType(AppSegments);
    final group = find.byType(GroupCard).last;
    final groupBox = find
        .descendant(of: group, matching: find.byType(Container))
        .first;
    // Container includes its 16-point margin in its reported outer bounds.
    expect(
      tester.getTopLeft(groupBox).dx + 16,
      tester.getTopLeft(segments.first).dx,
    );
    expect(
      tester.getSize(groupBox).width - 32,
      tester.getSize(segments.first).width,
    );
    await tester.tap(find.text('有点累'));
    await settle(tester);
    await tester.tap(find.text('精简'));
    await settle(tester);
    expect(h.controller.dayStates[h.controller.today]['ready'], 'tired');
    expect(h.controller.dayStates[h.controller.today]['lite'], isTrue);
    await tester.tap(find.text('不舒服'));
    await settle(tester);
    expect(h.controller.dayStates[h.controller.today]['ready'], 'bad');
    await tester.tap(find.text('取消'));
    await settle(tester);
    expect(find.text('调整今天的训练 · 不舒服 · 精简 ›'), findsOneWidget);
    await tapVisible(tester, find.text('今天休息'));
    expect(TodayModel(h.controller).train, isFalse);
    await tapVisible(tester, find.text('恢复原计划'));
    expect(TodayModel(h.controller).train, isTrue);
    expect(
      jsonRows(h.controller.repo.day(h.controller.today)['sets']),
      hasLength(originalSets),
    );
    final state = jsonDecode(
      h.native.docs['fw-plan-day-v1']!,
    )[h.controller.today];
    expect(state['ready'], 'bad');
    expect(state['lite'], isTrue);
  });

  todayTest('提示默认一条：安全优先于疲劳、建议和通知，其余可展开', (tester) async {
    final h = await Harness.pump(
      tester,
      size: const Size(393, 1800),
      seed: (n) => n.notifyGranted = false,
    );
    await h.controller.patchDayState(h.controller.today, {'ready': 'bad'});
    await settle(tester);
    expect(find.byType(TodayTipCard), findsOneWidget);
    expect(
      tester.widget<TodayTipCard>(find.byType(TodayTipCard)).heading,
      '身体不舒服就别硬练',
    );
    await tapVisible(tester, find.textContaining('条提示 ›'));
    expect(find.byType(TodayTipCard), findsWidgets);
    await tapVisible(tester, find.text('收起提示'));
    await h.controller.patchDayState(h.controller.today, {'ready': 'tired'});
    await settle(tester);
    expect(
      tester.widget<TodayTipCard>(find.byType(TodayTipCard)).heading,
      '今天有点累',
    );
    await h.controller.patchDayState(h.controller.today, {'ready': null});
    await settle(tester);
    expect(tester.widget<TodayTipCard>(find.byType(TodayTipCard)).priority, 4);
  });

  todayTest('常吃排序、单击写一餐，蛋白粉置顶', (tester) async {
    final h = await Harness.pump(
      tester,
      empty: true,
      size: const Size(393, 2300),
    );
    for (var i = 0; i < 2; i++) {
      await h.controller.repo.saveMeal(
        date: h.controller.today,
        meal: '午餐',
        source: '手动填写',
        items: [
          {'name': '鸡蛋', 'portion': '2 个', 'kcal': 140, 'protein': 12},
        ],
      );
    }
    await settle(tester);
    final foods = frequentTodayFoods(h.controller, h.controller.today);
    expect(foods.first['name'], '鸡蛋');
    expect(foods.first['portion'], '2 个');
    await tapVisible(tester, find.bySemanticsLabel(RegExp('展开营养条带')));
    final buttons = tester
        .widgetList<TodayFoodChip>(
          find.descendant(
            of: find.byType(TodayNutritionStrip),
            matching: find.byType(TodayFoodChip),
          ),
        )
        .toList();
    expect(buttons.first.name, '酵母蛋白粉');
    expect(buttons.first.protein, 22.6);
    for (final chip in find.byType(TodayFoodChip).evaluate()) {
      final size = tester.getSize(find.byWidget(chip.widget));
      expect(size.height, 44);
      expect(size.width, lessThan(329));
    }
    await tapVisible(tester, find.text('鸡蛋'));
    expect(
      jsonRows(h.controller.repo.meals(h.controller.today)['meals']),
      hasLength(3),
    );
    expect(find.text('已记入 鸡蛋'), findsOneWidget);
    await tapVisible(tester, find.text('酵母蛋白粉'));
    expect(
      jsonMap(h.controller.repo.meals(h.controller.today)['totals'])['protein'],
      58.6,
    );
    await tester.pump(const Duration(seconds: 4));
  });

  todayTest('动作点击：未开始看示范，已开始定位训练，两栏只切换示范', (tester) async {
    final h = await Harness.pump(
      tester,
      empty: true,
      size: const Size(393, 2300),
    );
    await loadExerciseImages(tester);
    final first = TodayModel(h.controller).all.first;
    await tapVisible(
      tester,
      find.bySemanticsLabel(RegExp('${first['name']}，看示范')),
    );
    expect(find.byType(SheetGuideBody), findsOneWidget);
    await tester.tap(find.text('关闭'));
    await settle(tester);
    await h.controller.patchDayState(h.controller.today, {'started': true});
    await settle(tester);
    await tapVisible(
      tester,
      find.bySemanticsLabel(RegExp('${first['name']}，进入训练')),
    );
    expect(
      tester.widget<TrainingMode>(find.byType(TrainingMode)).exerciseId,
      first['id'],
    );
    await tester.tap(find.bySemanticsLabel('关闭'));
    await settle(tester);
  });

  todayTest('动作清单热身可勾选，提醒默认折叠且能展开', (tester) async {
    final h = await Harness.pump(tester, size: const Size(393, 2300));
    final m = TodayModel(h.controller);
    final rules = m.workout['rules'] as List;
    await tapVisible(
      tester,
      find.text('热身 ${jsonMap(m.workout['warmup'])['minutes']} 分钟'),
    );
    expect(h.controller.dayStates[m.iso]['warm'], isTrue);
    expect(find.text(rules.join('\n')), findsNothing);
    await tapVisible(tester, find.text('今天要记住的 ${rules.length} 点 ›'));
    expect(find.text(rules.join('\n')), findsOneWidget);
    await tapVisible(tester, find.text('今天要记住的 ${rules.length} 点 ›'));
    expect(find.text(rules.join('\n')), findsNothing);
  });

  todayTest('内屏两栏示范与选择动作', (tester) async {
    await Harness.pump(tester, size: const Size(852, 850));
    await loadExerciseImages(tester);
    expect(find.text('怎么做'), findsOneWidget);
    await tapVisible(tester, find.bySemanticsLabel(RegExp('高位俯卧撑，进入训练')));
    expect(
      tester.widget<GuideBody>(find.byType(GuideBody)).exercise['name'],
      '高位俯卧撑',
    );
    expect(find.byType(TrainingMode), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    final scheme = dark ? 'dark' : 'light';
    for (final scenario in [
      'train',
      'done',
      'rest',
      'new',
      'adjust',
      'long',
      'strip-open',
      'nostrip',
    ]) {
      todayTest('R 今日 $scenario $scheme', (tester) async {
        final h = await Harness.pump(
          tester,
          dark: dark,
          size: Size(393, scenario == 'long' ? 2000 : 852),
          seed: (n) {
            if (scenario != 'new' && scenario != 'nostrip') {
              n.docs['fw-profile-v1'] = jsonEncode(fourProfile());
            }
          },
        );
        if (scenario == 'long') {
          await h.controller.patchDayState(h.controller.today, {
            'started': true,
          });
          await h.controller.recordBody(date: '2026-10-09', weightKg: 70.5);
          await h.controller.recordBody(date: '2026-10-16', weightKg: 70.2);
          await settle(tester);
        }
        if (scenario == 'done') {
          final m = TodayModel(h.controller);
          for (final item in m.items) {
            final e = jsonMap(item['ex']);
            final target = m.before['${e['id']}']!;
            final missing =
                jsNumber(target['sets']).toInt() -
                jsNumber(item['done']).toInt();
            if (missing <= 0) continue;
            await h.controller.repo.addSets(
              date: m.iso,
              part: '${e['part']}',
              exercise: '${e['name']}',
              rows: [
                for (var i = 0; i < missing; i++)
                  {
                    'weight': target['weight'],
                    'reps': target['reps'],
                    'type': '正式',
                  },
              ],
            );
          }
          await settle(tester);
          expect(TodayModel(h.controller).complete, isTrue);
          expect(find.text('继续训练'), findsNothing);
          expect(find.textContaining('今天练完了'), findsOneWidget);
        }
        if (scenario == 'rest') {
          await h.controller.patchDayState(h.controller.today, {
            'override': 'rest',
          });
          await settle(tester);
          expect(find.text('今天想加练'), findsOneWidget);
        }
        if (scenario == 'new' || scenario == 'nostrip') {
          expect(find.text('设定目标'), findsNothing);
          expect(find.bySemanticsLabel(RegExp('展开营养条带')), findsNothing);
        }
        if (scenario == 'strip-open') {
          await tapVisible(tester, find.bySemanticsLabel(RegExp('展开营养条带')));
          await tester.drag(find.byType(ListView).first, const Offset(0, -140));
          await settle(tester);
        }
        if (scenario == 'adjust') {
          await tapVisible(tester, find.text('调整今天的训练 ›'));
        }
        await loadExerciseImages(tester);
        await h.shot(tester, 'r-today-$scenario-$scheme');
        expect(tester.takeException(), isNull);
      });
    }
    todayTest('R 记录 $scheme', (tester) async {
      final h = await Harness.pump(
        tester,
        dark: dark,
        tab: 1,
        size: const Size(393, 852),
      );
      await h.shot(tester, 'r-log-$scheme');
      expect(tester.takeException(), isNull);
    });
  }
}
