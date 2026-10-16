import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/domain/body.dart';
import 'package:leandaily/ui/kit/form.dart';
import 'package:leandaily/ui/kit/number_field.dart';
import 'package:leandaily/ui/sheets/profile_sheet.dart';
import 'package:leandaily/ui/sheets/android_settings_sheet.dart';
import 'package:leandaily/ui/sheets/goals_sheet.dart';
import 'package:leandaily/ui/sheets/settings/profile_controls.dart';

import 'settings_goals_test.dart' show SettingsHarness, settle;

Finder input(String label) => find.descendant(
  of: find.byWidgetPredicate((w) => w is FormInput && w.label == label),
  matching: find.byType(EditableText),
);
Future<void> reveal(WidgetTester t, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  t.testTextInput.hide();
  await settle(t);
  await t.ensureVisible(finder);
  await settle(t);
}

Future<SettingsHarness> profile(WidgetTester t, {bool dark = false}) async {
  final h = await SettingsHarness.pump(
    t,
    dark: dark,
    size: const Size(393, 852),
  );
  await h.controller.setProfile({
    ...profileDefaults,
    'bodyFatPct': 25,
    'bodyFatMethod': 'manual',
  });
  h.open(const ProfileSheet());
  await settle(t);
  return h;
}

void main() {
  setUpAll(SettingsHarness.setUpAll);
  for (final dark in [false, true]) {
    testWidgets(
      'profile ${dark ? 'dark' : 'light'} edits recompute and persist',
      (t) async {
        final h = await profile(t, dark: dark);
        await h.shot(t, 'r-profile-${dark ? 'dark' : 'light'}');
        final initial = t
            .widget<ProfileDiagnosis>(find.byType(ProfileDiagnosis))
            .kcal;
        await t.tap(find.bySemanticsLabel(RegExp('^编辑体重')));
        await settle(t);
        await h.shot(t, 'r-profile-edit-${dark ? 'dark' : 'light'}');
        await reveal(t, input('体重'));
        await t.enterText(input('体重'), '90');
        await settle(t);
        expect(
          t.widget<ProfileDiagnosis>(find.byType(ProfileDiagnosis)).kcal,
          isNot(initial),
        );
        await t.tap(find.text('保存').first);
        await settle(t);
        expect(jsonDecode(h.native.docs['fw-profile-v1']!)['weightKg'], 90);
        expect(h.controller.targets!['kcal'], isNot(initial));
      },
    );
  }
  for (final dark in [false, true]) {
    testWidgets('grouped goals screenshot $dark', (t) async {
      final h = await SettingsHarness.pump(
        t,
        dark: dark,
        size: const Size(393, 852),
      );
      await h.controller.setProfile({
        ...profileDefaults,
        'bodyFatPct': 25,
        'bodyFatMethod': 'manual',
      });
      h.open(const GoalsSheet());
      await settle(t);
      await h.shot(t, 'r-goals-${dark ? 'dark' : 'light'}');
    });
  }
  testWidgets('goal clamp and manual override safety persist', (t) async {
    final h = await profile(t);
    await reveal(t, find.text('目标体脂').last);
    await t.tap(find.text('目标体脂').last);
    await settle(t);
    await reveal(t, input('目标体脂'));
    await t.enterText(input('目标体脂'), '2');
    await settle(t);
    expect(find.text('目标体脂低于安全下限，已调整为 8%'), findsOneWidget);
    expect(
      t
          .widget<ProfileDiagnosis>(find.byType(ProfileDiagnosis))
          .targets['goalBodyFat'],
      8,
    );
    await reveal(t, find.text('自定义每日热量'));
    await t.tap(
      find.byWidgetPredicate((w) => w is FormSwitch && w.label == '自定义每日热量'),
    );
    await settle(t);
    await reveal(t, input('每日热量'));
    await t.enterText(input('每日热量'), '100');
    await settle(t);
    await reveal(t, find.text('自定义每日蛋白'));
    await t.tap(
      find.byWidgetPredicate((w) => w is FormSwitch && w.label == '自定义每日蛋白'),
    );
    await settle(t);
    await reveal(t, input('每日蛋白'));
    await t.enterText(input('每日蛋白'), '999');
    await settle(t);
    expect(find.text('每日蛋白已限制在 1–220 克'), findsOneWidget);
    await t.tap(find.text('保存').first);
    await settle(t);
    expect(
      h.controller.kcalGoal,
      greaterThanOrEqualTo(bmr(h.controller.profile!)),
    );
    expect(h.controller.proteinGoal, 220);
    expect(h.controller.targetPrefs['goalBodyFat'], 8);
    h.open(const ProfileSheet());
    await settle(t);
    expect(
      t.widget<ProfileDiagnosis>(find.byType(ProfileDiagnosis)).protein,
      220,
    );
  });
  testWidgets('weight log overwrites today and profile update is optional', (
    t,
  ) async {
    final h = await profile(t);
    await t.tap(find.text('记一次'));
    await settle(t);
    await t.enterText(
      find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is SheetInput && w.label == '体重 kg',
        ),
        matching: find.byType(EditableText),
      ),
      '72',
    );
    await t.tap(find.text('保存').last);
    await settle(t);
    expect(
      jsonDecode(h.native.docs['fw-body-v1']!)['entries'].single['weightKg'],
      72,
    );
    expect(h.controller.profile!['weightKg'], 72);
    await t.tap(find.text('记一次'));
    await settle(t);
    await t.enterText(
      find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is SheetInput && w.label == '体重 kg',
        ),
        matching: find.byType(EditableText),
      ),
      '73',
    );
    await t.tap(
      find.byWidgetPredicate((w) => w is FormSwitch && w.label == '同步到我的资料'),
    );
    await settle(t);
    await t.tap(find.text('保存').last);
    await settle(t);
    expect(jsonDecode(h.native.docs['fw-body-v1']!)['entries'], hasLength(1));
    expect(
      jsonDecode(h.native.docs['fw-body-v1']!)['entries'].single['weightKg'],
      73,
    );
    expect(h.controller.profile!['weightKg'], 72);
    await t.tap(find.text('保存').first);
    await settle(t);
    expect(jsonDecode(h.native.docs['fw-profile-v1']!)['weightKg'], 72);
    await t.pump(const Duration(seconds: 3));
  });
  testWidgets('profile empty state offers assessment', (t) async {
    final h = await SettingsHarness.pump(t);
    h.open(const ProfileSheet());
    await settle(t);
    expect(find.text('开始评估'), findsOneWidget);
    expect(find.byType(ProfileDiagnosis), findsNothing);
    await t.tap(find.text('开始评估'));
    await settle(t);
    expect(find.text('我的资料与目标').hitTestable(), findsNothing);
  });
  for (final dark in [false, true]) {
    testWidgets(
      'advanced ${dark ? 'dark' : 'light'} keeps backup and model settings accessible',
      (t) async {
        final h = await SettingsHarness.pump(
          t,
          dark: dark,
          size: const Size(393, 852),
        );
        h.open(const AndroidSettingsSheet());
        await settle(t);
        await h.shot(t, 'advanced-${dark ? 'dark' : 'light'}');
        expect(find.text('高级'), findsOneWidget);
        expect(
          t.getTopLeft(find.text('备份与恢复')).dy,
          lessThan(t.getTopLeft(find.text('拍照识别（大模型）')).dy),
        );
        await t.tap(find.text('保存').first);
        await settle(t);
        expect(h.controller.settings.value['tz'], 'Asia/Shanghai');
        await t.pump(const Duration(seconds: 3));
      },
    );
  }
  testWidgets(
    'settings directs calculated calories to profile and preserves target',
    (t) async {
      final h = await SettingsHarness.pump(t);
      await h.controller.setProfile({...profileDefaults});
      h.open(const GoalsSheet());
      await settle(t);
      expect(input('每天千卡'), findsNothing);
      await reveal(t, find.text('每天千卡'));
      expect(find.bySemanticsLabel(RegExp('^我的资料与目标')), findsOneWidget);
      final kcal = h.controller.kcalGoal;
      await t.enterText(input('每天正式组'), '15');
      await t.tap(find.text('保存'));
      await settle(t);
      expect(h.controller.goals['kcal'], kcal);
    },
  );

  testWidgets(
    'reselect opens plan selection without replacing the active plan',
    (t) async {
      final h = await profile(t);
      final original = h.native.docs['fw-plan-v1'];
      final count = h.controller.library.items.length;
      await reveal(t, find.text('用新资料重新选计划'));
      await t.tap(find.text('用新资料重新选计划'));
      await settle(t);
      expect(find.text('选择计划'), findsOneWidget);
      expect(h.native.docs['fw-plan-v1'], original);
      final preview = find.bySemanticsLabel(RegExp('^预览')).first;
      await reveal(t, preview);
      await t.tap(preview);
      await settle(t);
      await t.tap(find.bySemanticsLabel('使用这个方案'));
      await settle(t);
      await t.tap(find.text('另外添加这个计划').last);
      await settle(t);
      expect(h.controller.library.items.length, count + 1);
      expect(h.native.docs['fw-plan-v1'], original);
    },
  );
  testWidgets('advanced validation, permissions, backup and restore', (
    t,
  ) async {
    final h = await SettingsHarness.pump(t, empty: true);
    h.open(const AndroidSettingsSheet());
    await settle(t);
    await t.enterText(input('接口地址'), 'http://example.test');
    await t.tap(find.text('保存').first);
    await settle(t);
    expect(find.text('模型接口必须使用 HTTPS'), findsOneWidget);
    await t.enterText(input('接口地址'), '');
    h.native.notifyGranted = false;
    await reveal(t, find.text('开启锁屏休息提醒'));
    await t.tap(find.text('开启锁屏休息提醒'));
    await settle(t);
    expect(find.text('通知权限未开启，将仅显示页面倒计时'), findsOneWidget);
    await reveal(t, find.text('导出备份'));
    await t.tap(find.text('导出备份'));
    await settle(t);
    expect(jsonDecode(h.native.exported!)['format'], 'leandaily-backup');
    h.native.importData = h.native.exported;
    await h.controller.repo.addSets(
      date: h.controller.today,
      part: '胸',
      exercise: '恢复前新增',
      rows: [
        {'weight': 5, 'reps': 8, 'type': '正式'},
      ],
    );
    await reveal(t, find.text('选择备份并恢复'));
    await t.tap(find.text('选择备份并恢复'));
    await settle(t);
    await t.tap(find.text('恢复'));
    await settle(t);
    expect(h.controller.repo.state['sets'], isEmpty);
    expect(h.controller.settings.value['tz'], 'Asia/Shanghai');
    await t.pump(const Duration(seconds: 3));
  });
}
