import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/domain/templates.dart' as templates;
import 'package:leandaily/ui/sheets/plan_editor_sheet.dart';

import 'settings_goals_test.dart' show SettingsHarness, settle;

/// 回归：旧计划/导入计划缺少顶层字段时，点今日页右上角的计划按钮曾报
/// “空值不是 Map 的子类型（type cast）”。
void main() {
  setUpAll(SettingsHarness.setUpAll);

  test('ensurePlanShape 只补缺失字段，已有内容原样保留', () {
    final plan = templates.buildPlan('full-2', startDate: '2026-10-16');
    final before = jsonEncode(plan['workouts']);
    final shaped = ensurePlanShape(
      jsonDecode(jsonEncode(plan)) as Map<String, dynamic>
        ..remove('reminder')
        ..remove('venues')
        ..remove('ladders')
        ..['protein'] = {'goal': 150},
      '2026-10-16',
    );
    expect(jsonEncode(shaped['workouts']), before);
    expect((shaped['reminder'] as Map)['enabled'], isNotNull);
    expect(shaped['venues'], isA<Map>());
    expect((shaped['protein'] as Map)['goal'], 150);
    expect(((shaped['protein'] as Map)['powder'] as Map)['grams'], isNotNull);
  });

  for (final key in ['reminder', 'venues', 'protein', 'schedule', 'ladders']) {
    testWidgets('计划缺少 $key 时编辑弹层仍能打开', (t) async {
      final h = await SettingsHarness.pump(t);
      final plan = jsonDecode(jsonEncode(h.controller.plan)) as Map<String, dynamic>
        ..remove(key);
      h.controller.plan = plan;
      h.open(const PlanEditorSheet());
      await settle(t);
      expect(t.takeException(), isNull);
      expect(find.byType(PlanEditorSheet), findsOneWidget);
    });
  }

  testWidgets('蛋白粉配置缺失时也能打开', (t) async {
    final h = await SettingsHarness.pump(t);
    final plan = jsonDecode(jsonEncode(h.controller.plan)) as Map<String, dynamic>;
    (plan['protein'] as Map).remove('powder');
    h.controller.plan = plan;
    h.open(const PlanEditorSheet());
    await settle(t);
    expect(t.takeException(), isNull);
  });
}
