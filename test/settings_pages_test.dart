import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/ui/sheets/android_settings_sheet.dart';
import 'package:leandaily/ui/sheets/plan_editor_sheet.dart';
import 'package:leandaily/ui/kit/form.dart';
import 'settings_goals_test.dart' show SettingsHarness;

Future<void> settle(WidgetTester t) async { await t.pumpAndSettle(); await t.pumpAndSettle(); }
Finder input(String label) => find.descendant(of: find.byWidgetPredicate((w) => w is FormInput && w.label == label), matching: find.byType(EditableText));
Future<void> reveal(WidgetTester t, Finder f) async { FocusManager.instance.primaryFocus?.unfocus(); t.testTextInput.hide(); await settle(t); await t.ensureVisible(f); await settle(t); await t.ensureVisible(f); await settle(t); }
void main() {
  setUpAll(SettingsHarness.setUpAll);
  for (final dark in [false, true]) {
    final scheme = dark ? 'dark' : 'light';
    testWidgets('android settings $scheme', (t) async {
      final h = await SettingsHarness.pump(t, dark: dark);
      h.open(const AndroidSettingsSheet()); await settle(t);
      await h.shot(t, 'sheet-android-$scheme'); debugDisableShadows = true;
      await t.enterText(input('接口地址'), 'https://example.test/v1');
      await t.enterText(input('模型名称'), 'vision-test');
      await t.enterText(input('API Key'), 'local-test-key');
      await t.tap(find.text('保存').first); await settle(t);
      final saved = jsonDecode(h.native.docs['android-settings']!) as Map;
      expect(saved['baseUrl'], 'https://example.test/v1');
      expect(saved.containsKey('modelKey'), false);
      expect(h.native.secrets.modelKey, 'local-test-key');
      await t.pump(const Duration(seconds: 3));
    });
    testWidgets('plan $scheme', (t) async {
      final h = await SettingsHarness.pump(t, dark: dark, size: const Size(393, 1700));
      h.open(const PlanEditorSheet()); await settle(t);
      await h.shot(t, 'sheet-plan-$scheme'); debugDisableShadows = true;
      final original = jsonEncode(h.controller.plan);
      await t.enterText(input('名称').first, '新的训练日');
      expect(jsonEncode(h.controller.plan), original);
      await t.tap(find.text('保存').first); await settle(t);
      expect(jsonDecode(h.native.docs['fw-plan-v1']!)['workouts']['w1']['name'], '新的训练日');
      await t.pump(const Duration(seconds: 3));
    });
  }
  testWidgets('settings validation, permissions, export and restore', (t) async {
    final h = await SettingsHarness.pump(t, empty: true); debugDisableShadows = true;
    h.open(const AndroidSettingsSheet()); await settle(t);
    await t.enterText(input('接口地址'), 'http://example.test');
    await t.tap(find.text('保存').first); await settle(t);
    expect(find.text('模型接口必须使用 HTTPS'), findsOneWidget);
    await t.enterText(input('接口地址'), '');
    h.native.notifyGranted = false;
    await reveal(t, find.text('锁屏休息提醒')); await t.tap(find.text('锁屏休息提醒')); await settle(t);
    expect(find.text('通知权限未开启，将仅显示页面倒计时'), findsOneWidget);
    await reveal(t, find.text('导出备份')); await t.tap(find.text('导出备份')); await settle(t);
    final exported = h.native.exported!;
    expect(jsonDecode(exported)['format'], 'leandaily-backup');
    await h.controller.repo.addSets(date: h.controller.today, part: '胸', exercise: '恢复前新增', rows: [{'weight': 5, 'reps': 8, 'type': '正式'}]);
    expect((jsonDecode(h.native.docs['android-state']!)['sets'] as Map).length, 1);
    h.native.importData = exported;
    await reveal(t, find.text('从备份恢复')); await t.tap(find.text('从备份恢复')); await settle(t);
    expect(find.text('恢复备份并替换手机记录？'), findsOneWidget);
    await t.tap(find.text('恢复')); await settle(t);
    expect(h.native.secrets.modelKey, '');
    expect(h.controller.settings.value['tz'], h.controller.settings.deviceTz);
    expect(jsonDecode(h.native.docs['android-state']!)['sets'], isEmpty);
    expect(h.controller.repo.state['sets'], isEmpty);
    await t.pump(const Duration(seconds: 3));
  });
  testWidgets('plan reset is a draft until saved and venue choices persist', (t) async {
    final h = await SettingsHarness.pump(t, size: const Size(393, 1700)); debugDisableShadows = true;
    h.open(const PlanEditorSheet()); await settle(t);
    await t.tap(find.byWidgetPredicate((w) => w is FormChoice && w.label == '周一默认场地')); await settle(t);
    await t.tap(find.text('健身房').last); await settle(t);
    await t.tap(find.text('保存').first); await settle(t);
    expect(h.controller.plan['venues']['1'], 'gym');
    h.open(const PlanEditorSheet()); await settle(t);
    await reveal(t, find.text('恢复默认计划')); await t.tap(find.text('恢复默认计划')); await settle(t);
    expect(find.text('恢复成默认计划？'), findsOneWidget);
    await t.tap(find.text('恢复')); await settle(t);
    expect(h.controller.plan['venues']['1'], 'gym');
    await t.tap(find.text('取消').first); await settle(t);
    await t.tap(find.text('放弃')); await settle(t);
    expect(h.controller.plan['venues']['1'], 'gym');
    await t.pump(const Duration(seconds: 3));
  });
}
