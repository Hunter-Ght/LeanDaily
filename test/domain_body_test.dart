import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/domain/body.dart';

Profile profile([Map<String, dynamic> patch = const {}]) => {
  ...profileDefaults,
  'age': 30,
  'heightCm': 200,
  'weightKg': 80,
  'bodyFatMethod': 'manual',
  'bodyFatPct': 20,
  ...patch,
};

void main() {
  test('男/女各阶段的热量、蛋白、周期手算向量', () {
    // BMI=80/2²=20; male BMR=800+1250-150+5=1905,
    // TDEE=2667; female BMR=1739, TDEE=2434.6.
    // female refine first rounds2434.6->2435 then tens->2440.
    // cut/recomp/trim/refine factors=.78/.9/.88/1.
    // cut protein=144 ->145; others=160; per jin=protein/160.
    // male goal11: BF25 lean60,target67.41573,loss12.58427,
    // weeks=19.66292 -> [16,26]; BF18 weeks15.73034 ->[13,20];
    // BF13 weeks4.49438 ->[4,6]. Female goal20: BF35 lean52,
    // target65,loss15,weeks23.4375 ->[19,30]; BF28 weeks20 ->[16,26];
    // BF23 weeks7.5 ->[6,10].
    final vectors = [
      [
        'male',
        25,
        'cut',
        2080,
        145,
        [16, 26],
      ],
      [
        'male',
        18,
        'recomp',
        2400,
        160,
        [13, 20],
      ],
      [
        'male',
        13,
        'trim',
        2350,
        160,
        [4, 6],
      ],
      ['male', 12, 'refine', 2670, 160, null],
      [
        'female',
        35,
        'cut',
        1900,
        145,
        [19, 30],
      ],
      [
        'female',
        28,
        'recomp',
        2190,
        160,
        [16, 26],
      ],
      [
        'female',
        23,
        'trim',
        2140,
        160,
        [6, 10],
      ],
      ['female', 22, 'refine', 2440, 160, null],
    ];
    for (final v in vectors) {
      final t = buildTargets(profile({'sex': v[0], 'bodyFatPct': v[1]}));
      expect([
        t['stage'],
        t['kcal'],
        t['proteinG'],
        t['weeksRange'],
      ], v.sublist(2));
      expect(t['proteinPerJin'], (v[4] as int) / 160);
      expect(t['headline'], headline(t));
    }
    for (final sex in ['male', 'female']) {
      // BMI=76/4=19, BF12; male BMR1865,TDEE2611,*1.08=2819.88;
      // female BMR1699,TDEE2378.6,*1.08=2568.888. Protein152->150.
      final bulk = buildTargets(
        profile({'sex': sex, 'weightKg': 76, 'bodyFatPct': 12}),
      );
      expect(bulk['stage'], 'bulk');
      expect(bulk['kcal'], sex == 'male' ? 2820 : 2570);
      expect(bulk['proteinG'], 150);
      expect(bulk['weeksRange'], isNull);
      // age17: male BMR1970,TDEE2758; female1804,TDEE2525.6;
      // protein80*1.6=128->130; youth precedes all fat/BMI stages.
      final youth = buildTargets(
        profile({'sex': sex, 'age': 17, 'bodyFatPct': 60}),
      );
      expect(youth['stage'], 'youth');
      expect(youth['kcal'], sex == 'male' ? 2760 : 2530);
      expect(youth['proteinG'], 130);
      expect(youth['warnings'], contains('年龄未满 18 岁，吃够睡够，重视动作质量。'));
      expect(youth['weeksRange'], isNull);
    }
  });

  test('男/女 × 六阶段 × 四种估算方式交叉向量', () {
    for (final sex in ['male', 'female']) {
      final male = sex == 'male';
      for (final stage in [
        'cut',
        'recomp',
        'trim',
        'refine',
        'bulk',
        'youth',
      ]) {
        for (final method in ['manual', 'picker', 'navy', 'bmi']) {
          final index = [
            'cut',
            'recomp',
            'trim',
            'refine',
            'bulk',
            'youth',
          ].indexOf(stage);
          // At h200, neck30, hip100 the Navy denominator/formula yields:
          // male waist100/90/80/70 => BF27.8/22.0/15.3/7.3;
          // female waist110/90/80/65 => BF37.7/29.3/24.8/17.6.
          // BMI formula at age30: BMI30/25/20 => male26.7/20.7/14.7,
          // female37.5/31.5/25.5. At age18, BMI20/19 =>
          // male11.9/10.7, female22.7/21.5. BMI19 forces bulk.
          final waist = (male
              ? [100, 90, 80, 70, 70, 100]
              : [110, 90, 80, 65, 65, 110])[index];
          final picked = (male
              ? [25, 20, 15, 10, 10, 25]
              : [35, 30, 26, 22, 22, 35])[index];
          final bmiWeight = [120, 100, 80, 80, 76, 80][index];
          final p = profile({
            'sex': sex,
            'bodyFatMethod': method,
            'bodyFatPct': picked,
            'waistCm': waist,
            'neckCm': 30,
            'hipCm': 100,
            'weightKg': method == 'bmi'
                ? bmiWeight
                : stage == 'bulk'
                ? 76
                : 80,
            'age': stage == 'youth'
                ? 17
                : method == 'bmi' && ['refine', 'bulk'].contains(stage)
                ? 18
                : 30,
          });
          final t = buildTargets(p);
          expect(t['stage'], stage, reason: '$sex / $stage / $method');
          expect((t['bodyFat'] as Map)['method'], method);
        }
      }
    }
  });

  test('BMI、BMR、活动系数独立手算', () {
    // 80/(2²)=20; 1905 * [1.25,1.4,1.55]=[2381.25,2667,2952.75].
    expect(bmi(profile()), 20);
    expect(bmr(profile()), 1905);
    for (final entry in {
      'sedentary': 2381.25,
      'light': 2667.0,
      'active': 2952.75,
    }.entries) {
      expect(
        tdee(profile({'activity': entry.key})),
        closeTo(entry.value, 1e-6),
      );
    }
  });

  test('体脂估算四种方法与 Navy 缺测兜底', () {
    // male waist-neck=60,log10=1.77815125; height200 log10=2.30103;
    // denominator1.048829282 ->21.9547866 ->22.0.
    // female waist+hip-neck=160,log10=2.20411998;
    // denominator1.032787470 ->29.2854428 ->29.3.
    for (final sex in ['male', 'female']) {
      final p = profile({'sex': sex});
      expect(estimateBodyFat(p), {
        'value': 20.0,
        'margin': 0,
        'method': 'manual',
      });
      expect(estimateBodyFat({...p, 'bodyFatMethod': 'picker'}), {
        'value': sex == 'male' ? 20.0 : 18.0,
        'margin': 4,
        'method': 'picker',
      });
      expect(
        estimateBodyFat({
          ...p,
          'bodyFatMethod': 'navy',
          'waistCm': 90,
          'neckCm': 30,
          'hipCm': 100,
        }),
        {'value': sex == 'male' ? 22.0 : 29.3, 'margin': 3, 'method': 'navy'},
      );
      // 1.2*20+.23*30-10.8*sex-5.4 =>14.7 male /25.5 female.
      final fallback = {
        'value': sex == 'male' ? 14.7 : 25.5,
        'margin': 5,
        'method': 'bmi',
      };
      expect(estimateBodyFat({...p, 'bodyFatMethod': 'bmi'}), fallback);
      expect(estimateBodyFat({...p, 'bodyFatMethod': 'navy'}), fallback);
      expect(
        estimateBodyFat({
          ...p,
          'bodyFatMethod': 'navy',
          'waistCm': 20,
          'neckCm': 200,
          'hipCm': 20,
        }),
        fallback,
      );
      expect(estimateBodyFat({...p, 'bodyFatPct': null}), fallback);
      final bands = sex == 'male'
          ? [6, 10, 15, 20, 25, 30, 35, 40]
          : [14, 18, 22, 26, 30, 35, 40, 45];
      for (final band in bands) {
        expect(
          estimateBodyFat({
            ...p,
            'bodyFatMethod': 'picker',
            'bodyFatPct': band,
          })['value'],
          band,
        );
      }
    }
    // BMI30/(2.3²)=5.671..., age10 -> negative estimate clamps to3;
    // BMI250/1.2²=173.611..., age90 -> above60 clamps to60.
    expect(
      estimateBodyFat(
        profile({
          'heightCm': 230,
          'weightKg': 30,
          'age': 10,
          'bodyFatMethod': 'bmi',
        }),
      )['value'],
      3,
    );
    expect(
      estimateBodyFat(
        profile({
          'heightCm': 120,
          'weightKg': 250,
          'age': 90,
          'bodyFatMethod': 'bmi',
        }),
      )['value'],
      60,
    );
  });

  test('精确阶段阈值、BMI18.5/20与年龄17/18', () {
    for (final sex in ['male', 'female']) {
      final p = profile({'sex': sex});
      final thresholds = sex == 'male' ? [25, 18, 13] : [35, 28, 23];
      final below = ['recomp', 'trim', 'refine'];
      for (var i = 0; i < 3; i++) {
        expect(stageOf(p, thresholds[i]), ['cut', 'recomp', 'trim'][i]);
        expect(stageOf(p, thresholds[i] - .1), below[i]);
      }
      // h=200, w74 gives BMI18.5; w80 gives20.
      expect(stageOf({...p, 'weightKg': 73.96}, 60), 'bulk');
      expect(stageOf({...p, 'weightKg': 74}, 60), 'cut');
      expect(stageOf({...p, 'weightKg': 79.96}, 12), 'bulk');
      expect(stageOf({...p, 'weightKg': 80}, 12), 'refine');
      final thinFat = sex == 'male' ? 18 : 26;
      expect(stageOf({...p, 'weightKg': 76}, thinFat - .1), 'bulk');
      expect(
        stageOf({...p, 'weightKg': 76}, thinFat),
        sex == 'male' ? 'recomp' : 'trim',
      );
      expect(stageOf({...p, 'age': 17}, 60), 'youth');
      expect(stageOf({...p, 'age': 18}, 60), 'cut');
    }
  });

  test('安全下限、warnings、周期上下限与诊断文案', () {
    for (final sex in ['male', 'female']) {
      final p = profile({'sex': sex, 'bodyFatPct': 60, 'goalBodyFatPct': 3});
      final t = buildTargets(p);
      final floor = sex == 'male' ? 8 : 16;
      expect(t['goalBodyFat'], floor);
      expect(t['warnings'], contains('目标体脂低于安全下限，已调整为 $floor%'));
      expect(t['warnings'], contains('已采用安全范围内的目标。'));
      expect(t['warnings'], contains('减脂超过 16 周，建议阶段性休整'));
      expect(buildTargets(p, goalOverride: 30)['goalBodyFat'], 30);
      expect(
        buildTargets(p, goalOverride: 30)['warnings'],
        isNot(contains('已采用安全范围内的目标。')),
      );
    }
    // h120,w30,age90: BMR605 male /439 female; sedentary cut
    // below1500/1200; final values lifted to those absolute floors.
    for (final sex in ['male', 'female']) {
      final t = buildTargets(
        profile({
          'sex': sex,
          'heightCm': 120,
          'weightKg': 30,
          'age': 90,
          'activity': 'sedentary',
          'bodyFatPct': 40,
        }),
      );
      expect(t['kcal'], sex == 'male' ? 1500 : 1200);
      expect(t['warnings'], contains('每日热量已按安全下限抬高'));
    }
    // BMR1905, sedentary cut1857.375 -> BMR floor ->1910.
    expect(
      buildTargets(
        profile({'activity': 'sedentary', 'bodyFatPct': 25}),
      )['kcal'],
      1910,
    );
    expect(buildTargets(profile({'weightKg': 250}))['proteinG'], 220);
    expect(
      buildTargets(profile({'weightKg': 30}))['warnings'],
      contains('建议先吃够营养，配合训练增加肌肉。'),
    );
    expect(
      buildTargets(profile({'bodyFatMethod': 'bmi'}))['warnings'],
      contains('体脂为估算值，估算误差 ±5%'),
    );
    expect(
      buildTargets(
        profile({'bodyFatPct': 25, 'goalBodyFatPct': 30}),
      )['weeksRange'],
      [4, 4],
    );
    // BF60->goal8: lean32,target34.78261,loss45.21739;
    // cut rate .008 gives70.65217 -> both ends clamp52.
    expect(
      buildTargets(
        profile({'bodyFatPct': 60, 'goalBodyFatPct': 8}),
      )['weeksRange'],
      [52, 52],
    );
    expect(
      buildTargets(profile({'bodyFatPct': 25}))['headline'],
      '体脂约 25%，目标 11%。温和调整饮食，配合力量训练保留肌肉。',
    );
    expect(
      buildTargets(profile({'bodyFatPct': 12}))['headline'],
      isNot(contains('预计')),
    );
    for (final stage in ['cut', 'recomp', 'trim', 'refine', 'bulk', 'youth']) {
      expect(stageName(stage), isNotEmpty);
      expect(routeText(stage), isNotEmpty);
    }
  });

  test('normalizeProfile 非法输入、范围与默认值', () {
    expect(normalizeProfile(null)['profile'], profileDefaults);
    expect(normalizeProfile([])['errors'], ['个人资料格式无效']);
    final result = normalizeProfile({
      'sex': 'x',
      'age': double.nan,
      'heightCm': double.infinity,
      'weightKg': '70',
      'bodyFatPct': false,
      'bodyFatMethod': 'x',
      'waistCm': {},
      'neckCm': [],
      'hipCm': '',
      'goalBodyFatPct': 'x',
      'activity': 'x',
      'venue': 'x',
      'daysPerWeek': null,
      'experience': 'x',
      'limits': ['膝', 1],
    });
    expect(result['errors'], hasLength(15));
    expect(result['profile'], {
      ...profileDefaults,
      'limits': ['膝'],
    });
    final low =
        normalizeProfile({
              'age': 1,
              'heightCm': 1,
              'weightKg': 1,
              'bodyFatPct': 1,
              'waistCm': 1,
              'neckCm': 1,
              'hipCm': 1,
              'daysPerWeek': 1,
              'goalBodyFatPct': 1,
            })['profile']
            as Profile;
    expect(
      [
        low['age'],
        low['heightCm'],
        low['weightKg'],
        low['bodyFatPct'],
        low['waistCm'],
        low['neckCm'],
        low['hipCm'],
        low['daysPerWeek'],
        low['goalBodyFatPct'],
      ],
      [10, 120, 30, 3, 20, 20, 20, 2, 3],
    );
    final high =
        normalizeProfile({
              'age': 100,
              'heightCm': 300,
              'weightKg': 300,
              'bodyFatPct': 100,
              'waistCm': 300,
              'neckCm': 300,
              'hipCm': 300,
              'daysPerWeek': 9,
              'goalBodyFatPct': 100,
            })['profile']
            as Profile;
    expect(
      [
        high['age'],
        high['heightCm'],
        high['weightKg'],
        high['bodyFatPct'],
        high['waistCm'],
        high['neckCm'],
        high['hipCm'],
        high['daysPerWeek'],
        high['goalBodyFatPct'],
      ],
      [90, 230, 250, 60, 200, 200, 200, 6, 60],
    );
    expect(normalizeProfile(high)['profile'], high);
  });
}
