import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/domain/foods.dart';
import 'package:leandaily/domain/format.dart' show fmt;
import 'package:leandaily/l10n/app_messages.dart';
import 'package:leandaily/ui/kit/grouped.dart';
import 'package:leandaily/ui/kit/app_icon.dart';
import 'package:leandaily/ui/sheets/food/food_controls.dart';
import 'package:leandaily/ui/today/today_nutrition_strip.dart';

import 'support/harness.dart';
import 'quick_food_test.dart' show openFood, settleFood, enterFood;
import 'today_four_test.dart' show fourProfile;

void main() {
  setUpAll(Harness.setUpAll);
  test('generic scoop scales configured nutrition without mutating it', () {
    final configured = {
      'name': '乳清蛋白粉',
      'grams': 40,
      'protein': 30,
      'kcal': 160,
    };
    final before = jsonEncode(configured);
    final serving = entryFor(proteinPowderFood(configured), units: 1);
    expect(serving['name'], '蛋白粉');
    expect(serving['portion'], '约1勺（30g）');
    expect(serving['kcal'], 120);
    expect(serving['protein'], 22.5);
    expect(jsonEncode(configured), before);
  });
  testWidgets('language row has a dedicated globe icon', (t) async {
    await Harness.pump(t, tab: 3);
    final row = find.byWidgetPredicate((w) => w is GroupRow && w.label == '语言');
    expect(
      find.descendant(
        of: row,
        matching: find.byWidgetPredicate(
          (w) => w is AppIcon && w.name == 'language',
        ),
      ),
      findsOneWidget,
    );
  });
  testWidgets(
    'English quick foods show servings, one powder and preserve past records',
    (t) async {
      final h = await Harness.pump(t, locale: const Locale('en'), empty: true);
      await h.controller.repo.saveMeal(
        date: h.controller.date,
        meal: '加餐',
        time: '08:00',
        source: '手动填写',
        items: [
          {
            'name': '酵母蛋白粉',
            'portion': '1 勺',
            'protein': 22.6,
            'kcal': 124,
            'carbs': 0,
            'fat': 0,
          },
        ],
      );
      final before = h.native.docs['android-state'];
      await openFood(t);
      expect(
        find.text('Protein powder'),
        findsNWidgets(2),
      ); // recent + recommended
      expect(find.textContaining('酵母'), findsNothing);
      expect(find.textContaining('100g'), findsNothing);
      expect(find.textContaining('1 scoop (30 g)'), findsWidgets);
      await enterFood(t, '搜索食物', 'rice');
      FocusManager.instance.primaryFocus?.unfocus();
      await settleFood(t);
      final rice = h.controller.foods!.items.firstWhere(
        (f) => f['name'] == '米饭',
      );
      final serving = entryFor(rice, units: 1);
      expect(
        find.text(
          '1 bowl (150 g) · ${fmt(serving['kcal'])} kcal / ${fmt(serving['protein'])} g protein',
        ),
        findsWidgets,
      );
      expect(h.native.docs['android-state'], before);
      await h.shot(t, 'quick-food-serving-en');
      await t.tap(
        find.byWidgetPredicate((w) => w is FoodButton && w.label == '＋').first,
      );
      await settleFood(t);
      expect(find.text('0.5 bowl'), findsOneWidget);
      expect(find.textContaining('碗'), findsNothing);
    },
  );
  testWidgets(
    'today powder chip and saved scoop use the same generic serving',
    (t) async {
      final h = await Harness.pump(
        t,
        locale: const Locale('en'),
        empty: true,
        size: const Size(393, 2300),
        seed: (n) => n.docs['fw-profile-v1'] = jsonEncode(fourProfile()),
      );
      final planBefore = jsonEncode(h.controller.plan);
      final label = AppMessages(const Locale('en')).text('展开营养条带');
      await t.tap(find.bySemanticsLabel(RegExp(RegExp.escape(label))));
      await settleFood(t);
      final chip = t
          .widgetList<TodayFoodChip>(find.byType(TodayFoodChip))
          .firstWhere((w) => w.name == '蛋白粉');
      expect(chip.portion, '1 勺（30 g）');
      expect(find.textContaining('酵母'), findsNothing);
      chip.onTap!();
      await settleFood(t);
      final record =
          (h.controller.repo.meals(h.controller.date)['meals'] as List)
              .single['items']
              .single;
      expect(record['name'], '蛋白粉');
      expect(record['portion'], '约1勺（30g）');
      expect(record['protein'], chip.protein);
      expect(jsonEncode(h.controller.plan), planBefore);
      await t.pump(const Duration(seconds: 4));
    },
  );
  for (final locale in AppMessages.locales) {
    for (final width in [320.0, 393.0]) {
      testWidgets('manual fields do not overlap More: $locale / $width', (
        t,
      ) async {
        final h = await Harness.pump(
          t,
          locale: locale,
          empty: true,
          size: Size(width, 852),
        );
        final m = AppMessages(locale);
        await openFood(t);
        await t.tap(find.text(m.text('手动输入')));
        await settleFood(t);
        final kcal = find.byWidgetPredicate(
          (w) => w is FoodField && w.label == '热量（千卡）',
        );
        final protein = find.byWidgetPredicate(
          (w) => w is FoodField && w.label == '蛋白（g）',
        );
        final more = find.byWidgetPredicate(
          (w) => w is FoodButton && w.label == '更多',
        );
        expect(
          t.getRect(more).top - t.getRect(kcal).bottom,
          greaterThanOrEqualTo(10),
        );
        expect(
          t.getRect(more).top - t.getRect(protein).bottom,
          greaterThanOrEqualTo(10),
        );
        await t.tap(more);
        await settleFood(t);
        expect(t.takeException(), isNull);
        if (width == 393) await h.shot(t, 'quick-food-manual-${m.code}');
      });
    }
  }
}
