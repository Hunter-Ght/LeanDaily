import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

/// 一年多的真实规模数据：启动和切换标签页不能卡死。
void main() {
  setUpAll(Harness.setUpAll);

  testWidgets('18 months of history boots and renders quickly', (tester) async {
    final legacy = (jsonDecode(File('test/fixtures/legacy_store.json').readAsStringSync()) as Map).cast<String, String>();
    final state = jsonDecode(legacy['android-state']!) as Map<String, dynamic>;
    final rnd = Random(7);
    final sets = <String, dynamic>{...(state['sets'] as Map).cast<String, dynamic>()};
    final meals = <String, dynamic>{...(state['meals'] as Map).cast<String, dynamic>()};
    final names = ['高位俯卧撑', '哑铃地板卧推', '单臂哑铃划船', '反向卷腹', '平板支撑', '深蹲', '卧推', '引体向上', '硬拉', '侧平举', '哑铃弯举', '腿举', '坐姿推胸机'];
    final parts = ['胸', '胸', '背', '核心', '核心', '腿', '胸', '背', '背', '肩', '手臂', '腿', '胸'];
    var n = 0;
    final today = DateTime(2026, 10, 16);
    for (var d = 1; d < 550; d++) {
      if (rnd.nextInt(3) != 0) continue;
      final day = today.subtract(Duration(days: d));
      final iso = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      for (var e = 0; e < 5 + rnd.nextInt(4); e++) {
        final k = rnd.nextInt(names.length);
        for (var j = 1; j <= 2 + rnd.nextInt(3); j++) {
          final id = '00000000-0000-4000-8000-${(n++).toString().padLeft(12, '0')}';
          sets[id] = {'id': id, 'ts': day.millisecondsSinceEpoch + j * 1000, 'date': iso, 'part': parts[k], 'ex': names[k], 'no': j, 'w': rnd.nextInt(40).toDouble(), 'reps': 6 + rnd.nextInt(10), 'type': j == 1 && rnd.nextBool() ? '热身' : '正式', 'rpe': rnd.nextBool() ? 7 + rnd.nextInt(3) : null, 'notes': ''};
        }
      }
      final mid = 'm${d}a';
      meals[mid] = {'record_id': mid, 'date': iso, 'meal': '午餐', 'time': '12:00', 'note': '', 'source': '手动填写', 'items': [{'name': '饭', 'portion': '1碗', 'kcal': 500, 'protein': 20, 'carbs': 70, 'fat': 10}], 'photo_ids': <String>[], 'kcal': 500, 'protein': 20, 'carbs': 70, 'fat': 10};
    }
    state['sets'] = sets;
    state['meals'] = meals;
    final docs = {...legacy, 'android-state': jsonEncode(state)};
    final watch = Stopwatch()..start();
    final h = await Harness.pump(tester, empty: true, seed: (nat) => nat.docs.addAll(docs));
    expect(h.controller.booted, isTrue, reason: h.controller.bootError);
    final boot = watch.elapsedMilliseconds;
    for (final tab in [1, 2, 0]) {
      h.controller.setTab(tab);
      await tester.pumpAndSettle();
    }
    // ignore: avoid_print
    print('sets=${sets.length} boot=${boot}ms total=${watch.elapsedMilliseconds}ms');
    expect(watch.elapsedMilliseconds, lessThan(20000));
  });
}
