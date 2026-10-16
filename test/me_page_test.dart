import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/ui/me/me_page.dart';
import 'package:leandaily/ui/onboarding/onboarding_flow.dart';
import 'package:leandaily/ui/sheets/body_log_sheet.dart';
import 'package:leandaily/ui/sheets/profile_sheet.dart';
import 'package:leandaily/ui/sheets/plan_editor_sheet.dart';
import 'package:leandaily/ui/sheets/template_browser_sheet.dart';
import 'package:leandaily/ui/sheets/goals_sheet.dart';
import 'package:leandaily/ui/sheets/android_settings_sheet.dart';

import 'support/harness.dart';

void main() {
  setUpAll(Harness.setUpAll);
  for (final dark in [false, true]) {
    for (final empty in [false, true]) {
      testWidgets('me screenshot $dark $empty', (tester) async {
        final h = await Harness.pump(
          tester,
          tab: 3,
          dark: dark,
          size: const Size(393, 852),
          seed: (n) {
            if (!empty) {
              n.docs['fw-profile-v1'] = jsonEncode({
                'age': 30,
                'weightKg': 82,
                'bodyFatPct': 24,
                'bodyFatMethod': 'manual',
              });
            }
          },
        );
        expect(find.byType(MePage), findsOneWidget);
        expect(find.text(empty ? '开始评估' : '重组路线'), findsOneWidget);
        await h.shot(
          tester,
          'r-me${empty ? '-empty' : ''}-${dark ? 'dark' : 'light'}',
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
  for (final row in [
    ('当前计划', PlanEditorSheet),
    ('浏览训练模板', TemplateBrowserSheet),
    ('记体重和腰围', BodyLogSheet),
    ('我的资料与目标', ProfileSheet),
    ('每日目标与休息', GoalsSheet),
    ('提醒', PlanEditorSheet),
    ('备份与高级', AndroidSettingsSheet),
  ]) {
    testWidgets('me opens ${row.$1}', (tester) async {
      await Harness.pump(tester, tab: 3);
      await tester.ensureVisible(find.text(row.$1));
      await tester.tap(find.text(row.$1));
      await tester.pumpAndSettle();
      expect(find.byType(row.$2), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('local data settings and empty profile assessment', (
    tester,
  ) async {
    await Harness.pump(tester, tab: 3);
    expect(find.text('备份恢复 · 拍照识别'), findsOneWidget);
    expect(find.text('立即同步'), findsNothing);
    await tester.ensureVisible(find.text('开始评估'));
    await tester.tap(find.text('开始评估'));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingFlow), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });
}
