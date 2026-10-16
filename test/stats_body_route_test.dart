import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/ui/stats/stats_page.dart';

import 'support/harness.dart';

void main() {
  setUpAll(Harness.setUpAll);
  for (final dark in [false, true]) {
    for (final mode in ['cut', 'bulk', 'empty']) {
      testWidgets('progress $mode $dark', (tester) async {
        final h = await Harness.pump(
          tester,
          tab: 2,
          dark: dark,
          size: const Size(393, 852),
          seed: (n) {
            if (mode != 'empty') {
              n.docs['fw-profile-v1'] = jsonEncode({
                'age': 30,
                'heightCm': 180,
                'weightKg': mode == 'cut' ? 82 : 62,
                'bodyFatPct': mode == 'cut' ? 28 : 9,
                'bodyFatMethod': 'manual',
                'goalBodyFatPct': 15,
              });
              n.docs['fw-body-v1'] = jsonEncode({
                'v': 1,
                'entries': [
                  for (var i = 0; i < 84; i++)
                    {
                      'date': DateTime(
                        2026,
                        7,
                        25 + i,
                      ).toIso8601String().substring(0, 10),
                      'weightKg': mode == 'cut' ? 82 - i * .045 : 62 + i * .04,
                    },
                ],
              });
            }
          },
        );
        expect(find.byType(StatsPage), findsOneWidget);
        expect(find.text('本周总览'), findsOneWidget);
        expect(find.text('今天'), findsNothing);
        if (mode == 'empty') {
          expect(find.text('记录体重，看见趋势'), findsOneWidget);
        }
        if (mode == 'cut') {
          expect(find.textContaining('估算 '), findsWidgets);
        }
        if (mode == 'bulk') {
          expect(find.textContaining('每周增重参考'), findsOneWidget);
        }
        await h.shot(
          tester,
          'r-progress${mode == 'cut' ? '' : '-$mode'}-${dark ? 'dark' : 'light'}',
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('bodyweight chart uses repetitions', (tester) async {
    final h = await Harness.pump(
      tester,
      tab: 2,
      empty: true,
      size: const Size(393, 2000),
    );
    await h.controller.repo.addSets(
      date: h.controller.today,
      part: '胸',
      exercise: '俯卧撑',
      rows: [
        {'weight': 0, 'reps': 9, 'type': '正式'},
      ],
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.text('次数'), findsOneWidget);
    expect(find.text('自重 × 9 次'), findsOneWidget);
    expect(find.text('0 kg'), findsNothing);
    expect(find.bySemanticsLabel('俯卧撑 的次数'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('review and personal bests expand on demand', (tester) async {
    final h = await Harness.pump(tester, tab: 2, size: const Size(393, 2600));
    for (var i = 0; i < 7; i++) {
      await h.controller.repo.addSets(
        date: h.controller.today,
        part: '胸',
        exercise: '测试动作$i',
        rows: [
          {'weight': 10 + i, 'reps': 10, 'type': '正式'},
        ],
      );
    }
    await tester.pumpAndSettle();
    expect(find.text('查看全部'), findsOneWidget);
    await tester.ensureVisible(find.text('查看全部'));
    await tester.tap(find.text('查看全部'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 7; i++) {
      expect(find.text('测试动作$i'), findsWidgets);
    }
    await tester.ensureVisible(find.text('展开全部肌肉'));
    await tester.tap(find.text('展开全部肌肉'));
    await tester.pumpAndSettle();
    expect(find.text('展开全部肌肉'), findsNothing);
    expect(find.text('收起'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
