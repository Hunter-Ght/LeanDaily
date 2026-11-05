import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/domain/free_training.dart';
import 'package:leandaily/domain/movements.dart';
import 'package:leandaily/domain/muscles.dart';

const now = '2026-11-04';

Map<String, Map<String, dynamic>> day(String date, List<(String, String)> ex) =>
    {
      date: {
        'sets': [
          for (final (name, part) in ex)
            for (var i = 0; i < 4; i++)
              {
                'id': '$name-$i',
                'ts': dateMs(date, 10),
                'date': date,
                'part': part,
                'ex': name,
                'w': 40,
                'reps': 10,
                'type': '正式',
                'rpe': 8,
              },
        ],
      },
    };

Map status(Map<String, Map<String, dynamic>> days) =>
    muscleStatus(days, dateMs(now, 18));

void main() {
  test('fresh user: every strength group is recommended, no cardio', () {
    final groups = recommendNow(status({}));
    expect(groups.map((g) => g.group).toSet(), {
      for (final g in GROUPS) g['id'],
    });
    for (final g in groups) {
      expect(g.daysSince, isNull);
      expect(g.exercises, isNotEmpty);
      expect(g.exercises.length, lessThanOrEqualTo(3));
      for (final e in g.exercises) {
        expect(e.ready, isTrue);
        expect(MUSCLE[e.primary]!['group'], g.group);
        expect(e.name, isNot(anyOf('跑步机', '椭圆机', '划船机', '单车')));
      }
    }
    expect(recoveringGroups(status({})), isEmpty);
  });

  test('just-trained chest is excluded and listed as recovering', () {
    final s = status(day(now, [('坐姿推胸机', '胸'), ('卧推', '胸')]));
    final ids = recommendNow(s).map((g) => g.group).toList();
    expect(ids, isNot(contains('chest')));
    final rec = recoveringGroups(s);
    expect(rec.map((r) => r.group), contains('chest'));
    expect(rec.firstWhere((r) => r.group == 'chest').daysLeft, greaterThan(0));
  });

  test('longest-untrained groups come first, never-trained before all', () {
    final days = {
      ...day('2026-10-31', [('高位下拉', '背')]),
      ...day('2026-10-24', [('深蹲', '腿')]),
    };
    final ids = recommendNow(status(days)).map((g) => g.group).toList();
    // 没练过的在前，然后是 11 天前的腿，再是 4 天前的背
    expect(ids.indexOf('quads'), lessThan(ids.indexOf('back')));
    expect(ids.indexOf('chest'), lessThan(ids.indexOf('quads')));
  });

  test('small never-trained groups do not crowd out big ones', () {
    final days = day('2026-10-28', [('卧推', '胸')]);
    final ids = recommendNow(status(days)).map((g) => g.group).toList();
    // 7 天没练的胸排在从没练过的小腿、手臂、腹前面
    for (final small in ['calves', 'arms', 'abs']) {
      expect(ids.indexOf('chest'), lessThan(ids.indexOf(small)), reason: small);
    }
  });

  test('low-weight moves still need their main muscle recovered', () {
    // 髋内收机各肌肉权重都低于 0.5：股四头和臀刚练过，就不该推荐它
    final s = status(day(now, [('深蹲', '腿'), ('腿举', '腿')]));
    expect(exerciseReady(s, '髋内收机'), isFalse);
    expect(
      recommendNow(s).expand((g) => g.exercises).map((e) => e.name),
      isNot(contains('髋内收机')),
    );
  });

  test('group recency follows the recommended muscles', () {
    // 推胸会带到前束肩；侧平举练中束，肩不该显示“今天练过”
    final s = status(day(now, [('坐姿推胸机', '胸')]));
    final shoulders = recommendNow(s).firstWhere((g) => g.group == 'shoulders');
    expect(
      shoulders.exercises.map((e) => e.primary),
      isNot(contains('delt_front')),
    );
    expect(shoulders.daysSince, isNull);
  });

  test('calf machine busy: standing calf raise is an alternative', () {
    expect(
      alternativesFor(status({}), '坐姿提踵机').map((e) => e.name),
      contains('提踵'),
    );
    final alt = alternativesFor(
      status({}),
      '坐姿提踵机',
    ).firstWhere((e) => e.name == '提踵');
    expect(alt.equipment, '哑铃');
  });

  test('exercises the user has done are preferred', () {
    final days = day('2026-10-20', [('坐姿划船', '背')]);
    final back = recommendNow(
      status(days),
      done: {'坐姿划船'},
    ).firstWhere((g) => g.group == 'back');
    expect(back.exercises.first.name, '坐姿划船');
    expect(back.exercises.first.done, isTrue);
  });

  test('my gym limits recommendations to owned machines or bodyweight', () {
    final groups = recommendNow(status({}), owned: {'leg-press'});
    for (final g in groups) {
      for (final e in g.exercises) {
        expect(
          exerciseAvailable(e.name, {'leg-press'}),
          isTrue,
          reason: e.name,
        );
      }
    }
    final legs = groups.firstWhere((g) => g.group == 'quads');
    expect(legs.exercises.map((e) => e.name), contains('腿举'));
    expect(legs.exercises.map((e) => e.name), isNot(contains('腿屈伸')));
  });

  test('alternatives keep the primary muscle and switch equipment', () {
    final alts = alternativesFor(status({}), '坐姿推胸机');
    expect(alts, isNotEmpty);
    expect(alts.length, lessThanOrEqualTo(5));
    for (final a in alts) {
      expect(a.primary, 'chest');
      expect(a.name, isNot('坐姿推胸机'));
    }
    expect(alts.map((a) => a.name), contains('卧推'));
  });

  test('alternatives skip moves on the same busy machine', () {
    final alts = alternativesFor(status({}), '绳索下压').map((a) => a.name);
    expect(alts, isNot(contains('绳索下压')));
    for (final name in alts) {
      // 其他替代不能只在龙门架上做
      expect(name, isNot(anyOf('绳索弯举', '绳索卷腹', '绳索面拉')));
    }
    expect(alternativesFor(status({}), '倒蹬').first.primary, 'quads');
    expect(alternativesFor(status({}), '跑步机'), isEmpty);
  });

  test('alternatives respect my gym', () {
    final alts = alternativesFor(status({}), '坐姿推胸机', owned: {'smith'});
    for (final a in alts) {
      expect(exerciseAvailable(a.name, {'smith'}), isTrue, reason: a.name);
    }
    expect(alts.map((a) => a.name), contains('史密斯卧推'));
  });
}
