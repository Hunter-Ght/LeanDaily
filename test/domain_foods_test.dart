import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/domain/foods.dart';
import 'package:leandaily/domain/records.dart' show cleanItems;

Map<String, dynamic> sample(
  String name, {
  List<String> aliases = const [],
  num kcal = 145,
  num protein = 13,
}) => {
  'name': name,
  'aliases': aliases,
  'category': '肉禽蛋',
  'unit': '个',
  'gramsPerUnit': 50,
  'kcal100': kcal,
  'protein100': protein,
  'carbs100': 2,
  'fat100': 10,
};

void main() {
  final source = File('assets/foods.json').readAsStringSync();
  final foods = Foods.parse(source);
  Map<String, dynamic> named(String name) =>
      foods.items.singleWhere((food) => food['name'] == name);

  group('parse', () {
    test('parses JSON shapes without mutating or exposing catalogue state', () {
      final parsed = Foods.parse(jsonEncode([sample('鸡蛋')]));
      expect(parsed.items.single, sample('鸡蛋'));
      expect(() => parsed.items.clear(), throwsUnsupportedError);
      expect(() => parsed.items.single['name'] = '鸭蛋', throwsUnsupportedError);
      expect(
        () => (parsed.items.single['aliases'] as List).add('蛋'),
        throwsUnsupportedError,
      );
      expect(Foods.parse('[]').search(''), isEmpty);
    });

    test('rejects malformed schema, duplicate names and invalid nutrients', () {
      for (final value in [
        {},
        [null],
        [sample('')],
        [sample(' 鸡蛋')],
        [sample('鸡蛋'), sample('鸡蛋')],
        [
          {...sample('鸡蛋'), 'aliases': '蛋'},
        ],
        [
          {
            ...sample('鸡蛋'),
            'aliases': [1],
          },
        ],
        [
          {
            ...sample('鸡蛋'),
            'aliases': [' '],
          },
        ],
        [
          {...sample('鸡蛋'), 'category': ''},
        ],
        [
          {...sample('鸡蛋'), 'unit': ''},
        ],
        [
          {...sample('鸡蛋'), 'gramsPerUnit': 0},
        ],
        [
          {...sample('鸡蛋'), 'gramsPerUnit': -1},
        ],
        [
          {...sample('鸡蛋'), 'kcal100': '145'},
        ],
        [
          {...sample('鸡蛋'), 'protein100': -1},
        ],
        [
          {...sample('鸡蛋')}..remove('fat100'),
        ],
      ]) {
        expect(() => Foods.parse(jsonEncode(value)), throwsFormatException);
      }
      expect(() => Foods.parse('{'), throwsFormatException);
    });
  });

  group('search and recommendations', () {
    test('ranks exact, prefix, substring, aliases, then initials stably', () {
      final catalogue = Foods.parse(
        jsonEncode([
          sample('别名食物', aliases: ['鸡蛋']),
          sample('熟鸡蛋'),
          sample('鸡蛋白'),
          sample('鸡蛋'),
          sample('鸡蛋黄'),
        ]),
      );
      expect(catalogue.search(' 鸡蛋 ').map((f) => f['name']), [
        '鸡蛋',
        '鸡蛋白',
        '鸡蛋黄',
        '熟鸡蛋',
        '别名食物',
      ]);
      expect(catalogue.search('鸡蛋', limit: 2).length, 2);
      expect(catalogue.search('鸡蛋', limit: 0), isEmpty);
      expect(catalogue.search('鸡蛋', limit: -1), isEmpty);
      expect(catalogue.search('不存在的食物'), isEmpty);
    });

    test('finds chicken, eggs, aliases and uppercase pinyin initials', () {
      expect(foods.search('鸡胸').first['name'], '鸡胸肉（生，去皮）');
      expect(foods.search('蛋').map((f) => f['name']), contains('鸡蛋（全蛋）'));
      expect(foods.search('mt').first['name'], '馒头');
      expect(foods.search('xlh').first['name'], '西兰花（生）');
      expect(foods.search('jlj').first['name'], '鸡里脊（生）');
      expect(foods.search('hlb').first['name'], '胡萝卜（生）');
      expect(foods.search('hs').map((f) => f['name']), contains('海参（水发）'));
      expect(foods.search(' MT ').first['name'], '馒头');
      expect(foods.search('jx').map((f) => f['name']), contains('鸡胸肉（生，去皮）'));
      expect(foods.search('xhs').map((f) => f['name']), contains('番茄（生）'));
      expect(foods.search('西红柿').first['name'], '番茄（生）');
      expect(foods.search('蛋白粉').first['name'], '乳清蛋白粉');
      expect(foods.search('牛奶').map((f) => f['name']), contains('纯牛奶（全脂）'));
      expect(foods.search('美式').first['name'], '黑咖啡（无糖）');
    });

    test('empty queries return common foods plus high-protein choices', () {
      final results = foods.search('  ', limit: 300);
      expect(results.length, foods.items.length);
      expect(results.first['name'], '米饭');
      expect(results.map((f) => f['name']).toSet().length, results.length);
      expect(results.take(20).map((f) => f['name']), contains('鸡蛋白'));
      expect(foods.search('').length, 30);
    });

    test('ranks by protein per kcal and excludes zero-energy foods', () {
      final ranked = foods.proteinRanking();
      double density(Map<String, dynamic> f) =>
          (f['protein100'] as num) / (f['kcal100'] as num);
      for (var i = 1; i < ranked.length; i++) {
        expect(
          density(ranked[i - 1]),
          greaterThanOrEqualTo(density(ranked[i])),
        );
      }
      expect(ranked.every((f) => (f['kcal100'] as num) > 0), isTrue);
      expect(ranked.take(20).map((f) => f['name']), contains('分离乳清蛋白粉'));
      expect(ranked.map((f) => f['name']), isNot(contains('无糖可乐')));
      final catalogue = Foods.parse(
        jsonEncode([
          sample('低密度', kcal: 200, protein: 10),
          sample('高密度一', kcal: 100, protein: 20),
          sample('零热量', kcal: 0, protein: 0),
          sample('高密度二', kcal: 50, protein: 10),
        ]),
      );
      expect(catalogue.proteinRanking().map((f) => f['name']), [
        '高密度一',
        '高密度二',
        '低密度',
      ]);
      // Sorting and truncating results must not reorder the source catalogue.
      final original = foods.items.map((f) => f['name']).toList();
      foods.search('蛋', limit: 1).clear();
      foods.proteinRanking().clear();
      expect(foods.items.map((f) => f['name']), original);
    });
  });

  group('portions and records compatibility', () {
    test('hand-calculated grams, household units and defaults', () {
      expect(foods.entryFor(named('鸡蛋（全蛋）')), {
        'name': '鸡蛋（全蛋）',
        'portion': '约1个（50g）',
        'kcal': 73,
        'protein': 6.5,
        'carbs': 1.0,
        'fat': 5.0,
      });
      expect(entryFor(named('米饭'), units: 1.5), {
        'name': '米饭',
        'portion': '约1.5碗（225g）',
        'kcal': 261,
        'protein': 6.8,
        'carbs': 58.5,
        'fat': 0.0,
      });
      expect(foods.entryFor(named('鸡胸肉（水煮，去皮）'), grams: 150), {
        'name': '鸡胸肉（水煮，去皮）',
        'portion': '约150g',
        'kcal': 248,
        'protein': 46.5,
        'carbs': 0.0,
        'fat': 6.0,
      });
      expect(foods.entryFor(named('纯牛奶（全脂）'), units: 1)['kcal'], 163);
      expect(foods.entryFor(named('虾仁（生）'))['portion'], '约1份（100g）');
      expect(foods.entryFor(named('虾仁（生）'), units: 2)['portion'], '约2份（200g）');
      expect(foods.entryFor(named('米饭'), grams: 0)['kcal'], 0);
      expect(foods.entryFor(named('米饭'), units: 0)['protein'], 0);
    });

    test('rejects ambiguous, negative, infinite and excessive quantities', () {
      final food = named('米饭');
      expect(
        () => foods.entryFor(food, grams: 100, units: 1),
        throwsArgumentError,
      );
      for (final quantity in [-1, double.nan, double.infinity, 1e30]) {
        expect(
          () => foods.entryFor(food, grams: quantity),
          throwsArgumentError,
        );
        expect(
          () => foods.entryFor(food, units: quantity),
          throwsArgumentError,
        );
      }
    });

    test(
      'all entries and seeded fractional portions survive cleanItems intact',
      () {
        final random = Random(20261015);
        for (final food in foods.items) {
          for (final entry in [
            foods.entryFor(food),
            foods.entryFor(
              food,
              grams: random.nextInt(1000) + random.nextDouble(),
            ),
            foods.entryFor(
              food,
              units: random.nextInt(5) + random.nextDouble(),
            ),
          ]) {
            expect(cleanItems([entry]), [
              entry,
            ], reason: food['name'] as String);
            expect(entry.keys.toSet(), {
              'name',
              'portion',
              'kcal',
              'protein',
              'carbs',
              'fat',
            });
            expect(entry['kcal'], isA<int>());
            for (final key in ['protein', 'carbs', 'fat']) {
              final n = entry[key] as num;
              expect(n * 10, closeTo((n * 10).round(), 1e-6));
            }
          }
        }
      },
    );
  });

  test(
    'catalogue coverage, plausible energy, unique names and legal units',
    () {
      expect(foods.items.length, inInclusiveRange(280, 320));
      expect(
        foods.items.map((f) => f['name']).toSet().length,
        foods.items.length,
      );
      expect(foods.items.map((f) => f['category']).toSet(), {
        '主食',
        '肉禽蛋',
        '水产',
        '奶豆',
        '蔬菜',
        '水果',
        '坚果油脂',
        '零食饮料',
        '常见外食/菜品',
        '蛋白粉与高蛋白即食食品',
      });
      const units = {
        '100g',
        '个',
        '杯',
        '碗',
        '片',
        '勺',
        '块',
        '根',
        '把',
        '袋',
        '罐',
        '盒',
        '张',
        '棵',
        '朵',
        '节',
        '颗',
        '瓣',
        '份',
        '只',
        '瓶',
        '球',
      };
      for (final food in foods.items) {
        final kcal = food['kcal100'] as num;
        final p = food['protein100'] as num;
        final c = food['carbs100'] as num;
        final f = food['fat100'] as num;
        final energy = 4 * p + 4 * c + 9 * f;
        expect(
          (kcal - energy).abs(),
          lessThanOrEqualTo(max(25, kcal * .25)),
          reason: food['name'] as String,
        );
        expect(
          p + c + f,
          lessThanOrEqualTo(100),
          reason: food['name'] as String,
        );
        expect(kcal, inInclusiveRange(0, 900));
        expect(units, contains(food['unit']));
        expect(food['gramsPerUnit'] as num, inInclusiveRange(1, 1000));
        // 默认展示一人一次的常见份量，而不是“每 100 g”。
        expect(food['unit'], isNot('100g'), reason: food['name'] as String);
        expect(
          foods.search(food['name'] as String).first['name'],
          food['name'],
        );
      }
    },
  );
}
