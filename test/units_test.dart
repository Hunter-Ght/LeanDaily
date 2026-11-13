import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/domain/progress.dart' as p;
import 'package:leandaily/domain/progress_options.dart';
import 'package:leandaily/domain/units.dart';
import 'package:leandaily/ui/training/training_logic.dart';

void main() {
  const lb = Units.imperial, kg = Units.metric;

  test('metric output matches the pre-units formatting', () {
    expect(kg.loadText(40), '40 kg');
    expect(kg.loadText(62.5), '62.5 kg');
    expect(kg.load(1.25), '1.3');
    expect(kg.bodyWeight(70, fixed: true), '70.0');
    expect(kg.bodyWeightText(70.04), '70.0 kg');
    expect(kg.bodyWeightText(70), '70 kg');
    expect(kg.heightText(175), '175 cm');
    expect(kg.lengthText(80.5), '80.5 cm');
    expect(kg.loadToKg(62.5), 62.5);
    expect(kg.snapLoad(12.34), 12.34);
    expect(kg.localizeText('5 kg 哑铃'), '5 kg 哑铃');
  });

  test('training loads survive lb -> kg -> JSON -> lb for 2.5..500 lb', () {
    for (var x = 2.5; x <= 500; x += 2.5) {
      final stored = jsonDecode(jsonEncode(lb.loadToKg(x))) as num;
      expect(lb.loadValue(stored), x, reason: '$x lb');
      expect(lb.load(stored), x == x.roundToDouble() ? '${x.toInt()}' : '$x');
    }
  });

  test('half-pound entries also round-trip', () {
    for (var x = 0.5; x <= 1000; x += 0.5) {
      expect(lb.loadValue(lb.loadToKg(x)), x);
    }
  });

  test('body weight keeps 0.1 lb exactly', () {
    for (var tenths = 670; tenths <= 5510; tenths++) {
      final x = tenths / 10;
      final stored = jsonDecode(jsonEncode(lb.bodyWeightToKg(x))) as num;
      expect(lb.bodyWeightValue(stored), x, reason: '$x lb');
    }
    expect(lb.bodyWeight(lb.bodyWeightToKg(180.5), fixed: true), '180.5');
    expect(lb.bodyWeight(lb.bodyWeightToKg(180)), '180');
    expect(lb.bodyWeightText(80), '176.4 lb');
  });

  test('height is ft + in and round-trips by whole inch', () {
    for (var inch = 48; inch <= 90; inch++) {
      final cm = lb.heightFromInches(inch);
      expect(lb.heightInches(cm), inch);
      expect(lb.feetInches(cm), (inch ~/ 12, inch % 12));
    }
    expect(lb.heightText(lb.heightFromFeetInches(5, 10)), '5 ft 10 in');
    expect(lb.heightText(175), '5 ft 9 in');
    expect(lb.heightFromFeetInches(5, 10), 177.8);
  });

  test('waist is inches to 0.1 and round-trips', () {
    for (var tenths = 80; tenths <= 780; tenths++) {
      final x = tenths / 10;
      expect(lb.lengthValue(lb.lengthToCm(x)), x, reason: '$x in');
    }
    expect(lb.lengthText(lb.lengthToCm(34.5)), '34.5 in');
    expect(lb.lengthUnit, 'in');
    expect(lb.bodyWeightInRange(66), false);
    expect(lb.bodyWeightInRange(67), true);
    expect(lb.bodyWeightInRange(551), true);
    expect(lb.bodyWeightInRange(552), false);
    expect(lb.lengthToCm(double.nan).isNaN, true);
  });

  test(
    'input steps: dumbbell 5 lb (2.5 below 20), barbell and machine 5 lb',
    () {
      final db = {'name': '哑铃卧推'};
      num step(Map<String, dynamic> ex, num v, bool up, {num? kgStep}) =>
          lb.stepLoad(ex, v, up: up, explicitKg: kgStep);
      expect(step(db, 10, true), 12.5);
      expect(step(db, 17.5, true), 20);
      expect(step(db, 20, true), 25);
      expect(step(db, 20, false), 17.5);
      expect(step(db, 25, false), 20);
      expect(step(db, 22.5, false), 20);
      expect(step(db, 0, true), 2.5);
      expect(step({'name': '杠铃卧推'}, 45, true), 50);
      expect(step({'name': '器械推胸', 'machine': true}, 100, false), 95);
      expect(step({'name': '器械推胸', 'machine': true}, 10, true), 15);
      // 用户设了最小一档（kg 存储）：2.5 lb ≈ 1.134 kg
      expect(
        step({'name': '器械推胸', 'machine': true}, 100, true, kgStep: 1.134),
        102.5,
      );
      // 公制行为不变
      expect(kg.stepLoad({'name': '哑铃卧推'}, 10, up: true), 10.5);
      expect(kg.stepLoad({'name': '器械', 'machine': true}, 40, up: true), 42.5);
      expect(
        kg.stepLoad(
          {'name': '器械', 'machine': true},
          40,
          up: false,
          explicitKg: 5,
        ),
        35,
      );
    },
  );

  test('progression steps are whole 5 / 2.5 lb stages in imperial', () {
    final db = {'name': '哑铃卧推'};
    expect(lb.loadValue(lb.progressStepKg(db, lb.loadToKg(15))), 2.5);
    expect(lb.loadValue(lb.progressStepKg(db, lb.loadToKg(40))), 5);
    expect(lb.loadValue(lb.progressStepKg({'name': '杠铃卧推'}, 60)), 5);
    // loadStep 只在英制下改变，公制不变
    expect(loadStep(db, 20, const ProgressOptions()), 2);
    expect(
      loadStep(db, 20, const ProgressOptions(units: Units.imperial)),
      lb.loadToKg(5),
    );
  });

  test('suggestions say lb in imperial and keep kg rules untouched', () {
    Map<String, dynamic>? make(Units units) {
      final ex = {
        'id': 'e',
        'name': '杠铃卧推',
        'part': '胸',
        'sets': 2,
        'min': 8,
        'max': 12,
        'weight': 40,
      };
      Map<String, dynamic> day() => {
        'sets': [
          for (var i = 0; i < 2; i++)
            {'ex': ex['name'], 'reps': 12, 'w': 40, 'rpe': 7},
        ],
      };
      return p.suggest(ex, {
        'days': {'2026-01-05': day(), '2026-01-08': day()},
        'today': '2026-01-15',
        'progress': {
          ...p.emptyProgress(),
          'anchors': {
            ex['name']: {'date': '2026-01-01', 'reps': 12, 'weight': 40},
          },
        },
        'plan': {
          'startDate': '2025-10-01',
          'workouts': {
            'a': {
              'exercises': [ex],
            },
          },
          'ladders': <String, dynamic>{},
        },
      }, options: ProgressOptions(venue: 'gym', units: units));
    }

    final metric = make(kg)!, imperial = make(lb)!;
    expect(metric['kind'], 'load');
    expect(metric['acceptLabel'], '试 42.5 kg');
    expect(imperial['kind'], 'load');
    // 40 kg = 88.2 lb -> 88 lb；+5 lb -> 93 lb
    expect(imperial['acceptLabel'], '试 93 lb');
    expect(imperial['body'], contains('+5 lb'));
    expect(imperial['body'], isNot(contains('kg')));
    expect(lb.loadValue(imperial['accept']['weight'] as num), 93);
  });

  test(
    'plan-suggested weights snap to usable lb stages, records stay exact',
    () {
      expect(lb.suggested(5), '10');
      expect(lb.suggested(10), '20');
      expect(lb.suggested(20), '45');
      expect(lb.suggested(2), '5');
      expect(lb.suggested(1), '2.5');
      expect(lb.suggested(30), '65');
      expect(lb.suggestedText(5), '10 lb');
      expect(lb.suggestedLoad(0), 0);
      // 存下的就是整档对应的 kg，再吸附一次不变
      for (final kgValue in [0.5, 1, 2, 5, 8, 10, 12.5, 20, 40, 60, 100]) {
        final once = lb.suggestedLoad(kgValue);
        expect(lb.suggestedLoad(once), once);
        expect((lb.loadValue(once) / 2.5) % 1, 0);
      }
      expect(kg.suggestedLoad(5), 5);
      expect(kg.suggestedText(5), '5 kg');
      // 用户记过的重量如实换算（0.5 lb）
      expect(lb.load(5), '11');
      expect(lb.load(lb.loadToKg(37.5)), '37.5');
    },
  );

  test(
    'training default weight: plan weight snaps, recorded weight does not',
    () {
      final ex = {'name': '哑铃卧推', 'weight': 5};
      // 没有练过：计划的 5 kg 在英制下是 10 lb 对应的 kg
      expect(trainingWeight(ex, {'weight': 5}, [], lb), lb.loadToKg(10));
      expect(trainingWeight(ex, {}, [], lb), lb.loadToKg(10));
      // 练过（target.last 有值）：如实用记录/进阶后的重量
      expect(
        trainingWeight(
          ex,
          {
            'weight': 5,
            'last': {'w': 5},
          },
          [],
          lb,
        ),
        5,
      );
      // 今天已经记了一组：用那一组
      expect(
        trainingWeight(
          ex,
          {'weight': 5},
          [
            {'w': 5.5},
          ],
          lb,
        ),
        5.5,
      );
      // 公制不变
      expect(trainingWeight(ex, {'weight': 5}, []), 5);
    },
  );

  test('region default and ids', () {
    expect(Units.forRegion('US'), Units.imperial);
    expect(Units.forRegion('us'), Units.imperial);
    expect(Units.forRegion('CN'), Units.metric);
    expect(Units.forRegion(null), Units.metric);
    expect(Units.byId('imperial'), Units.imperial);
    expect(Units.byId(null), Units.metric);
    expect(Units.imperial.id, 'imperial');
  });

  test('static text with kg becomes sensible lb', () {
    expect(lb.localizeText('5 kg 哑铃 × 2'), '10 lb 哑铃 × 2');
    expect(lb.localizeText('空杆通常是 20 kg，两边'), '空杆通常是 45 lb，两边');
    expect(lb.localizeText('水瓶（按 1 kg 记）'), '水瓶（按 2 lb 记）');
    expect(lb.localizeText('每周增重参考 0.2–0.4 kg'), '每周增重参考 0.5–1 lb');
    expect(
      lb.localizeText('Light dumbbells (count as 2 kg)'),
      'Light dumbbells (count as 4 lb)',
    );
    expect(lb.localizeText('没有重量'), '没有重量');
  });
}
