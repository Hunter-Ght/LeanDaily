import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/domain/e1rm.dart';
import 'package:leandaily/domain/progress.dart' as p;
import 'package:leandaily/domain/records.dart' as records;
import 'package:leandaily/domain/stats.dart' as stats;

void main() {
  test('Epley：重量 × (1 + 次数 / 30)，自重为 0', () {
    expect(estimateE1rm(60, 6), 72);
    expect(estimateE1rm(100, 1), closeTo(103.333, 1e-3));
    expect(estimateE1rm(0, 12), 0);
    expect(estimateE1rmRounded(100, 1), 103.3);
    expect(estimateE1rmRounded(22.5, 10), 30);
  });

  test('可靠区间：1～12 次', () {
    expect([0, 1, 12].map(e1rmReliable), [false, true, true]);
    expect(e1rmReliable(13), false);
  });

  test('进度页、记录导出、新纪录用同一口径', () {
    final days = {
      '2026-01-05': {
        'sets': [
          {'ex': '哑铃卧推', 'w': 20, 'reps': 10, 'type': '正式'},
        ],
      },
    };
    final best =
        (stats.buildStats('2026-01-07', null, null, days: days)['bests']
                    as List)
                .single
            as Map;
    expect(best['e1'], estimateE1rmRounded(20, 10));
    // 同一组成绩：不是新纪录；多 1 次才是。
    expect(p.isPersonalBest(days, '哑铃卧推', 10, 20), false);
    expect(p.isPersonalBest(days, '哑铃卧推', 11, 20), true);
    // 自重动作比次数。
    final bw = {
      '2026-01-05': {
        'sets': [
          {'ex': '深蹲', 'w': 0, 'reps': 15, 'type': '正式'},
        ],
      },
    };
    expect(p.isPersonalBest(bw, '深蹲', 16, 0), true);
    expect(strengthMetric(0, 15), 15);
    expect(strengthMetric(20, 10), estimateE1rm(20, 10));
  });

  test('除 e1rm.dart 外，领域层不再有自己的 1 + 次数 / 30', () {
    for (final f
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where(
              (f) => f.path.endsWith('.dart') && !f.path.endsWith('e1rm.dart'),
            )) {
      expect(
        RegExp(r'1 \+ [^;]*/ 30\)').hasMatch(f.readAsStringSync()),
        false,
        reason: f.path,
      );
    }
    expect(records.r1(1.04), 1);
  });
}
