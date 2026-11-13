import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/domain/catalog.dart' show catalog;
import 'package:leandaily/domain/guide.dart' show guideFor;
import 'package:leandaily/domain/plan.dart' as plans;
import 'package:leandaily/domain/plan_recipe.dart';

import 'support/recipe_checks.dart';

void main() {
  test('规范化配方：补默认值、拉回范围', () {
    final r = normalizeRecipe({});
    expect(r, {
      'v': 1,
      'days': 3,
      'minutes': 35,
      'focus': 'balanced',
      'split': 'full',
      'weekdays': [1, 3, 5],
      'venue': 'bodyweight',
      'experience': 'new',
      'sex': 'male',
      'stage': null,
      'limits': <String>[],
    });
    expect(normalizeRecipe({'days': 9})['days'], 5);
    expect(normalizeRecipe({'days': 1})['days'], 2);
    expect(normalizeRecipe({'days': 2, 'split': 'ppl'})['split'], 'full');
    expect(
      normalizeRecipe({
        'limits': ['膝', '头', '腕'],
      })['limits'],
      ['膝', '腕'],
    );
    expect(normalizeRecipe(r), r);
  });

  test('排法：默认排法排在第一个，所有天数都有可选排法', () {
    for (var d = 2; d <= 5; d++) {
      for (final e in recipeLevels) {
        final splits = splitsFor(d, e);
        expect(splits.first, defaultSplit(d, e));
        expect(splits.toSet().length, splits.length);
      }
    }
    expect(defaultSplit(2, 'new'), 'full');
    expect(defaultSplit(3, 'new'), 'full');
    expect(defaultSplit(4, 'some'), 'ul');
    expect(defaultSplit(5, 'trained'), 'ul');
    expect(splitsFor(3, 'new'), ['full', 'ppl']);
    expect(splitsFor(5, 'new'), ['ul', 'ppl']);
  });

  test('默认配方取自资料，另一种排法保持其他设置', () {
    final r = defaultRecipe(
      {
        'daysPerWeek': 4,
        'venue': 'gym',
        'experience': 'some',
        'sex': 'female',
        'limits': ['膝'],
      },
      {'stage': 'cut'},
    );
    expect(r['days'], 4);
    expect(r['venue'], 'gym');
    expect(r['experience'], 'some');
    expect(r['sex'], 'female');
    expect(r['limits'], ['膝']);
    expect(r['stage'], 'cut');
    expect(r['minutes'], 35);
    expect(r['focus'], 'balanced');
    expect(r['split'], 'ul');
    final alt = alternateRecipe(r)!;
    expect(alt['split'], 'full');
    expect({...alt, 'split': 'ul'}, r);
    expect(alternateRecipe(normalizeRecipe({'days': 2})), isNull);
    expect(alternateRecipe(alt)!['split'], 'ul');
  });

  test('recipeName 整句、带天数', () {
    expect(recipeName({'days': 3}), '每周 3 天 · 全身均衡');
    expect(
      recipeName({'days': 4, 'focus': 'shoulders_back'}),
      '每周 4 天 · 肩背多一点',
    );
  });

  test('weeklyVolume：八个部位、参考范围随重点和档位变化', () {
    final plan = buildRecipePlan(
      makeRecipe(
        days: 3,
        minutes: 35,
        focus: 'core',
        venue: 'dumbbell',
        experience: 'new',
      ),
    );
    final v = weeklyVolume(plan);
    expect(v.map((e) => e['group']), recipeGroups);
    final byGroup = {for (final e in v) e['group']: e};
    expect(byGroup['abs']!['focus'], true);
    expect(byGroup['abs']!['low'], 8);
    expect(byGroup['abs']!['high'], 14);
    expect(byGroup['chest']!['focus'], false);
    expect(byGroup['chest']!['low'], 4);
    expect(byGroup['chest']!['high'], 10);
    expect(byGroup['arms']!['low'], 3);
    expect(byGroup['arms']!['high'], 8);
    expect(byGroup['hamstrings']!['low'], 3);
    final light = weeklyVolume(
      buildRecipePlan(
        makeRecipe(
          days: 2,
          minutes: 20,
          focus: 'core',
          venue: 'dumbbell',
          experience: 'new',
        ),
      ),
    );
    final lightBy = {for (final e in light) e['group']: e};
    expect(lightBy['abs']!['low'], 5);
    expect(lightBy['abs']!['high'], 10);
    expect(lightBy['chest']!['low'], 3);
    expect(lightBy['hamstrings']!['low'], 2);
    // 没有休息日的空方案：全是 0 组。
    final empty = weeklyVolume({
      'schedule': <String, dynamic>{},
      'workouts': <String, dynamic>{},
    });
    expect(empty.every((e) => e['sets'] == 0), true);
    // 居家版和健身房版各算各的。
    final home = {for (final e in weeklyVolume(plan)) e['group']: e['sets']};
    final gym = {
      for (final e in weeklyVolume(plan, venue: 'gym')) e['group']: e['sets'],
    };
    expect(home.keys, gym.keys);
  });

  /// 把失败按「配置：问题」列出来，最多显示前 40 条。
  void expectClean(List<String> failures) {
    expect(failures.length, 0, reason: failures.take(40).join('\n'));
  }

  test('全组合（天数 × 时长 × 重点 × 场地 × 经验 × 排法）：时长、组数、频率、处方、不动点', () {
    final failures = <String>[];
    final names = <String>{};
    var count = 0;
    for (final days in [2, 3, 4, 5]) {
      for (final minutes in recipeMinutes) {
        for (final focus in recipeFocuses) {
          for (final venue in recipeVenues) {
            for (final exp in recipeLevels) {
              for (final split in splitsFor(days, exp)) {
                final recipe = makeRecipe(
                  days: days,
                  minutes: minutes,
                  focus: focus,
                  venue: venue,
                  experience: exp,
                  split: split,
                );
                final plan = buildRecipePlan(recipe, startDate: '2026-11-02');
                count++;
                names.addAll(recipeNames(plan));
                for (final p in recipeProblems(plan)) {
                  failures.add('${recipeLabel(plan['recipe'])}：$p');
                }
              }
            }
          }
        }
      }
    }
    expect(count, 1512);
    expectClean(failures);
    // 用到的每个动作都能在动作库或模板自带动作里找到，并且有示范。
    const own = recipeTemplateOwn;
    final unknown = [
      for (final n in names)
        if (!catalog().containsKey(n) && !own.contains(n)) n,
    ];
    expect(unknown, isEmpty, reason: '动作库里没有：$unknown');
    final noGuide = [
      for (final n in names)
        if (guideFor({'name': n}) == null) n,
    ];
    expect(noGuide, isEmpty, reason: '没有示范：$noGuide');
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('不方便的部位：单项、组合；路线；动作从不出现，说明写进 recipeNotes', () {
    final failures = <String>[];
    var count = 0;
    const sets = [
      ['膝'],
      ['腰'],
      ['肩'],
      ['腕'],
      ['膝', '腰'],
      ['肩', '腕'],
      ['膝', '腰', '肩', '腕'],
    ];
    const foci = ['balanced', 'glutes_legs', 'shoulders_back'];
    for (final limits in sets) {
      for (final days in [2, 3, 4, 5]) {
        for (final minutes in recipeMinutes) {
          for (final focus in foci) {
            for (final venue in recipeVenues) {
              for (final exp in ['new', 'trained']) {
                for (final split in {
                  splitsFor(days, exp).first,
                  splitsFor(days, exp).last,
                }) {
                  final stage = const [
                    null,
                    'cut',
                    'recomp',
                    'bulk',
                  ][(count++) % 4];
                  final plan = buildRecipePlan(
                    makeRecipe(
                      days: days,
                      minutes: minutes,
                      focus: focus,
                      venue: venue,
                      experience: exp,
                      split: split,
                      limits: limits,
                      stage: stage,
                    ),
                    startDate: '2026-11-02',
                  );
                  for (final p in recipeProblems(plan)) {
                    failures.add('${recipeLabel(plan['recipe'])}：$p');
                  }
                }
              }
            }
          }
        }
      }
    }
    expectClean(failures);
    final knee = buildRecipePlan(
      makeRecipe(
        days: 3,
        minutes: 35,
        focus: 'glutes_legs',
        venue: 'gym',
        experience: 'new',
        limits: ['膝'],
      ),
    );
    expect(knee['recipeNotes'], isNotEmpty);
    expect(
      (knee['recipeNotes'] as List).first,
      '膝盖不方便：深蹲类换成了臀桥、罗马尼亚硬拉和腿弯举，大腿前侧的量会偏少。',
    );
    final none = buildRecipePlan(
      makeRecipe(
        days: 3,
        minutes: 35,
        focus: 'balanced',
        venue: 'gym',
        experience: 'new',
      ),
    );
    expect(none['recipeNotes'], <String>[]);
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('路线：减脂每周 2 次有氧、重组 1 次，其他不设；减脂辅助一律 2 组', () {
    Map<String, dynamic> build(String? stage) => buildRecipePlan(
      makeRecipe(
        days: 4,
        minutes: 50,
        focus: 'balanced',
        venue: 'gym',
        experience: 'trained',
        stage: stage,
      ),
    );
    expect(build('cut')['cardio'], {'perWeek': 2, 'minutes': 20});
    expect(build('recomp')['cardio'], {'perWeek': 1, 'minutes': 20});
    for (final stage in [null, 'bulk', 'refine', 'trim', 'youth']) {
      expect(build(stage).containsKey('cardio'), false, reason: '$stage');
    }
    // 有经验的人辅助动作本来是 3 组；减脂路线一律 2 组，主项仍 3 组。
    final normal = build('bulk');
    final cut = build('cut');
    int assistSets(Map plan) => [
      for (final id in plan['order'] as List)
        for (final e in (plan['workouts'][id]['exercises'] as List))
          if (e['core'] != true) e['sets'] as int,
    ].reduce((a, b) => a > b ? a : b);
    expect(assistSets(normal) >= 3, true);
    expect(assistSets(cut), 2);
  });

  test('同样的配方永远得到同样的方案；plan[recipe] 就是规范化后的配方', () {
    final raw = makeRecipe(
      days: 4,
      minutes: 35,
      focus: 'posture',
      venue: 'dumbbell',
      experience: 'some',
      limits: ['肩'],
      stage: 'recomp',
    );
    final a = buildRecipePlan(raw, startDate: '2026-11-02');
    final b = buildRecipePlan(raw, startDate: '2026-11-02');
    expect(jsonEncode(a), jsonEncode(b));
    expect(a['recipe'], normalizeRecipe(raw));
    expect(a['startDate'], '2026-11-02');
    // 传入的配方不会被改动；不规范的配方先规范化。
    final messy = {
      'days': 7,
      'minutes': 99,
      'focus': 'x',
      'limits': ['头'],
    };
    final before = jsonEncode(messy);
    final plan = buildRecipePlan(messy);
    expect(jsonEncode(messy), before);
    expect(plan['recipe'], normalizeRecipe(messy));
    expect((plan['order'] as List).length, 5);
    // 生成的方案经 normalizePlan 不变。
    final snapshot = jsonDecode(jsonEncode(a));
    expect(plans.normalizePlan(a, '2026-11-02'), snapshot);
  });

  test('按 weekdays 排训练日；gym 场地把训练日设为 gym', () {
    final plan = buildRecipePlan(
      makeRecipe(
        days: 3,
        minutes: 35,
        focus: 'balanced',
        venue: 'gym',
        experience: 'new',
      )..['weekdays'] = [6, 2, 4],
    );
    // 周二、周四、周六；周日是 0。
    expect(plan['schedule'], {'2': 'r1', '4': 'r2', '6': 'r3'});
    expect(plan['venues'], {'2': 'gym', '4': 'gym', '6': 'gym'});
    expect(plan['order'], ['r1', 'r2', 'r3']);
    expect((plan['recipe'] as Map)['weekdays'], [2, 4, 6]);
  });

  test('居家无器械：肩中束和后束有动作，用水瓶或装书的背包；反向划船有备选', () {
    final plan = buildRecipePlan(
      makeRecipe(
        days: 3,
        minutes: 35,
        focus: 'balanced',
        venue: 'bodyweight',
        experience: 'new',
      ),
    );
    final home = [
      for (final id in plan['order'] as List)
        ...(plan['workouts'][id]['exercises'] as List),
    ];
    final lateral = home.where((e) => e['name'] == '轻重量侧平举');
    final rear = home.where((e) => e['name'] == '俯身哑铃反向飞鸟');
    expect(lateral, isNotEmpty);
    expect(rear, isNotEmpty);
    for (final e in [...lateral, ...rear]) {
      expect(e['gear'], contains('水瓶'));
      expect(e['gear'], contains('背包'));
    }
    expect(home.every((e) => e['machine'] != true), true);
    final rows = home.where((e) => e['name'] == '反向划船');
    expect(rows, isNotEmpty);
    expect(rows.first['ladder'], 'row');
    expect((rows.first['alts'] as List).map((a) => a['name']), ['超人式']);
    // 腰不方便：备选里的超人式也去掉。
    final waist = buildRecipePlan(
      makeRecipe(
        days: 3,
        minutes: 35,
        focus: 'balanced',
        venue: 'bodyweight',
        experience: 'new',
        limits: ['腰'],
      ),
    );
    for (final id in waist['order'] as List) {
      for (final e in waist['workouts'][id]['exercises'] as List) {
        expect(e['alts'], isEmpty, reason: '${e['name']}');
      }
    }
  });

  test('时长档：动作数大致是 20 分钟 3～4 个、35 分钟 5～6 个、50 分钟 7～8 个', () {
    final counts = <int, Set<int>>{20: {}, 35: {}, 50: {}};
    for (final minutes in recipeMinutes) {
      for (final focus in ['balanced', 'core']) {
        for (final venue in ['dumbbell', 'gym']) {
          final plan = buildRecipePlan(
            makeRecipe(
              days: 4,
              minutes: minutes,
              focus: focus,
              venue: venue,
              experience: 'new',
            ),
          );
          for (final id in plan['order'] as List) {
            counts[minutes]!.add(
              (plan['workouts'][id]['exercises'] as List).length,
            );
          }
        }
      }
    }
    expect(
      counts[20]!.every((n) => n >= 2 && n <= 4),
      true,
      reason: '${counts[20]}',
    );
    expect(
      counts[35]!.every((n) => n >= 4 && n <= 6),
      true,
      reason: '${counts[35]}',
    );
    expect(
      counts[50]!.every((n) => n >= 5 && n <= 8),
      true,
      reason: '${counts[50]}',
    );
    expect(counts[50]!.reduce((a, b) => a > b ? a : b) >= 7, true);
  });

  test('打印每周组数表（供检查）', () {
    String table(Map<String, dynamic> base, List<String> foci) {
      final out = StringBuffer();
      out.writeln('配置：${const JsonEncoder().convert(base)}');
      out.writeln('重点\t\t版本\t${recipeGroups.join('\t')}');
      for (final focus in foci) {
        final plan = buildRecipePlan({...base, 'focus': focus});
        for (final venue in ['home', 'gym']) {
          final v = weeklyVolume(plan, venue: venue);
          out.writeln(
            '${focus.padRight(15)}\t$venue\t'
            '${v.map((e) => (e['sets'] as num).toStringAsFixed(1)).join('\t')}',
          );
        }
      }
      return out.toString();
    }

    // ignore: avoid_print
    print(
      table(
        makeRecipe(
          days: 3,
          minutes: 35,
          focus: 'balanced',
          venue: 'dumbbell',
          experience: 'new',
        ),
        recipeFocuses,
      ),
    );
    // ignore: avoid_print
    print(
      table(
        makeRecipe(
          days: 4,
          minutes: 50,
          focus: 'balanced',
          venue: 'gym',
          experience: 'some',
        ),
        ['balanced'],
      ),
    );
  });
}
