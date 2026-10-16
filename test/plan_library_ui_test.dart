import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/domain/templates.dart';
import 'package:leandaily/domain/body.dart' show profileDefaults;
import 'package:leandaily/ui/kit/form.dart';
import 'package:leandaily/ui/kit/plan_widgets.dart';
import 'package:leandaily/ui/sheets/plan_editor_sheet.dart';
import 'package:leandaily/ui/sheets/template_browser_sheet.dart';

import 'settings_goals_test.dart' show SettingsHarness, settle;

Future<void> tapText(WidgetTester t, String text) async {
  final target = find.text(text).last;
  await t.ensureVisible(target);
  await t.tap(target);
  await settle(t);
  await t.pump(const Duration(seconds: 3));
  await settle(t);
}

Future<void> menu(WidgetTester t, String name) async {
  await t.tap(
    find.bySemanticsLabel(
      '$name'
      '的更多操作',
    ),
  );
  await settle(t);
}

Map<String, dynamic> doc(SettingsHarness h, String key) =>
    jsonDecode(h.native.docs[key]!) as Map<String, dynamic>;

void main() {
  setUpAll(() async {
    await SettingsHarness.setUpAll();
    await MiniBody.load();
  });
  testWidgets(
    'library switch, rename, copy, delete and legacy recovery persist',
    (t) async {
      final h = await SettingsHarness.pump(t);
      final app = h.controller;
      final original = jsonEncode(app.plan);
      final originalId = app.activePlanId;
      await app.addTemplatePlan('full-2');
      h.open(const PlanEditorSheet());
      await settle(t);
      await menu(t, '我的原始方案');
      final disabledDelete = t.widget<FormButton>(
        find.byWidgetPredicate((w) => w is FormButton && w.label == '删除'),
      );
      expect(disabledDelete.onTap, isNull);
      expect(find.text('当前使用的方案不能删除，请先切换方案'), findsOneWidget);
      await tapText(t, '取消');
      await t.tap(find.bySemanticsLabel('使用方案：全身两练 · 入门'));
      await settle(t);
      expect(find.text('切换后今日页按这个计划走，训练记录不受影响'), findsOneWidget);
      await tapText(t, '使用');
      expect(app.activePlanId, isNot(originalId));
      expect(doc(h, 'fw-plans-v1')['activeId'], app.activePlanId);
      expect(doc(h, 'fw-plan-v1'), app.plan);
      expect(find.text('正在编辑：全身两练 · 入门'), findsOneWidget);
      await menu(t, '全身两练 · 入门');
      await tapText(t, '重命名');
      await t.enterText(find.byType(EditableText).last, '我的两练');
      await tapText(t, '保存');
      expect(app.plans.last['name'], '我的两练');
      expect(find.text('正在编辑：我的两练'), findsOneWidget);
      await menu(t, '我的两练');
      await tapText(t, '复制');
      expect(app.plans.length, 3);
      await menu(t, '我的两练（副本）');
      await tapText(t, '删除');
      await tapText(t, '删除');
      expect(app.plans.length, 2);
      await menu(t, '我的两练');
      await tapText(t, '恢复到升级前的方案');
      await tapText(t, '恢复');
      expect(jsonEncode(app.plan), original);
      expect(doc(h, 'fw-plan-v1'), app.plan);
      expect(doc(h, 'fw-plans-v1')['activeId'], app.activePlanId);
    },
  );

  testWidgets(
    'last plan is disabled and draft survives rename but switching asks to discard',
    (t) async {
      final h = await SettingsHarness.pump(t);
      h.open(const PlanEditorSheet());
      await settle(t);
      await menu(t, '我的原始方案');
      expect(find.text('最后一个方案不能删除'), findsOneWidget);
      expect(
        t
            .widget<FormButton>(
              find.byWidgetPredicate((w) => w is FormButton && w.label == '删除'),
            )
            .onTap,
        isNull,
      );
      await tapText(t, '取消');
      await t.tap(find.byType(FormSwitch).first);
      await settle(t);
      await h.controller.addTemplatePlan('full-2');
      await settle(t);
      await t.tap(find.bySemanticsLabel('使用方案：全身两练 · 入门'));
      await settle(t);
      await tapText(t, '使用');
      expect(find.text('已填的内容不会保存。'), findsOneWidget);
      await tapText(t, '取消');
      expect(h.controller.plans.first['id'], h.controller.activePlanId);
      await t.tap(find.bySemanticsLabel('使用方案：全身两练 · 入门'));
      await settle(t);
      await tapText(t, '使用');
      await tapText(t, '放弃');
      expect(h.controller.plans.last['id'], h.controller.activePlanId);
    },
  );

  testWidgets(
    'saving edits writes only the active library entry and reopens them',
    (t) async {
      final h = await SettingsHarness.pump(t);
      final original = jsonEncode(h.controller.plans.first['plan']);
      await h.controller.addTemplatePlan('full-2', activate: true);
      h.open(const PlanEditorSheet());
      await settle(t);
      final initial = (h.controller.plan['reminder'] as Map)['enabled'];
      await t.tap(find.byType(FormSwitch).first);
      await settle(t);
      await tapText(t, '保存');
      expect((doc(h, 'fw-plan-v1')['reminder'] as Map)['enabled'], !initial);
      expect(doc(h, 'fw-plan-v1'), h.controller.plans.last['plan']);
      expect(jsonEncode(h.controller.plans.first['plan']), original);
      h.open(const PlanEditorSheet());
      await settle(t);
      expect(
        t.widget<FormSwitch>(find.byType(FormSwitch).first).value,
        !initial,
      );
    },
  );

  testWidgets(
    'profile ranking and combined filters; preview back retains filters',
    (t) async {
      final h = await SettingsHarness.pump(t);
      await h.controller.setProfile({
        ...profileDefaults,
        'sex': 'female',
        'venue': 'dumbbell',
        'daysPerWeek': 3,
      });
      h.open(const TemplateBrowserSheet());
      await settle(t);
      final ranked = recommend(h.controller.profile!, h.controller.targets!);
      final first = templates.firstWhere(
        (tpl) => tpl['id'] == ranked.first['templateId'],
      );
      expect(find.byType(PlanCard), findsWidgets);
      final list = t.widget<ListView>(find.byType(ListView).last);
      expect(list.childrenDelegate, isA<SliverChildBuilderDelegate>());
      expect(
        t
            .getTopLeft(
              find.byWidgetPredicate(
                (w) => w is PlanCard && w.name == first['name'],
              ),
            )
            .dy,
        lessThan(t.getTopLeft(find.text('薄肌三练 · 推拉腿')).dy),
      );
      await tapText(t, '在家');
      expect(
        find.byWidgetPredicate((w) => w is PlanCard && w.name == '居家自重三练（无器械）'),
        findsOneWidget,
      );
      await tapText(t, '4');
      expect(find.text('上下肢四练'), findsOneWidget);
      expect(find.text('薄肌三练 · 推拉腿'), findsNothing);
      await t.tap(find.bySemanticsLabel(RegExp('^上下肢四练，每周')));
      await settle(t);
      await tapText(t, '返回');
      expect(find.text('上下肢四练'), findsOneWidget);
      expect(find.text('薄肌三练 · 推拉腿'), findsNothing);
    },
  );

  for (final dark in [false, true]) {
    final tone = dark ? 'dark' : 'light';
    testWidgets(
      'library and template screenshots $tone; only add preserves current plan',
      (t) async {
        final h = await SettingsHarness.pump(t, dark: dark);
        await h.controller.addTemplatePlan('full-2');
        h.open(const PlanEditorSheet());
        await settle(t);
        await h.shot(t, 'plan-library-$tone');
        await tapText(t, '＋ 从模板添加');
        await h.shot(t, 'template-browser-$tone');
        await tapText(t, '5+');
        expect(find.text('推拉腿 + 上下肢 五练'), findsOneWidget);
        expect(find.text('薄肌三练 · 推拉腿'), findsNothing);
        await t.tap(find.bySemanticsLabel('全部').first);
        await settle(t);
        await t.tap(find.bySemanticsLabel(RegExp('^薄肌三练 · 推拉腿，每周')));
        await settle(t);
        await h.shot(t, 'template-preview-$tone');
        final beforeId = h.controller.activePlanId;
        final beforePlan = h.native.docs['fw-plan-v1'];
        await tapText(t, '仅添加');
        expect(h.controller.activePlanId, beforeId);
        expect(h.native.docs['fw-plan-v1'], beforePlan);
        expect(h.controller.plans.length, 3);
        await tapText(t, '＋ 从模板添加');
        await t.tap(find.bySemanticsLabel(RegExp('^薄肌三练 · 推拉腿，每周')));
        await settle(t);
        await tapText(t, '使用这个方案');
        expect(h.controller.plans.last['name'], '薄肌三练 · 推拉腿（2）');
        expect(
          doc(h, 'fw-plans-v1')['activeId'],
          h.controller.plans.last['id'],
        );
        expect(doc(h, 'fw-plan-v1'), h.controller.plan);
        expect(find.text('正在编辑：薄肌三练 · 推拉腿（2）'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'every template preview uses buildPlan home and gym prescriptions; back keeps filters',
    (t) async {
      final h = await SettingsHarness.pump(t);
      h.open(const TemplateBrowserSheet());
      await settle(t);
      for (final template in templates) {
        final name = template['name'] as String;
        await t.ensureVisible(
          find.bySemanticsLabel(RegExp('^${RegExp.escape(name)}，每周')),
        );
        await t.tap(
          find.bySemanticsLabel(RegExp('^${RegExp.escape(name)}，每周')),
        );
        await settle(t);
        final plan = buildPlan(
          template['id'] as String,
          startDate: h.controller.today,
        );
        for (final venue in ['home', 'gym']) {
          if (venue == 'gym') {
            if (!(plan['workouts'] as Map).values.any((w) => w['gym'] is Map)) {
              continue;
            }
            await tapText(t, '健身房版');
          }
          for (final w in (plan['workouts'] as Map).values) {
            final list = venue == 'gym' && w['gym'] is Map
                ? w['gym']['exercises'] as List
                : w['exercises'] as List;
            for (final ex in list) {
              expect(find.textContaining('${ex['name']} ·'), findsWidgets);
              final prescription =
                  '${ex['sets']} 组 × ${ex['min']}–${ex['max']} ${ex['unit'] == 'sec' ? '秒' : '次'}${ex['side'] == true ? ' / 每侧' : ''}${ex['optional'] == true ? ' · 可选' : ''}';
              expect(find.textContaining(prescription), findsWidgets);
            }
          }
        }
        await tapText(t, '返回');
        expect(find.text('从模板添加'), findsOneWidget);
      }
    },
  );
}
