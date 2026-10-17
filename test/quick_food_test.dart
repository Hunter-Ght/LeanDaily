import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/app/routes.dart' show openQuickFood;
import 'package:leandaily/app/app_controller.dart';
import 'package:leandaily/domain/foods.dart';
import 'package:leandaily/core/native.dart';
import 'package:leandaily/ui/sheets/food/portion_panel.dart';
import 'package:leandaily/ui/sheets/quick_food_sheet.dart' show QuickFoodSheet;
import 'package:leandaily/ui/today/today_page.dart';
import 'package:leandaily/ui/today/today_widgets.dart';
import 'package:leandaily/ui/sheets/meal_sheet.dart';

import 'support/harness.dart';
import 'today_four_test.dart' show fourProfile;

Future<void> settleFood(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pumpAndSettle();
}

Future<void> enterFood(WidgetTester tester, String label, String value) async {
  final field = find
      .descendant(
        of: find.byWidgetPredicate((w) => w is TodayInput && w.label == label),
        matching: find.byType(EditableText),
      )
      .first;
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pump();
}

Future<void> openFood(WidgetTester tester) async {
  final context = tester.element(find.byType(TodayPage));
  // Asset decoding uses an isolate; seed the already-loaded catalogue contract
  // synchronously in widget tests, keeping the full production food asset.
  context.app.foods ??= Foods.parse(
    File('assets/foods.json').readAsStringSync(),
  );
  openQuickFood(context);
  await settleFood(tester);
}

void main() {
  setUpAll(Harness.setUpAll);
  for (final dark in [false, true]) {
    testWidgets('搜索→份量→托盘→保存和即时刷新 ${dark ? 'dark' : 'light'}', (tester) async {
      final h = await Harness.pump(
        tester,
        empty: true,
        dark: dark,
        seed: (n) => n.docs['fw-profile-v1'] = jsonEncode(fourProfile()),
      );
      await openFood(tester);
      expect(find.text('拍照'), findsNothing);
      expect(find.text('在 我的 → 高级 里配置大模型后可用'), findsOneWidget);
      await enterFood(tester, '搜索食物', '鸡胸肉');
      FocusManager.instance.primaryFocus?.unfocus();
      await settleFood(tester);
      await h.shot(tester, 'quick-food-search-${dark ? 'dark' : 'light'}');
      final food = h.controller.foods!.search('鸡胸肉').first;
      await tester.tap(find.bySemanticsLabel('选择 ${food['name']}'));
      await settleFood(tester);
      if (find
          .byWidgetPredicate((w) => w is TodayInput && w.label == '克数')
          .evaluate()
          .isEmpty) {
        await tester.tap(find.text('改用克数'));
        await settleFood(tester);
      }
      await enterFood(tester, '克数', '200');
      FocusManager.instance.primaryFocus?.unfocus();
      await settleFood(tester);
      await tester.tap(find.text('加入'));
      await settleFood(tester);
      final expected = h.controller.foods!.entryFor(food, grams: 200);
      expect(find.textContaining('${food['name']} ×'), findsOneWidget);
      await h.shot(tester, 'quick-food-tray-${dark ? 'dark' : 'light'}');
      await tester.tap(find.text('午餐'));
      await tester.tap(
        find.descendant(
          of: find.byType(QuickFoodSheet),
          matching: find.text('记录'),
        ),
      );
      await settleFood(tester);
      expect(find.byType(QuickFoodSheet), findsNothing);
      final meals =
          h.controller.repo.meals(h.controller.today)['meals'] as List;
      expect(meals, hasLength(1));
      expect(meals.single['source'], '手动填写');
      expect(meals.single['meal'], '午餐');
      expect(meals.single['items'], [expected]);
      final stored = jsonDecode(h.native.docs['android-state']!) as Map;
      expect((stored['meals'] as Map).values.single['items'], [expected]);
      // 今日页的营养条带读同一份合计：蛋白合计包含刚记的这一项。
      expect(
        (h.controller.repo.meals(h.controller.today)['totals']
            as Map)['protein'],
        greaterThanOrEqualTo(expected['protein'] as num),
      );
      // The same food now appears in the actual recent-history section.
      await openFood(tester);
      expect(find.text('${food['name']}').first, findsOneWidget);
      await tester.tap(find.text('手动输入'));
      await settleFood(tester);
    });
  }

  testWidgets('份量默认一份而不是 100 克，可半份加减并在份数与克数间换算', (tester) async {
    await Harness.pump(tester, empty: true);
    await openFood(tester);
    await enterFood(tester, '搜索食物', '米饭');
    FocusManager.instance.primaryFocus?.unfocus();
    await settleFood(tester);
    await tester.tap(find.bySemanticsLabel('选择 米饭'));
    await settleFood(tester);
    expect(find.text('1 碗 ≈ 150 g，共约 150 g'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(FoodPortionPanel),
        matching: find.text('＋'),
      ),
    );
    await settleFood(tester);
    expect(find.text('1 碗 ≈ 150 g，共约 225 g'), findsOneWidget);
    await tester.tap(find.text('改用克数'));
    await settleFood(tester);
    expect(find.text('约 1.5 碗'), findsOneWidget);
    expect(find.text('改用份数（碗）'), findsOneWidget);
    await tester.tap(find.text('改用份数（碗）'));
    await settleFood(tester);
    expect(find.text('1 碗 ≈ 150 g，共约 225 g'), findsOneWidget);
    await tester.tap(find.text('1碗'));
    await settleFood(tester);
    expect(find.text('1 碗 ≈ 150 g，共约 150 g'), findsOneWidget);
    await tester.tap(find.text('加入'));
    await settleFood(tester);
    expect(find.textContaining('米饭 ×'), findsOneWidget);
  });

  testWidgets('手动输入更多字段、移除、合并保存与非法值保护', (tester) async {
    final h = await Harness.pump(tester, empty: true);
    await openFood(tester);
    await tester.tap(find.text('手动输入'));
    await settleFood(tester);
    await enterFood(tester, '名称', '自制便当');
    await enterFood(tester, '热量（千卡）', '-1');
    await enterFood(tester, '蛋白（g）', '30');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.tap(find.text('加入'));
    await settleFood(tester);
    expect(find.text('已选 0'), findsOneWidget);
    await enterFood(tester, '热量（千卡）', '450');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.tap(find.text('更多'));
    await settleFood(tester);
    await enterFood(tester, '碳水（g）', '50');
    await enterFood(tester, '脂肪（g）', '12');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.tap(find.text('加入'));
    await settleFood(tester);
    expect(find.text('已选 1'), findsOneWidget);
    await tester.tap(find.textContaining('自制便当 ×'));
    await settleFood(tester);
    expect(find.text('已选 0'), findsOneWidget);
    await enterFood(tester, '名称', '酸奶');
    await enterFood(tester, '热量（千卡）', '100');
    await enterFood(tester, '蛋白（g）', '8');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.tap(find.text('加入'));
    await settleFood(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(QuickFoodSheet),
        matching: find.text('记录'),
      ),
    );
    await settleFood(tester);
    final meals = h.controller.repo.meals(h.controller.today)['meals'] as List;
    expect(meals.single['items'].single['name'], '酸奶');
    expect(meals.single['items'].single['kcal'], 100);
    expect(meals.single['items'].single['protein'], 8);
    await tester.pump(const Duration(seconds: 3));
    await settleFood(tester);
  });

  testWidgets('历史日期、常吃边界与多项合并保存', (tester) async {
    final h = await Harness.pump(tester, empty: true);
    await h.controller.repo.saveMeal(
      date: '2026-10-02',
      meal: '早餐',
      items: [
        {'name': '超过窗口的便当', 'kcal': 200, 'protein': 10},
      ],
    );
    await h.controller.repo.saveMeal(
      date: '2026-10-03',
      meal: '早餐',
      items: [
        {'name': '自配高蛋白便当', 'portion': '一盒', 'kcal': 400, 'protein': 30},
      ],
    );
    await settleFood(tester);
    await openFood(tester);
    expect(find.text('自配高蛋白便当'), findsOneWidget);
    expect(find.text('超过窗口的便当'), findsNothing);
    await tester.tap(find.bySemanticsLabel('选择 自配高蛋白便当'));
    await settleFood(tester);
    expect(find.text('改用克数'), findsNothing);
    await tester.tap(find.text('加入'));
    await settleFood(tester);
    await tester.tap(find.text('手动输入'));
    await settleFood(tester);
    await enterFood(tester, '名称', '加一杯奶');
    await enterFood(tester, '热量（千卡）', '100');
    await enterFood(tester, '蛋白（g）', '8');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.tap(find.text('加入'));
    await settleFood(tester);
    expect(find.text('已选 2'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(QuickFoodSheet),
        matching: find.text('记录'),
      ),
    );
    await settleFood(tester);
    final meals = h.controller.repo.meals(h.controller.today)['meals'] as List;
    expect(meals, hasLength(1));
    expect(meals.single['items'], hasLength(2));
    expect(meals.single['kcal'], 500);
    expect(meals.single['protein'], 38);
    await tester.pump(const Duration(seconds: 3));
    // Explicit dates stay independent of the globally selected date.
    openQuickFood(
      tester.element(find.byType(TodayPage)),
      date: '2026-10-04',
      meal: '晚餐',
    );
    await settleFood(tester);
    await tester.tap(find.bySemanticsLabel('选择 自配高蛋白便当'));
    await settleFood(tester);
    await tester.tap(find.text('加入'));
    await settleFood(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(QuickFoodSheet),
        matching: find.text('记录'),
      ),
    );
    await settleFood(tester);
    expect(
      (h.controller.repo.meals('2026-10-04')['meals'] as List).single['meal'],
      '晚餐',
    );
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('食物库为空时显示加载中，键盘弹出时托盘保持可见', (tester) async {
    final h = await Harness.pump(tester, empty: true);
    openQuickFood(tester.element(find.byType(TodayPage)));
    await settleFood(tester);
    h.controller.foods = null;
    await tester.pump();
    expect(find.text('食物库加载中…'), findsOneWidget);
    await tester.tap(find.text('手动输入'));
    await settleFood(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 600);
    await tester.pump();
    expect(tester.takeException(), isNull);
    final record = find.descendant(
      of: find.byType(QuickFoodSheet),
      matching: find.text('记录'),
    );
    expect(tester.getBottomLeft(record).dy, lessThan(550));
    tester.view.resetViewInsets();
    await tester.pump();
  });

  testWidgets('模型和密钥全部存在才显示拍照', (tester) async {
    final h = await Harness.pump(
      tester,
      seed: (n) {
        n.secrets = const Secrets(modelKey: 'test-key');
      },
    );
    await h.controller.settings.save({
      ...h.controller.settings.value,
      'model': 'test-model',
      'baseUrl': 'https://example.invalid',
    });
    await openFood(tester);
    expect(find.text('拍照'), findsOneWidget);
    await tester.tap(find.text('拍照'));
    await settleFood(tester);
    expect(find.byType(MealSheet), findsOneWidget);
  });
}
