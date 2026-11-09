import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/ui/stats/stats_page.dart';
import 'package:leandaily/domain/format.dart';
import 'package:leandaily/ui/stats/muscle/muscle_card.dart';

import 'support/harness.dart';

void main() {
  setUpAll(() async {
    await Harness.setUpAll();
    await rootBundle.loadString('assets/muscle_map.json');
  });
  for (final dark in [false, true]) {
    testWidgets('stats ${dark ? 'dark' : 'light'} screenshot', (tester) async {
      final h = await Harness.pump(
        tester,
        tab: 2,
        dark: dark,
        size: const Size(393, 2600),
      );
      debugDisableShadows = true;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      expect(find.text('力量'), findsOneWidget);
      expect(find.text('坚持'), findsOneWidget);
      expect(find.text('本周达成'), findsOneWidget);
      expect(find.text('本周回顾'), findsOneWidget);
      expect(find.text('本周总览'), findsNothing);
      expect(find.text('个人最佳'), findsNothing);
      expect(find.text('动作曲线'), findsNothing);
      expect(find.byType(MuscleCard), findsNothing);
      await tester.tap(find.text('查看每块肌肉'));
      await tester.pumpAndSettle();
      expect(find.byType(MuscleCard), findsOneWidget);
      await h.shot(tester, 'stats-${dark ? 'dark' : 'light'}');
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('empty and wide summary, live repository updates', (
    tester,
  ) async {
    final h = await Harness.pump(
      tester,
      tab: 2,
      empty: true,
      size: const Size(1000, 1000),
    );
    debugDisableShadows = true;
    // 没有训练记录：只有一个引导 + 体重，没有空的力量 / 坚持块。
    expect(find.text('练 3 次后，这里会出现你的身体热力图和力量变化'), findsOneWidget);
    expect(find.text('开始今天的训练'), findsOneWidget);
    expect(find.text('力量'), findsNothing);
    expect(find.text('坚持'), findsNothing);
    expect(find.text('体重'), findsOneWidget);
    expect(find.byType(StatsPage), findsOneWidget);
    expect(tester.takeException(), isNull);
    await h.controller.repo.addSets(
      date: h.controller.today,
      part: '胸',
      exercise: '哑铃卧推',
      rows: [
        {'weight': 12, 'reps': 10, 'type': '正式'},
      ],
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.text('练 3 次后，这里会出现你的身体热力图和力量变化'), findsNothing);
    expect(find.text('力量'), findsOneWidget);
    expect(find.text('坚持'), findsOneWidget);
    expect(find.text('首次记录'), findsOneWidget);
    // 只有 1 个数据点：点开后不画空坐标，给一句提示。
    await tester.tap(find.text('哑铃卧推'));
    await tester.pumpAndSettle();
    expect(find.text('再练几次就能看到曲线'), findsOneWidget);
    expect(find.bySemanticsLabel('哑铃卧推 的估算极限'), findsNothing);
    // 同一动作再练一天：有了 2 个点，展开后画曲线。
    await h.controller.repo.addSets(
      date: '2026-10-10',
      part: '胸',
      exercise: '哑铃卧推',
      rows: [
        {'weight': 10, 'reps': 10, 'type': '正式'},
      ],
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.text('再练几次就能看到曲线'), findsNothing);
    expect(find.bySemanticsLabel('哑铃卧推 的估算极限'), findsOneWidget);
    final state = jsonMap(jsonDecode(h.native.docs['android-state']!));
    expect(
      jsonMap(state['sets']).values.any((r) => jsonMap(r)['ex'] == '哑铃卧推'),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}
