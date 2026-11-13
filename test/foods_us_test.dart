import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/domain/foods.dart';

/// 英文界面显示的名称：已入库的翻译 + 还没导入的 pending 翻译（导入后 pending 可有可无）。
Map<String, String> englishNames() {
  final names = <String, String>{
    for (final e in (jsonDecode(
      File('assets/l10n/en.json').readAsStringSync(),
    ) as Map).entries)
      '${e.key}': '${e.value}',
  };
  final pending = File('tool/l10n/pending/diet.json');
  if (pending.existsSync()) {
    for (final e in (jsonDecode(pending.readAsStringSync()) as Map).entries) {
      final en = (e.value as Map)['en'];
      if (en is String) names['${e.key}'] = en;
    }
  }
  return names;
}

Foods loadFoods() => Foods.parse(
  File('assets/foods.json').readAsStringSync(),
  usSource: File('assets/foods_us.json').readAsStringSync(),
);

void main() {
  final foods = loadFoods();
  final en = englishNames();
  String shown(Map<String, dynamic> f) => en[f['name']] ?? '${f['name']}';
  List<Map<String, dynamic>> us() => foods.items.where(Foods.isUs).toList();
  List<Map<String, dynamic>> search(String q, {bool english = true}) =>
      foods.search(
        q,
        usFirst: english,
        localName: english ? (n) => en[n] ?? n : null,
      );

  group('美式食物包数据', () {
    test('约 300 种，字段完整，名称不与中式库重复', () {
      expect(us().length, inInclusiveRange(280, 330));
      final all = foods.items.map((f) => f['name']).toList();
      expect(all.toSet().length, all.length);
      expect(foods.items.length, greaterThan(331 + 280));
      for (final f in us()) {
        expect(f['region'], 'us');
        expect((f['aliases'] as List), isNotEmpty, reason: '${f['name']}');
      }
    });

    test('每个条目的英文名、分类、份量单位都有翻译', () {
      final cats = foods.categories(us: true);
      expect(cats.length, inInclusiveRange(10, 14));
      for (final f in us()) {
        expect(en[f['name']], isNotNull, reason: '缺英文名：${f['name']}');
        expect(en['${f['unit']}'], isNotNull, reason: '缺单位翻译：${f['unit']}');
        expect(
          (f['aliases'] as List).contains(en[f['name']]!.toLowerCase()),
          isTrue,
          reason: '英文名应是别名之一：${f['name']}',
        );
      }
      for (final c in cats) {
        expect(en[c], isNotNull, reason: c);
      }
    });

    test('热量与三大营养素大体自洽（酒精、膳食纤维留余量），一份量不离谱', () {
      for (final f in us()) {
        final kcal = f['kcal100'] as num;
        final macro =
            4 * (f['protein100'] as num) +
            4 * (f['carbs100'] as num) +
            9 * (f['fat100'] as num);
        final name = '${f['name']}';
        final alcohol = f['category'] == '美式饮品' && kcal > macro;
        if (!alcohol && kcal > 30) {
          expect((macro - kcal).abs() / kcal, lessThan(.3), reason: name);
        }
        expect(kcal, lessThanOrEqualTo(900), reason: name);
        final serving = kcal * (f['gramsPerUnit'] as num) / 100;
        expect(serving, lessThan(1400), reason: name);
      }
    });

    test('常见一餐：美式整餐标注餐次，四个餐次都有', () {
      for (final meal in mealNames) {
        final list = foods.typicalMeals(meal, us: true);
        expect(list, isNotEmpty, reason: meal);
        expect(list.every(Foods.isUs), isTrue);
      }
      expect(foods.typicalMeals('早餐').any(Foods.isUs), isFalse);
      expect(foods.typicalMeals('早餐'), isNotEmpty);
    });

    test('分类：英文是美式分类，中文保持原有分类，互不混入', () {
      final us = foods.categories(us: true), cn = foods.categories();
      expect(us.toSet().intersection(cn.toSet()), isEmpty);
      expect(cn, contains('主食'));
      expect(us, contains('美式早餐'));
      expect(foods.inCategory('美式早餐').every(Foods.isUs), isTrue);
    });
  });

  group('搜索', () {
    // 50 个美国用户常搜的词，以及第一条结果的英文名应包含的词。
    const terms = <(String, String)>[
      ('bagel', 'bagel'),
      ('burrito', 'burrito'),
      ('chicken breast', 'chicken breast'),
      ('greek yogurt', 'greek yogurt'),
      ('protein bar', 'protein bar'),
      ('oatmeal', 'oatmeal'),
      ('avocado toast', 'avocado toast'),
      ('peanut butter', 'peanut butter'),
      ('eggs', 'egg'),
      ('bacon', 'bacon'),
      ('pancakes', 'pancake'),
      ('waffle', 'waffle'),
      ('cereal', 'cereal'),
      ('toast', 'toast'),
      ('cheeseburger', 'cheeseburger'),
      ('pizza', 'pizza'),
      ('mac and cheese', 'mac and cheese'),
      ('sandwich', 'sandwich'),
      ('wrap', 'wrap'),
      ('caesar salad', 'caesar'),
      ('tacos', 'taco'),
      ('sushi', 'sushi'),
      ('fried chicken', 'fried chicken'),
      ('ramen', 'ramen'),
      ('latte', 'latte'),
      ('smoothie', 'smoothie'),
      ('protein shake', 'protein shake'),
      ('cottage cheese', 'cottage cheese'),
      ('jerky', 'jerky'),
      ('canned tuna', 'tuna'),
      ('deli turkey', 'deli turkey'),
      ('french fries', 'french fries'),
      ('hot dog', 'hot dog'),
      ('quesadilla', 'quesadilla'),
      ('nachos', 'nachos'),
      ('salmon', 'salmon'),
      ('shrimp', 'shrimp'),
      ('turkey sandwich', 'turkey sandwich'),
      ('string cheese', 'string cheese'),
      ('almond milk', 'almond milk'),
      ('orange juice', 'orange juice'),
      ('diet soda', 'diet soda'),
      ('beer', 'beer'),
      ('ice cream', 'ice cream'),
      ('chocolate chip cookie', 'cookie'),
      ('brownie', 'brownie'),
      ('donut', 'donut'),
      ('tortilla chips', 'tortilla chips'),
      ('hummus', 'hummus'),
      ('salad with chicken', 'salad with grilled chicken'),
    ];

    test('50 个常用词在英文界面命中率 >= 90%，第一条合理', () {
      expect(terms.length, 50);
      final misses = <String>[];
      var hits = 0;
      for (final (term, expected) in terms) {
        final result = search(term);
        if (result.isEmpty) {
          misses.add('$term（无结果）');
          continue;
        }
        final first = shown(result.first).toLowerCase();
        if (first.contains(expected)) {
          hits++;
        } else {
          misses.add('$term -> $first');
        }
      }
      expect(hits / terms.length, greaterThanOrEqualTo(.9), reason: '$misses');
      // 光有结果还不够：词本身都要能搜到。
      for (final (term, _) in terms) {
        expect(search(term), isNotEmpty, reason: term);
      }
    });

    test('大小写不敏感，英文复数等同单数', () {
      for (final (a, b) in [
        ('EGG', 'egg'),
        ('Eggs', 'egg'),
        ('bagels', 'bagel'),
        ('Burritos', 'burrito'),
        ('sandwiches', 'sandwich'),
        ('tomatoes', 'tomato'),
      ]) {
        expect(
          search(a).map((f) => f['name']).toList(),
          search(b).map((f) => f['name']).toList(),
          reason: '$a vs $b',
        );
      }
      expect(
        search('berries').map(shown),
        containsAll(['Strawberry', 'Blueberry']),
      );
      expect(search('egg'), isNotEmpty);
    });

    test('多个词可以分开写，顺序不限', () {
      expect(
        search('chicken salad').map(shown),
        contains('Salad with grilled chicken'),
      );
      expect(
        shown(search('breast chicken').first).toLowerCase(),
        contains('chicken'),
      );
    });

    test('英文界面美式食物排在前面，中文界面保持原来的顺序', () {
      final enFirst = search('egg').first;
      expect(Foods.isUs(enFirst), isTrue);
      // 中文界面：同样的词仍可搜到美式食物（别名），但中式条目先出现。
      final zh = foods.search('鸡蛋');
      expect(Foods.isUs(zh.first), isFalse);
      expect(zh.first['name'], '鸡蛋（全蛋）');
      expect(
        foods.search('bagel').any(Foods.isUs),
        isTrue,
        reason: '中文界面输入英文也能搜到美式食物',
      );
      // 中文界面不受美式食物包影响：同一个词，剔除美式条目后与只有中式库时完全一致。
      final cnOnly = Foods.parse(File('assets/foods.json').readAsStringSync());
      for (final q in ['鸡', '牛奶', '蛋', '米饭', 'rice', 'jd', '牛', '汤']) {
        expect(
          foods
              .search(q, limit: 500)
              .where((f) => !Foods.isUs(f))
              .map((f) => f['name'])
              .toList(),
          cnOnly.search(q, limit: 500).map((f) => f['name']).toList(),
          reason: q,
        );
      }
    });

    test('中文名搜美式食物：名称、简称都可以', () {
      expect(foods.search('贝果').map((f) => f['name']), contains('贝果'));
      expect(foods.search('墨西哥').any(Foods.isUs), isTrue);
    });

    test('分类浏览的食物数量合理', () {
      for (final c in foods.categories(us: true)) {
        expect(foods.inCategory(c).length, greaterThanOrEqualTo(5), reason: c);
      }
    });
  });
}
