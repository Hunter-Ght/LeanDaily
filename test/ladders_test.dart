import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/domain/format.dart';
import 'package:leandaily/domain/guide.dart' show guideFor;
import 'package:leandaily/domain/ladders.dart';
import 'package:leandaily/domain/plan.dart' as plans;
import 'package:leandaily/domain/progress.dart' as p;
import 'package:leandaily/domain/progress_options.dart';
import 'package:leandaily/domain/templates.dart';

import 'progression_options_test.dart'
    show exercise, history, session, suggestion, testPlan;

Map<String, dynamic> bodyweight(String name, {String? ladder}) => {
  'id': 'e',
  'name': name,
  'part': '腿',
  'sets': 2,
  'min': 10,
  'max': 15,
  'weight': 0,
  'unit': 'reps',
  'side': false,
  'machine': false,
  'ladder': ?ladder,
};

void main() {
  test('预设阶梯：每一级有区间、要点、器材，而且都有示范', () {
    expect(ladderPresets.map((e) => e.id), ['squat', 'row', 'bridge', 'core']);
    for (final l in ladderPresets) {
      expect(l.steps.length, inInclusiveRange(4, 5));
      expect(l.steps.map((s) => s['name']).toSet().length, l.steps.length);
      for (final s in l.steps) {
        expect(s['min'] as int, lessThan(s['max'] as int));
        for (final k in ['tip', 'hint', 'gear']) {
          expect('${s[k]}', isNotEmpty, reason: '${s['name']} $k');
        }
        expect(
          guideFor({'name': s['name']}),
          isNotNull,
          reason: '${s['name']}',
        );
      }
    }
  });

  test('居家自重模板带四条阶梯，居家哑铃模板带臀桥和腹肌，其他模板不变', () {
    final bw = buildPlan('bodyweight-3', startDate: '2026-10-12');
    expect(jsonMap(bw['ladders']).keys.toSet(), {
      'pushup',
      'squat',
      'row',
      'bridge',
      'core',
    });
    expect(jsonMap(bw['ladders'])['row']['stage'], 1);
    final names = <String, String>{};
    for (final w in jsonMap(bw['workouts']).values) {
      for (final e in jsonRows(w['exercises'])) {
        if (e['ladder'] != null) names['${e['ladder']}'] = '${e['name']}';
        final r = plans.resolveEx(bw, e);
        if (e['ladder'] == 'squat') {
          expect(r['tip'], contains('膝盖'));
          expect(r['side'], false);
        }
      }
      // 健身房版不带新阶梯。
      for (final e in jsonRows(jsonMap(w['gym'])['exercises'])) {
        expect(e['ladder'] == null || e['ladder'] == 'pushup', true);
      }
    }
    expect(names, {
      'pushup': '高位俯卧撑',
      'squat': '深蹲',
      'row': '反向划船',
      'bridge': '臀桥',
      'core': '反向卷腹',
    });
    final db = buildPlan('dumbbell-3', startDate: '2026-10-12');
    expect(jsonMap(db['ladders']).keys.toSet(), {'pushup', 'bridge', 'core'});
    for (final id in ['bochi-ppl-3', 'full-2', 'ul-4', 'lean-female-3']) {
      expect(jsonMap(buildPlan(id)['ladders']).keys, ['pushup'], reason: id);
    }
  });

  test('resolveEx：俯卧撑阶梯保持原样，新阶梯换要点、器材和分侧', () {
    final plan = buildPlan('bodyweight-3');
    final push = jsonRows(jsonMap(jsonMap(plan['workouts'])['t1'])['exercises'])
        .first;
    final before = {...push};
    final r = plans.resolveEx(plan, push);
    expect(r['tip'], before['tip']);
    expect(r['gear'], before['gear']);
    final squat = {...bodyweight('深蹲', ladder: 'squat')};
    jsonMap(plan['ladders'])['squat']['stage'] = 3;
    final s = plans.resolveEx(plan, squat);
    expect(s['name'], '保加利亚分腿蹲');
    expect(s['side'], true);
    expect(s['gear'], contains('椅子'));
  });

  test('升级：做满上限且有余力才升一级，文案带一句要点；悬垂级提示需要单杠', () {
    final plan = buildPlan('bodyweight-3');
    jsonMap(plan['ladders'])['core']['stage'] = 1;
    final ex = plans.resolveEx(
      plan,
      jsonRows(jsonMap(jsonMap(plan['workouts'])['t2'])['exercises']).last,
    );
    expect(ex['name'], '反向卷腹');
    const o = ProgressOptions(experience: 'new');
    final s = suggestion(
      {...ex, 'max': 15},
      history(ex, 2, reps: 15, rir: 2),
      o,
      plan: plan,
    )!;
    expect(s['kind'], 'ladder');
    expect(jsonMap(s['accept'])['stage'], 2);
    expect('${s['body']}', contains('单杠'));
    // 没有余力（RIR 0）不升级。
    expect(
      suggestion(
        {...ex, 'max': 15},
        history(ex, 2, reps: 15, rir: 0),
        o,
        plan: plan,
      )?['kind'],
      isNot('ladder'),
    );
  });

  test('退一级：连续两次没到下限，建议退回上一阶', () {
    final plan = buildPlan('bodyweight-3');
    jsonMap(plan['ladders'])['bridge']['stage'] = 2;
    final ex = plans.resolveEx(plan, {
      ...bodyweight('臀桥', ladder: 'bridge'),
      'min': 8,
      'max': 12,
    });
    expect(ex['name'], '单腿臀桥');
    final s = p.suggest(ex, {
      'plan': plan,
      'days': history(ex, 2, reps: 4),
      'today': '2026-01-15',
    }, options: const ProgressOptions(experience: 'new'))!;
    expect(s['kind'], 'ease');
    expect(jsonMap(s['accept'])['stage'], 1);
    expect(s['acceptLabel'], '退回上一阶');
  });

  group('老计划里没有阶梯的动作', () {
    Map<String, dynamic> oldPlan(Map<String, dynamic> ex) => {
      ...testPlan(ex),
      'workouts': {
        'a': {
          'exercises': [ex],
          'gym': {
            'exercises': [
              {...ex, 'id': 'g'},
            ],
          },
        },
      },
    };
    Map<String, dynamic> atCap(Map<String, dynamic> ex) => {
      ...p.emptyProgress(),
      'anchors': {
        ex['name']: {'date': '2026-01-01', 'reps': 15, 'weight': 0},
      },
    };
    Map<String, dynamic>? ask(
      Map<String, dynamic> ex,
      Map<String, dynamic> plan, {
      ProgressOptions? options = const ProgressOptions(experience: 'new'),
      Map<String, dynamic>? progress,
    }) => p.suggest(ex, {
      'plan': plan,
      'days': history(ex, 2, reps: 15, rir: 2),
      'today': '2026-01-15',
      'progress': progress ?? atCap(ex),
    }, options: options);

    test('做满时给一条可接受 / 可忽略的升级建议，接受后才加阶梯', () {
      final ex = bodyweight('深蹲');
      final plan = oldPlan(ex);
      final s = ask(ex, plan)!;
      expect(s['kind'], 'ladder');
      expect(s['acceptLabel'], '升级到停顿深蹲');
      expect(jsonMap(plan['ladders']), isEmpty); // 建议本身不改计划
      final r = p.applyAccept(plan, null, jsonMap(s['accept']), '2026-01-15');
      final next = jsonMap(r['plan']);
      expect(jsonMap(next['ladders'])['squat']['stage'], 1);
      for (final e in [
        jsonRows(jsonMap(next['workouts'])['a']['exercises']).first,
        jsonRows(jsonMap(jsonMap(next['workouts'])['a']['gym'])['exercises'])
            .first,
      ]) {
        expect(e['ladder'], 'squat');
        expect(plans.resolveEx(next, e)['name'], '停顿深蹲');
      }
      // 旧计划对象没被改。
      expect(
        plan['workouts']['a']['exercises'][0].containsKey('ladder'),
        false,
      );
    });

    test('忽略后 14 天内不再提', () {
      final ex = bodyweight('深蹲');
      final s = ask(ex, oldPlan(ex))!;
      final progress = p.decline(atCap(ex), '${s['key']}', '2026-01-10');
      expect(
        ask(ex, oldPlan(ex), progress: progress)?['kind'],
        isNot('ladder'),
      );
    });

    test('不会误加：加了重量的、计时的、已有同名阶梯的、成长期、网页对照模式', () {
      final ex = bodyweight('深蹲');
      expect(ask({...ex, 'weight': 10}, oldPlan(ex))?['kind'], isNot('ladder'));
      expect(
        ask({...ex, 'machine': true}, oldPlan(ex))?['kind'],
        isNot('ladder'),
      );
      final withLadder = {
        ...oldPlan(ex),
        'ladders': {'squat': buildLadder('squat')},
      };
      expect(ask(ex, withLadder)?['kind'], isNot('ladder'));
      expect(
        ask(
          ex,
          oldPlan(ex),
          options: const ProgressOptions(stage: 'youth'),
        )?['kind'],
        isNot('ladder'),
      );
      expect(ask(ex, oldPlan(ex), options: null)?['kind'], isNot('ladder'));
      expect(ask(bodyweight('高脚杯深蹲'), oldPlan(ex))?['kind'], isNot('ladder'));
      // 已经是这条阶梯最后一级：没有下一级可建议。
      expect(
        ask(bodyweight('慢速保加利亚分腿蹲'), oldPlan(ex))?['kind'],
        isNot('ladder'),
      );
    });

    test('疼痛后不建议升级', () {
      final ex = bodyweight('臀桥');
      final days = {
        ...history(ex, 2, reps: 15, rir: 2),
        '2026-01-12': session(ex, '', 15, flag: 'pain'),
      };
      final s = p.suggest(ex, {
        'plan': oldPlan(ex),
        'days': days,
        'today': '2026-01-15',
      }, options: const ProgressOptions(experience: 'new'));
      expect(s?['kind'], 'pain');
    });
  });

  test('ladderMatch 与 ladderLabel', () {
    expect(ladderMatch(bodyweight('单腿臀桥'))?.id, 'bridge');
    expect(ladderMatch(bodyweight('单腿臀桥'))?.stage, 2);
    expect(ladderMatch(exercise(name: '哑铃卧推')), isNull);
    expect(ladderLabel('pushup', {}), '俯卧撑');
    expect(ladderLabel('core', {'label': '腹肌'}), '腹肌');
  });
}
