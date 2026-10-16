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
    await rootBundle.loadString('assets/body_paths.json');
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
      expect(find.text('本周总览'), findsOneWidget);
      expect(find.text('个人最佳'), findsOneWidget);
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
    expect(find.text('还没有正式组。'), findsOneWidget);
    expect(find.text('记过正式组之后，这里会画出每次的估算极限。'), findsOneWidget);
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
    expect(find.text('还没有正式组。'), findsNothing);
    expect(find.text('记过正式组之后，这里会画出每次的估算极限。'), findsNothing);
    expect(find.bySemanticsLabel('哑铃卧推 的估算极限'), findsOneWidget);
    final state = jsonMap(jsonDecode(h.native.docs['android-state']!));
    expect(
      jsonMap(state['sets']).values.any((r) => jsonMap(r)['ex'] == '哑铃卧推'),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}
