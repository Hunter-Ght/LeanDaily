import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/domain/muscle_brief.dart';
import 'package:leandaily/domain/progress_options.dart';
import 'package:leandaily/domain/stats_range.dart';
import 'package:leandaily/domain/strength_hint.dart';
import 'package:leandaily/domain/strength_rows.dart';
import 'package:leandaily/domain/units.dart';

const _today = '2026-11-04';

Map<String, dynamic> _pt(String iso, num weight, num reps) => {
  'iso': iso,
  'weight': weight,
  'reps': reps,
  'e1': weight * (1 + reps / 30),
};

StrengthRow _row(
  String name,
  List<Map<String, dynamic>> points, {
  Set<String> timed = const {},
}) => strengthRows(
  exercises: [
    {'ex': name, 'points': points},
  ],
  bests: [
    {
      'ex': name,
      'heavy': points
          .map((p) => p['weight'] as num)
          .reduce((a, b) => a > b ? a : b),
      'heavyReps': points.last['reps'],
      'e1': points.last['e1'],
    },
  ],
  today: _today,
  range: StatsRange.weeks4,
  timedNames: timed,
).single;

/// 一次训练（每组同样次数）。
Map<String, dynamic> _day(String name, num w, List<num> reps, {String? flag}) =>
    {
      'sets': [
        for (final r in reps)
          {'ex': name, 'reps': r, 'w': w, 'rpe': 7, 'flag': ?flag},
      ],
    };

Map<String, dynamic> _plan(Map<String, dynamic> ex) => {
  'startDate': '2026-01-01',
  'workouts': {
    'a': {
      'exercises': [ex],
    },
  },
  'ladders': <String, dynamic>{},
};

StrengthStep? _step(
  Map<String, dynamic> ex,
  Map<String, dynamic> days, {
  ProgressOptions? options,
}) => strengthStepFor(
  '${ex['name']}',
  plan: _plan(ex),
  days: days,
  dayStates: const {},
  progress: const {},
  today: _today,
  options: options ?? const ProgressOptions(),
);

void main() {
  const weighted = {
    'id': 'e1',
    'name': '杠铃卧推',
    'part': '胸',
    'sets': 2,
    'min': 8,
    'max': 12,
    'weight': 40,
    'machine': true,
  };
  const bodyweight = {
    'id': 'e2',
    'name': '标准俯卧撑',
    'part': '胸',
    'sets': 2,
    'min': 8,
    'max': 12,
    'weight': 0,
  };
  const timed = {
    'id': 'e3',
    'name': '平板支撑',
    'part': '腹',
    'sets': 2,
    'min': 30,
    'max': 60,
    'unit': 'sec',
    'weight': 0,
  };

  group('只记录 1 次', () {
    test('带重量、自重、计时都是同一句', () {
      for (final r in [
        _row('杠铃卧推', [_pt('2026-11-01', 40, 8)]),
        _row('标准俯卧撑', [_pt('2026-11-01', 0, 8)]),
        _row('平板支撑', [_pt('2026-11-01', 0, 30)], timed: {'平板支撑'}),
      ]) {
        expect(
          strengthCaption(r, range: StatsRange.weeks4),
          '已记录 1 次，再练一次就能看到变化',
        );
      }
    });
  });

  group('有变化', () {
    test('带重量：估算极限，公制 kg，英制 lb', () {
      final r = _row('杠铃卧推', [
        _pt('2026-09-20', 50, 10),
        _pt('2026-10-20', 60, 10),
      ]);
      expect(r.change, StrengthChange.up);
      expect(
        strengthCaption(r, range: StatsRange.weeks4),
        '↑ 估算极限 +13.3 kg（比4 周前）',
      );
      // 13.3 kg = 29.3 lb
      expect(
        strengthCaption(r, range: StatsRange.weeks4, units: Units.imperial),
        '↑ 估算极限 +29.3 lb（比4 周前）',
      );
    });

    test('自重和计时的变化量不按重量换算（英制也一样）', () {
      final body = _row('标准俯卧撑', [
        _pt('2026-09-20', 0, 8),
        _pt('2026-10-20', 0, 11),
      ]);
      expect(
        strengthCaption(body, range: StatsRange.weeks4, units: Units.imperial),
        '↑ 次数 +3（比4 周前）',
      );
      final sec = _row(
        '平板支撑',
        [_pt('2026-09-20', 0, 30), _pt('2026-10-20', 0, 45)],
        timed: {'平板支撑'},
      );
      expect(sec.timed, isTrue);
      expect(
        strengthCaption(sec, range: StatsRange.weeks4, units: Units.imperial),
        '↑ 时长 +15 秒（比4 周前）',
      );
    });

    test('下降', () {
      final r = _row('杠铃卧推', [
        _pt('2026-09-20', 60, 10),
        _pt('2026-10-20', 50, 10),
      ]);
      expect(
        strengthCaption(r, range: StatsRange.weeks4, units: Units.imperial),
        '估算极限 −29.3 lb（比4 周前）',
      );
    });

    test('范围内没练过', () {
      final r = _row('杠铃卧推', [
        _pt('2026-08-01', 50, 10),
        _pt('2026-08-20', 50, 10),
      ]);
      expect(r.change, StrengthChange.idle);
      expect(strengthCaption(r, range: StatsRange.weeks4), '近 4 周没练过');
    });
  });

  group('持平：离下一步还差什么', () {
    final flatWeighted = _row('杠铃卧推', [
      _pt('2026-10-01', 40, 10),
      _pt('2026-10-30', 40, 10),
    ]);
    final flatBody = _row('标准俯卧撑', [
      _pt('2026-10-01', 0, 10),
      _pt('2026-10-30', 0, 10),
    ]);
    final flatTimed = _row(
      '平板支撑',
      [_pt('2026-10-01', 0, 40), _pt('2026-10-30', 0, 40)],
      timed: {'平板支撑'},
    );

    String text(StrengthRow r, StrengthStep? s, [Units u = Units.metric]) =>
        strengthCaption(r, range: StatsRange.weeks4, units: u, step: s);

    test('拿不到进阶状态：与上次持平', () {
      expect(flatWeighted.change, StrengthChange.flat);
      expect(text(flatWeighted, null), '与上次持平');
      // 计划里没有这个动作
      expect(
        strengthStepFor(
          '计划外动作',
          plan: _plan(weighted),
          days: const {},
          dayStates: const {},
          progress: const {},
          today: _today,
          options: const ProgressOptions(),
        ),
        isNull,
      );
    });

    test('带重量：上次没到目标', () {
      final days = {
        '2026-10-01': _day('杠铃卧推', 40, [10, 10]),
        '2026-10-30': _day('杠铃卧推', 40, [9, 10]),
      };
      // 起始目标 8 次，两次都做到了；用更高的下限造「没做到」
      final hard = {...weighted, 'min': 10, 'max': 12};
      expect(text(flatWeighted, _step(hard, days)), '目标 10 次，上次做到 9 次');
      // 英制只是显示，文案里没有重量
      expect(
        text(
          flatWeighted,
          _step(
            hard,
            days,
            options: const ProgressOptions(units: Units.imperial),
          ),
          Units.imperial,
        ),
        '目标 10 次，上次做到 9 次',
      );
    });

    test('带重量：做满上限，再做满几次就加重量', () {
      final one = {
        '2026-10-01': _day('杠铃卧推', 40, [12, 12]),
        '2026-10-30': _day('杠铃卧推', 40, [12, 12]),
      };
      // 目标要先升到 12：下限设成 12，做满即进入「做满」计数
      final cap = {...weighted, 'min': 12, 'max': 12};
      expect(text(flatWeighted, _step(cap, one)), '再做满 1 次 12 次就加重量');
      final first = {
        '2026-10-30': _day('杠铃卧推', 40, [12, 12]),
      };
      expect(text(flatWeighted, _step(cap, first)), '再做满 1 次 12 次就加重量');
      expect(
        text(
          flatWeighted,
          _step(
            cap,
            first,
            options: const ProgressOptions(experience: 'trained'),
          ),
        ),
        '再做满 2 次 12 次就加重量',
      );
      final done = {
        '2026-10-20': _day('杠铃卧推', 40, [12, 12]),
        ...one,
      };
      expect(text(flatWeighted, _step(cap, done)), '已稳定做满 12 次，可以加重量了');
    });

    test('自重：做满上限是升级难度，不是加重量', () {
      final cap = {...bodyweight, 'min': 12, 'max': 12};
      final days = {
        '2026-10-30': _day('标准俯卧撑', 0, [12, 12]),
      };
      expect(text(flatBody, _step(cap, days)), '再做满 1 次 12 次就升级难度');
    });

    test('自重：差一次就加目标', () {
      final days = {
        '2026-10-01': _day('标准俯卧撑', 0, [10, 10]),
        '2026-10-30': _day('标准俯卧撑', 0, [10, 10]),
      };
      // 目标 10（下限）：连续做到 1 次，再做到 1 次目标升到 11
      final ex = {...bodyweight, 'min': 10, 'max': 15};
      final step = _step(ex, {'2026-10-30': days['2026-10-30']!});
      expect(text(flatBody, step), '再做到 10 次，目标就提到 11 次');
    });

    test('计时：按秒说，每档 5 秒', () {
      final ex = {...timed, 'min': 40, 'max': 60};
      final hit = {
        '2026-10-30': _day('平板支撑', 0, [40, 40]),
      };
      expect(text(flatTimed, _step(ex, hit)), '再做到 40 秒，目标就提到 45 秒');
      final miss = {
        '2026-10-30': _day('平板支撑', 0, [35, 40]),
      };
      expect(text(flatTimed, _step(ex, miss)), '目标 40 秒，上次做到 35 秒');
      final cap = {...timed, 'min': 60, 'max': 60};
      final full = {
        '2026-10-30': _day('平板支撑', 0, [60, 60]),
      };
      expect(text(flatTimed, _step(cap, full)), '再做满 1 次 60 秒就升级难度');
    });

    test('上次标了不适，不谈进阶', () {
      final days = {
        '2026-10-30': _day('杠铃卧推', 40, [10, 10], flag: 'pain'),
      };
      expect(text(flatWeighted, _step(weighted, days)), '上次标了不舒服，这次先不加量');
    });
  });

  group('muscleBrief', () {
    final days = <String, Map<String, dynamic>>{
      '2026-10-20': _day('杠铃卧推', 40, [10, 10, 10]),
      '2026-11-02': _day('标准俯卧撑', 0, [10, 10]),
      '2026-08-01': _day('杠铃卧推', 40, [10]),
    };
    final window = rangeWindow(StatsRange.weeks4, _today);

    test('范围内的组数、上次练的日期、最常练的动作', () {
      final b = muscleBrief(days, 'chest', window, _today);
      expect(b.sets, 5);
      expect(b.lastDate, '2026-11-02');
      expect(b.daysSince, 2);
      expect(b.top, ['杠铃卧推', '标准俯卧撑']);
    });

    test('范围外练过：组数 0，仍给出上次日期', () {
      final b = muscleBrief(
        {'2026-08-01': days['2026-08-01']!},
        'chest',
        window,
        _today,
      );
      expect(b.sets, 0);
      expect(b.top, isEmpty);
      expect(b.lastDate, '2026-08-01');
    });

    test('从没练到过', () {
      final b = muscleBrief(days, 'calves', window, _today);
      expect(b.sets, 0);
      expect(b.lastDate, isNull);
      expect(b.daysSince, isNull);
    });

    test('多久没练的说法', () {
      expect(sinceText(0), '今天');
      expect(sinceText(3), '3 天前');
      expect(sinceText(21), '3 周前');
      expect(sinceText(120), '4 个月前');
    });
  });
}
