import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/core/native.dart';
import 'package:leandaily/domain/foods.dart';
import 'package:leandaily/ui/log/day_cards.dart';
import 'package:leandaily/ui/sheets/food/portion_panel.dart';
import 'package:leandaily/ui/sheets/meal_sheet.dart';

import 'meal_sheet_test.dart' show jpeg;
import 'support/harness.dart';

void main() {
  setUpAll(Harness.setUpAll);

  testWidgets('进入记录默认饮食，查训练时翻日期保留选择，再次进入回到饮食', (tester) async {
    final h = await Harness.pump(tester, tab: 1);
    expect(tester.widget<DayCards>(find.byType(DayCards)).shown, '饮食');
    h.controller.showRecordSection('训练');
    h.controller.setDate('2026-10-15');
    await tester.pumpAndSettle();
    expect(tester.widget<DayCards>(find.byType(DayCards)).shown, '训练');
    h.controller.setTab(2);
    await tester.pumpAndSettle();
    h.controller.setTab(1);
    await tester.pumpAndSettle();
    expect(tester.widget<DayCards>(find.byType(DayCards)).shown, '饮食');
    expect(find.text('拍照记饮食').hitTestable(), findsOneWidget);
  });

  testWidgets('蛋白粉在所选历史日期记一份，撤销只删除本次记录', (tester) async {
    final h = await Harness.pump(tester, tab: 1, empty: true);
    h.controller.setDate('2026-10-15');
    await tester.pumpAndSettle();
    await tester.tap(find.text('加蛋白粉'));
    await tester.pumpAndSettle();
    final meals = h.controller.repo.meals('2026-10-15')['meals'] as List;
    expect(meals, hasLength(1));
    final meal = meals.single as Map;
    final powder = proteinPowderFood(
      (h.controller.plan['protein'] as Map?)?['powder'] as Map?,
    );
    expect(meal['items'], [entryFor(powder, units: 1)]);
    expect(h.controller.repo.meals(h.controller.today)['meals'], isEmpty);
    await tester.tap(find.text('撤销').hitTestable());
    await tester.pumpAndSettle();
    expect(h.controller.repo.meals('2026-10-15')['meals'], isEmpty);
    expect(
      h.controller.repo.state['meals'][meal['record_id']]['deleted'],
      true,
    );
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('蛋白粉调整份量后按所选份数保存', (tester) async {
    final h = await Harness.pump(tester, tab: 1, empty: true);
    await tester.tap(find.bySemanticsLabel('调整份量'));
    await tester.pumpAndSettle();
    expect(find.byType(FoodPortionPanel), findsOneWidget);
    await tester.tap(find.text('0.5勺'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('加入'));
    await tester.pumpAndSettle();
    final meal =
        (h.controller.repo.meals(h.controller.today)['meals'] as List).single
            as Map;
    final powder = proteinPowderFood(
      (h.controller.plan['protein'] as Map?)?['powder'] as Map?,
    );
    expect(meal['items'], [entryFor(powder, units: .5)]);
    await tester.pump(const Duration(seconds: 7));
  });

  testWidgets('AI入口使用所选日期，恢复对应草稿而不改变全局日期', (tester) async {
    final h = await Harness.pump(tester, tab: 1, empty: true);
    h.controller.setDate('2026-10-15');
    h.native.docs['android-meal-draft:2026-10-15'] = jsonEncode({
      'meal': '晚餐',
      'note': '昨天的晚餐',
      'items': [],
    });
    await tester.pumpAndSettle();
    await tester.tap(find.text('拍照记饮食'));
    await tester.pumpAndSettle();
    expect(find.byType(MealSheet), findsOneWidget);
    expect(find.text('昨天的晚餐'), findsOneWidget);
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    final meal =
        (h.controller.repo.meals('2026-10-15')['meals'] as List).single as Map;
    expect(meal['meal'], '晚餐');
    expect(h.controller.date, '2026-10-15');
    expect(h.native.docs['android-meal-draft:2026-10-15'], 'null');
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('记录卡直接标记吃光，照片、营养和记录ID保持原值', (tester) async {
    final h = await Harness.pump(tester, tab: 1, empty: true);
    final path = await h.native.photoWrite(jpeg);
    final id = await h.controller.repo.saveMeal(
      date: h.controller.today,
      meal: '午餐',
      source: 'AI识别',
      items: [
        {'name': '米饭', 'portion': '1碗', 'kcal': 174, 'protein': 4.5},
      ],
      photoIds: [path],
      photoPhases: ['before'],
      basis: '仅吃前估算',
    );
    final before = Map<String, dynamic>.from(
      h.controller.repo.state['meals'][id] as Map,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('我吃光了'));
    await tester.tap(find.text('我吃光了'));
    await tester.pumpAndSettle();
    expect(h.controller.repo.state['meals'][id], {
      ...before,
      'after_skipped': true,
    });
    expect(find.byType(MealSheet), findsNothing);
    expect(find.text('补拍剩余'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('配置AI后再次进入记录更新入口说明', (tester) async {
    final h = await Harness.pump(tester, tab: 1, empty: true);
    expect(find.text('未设置 AI，可先存照片'), findsOneWidget);
    h.controller.setTab(3);
    await tester.pumpAndSettle();
    await h.controller.settings.save({
      ...h.controller.settings.value,
      'baseUrl': 'https://example.test',
      'model': 'm',
    }, const Secrets(modelKey: 'test'));
    h.controller.setTab(1);
    await tester.pumpAndSettle();
    expect(find.text('估算热量与蛋白质'), findsOneWidget);
  });
}
