import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/core/native.dart';
import 'package:leandaily/data/backup.dart';
import 'package:leandaily/data/my_foods_store.dart';
import 'package:leandaily/data/repository.dart';
import 'package:leandaily/l10n/app_messages.dart';
import 'package:leandaily/ui/kit/form.dart' show FormSwitch;
import 'package:leandaily/ui/sheets/food/food_controls.dart';
import 'package:leandaily/ui/sheets/quick_food_sheet.dart';
import 'package:leandaily/ui/today/today_widgets.dart';

import 'foods_us_test.dart' show loadFoods;
import 'support/harness.dart';

const _today = '2026-10-16', _yesterday = '2026-10-15';

final _eggToast = [
  {
    'name': '鸡蛋（全蛋）',
    'portion': '约2个（100g）',
    'kcal': 143,
    'protein': 12.6,
    'carbs': 0.7,
    'fat': 9.5,
  },
  {
    'name': '白吐司',
    'portion': '约2片（60g）',
    'kcal': 160,
    'protein': 5,
    'carbs': 30,
    'fat': 2,
  },
];

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pumpAndSettle();
}

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text).hitTestable().first);
  await _settle(tester);
}

/// 与线上一致：加号 → 搜索 / 手动记饮食。返回已经点过的次数。
Future<int> _openQuick(
  WidgetTester tester, {
  String label = '搜索 / 手动记饮食',
}) async {
  await tester.tap(find.byKey(const ValueKey('log-add')));
  await _settle(tester);
  await tester.tap(find.text(label));
  await _settle(tester);
  return 2;
}

Future<Harness> _pump(
  WidgetTester tester, {
  bool dark = false,
  Locale locale = const Locale('zh', 'CN'),
  void Function(FakeNative)? seed,
}) async {
  if (locale.languageCode == 'en') {
    // 还没导入主翻译表时，用 pending 里的英文模拟导入后的样子。
    await tester.runAsync(
      () => AppMessages.debugMerge(
        jsonDecode(File('tool/l10n/pending/diet.json').readAsStringSync())
            as Map<String, dynamic>,
      ),
    );
  }
  final h = await Harness.pump(
    tester,
    tab: 1,
    empty: true,
    dark: dark,
    locale: locale,
    seed: seed,
  );
  // 食物库用同一份真实资源，避免测试里解码资源的异步等待。
  h.controller.foods = loadFoods();
  return h;
}

List meals(Harness h, String date) =>
    h.controller.repo.meals(date)['meals'] as List;

Future<void> _enter(WidgetTester tester, String label, String value) async {
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

Future<void> _seedMeal(
  Harness h, {
  String date = _today,
  String meal = '午餐',
  String time = '12:10',
  List? items,
}) => h.controller.repo.saveMeal(
  date: date,
  meal: meal,
  time: time,
  source: '手动填写',
  items: items ?? _eggToast,
);

void main() {
  setUpAll(Harness.setUpAll);

  group('再记一次', () {
    testWidgets('餐卡一点就把这一餐复制到所选日期、同一餐次，可撤销', (tester) async {
      final h = await _pump(tester);
      await _seedMeal(h);
      await _settle(tester);
      expect(find.text('再记一次'), findsOneWidget);
      await tester.tap(find.text('再记一次'));
      await _settle(tester);
      final rows = meals(h, _today);
      expect(rows, hasLength(2));
      final copy = rows.firstWhere(
        (m) => m['record_id'] != meals(h, _today).first['record_id'],
      ) as Map;
      final original =
          rows.firstWhere((m) => m['record_id'] != copy['record_id']) as Map;
      expect(copy['meal'], '午餐');
      expect(copy['items'], original['items']);
      expect(copy['kcal'], original['kcal']);
      expect(copy['protein'], original['protein']);
      expect(copy['source'], '手动填写');
      expect(copy['photo_ids'], isEmpty);
      // 原来的一餐没有被改动。
      expect(original['items'], _eggToast.map((e) => e).toList());
      await tester.tap(find.text('撤销').hitTestable());
      await _settle(tester);
      expect(meals(h, _today), hasLength(1));
      await tester.pump(const Duration(seconds: 7));
    });

    testWidgets('看的是别的日子时，复制到那一天并沿用原来的时间', (tester) async {
      final h = await _pump(tester);
      await _seedMeal(h, date: _yesterday, meal: '晚餐', time: '19:20');
      h.controller.setDate(_yesterday);
      await _settle(tester);
      await tester.tap(find.text('再记一次'));
      await _settle(tester);
      expect(meals(h, _yesterday), hasLength(2));
      expect(meals(h, _today), isEmpty);
      expect(
        meals(h, _yesterday).map((m) => (m as Map)['time']),
        everyElement('19:20'),
      );
      await tester.pump(const Duration(seconds: 7));
    });

    testWidgets('没有食物明细的记录不出现「再记一次」', (tester) async {
      final h = await _pump(tester);
      await h.controller.repo.saveMeal(
        date: _today,
        meal: '早餐',
        note: '只写了备注',
        source: '手动填写',
      );
      await _settle(tester);
      expect(find.text('再记一次'), findsNothing);
      await tester.pump(const Duration(seconds: 7));
    });
  });

  group('和昨天一样', () {
    testWidgets('加号 → 记饮食 → 记下：3 次点击记完，且可撤销', (tester) async {
      final h = await _pump(tester);
      await _seedMeal(h, date: _yesterday, meal: '早餐', time: '08:05');
      await _settle(tester);
      var taps = await _openQuick(tester);
      expect(find.text('和昨天的早餐一样'), findsOneWidget);
      // 只留这一条，不堆列表。
      expect(find.textContaining('和昨天的'), findsOneWidget);
      await tester.tap(find.text('记下'));
      taps++;
      await _settle(tester);
      expect(taps, lessThanOrEqualTo(3));
      expect(find.byType(QuickFoodSheet), findsNothing);
      final saved = meals(h, _today).single as Map;
      expect(saved['meal'], '早餐');
      expect(saved['items'], _eggToast);
      expect(meals(h, _yesterday), hasLength(1));
      await tester.tap(find.text('撤销').hitTestable());
      await _settle(tester);
      expect(meals(h, _today), isEmpty);
      await tester.pump(const Duration(seconds: 7));
    });

    testWidgets('昨天同一餐次没有记录时不出现；换餐次跟着变', (tester) async {
      final h = await _pump(tester);
      await _seedMeal(h, date: _yesterday, meal: '晚餐', time: '19:00');
      await _openQuick(tester);
      // 现在是早上，默认早餐：昨天没有早餐。
      expect(find.textContaining('和昨天的'), findsNothing);
      await _tapText(tester, '晚餐');
      expect(find.text('和昨天的晚餐一样'), findsOneWidget);
      await _tapText(tester, '午餐');
      expect(find.textContaining('和昨天的'), findsNothing);
      expect(h.controller.repo.state['meals'].length, 1);
    });
  });

  group('我的食物', () {
    testWidgets('手动输入时勾选保存，之后能搜到、能编辑、能删除', (tester) async {
      final h = await _pump(tester);
      await _openQuick(tester);
      await _tapText(tester, '手动输入');
      await _enter(tester, '名称', '外婆的红烧肉');
      await _enter(tester, '热量（千卡）', '320');
      await _enter(tester, '蛋白（g）', '18');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.tap(find.byType(FormSwitch));
      await _settle(tester);
      await _tapText(tester, '加入');
      final doc = jsonDecode(h.native.docs[MyFoodsStore.key]!) as Map;
      expect(doc['v'], 1);
      expect((doc['foods'] as List).single, containsPair('name', '外婆的红烧肉'));
      expect((doc['foods'] as List).single['kcal'], 320);
      expect(h.controller.myFoods.foods, hasLength(1));

      // 没勾选的不会存。
      await _enter(tester, '名称', '一次性的');
      await _enter(tester, '热量（千卡）', '50');
      await _enter(tester, '蛋白（g）', '1');
      await tester.tap(find.byType(FormSwitch));
      await _settle(tester);
      await _tapText(tester, '加入');
      expect(h.controller.myFoods.foods, hasLength(1));

      // 搜得到。
      await _tapText(tester, '搜食物');
      await _enter(tester, '搜索食物', '红烧');
      FocusManager.instance.primaryFocus?.unfocus();
      await _settle(tester);
      expect(find.text('外婆的红烧肉'), findsWidgets);
      expect(find.text('1 份'), findsWidgets);
      await _enter(tester, '搜索食物', '');
      await _settle(tester);
      expect(find.text('我的食物'), findsOneWidget);

      // 编辑。
      await _tapText(tester, '编辑');
      await tester.tap(find.bySemanticsLabel('编辑 外婆的红烧肉'));
      await _settle(tester);
      await _enter(tester, '热量（千卡）', '400');
      await _tapText(tester, '保存');
      expect(h.controller.myFoods.foods.single['kcal'], 400);
      expect(
        (jsonDecode(h.native.docs[MyFoodsStore.key]!)['foods'] as List)
            .single['kcal'],
        400,
      );

      // 删除。
      await tester.tap(find.bySemanticsLabel('编辑 外婆的红烧肉'));
      await _settle(tester);
      await _tapText(tester, '删除');
      await _tapText(tester, '删除');
      expect(h.controller.myFoods.foods, isEmpty);
      expect(find.text('我的食物'), findsNothing);
      // 放弃这次填写？（购物篮里还有“一次性的”）
      await tester.pump(const Duration(seconds: 7));
    });

    testWidgets('我的食物按一份记，能调份数，营养写进记录', (tester) async {
      final h = await _pump(
        tester,
        seed: (n) => n.docs[MyFoodsStore.key] = jsonEncode({
          'v': 1,
          'foods': [
            {
              'id': 'f1',
              'name': '自制能量球',
              'kcal': 120,
              'protein': 6,
              'carbs': 14,
              'fat': 5,
            },
          ],
          'meals': [],
        }),
      );
      await _openQuick(tester);
      await tester.tap(find.bySemanticsLabel('选择 自制能量球'));
      await _settle(tester);
      await tester.tap(
        find.byWidgetPredicate((w) => w is FoodButton && w.label == '＋').last,
      );
      await _settle(tester);
      await tester.tap(
        find.byWidgetPredicate((w) => w is FoodButton && w.label == '＋').last,
      );
      await _settle(tester);
      await _tapText(tester, '加入');
      await _tapText(tester, '记录');
      final saved = meals(h, _today).single as Map;
      final item = (saved['items'] as List).single as Map;
      expect(item['name'], '自制能量球');
      expect(item['kcal'], 240);
      expect(item['protein'], 12);
      expect(item['portion'], '约2份');
      await tester.pump(const Duration(seconds: 7));
    });

    testWidgets('同名再次保存是更新，不会出现两条', (tester) async {
      final h = await _pump(tester);
      await h.controller.saveMyFood(name: '能量球', kcal: 100, protein: 5);
      await h.controller.saveMyFood(name: '能量球', kcal: 120, protein: 6);
      expect(h.controller.myFoods.foods, hasLength(1));
      expect(h.controller.myFoods.foods.single['kcal'], 120);
    });

    test('备份导出带上我的食物，恢复后还在；旧备份没有这一项也能导入', () async {
      final n = FakeNative(now: DateTime.parse('2026-10-16T09:00:00'));
      final repo = Repository(n);
      await repo.load();
      final store = MyFoodsStore(n);
      await store.saveFood(name: '能量球', kcal: 120, protein: 6);
      await store.saveMeal(items: _eggToast);
      final doc = n.docs[MyFoodsStore.key]!;
      final backup = await exportBackup(n, repo);
      expect(backup['preferences'][MyFoodsStore.key], doc);

      final target = FakeNative(now: DateTime.parse('2026-10-16T09:00:00'));
      final targetRepo = Repository(target);
      await targetRepo.load();
      await restoreBackup(target, targetRepo, backup);
      final back = await MyFoodsStore(target).load();
      expect(back.foods.single['name'], '能量球');
      expect(back.meals.single['items'], _eggToast);

      // 旧备份没有这一项：照常导入，我的食物为空，不报错。
      final old = jsonDecode(jsonEncode(backup)) as Map<String, dynamic>;
      (old['preferences'] as Map).remove(MyFoodsStore.key);
      await validateBackup(old, native: target);
      await restoreBackup(target, targetRepo, old);
      expect((await MyFoodsStore(target).load()).isEmpty, isTrue);
    });
  });

  group('保存为常吃整餐', () {
    testWidgets('多个食物存成整餐，下次加号 → 记饮食 → 记下 一下记完（3 次点击）', (tester) async {
      final h = await _pump(tester);
      await _openQuick(tester);
      // 手动加两个食物进购物篮。
      await _tapText(tester, '手动输入');
      for (final (name, kcal, protein) in [
        ('燕麦杯', '150', '5'),
        ('蛋白奶', '120', '24'),
      ]) {
        await _enter(tester, '名称', name);
        await _enter(tester, '热量（千卡）', kcal);
        await _enter(tester, '蛋白（g）', protein);
        FocusManager.instance.primaryFocus?.unfocus();
        await _tapText(tester, '加入');
        if (name == '燕麦杯') {
          // 只有一个食物时还不能存成整餐。
          expect(find.text('存为常吃整餐'), findsNothing);
        }
      }
      await _tapText(tester, '存为常吃整餐');
      expect(h.controller.myFoods.meals, hasLength(1));
      final meal = h.controller.myFoods.meals.single;
      expect(meal['name'], '燕麦杯、蛋白奶');
      expect((meal['items'] as List).map((e) => (e as Map)['name']), [
        '燕麦杯',
        '蛋白奶',
      ]);
      await _tapText(tester, '记录');
      expect(meals(h, _today), hasLength(1));
      await tester.pump(const Duration(seconds: 7));

      // 下一次：加号(1) → 记饮食(2) → 记下(3)。
      var taps = await _openQuick(tester);
      expect(find.text('燕麦杯、蛋白奶'), findsOneWidget);
      await tester.tap(find.text('记下').last);
      taps++;
      await _settle(tester);
      expect(taps, 3);
      expect(find.byType(QuickFoodSheet), findsNothing);
      final rows = meals(h, _today);
      expect(rows, hasLength(2));
      final latest = rows.cast<Map>().firstWhere(
        (m) => m['note'] == '' && m != rows.first,
      );
      expect((latest['items'] as List), hasLength(2));
      expect(latest['kcal'], 270);
      expect(latest['protein'], 29);
      expect(latest['meal'], '早餐');
      await tester.pump(const Duration(seconds: 7));
    });

    testWidgets('整餐可以改名和删除', (tester) async {
      final h = await _pump(tester);
      await h.controller.saveMyMeal(_eggToast);
      await _openQuick(tester);
      await _tapText(tester, '编辑');
      await tester.tap(find.bySemanticsLabel('编辑 鸡蛋（全蛋）、白吐司'));
      await _settle(tester);
      expect(find.text('碳水（g）'), findsNothing, reason: '整餐只改名称');
      await _enter(tester, '名称', '周末早餐');
      await _tapText(tester, '保存');
      expect(h.controller.myFoods.meals.single['name'], '周末早餐');
      await tester.tap(find.bySemanticsLabel('编辑 周末早餐'));
      await _settle(tester);
      await _tapText(tester, '删除');
      await _tapText(tester, '删除');
      expect(h.controller.myFoods.meals, isEmpty);
    });

    testWidgets('购物篮里已有食物时，常吃整餐改为加进购物篮而不是直接保存', (tester) async {
      final h = await _pump(tester);
      await h.controller.saveMyMeal(_eggToast);
      await _openQuick(tester);
      await _tapText(tester, '手动输入');
      await _enter(tester, '名称', '咖啡');
      await _enter(tester, '热量（千卡）', '5');
      await _enter(tester, '蛋白（g）', '0');
      FocusManager.instance.primaryFocus?.unfocus();
      await _tapText(tester, '加入');
      await _tapText(tester, '搜食物');
      await _tapText(tester, '加入');
      expect(meals(h, _today), isEmpty);
      expect(find.text('已选 3'), findsOneWidget);
    });
  });

  group('英文界面', () {
    testWidgets('美式分类和美式整餐在前，中文名走翻译', (tester) async {
      final h = await _pump(tester, locale: const Locale('en'));
      await _openQuick(tester, label: 'Search / enter a meal manually');
      // 分类默认是美式分类。
      expect(find.text('Breakfast'), findsWidgets);
      expect(find.text('Meals & takeout'), findsOneWidget);
      expect(find.text('Grains & starches'), findsNothing);
      // 常见一餐：美式整餐，名称是英文。
      expect(find.text('Eggs, bacon and toast breakfast'), findsOneWidget);
      expect(
        find.text('Egg, milk and whole-wheat bread breakfast'),
        findsNothing,
      );
      // 餐次分段里也有 Breakfast，分类 chip 在它后面。
      await tester.tap(find.text('Breakfast').last);
      await _settle(tester);
      expect(find.text('Bagel (4 in)'), findsOneWidget);
      expect(find.text('Chicken burrito'), findsNothing);
      await _enter(tester, '搜索食物', 'bagel');
      FocusManager.instance.primaryFocus?.unfocus();
      await _settle(tester);
      expect(find.text('Bagel (4 in)'), findsOneWidget);
      expect(find.text('1 piece (105 g)'), findsWidgets);
      expect(h.controller.foods, isNotNull);
    });

    testWidgets('中文界面保持原来的分类和整餐顺序', (tester) async {
      final h = await _pump(tester);
      await _openQuick(tester);
      expect(find.text('主食'), findsOneWidget);
      expect(find.text('美式早餐'), findsNothing);
      expect(find.text('鸡蛋牛奶全麦面包早餐'), findsOneWidget);
      expect(find.text('鸡蛋培根吐司早餐'), findsNothing);
      expect(h.controller.foods, isNotNull);
    });
  });

  group('截图', () {
    for (final (name, dark, locale) in [
      ('light', false, const Locale('zh', 'CN')),
      ('dark', true, const Locale('zh', 'CN')),
      ('en', false, const Locale('en')),
    ]) {
      testWidgets('记饮食弹层 + 餐卡 $name', (tester) async {
        final en = locale.languageCode == 'en';
        final h = await _pump(
          tester,
          dark: dark,
          locale: locale,
          seed: (n) => n.docs[MyFoodsStore.key] = jsonEncode({
            'v': 1,
            'foods': [
              {
                'id': 'f1',
                'name': en ? 'Energy bites' : '自制能量球',
                'kcal': 120,
                'protein': 6,
                'carbs': 14,
                'fat': 5,
              },
            ],
            'meals': [
              {
                'id': 'm1',
                'name': en ? 'Oats and whey' : '燕麦杯、蛋白奶',
                'items': _eggToast,
              },
            ],
          }),
        );
        await _seedMeal(h, date: _yesterday, meal: '早餐', time: '08:05');
        await _seedMeal(h, meal: '午餐');
        await _settle(tester);
        await h.shot(tester, 'diet-log-card-$name');
        await _openQuick(
          tester,
          label: en ? 'Search / enter a meal manually' : '搜索 / 手动记饮食',
        );
        await h.shot(tester, 'diet-quick-$name');
        // 手动输入页：保存到我的食物。
        await _tapText(tester, en ? 'Manual entry' : '手动输入');
        await h.shot(tester, 'diet-manual-$name');
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 7));
      });
    }
  });

  testWidgets('食物按钮仍是墨色主按钮，不用橙色', (tester) async {
    await _pump(tester);
    await _openQuick(tester);
    final primary = tester
        .widgetList<FoodButton>(find.byType(FoodButton))
        .where((b) => b.primary);
    expect(primary, hasLength(1));
  });
}
