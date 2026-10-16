import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/core/native.dart';
import 'package:leandaily/ui/kit/form.dart';
import 'package:leandaily/ui/sheets/goals_sheet.dart';
import 'package:leandaily/ui/sheets/plan_editor_sheet.dart';
import 'package:leandaily/ui/sheets/settings/exercise_editor.dart';

import 'settings_goals_test.dart' show SettingsHarness;
import 'settings_pages_test.dart' show input, reveal, settle;
import 'support/harness.dart' show Harness;

void main() {
  setUpAll(SettingsHarness.setUpAll);

  for (final dark in [false, true]) {
    testWidgets('我的页进入设置 ${dark ? 'dark' : 'light'}', (t) async {
      final h = await Harness.pump(t, tab: 3, dark: dark);
      await t.tap(find.text('每日目标与休息')); await settle(t);
      await h.shot(t, 'menu-more-${dark ? 'dark' : 'light'}');
      debugDisableShadows = true;
      expect(find.byType(GoalsSheet), findsOneWidget);
    });
  }

  testWidgets('goal bounds and failed writes keep the sheet available for retry', (t) async {
    final h = await SettingsHarness.pump(t);
    h.open(const GoalsSheet()); await settle(t);
    await t.enterText(input('每天正式组'), '100');
    await t.enterText(input('每天几餐'), '');
    await t.enterText(input('每天千卡'), '-3');
    await t.enterText(input('每周训练天数'), '9');
    h.native.failNextPut = const NativeError('保存失败，请重试');
    await t.tap(find.text('保存')); await settle(t);
    expect(find.text('保存失败，请重试'), findsOneWidget);
    expect(h.controller.goals['sets'], 12);
    await t.tap(find.text('保存')); await settle(t);
    expect(jsonDecode(h.native.docs['fw-goals-v1']!), {'sets': 40, 'meals': 1, 'kcal': 200, 'weekDays': 7});
  });

  testWidgets('exercise fields, alternatives and ordering persist after reopening', (t) async {
    final h = await SettingsHarness.pump(t, size: const Size(393, 1700));
    final originals = h.controller.plan['workouts']['w1']['exercises'] as List;
    final id = originals[1]['id'];
    originals[1]['alts'] = [{'name': '原替代', 'weight': 7}];
    final before = jsonEncode(h.controller.plan);
    h.open(const PlanEditorSheet()); await settle(t);
    final ladder = find.byType(ExerciseEditor).first;
    expect(t.widget<FormInput>(find.descendant(of: ladder, matching: find.byWidgetPredicate((w) => w is FormInput && w.label == '动作名'))).enabled, false);
    final editor = find.byWidgetPredicate((w) => w is ExerciseEditor && w.exercise['id'] == id);
    Finder field(String label) => find.descendant(of: editor, matching: find.descendant(of: find.byWidgetPredicate((w) => w is FormInput && w.label.startsWith(label)), matching: find.byType(EditableText)));
    await reveal(t, field('动作名')); await t.enterText(field('动作名'), '自定义动作');
    for (final e in {'组数': '3', '最少': '6', '最多': '10', 'kg': '7.5', '组间休息': '450', '没有时': '原替代，新增/另一个'}.entries) {
      await reveal(t, field(e.key)); await t.enterText(field(e.key), e.value);
    }
    for (final label in ['每侧', '按秒', '可选', '精简版必做', '器械（要填重量）']) {
      final flag = find.descendant(of: editor, matching: find.byWidgetPredicate((w) => w is FormCheck && w.label == label));
      await reveal(t, flag); await t.tap(flag); await settle(t);
    }
    final up = find.descendant(of: editor, matching: find.byWidgetPredicate((w) => w is FormButton && w.semanticLabel == '上移'));
    await reveal(t, up); await t.tap(up); await settle(t);
    expect(jsonEncode(h.controller.plan), before);
    await t.tap(find.text('保存').first); await settle(t);
    final ex = jsonDecode(h.native.docs['fw-plan-v1']!)['workouts']['w1']['exercises'][0] as Map;
    expect(ex['id'], id);
    expect(ex['name'], '自定义动作');
    expect(ex['sets'], 3); expect(ex['min'], 6); expect(ex['max'], 10);
    expect(ex['weight'], 7.5); expect(ex['rest'], 300); expect(ex['unit'], 'sec');
    expect(ex['side'], true); expect(ex['optional'], true); expect(ex['core'], false); expect(ex['machine'], true);
    expect(ex['alts'], [{'name': '原替代', 'weight': 7}, {'name': '新增'}, {'name': '另一个'}]);
    h.open(const PlanEditorSheet()); await settle(t);
    expect(find.text('自定义动作'), findsOneWidget);
    await t.pump(const Duration(seconds: 3));
  });

  testWidgets('adding and deleting an exercise requires confirmation and stays in draft', (t) async {
    final h = await SettingsHarness.pump(t, size: const Size(393, 1700));
    final count = (h.controller.plan['workouts']['w1']['exercises'] as List).length;
    h.open(const PlanEditorSheet()); await settle(t);
    await reveal(t, find.text('+ 添加动作')); await t.tap(find.text('+ 添加动作')); await settle(t);
    final added = find.byWidgetPredicate((w) => w is ExerciseEditor && w.exercise['name'] == '新动作');
    final remove = find.descendant(of: added, matching: find.byWidgetPredicate((w) => w is FormButton && w.semanticLabel == '删除'));
    await reveal(t, remove); await t.tap(remove); await settle(t);
    expect(find.text('删除「新动作」？'), findsOneWidget);
    await t.tap(find.text('取消').last); await settle(t);
    expect(added, findsOneWidget);
    await t.tap(remove); await settle(t); await t.tap(find.text('删除').last); await settle(t);
    expect(added, findsNothing);
    expect((h.controller.plan['workouts']['w1']['exercises'] as List).length, count);
    await t.tap(find.text('保存').first); await settle(t);
    expect((jsonDecode(h.native.docs['fw-plan-v1']!)['workouts']['w1']['exercises'] as List).length, count);
    await t.pump(const Duration(seconds: 3));
  });

  testWidgets('schedule, reminders, protein and start date survive saving and reopening', (t) async {
    final h = await SettingsHarness.pump(t, size: const Size(393, 1700));
    h.open(const PlanEditorSheet()); await settle(t);
    await t.enterText(input('提醒时间'), '18:35');
    await t.enterText(input('蛋白粉时间'), '15:20');
    final restDay = find.byWidgetPredicate((w) => w is FormSwitch && w.label == '休息日也提醒（预告下次）');
    await t.tap(restDay); await settle(t);
    await t.tap(find.byWidgetPredicate((w) => w is FormChoice && w.label == '周二安排')); await settle(t);
    await t.tap(find.text('胸 · 肩 · 腹').last); await settle(t);
    for (final e in {'每日目标 g': '125', '蛋白粉每份 g': '32.5', '每份含蛋白质 g': '24', '每份热量 kcal': '135', '计划开始日': '2026-10-01'}.entries) {
      await reveal(t, input(e.key)); await t.enterText(input(e.key), e.value);
    }
    h.native.notifyGranted = false;
    await t.tap(find.text('保存').first); await settle(t);
    final saved = jsonDecode(h.native.docs['fw-plan-v1']!) as Map;
    expect(saved['schedule']['2'], 'w1');
    expect(saved['reminder']['time'], '18:35');
    expect(saved['reminder']['proteinTime'], '15:20');
    expect(saved['reminder']['restDay'], false);
    expect(saved['protein']['goal'], 125);
    expect(saved['protein']['powder'], {'name': '酵母蛋白粉', 'grams': 32.5, 'protein': 24, 'kcal': 135});
    expect(saved['startDate'], '2026-10-01');
    h.open(const PlanEditorSheet()); await settle(t);
    expect(find.text('18:35'), findsOneWidget);
    await reveal(t, input('每日目标 g')); expect(find.text('125'), findsOneWidget);
    await t.pump(const Duration(seconds: 4));
  });
}
